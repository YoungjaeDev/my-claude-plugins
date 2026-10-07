# review-loop run blocks

The shell each step of `SKILL.md` runs, in run order. SKILL.md keeps the step sequence and each step's decision rule; each section below is named in the step that runs it and is run verbatim, in the one shell session the whole run shares (variables set in one block are read by later ones). Every `scripts/` path resolves against `SKILL_DIR` from Step 1.

## Step 2: repo, PR and counters

```bash
REPO_ROOT=$(git rev-parse --show-toplevel); cd "$REPO_ROOT"
START_SHA=$(git rev-parse HEAD)
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')
PR_NUM=$(gh pr list --head "$(git branch --show-current)" --state open --json number --jq '.[0].number // empty')
applied_total=0; deferred_total=0; skipped_total=0
review_total=0  # `review`-tier findings nobody could read; Step 14 files them too
verification_blocking=false; VERIFICATION_GATE=unknown
codex_active=unknown; codex_review_id_to_process=""
cli_invocations=0; rate_limit_hits=0
auto_judge_apply=0; auto_judge_defer=0; auto_judge_skip=0
# HOLD_STATE: a Step 13 stop waiting on the pushed HEAD's verdicts. HEAD_VERDICT:
# empty, or why the last HEAD was left unverified (timeout | unread) for Step 14.
HOLD_STATE=""; HEAD_VERDICT=""; pushed_this_cycle=false
```

## Step 2: draft PR

```bash
# CodeRabbit skips draft PRs unless `drafts: true`, so a draft only waits out the caps.
if [ "$(gh pr view "$PR_NUM" --json isDraft --jq '.isDraft')" = true ]; then
  echo "review-loop: PR #$PR_NUM is a draft and CodeRabbit does not review drafts. Run \`gh pr ready $PR_NUM\`, then re-run review-loop." >&2
  exit 1
fi
```

## Step 2: base branch and review request

```bash
BASE=$(gh pr view "$PR_NUM" --json baseRefName --jq '.baseRefName')
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')
# `request` when CodeRabbit will not auto-review a PR into $BASE: not the default
# branch, no reviews.auto_review.base_branches match, and auto-review not switched
# off (enabled: false wins, to save quota). No config file -> `request`.
CR_REVIEW_REQUEST=$(bash "$SKILL_DIR/scripts/cr-review-request.sh" "$BASE" "$DEFAULT_BRANCH" .coderabbit.yaml)
```

## Step 2: request_cr_review

```bash
# Posts `@coderabbitai review` for HEAD when the PR bot is the source and either
# CodeRabbit will not auto-review this base (Step 2) or, with `paused`, it paused
# automatic reviews (any base).
request_cr_review() {  # GitHub comments are the record; no state file
  local since decision
  case "$CR_SOURCE" in auto|pr-bot) : ;; *) return 0 ;; esac
  [ "$CR_REVIEW_REQUEST" = request ] || [ "${1:-}" = paused ] || return 0
  since=$(bash "$SKILL_DIR/scripts/push-time.sh" "$OWNER" "$REPO" "$(git rev-parse HEAD)")
  # Exit 1 = comments unreadable: do not post blind (the script logs why).
  decision=$(bash "$SKILL_DIR/scripts/cr-review-posted.sh" "$OWNER" "$REPO" "$PR_NUM" "$since") || return 0
  [ "$decision" = post ] && gh pr comment "$PR_NUM" --body "@coderabbitai review"
}
# Which reviewers are on now (Step 2b and pre-flight can drop one): cr_on, codex_on.
reviewers_on() {
  cr_on=false; case "$CR_SOURCE" in auto|pr-bot) cr_on=true ;; esac
  codex_on=auto; if [ "$NO_CODEX" = true ] || [ "$codex_active" = disabled ]; then codex_on=false; fi
}
# Waits, inside the existing caps (TIMEOUT for CodeRabbit, the Codex wait budget),
# until every reviewer this run has on gave HEAD a verdict. Sets hv (one JSON line,
# scripts/head-verdicts.sh) and hv_state: ready | timeout | codex_failed. A paused
# CodeRabbit (auto_pause_after_reviewed_commits) gets one `@coderabbitai review` for
# this HEAD, then the wait resumes on the same push-anchored budget.
await_head_verdicts() {
  local sha pt round cr_on codex_on
  sha=$(git rev-parse HEAD)
  pt=$(bash "$SKILL_DIR/scripts/push-time.sh" "$OWNER" "$REPO" "$sha")
  reviewers_on
  for round in 1 2; do
    # Bash(run_in_background=true, timeout=(TIMEOUT+CODEX_GRACE)*1000) + Monitor: one JSON line.
    hv=$(OWNER="$OWNER" REPO="$REPO" PR_NUM="$PR_NUM" CUR_SHA="$sha" PUSH_TIME="$pt" \
         CR_ON="$cr_on" CODEX_ON="$codex_on" TIMEOUT="$TIMEOUT" INTERVAL="$INTERVAL" \
         CODEX_GRACE="$CODEX_GRACE" bash "$SKILL_DIR/scripts/head-verdicts.sh")
    hv_state=$(jq -r '.state // empty' <<<"$hv" 2>/dev/null) || hv_state=""
    [ -n "$hv_state" ] || hv_state=timeout  # no line: the wait was cut off
    [ "$hv_state" = paused ] || return 0
    if [ "$round" = 1 ]; then request_cr_review paused; fi  # posts only when this HEAD has no request yet
  done
  hv_state=timeout  # still paused: the request did not land
}
# Before iter 1: the PR's opening push was never auto-reviewed.
request_cr_review
```

## Step 2: state init

```bash
mkdir -p .claude/state/archive
PRIOR_PROCESSED='[]'; PRIOR_CR_PROCESSED='[]'; PRIOR_ISSUE='null'
# Step 16's EXIT trap archives the live file, so on the next run the live path is
# usually absent — fall back to the newest archive or the Codex dedupe resets.
# `|| true`: a first run has no archive at all.
PRIOR_STATE=".claude/state/review-loop-${PR_NUM}.json"
[ -f "$PRIOR_STATE" ] || PRIOR_STATE=$(ls -1t ".claude/state/archive/review-loop-${PR_NUM}-"*.json 2>/dev/null | head -1 || true)
if [ -n "$PRIOR_STATE" ] && [ -f "$PRIOR_STATE" ]; then
  # Fail loud before creating a new state file: a silently reset dedupe re-judges
  # every already-processed Codex review.
  # The follow-up issue is inherited too, or every re-run on the same PR opens another one.
  PRIOR_ISSUE=$(jq -c '.followup_issue // null' "$PRIOR_STATE" 2>/dev/null) || PRIOR_ISSUE='null'
  PRIOR_PROCESSED=$(jq -c '.codex_processed_reviews // []' "$PRIOR_STATE" 2>/dev/null) || {
    echo "review-loop: prior state $PRIOR_STATE unparseable — aborting before the Codex dedupe is reset" >&2
    exit 1
  }
  # Same for CodeRabbit reviews whose outside-diff findings were already judged.
  PRIOR_CR_PROCESSED=$(jq -c '.cr_processed_reviews // []' "$PRIOR_STATE" 2>/dev/null) || {
    echo "review-loop: prior state $PRIOR_STATE unparseable — aborting before the CodeRabbit dedupe is reset" >&2
    exit 1
  }
  # Only the live file is archived; the $$ suffix keeps a same-second or parallel
  # run from clobbering an archive.
  if [ "$PRIOR_STATE" = ".claude/state/review-loop-${PR_NUM}.json" ]; then
    mv "$PRIOR_STATE" ".claude/state/archive/review-loop-${PR_NUM}-$(date +%Y%m%d-%H%M%S)-$$.json" \
      || { echo "review-loop: failed to archive prior state" >&2; exit 1; }
  fi
fi
STATE_FILE=".claude/state/review-loop-${PR_NUM}.json"
jq -n --arg sha "$START_SHA" --argjson prior "$PRIOR_PROCESSED" --argjson crprior "$PRIOR_CR_PROCESSED" \
  --argjson issue "$PRIOR_ISSUE" --arg src "$CR_SOURCE" \
  '{start_sha:$sha,iter:0,applied_total:0,deferred_total:0,codex_processed_reviews:$prior,cr_processed_reviews:$crprior,followup_issue:$issue,cr_source:($src // "pending"),pre_flight_decisions:[],auto_judge_log:[]}' \
  > "$STATE_FILE"

TRACK_FILE="/tmp/review-loop-${PR_NUM}-modified.list"; : > "$TRACK_FILE"
```

## Step 2: final-JSON trap

```bash
trap 'ITER=${ITER:-0} APPLIED_TOTAL=$applied_total DEFERRED_TOTAL=$deferred_total \
  SKIPPED_TOTAL=$skipped_total CODEX_STATE=$codex_active FINAL_STATE=${final_state:-unknown} \
  MERGED=${merged:-false} PR_NUM=$PR_NUM LAST_SHA=$(git rev-parse HEAD 2>/dev/null) \
  CR_SOURCE=$CR_SOURCE CLI_INVOCATIONS=$cli_invocations RATE_LIMIT_HITS=$rate_limit_hits \
  AUTO_JUDGE_APPLY=$auto_judge_apply AUTO_JUDGE_DEFER=$auto_judge_defer AUTO_JUDGE_SKIP=$auto_judge_skip \
  TRACK_FILE=$TRACK_FILE STATE_FILE=$STATE_FILE VERIFICATION_GATE=$VERIFICATION_GATE \
  bash $SKILL_DIR/scripts/emit-final-json.sh' EXIT
```

## Step 2b: reviewer availability

```bash
# Signals from an earlier push do not count: its quota may be back.
SINCE=$(bash "$SKILL_DIR/scripts/push-time.sh" "$OWNER" "$REPO" "$START_SHA")
if ru=$(CR_SOURCE="$CR_SOURCE" NO_CODEX="$NO_CODEX" SINCE="$SINCE" \
        bash "$SKILL_DIR/scripts/reviewer-availability.sh" "$OWNER" "$REPO" "$PR_NUM"); then
  case "$(jq -r '.action' <<<"$ru")" in
    drop_codex) NO_CODEX=true; codex_active=disabled ;;  # no Codex grace wait, no Codex fetch
    drop_cr)
      # No CR poll: the remaining reviewer is Codex, so the run becomes codex-only.
      CR_SOURCE=codex-only
      tmp=$(mktemp); jq '.cr_source = "codex-only"' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
      [ "$(bash "$SKILL_DIR/scripts/probe-codex-engagement.sh" "$OWNER" "$REPO" "$PR_NUM")" = active ] \
        || final_state=reviewers_unavailable ;;
    stop) final_state=reviewers_unavailable ;;
  esac
else
  echo "review-loop: reviewer availability not checked (comment fetch failed); keeping the normal wait path" >&2
fi
```

## Step 3: verification baseline

```bash
# VERIFY_CMD: the repo's build + test line, from AGENTS.md (Step 3) or the project's
# own entry points; empty when the repo names none. Lint is not part of it.
VERIFY_CMD="${VERIFY_CMD:-}"
VERIFICATION_GATE=$(NO_BUILD="$NO_BUILD" bash "$SKILL_DIR/scripts/verify-fix.sh" baseline "$VERIFY_CMD")
[ "$VERIFICATION_GATE" = on ] \
  || echo "review-loop: verification gate off ($VERIFICATION_GATE) — fixes will be committed unverified" >&2
```

## Step 5: loop head and pre-flight

Opens the per-iteration loop. Steps 5a to 13 run inside it; the Step 13 block closes it with `done`.

```bash
for ITER in $(seq 1 $MAX_ITER); do
  # Step 5a, before CUR_SHA is taken.
  if [ "$(gh pr view "$PR_NUM" --json mergeable --jq '.mergeable')" = CONFLICTING ]; then
    # references/merge-conflicts.md: merge origin/$BASE, resolve, re-check, commit, push.
    request_cr_review
    continue  # the merge commit is this iteration's one commit
  fi
  CUR_SHA=$(git rev-parse HEAD)
  pushed_this_cycle=false
  applied_this_cycle=0; deferred_this_cycle=0; high_sev_this_cycle=0
  churn_this_cycle=0; judged_this_cycle=0; review_this_cycle=0; late_p2_this_cycle=0
  # What the PREVIOUS iteration committed, for the Step 9c.4 in_prev_diff axis.
  # Empty on iter 1 or an empty diff both degrade to "no churn" — the safe side.
  PREV_SHA="${ITER_START_SHA:-}"; ITER_START_SHA="$CUR_SHA"
  PUSH_TIME=$(bash $SKILL_DIR/scripts/push-time.sh "$OWNER" "$REPO" "$CUR_SHA")

  if [ "$CR_SOURCE" = "auto" ] || [ "$CR_SOURCE" = "pr-bot" ]; then
    pf=$(OWNER="$OWNER" REPO="$REPO" PR_NUM="$PR_NUM" CUR_SHA="$CUR_SHA" \
         PUSH_TIME="$PUSH_TIME" STATE_FILE="$STATE_FILE" NO_CODEX="$NO_CODEX" CODEX_GRACE="$CODEX_GRACE" \
         bash $SKILL_DIR/scripts/pre-flight.sh 2>/dev/null || echo '{"gate":"cr_wait"}')
    gate=$(jq -r '.gate' <<<"$pf")
    cr_state_pf=$(jq -r '.cr_state' <<<"$pf")
    codex_state_pf=$(jq -r '.codex_state' <<<"$pf")
    codex_latest_id_pf=$(jq -r '.codex_latest_id // empty' <<<"$pf")
    rate_limit_source=$(jq -r '.rate_limit_source' <<<"$pf")
    codex_verdict_pf=$(jq -r '.codex_verdict // empty' <<<"$pf")

    # Persist pre-flight decision into STATE_FILE for diagnostics.
    tmp=$(mktemp); jq --argjson pf "$pf" --argjson iter "$ITER" \
      '.pre_flight_decisions += [($pf + {iter:$iter})]' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"

    # Codex reported Failed on HEAD: no review is coming, and the loop never asks
    # for one (no `@codex` comment). Stop without writing to the PR; the final
    # report tells the user.
    if [ "$codex_verdict_pf" = failed ]; then final_state=codex_failed; break; fi

    case "$gate" in
      proceed)
        # Both reviewers actionable (or one actionable + the other clean):
        # carry the Codex review id forward and skip Step 6/6b/7 entirely.
        [ -n "$codex_latest_id_pf" ] && codex_review_id_to_process="$codex_latest_id_pf"
        # Flip to "active" only on a real Codex signal, or NO_CODEX=true gets
        # revived and Step 6b/8b fetch what the user opted out of.
        if [ "$codex_state_pf" = "disabled" ]; then
          codex_active=disabled
        elif [ -n "$codex_latest_id_pf" ] || [ "$codex_state_pf" = "actionable" ]; then
          codex_active=active
        fi
        ;;
      cr_wait)
        : # fall through to Step 6 polling.
        ;;
      codex_wait)
        # CR is done; force Codex grace polling. Step 6's auto-detect runs only
        # on gate=cr_wait, so without this the Step 6b guard skips polling and
        # loses findings from a Codex review still publishing.
        codex_active=active
        ;;
      rate_limited)
        rate_limit_hits=$((rate_limit_hits+1))
        # Skip Step 6 polling, jump straight to Step 7c fallback resolution.
        ;;
      failure)
        final_state=failure; break
        ;;
    esac
  else
    gate="bypass"  # CLI / codex-only modes
  fi
```

## Step 6: CR status poll

```bash
if [ "$gate" = "cr_wait" ]; then
  # Bash(run_in_background=true, timeout=TIMEOUT*1000):
  #   OWNER=... REPO=... SHA=$CUR_SHA PR_NUM=... INTERVAL=$INTERVAL PUSH_TIME=$PUSH_TIME TIMEOUT=... \
  #     bash $SKILL_DIR/scripts/poll-cr-status.sh
  # Monitor returns one JSON line: {state:"success"|"failure"|"rate_limited", ...}
fi
# CR_SOURCE ∈ {cli, codex-only} sets gate="bypass" (Step 5) — never poll PR-bot in those modes;
# Step 7d (CLI) / Step 8b (Codex inline) handle the source directly.
```

## Step 7: in-progress sniffer

```bash
count=$(bash $SKILL_DIR/scripts/sniff-cr-inprogress.sh "$OWNER" "$REPO" "$PR_NUM" "$PUSH_TIME")
if [ "$count" -gt 0 ]; then sleep "$INTERVAL"; continue; fi  # counts toward iter budget
```

## Step 7b: rate-limit sniff

```bash
rl=$(bash $SKILL_DIR/scripts/sniff-cr-rate-limit.sh "$OWNER" "$REPO" "$PR_NUM" "$PUSH_TIME" || echo '')
reset=$(jq -r '.reset_minutes_estimate // empty' <<<"$rl")
channel=$(jq -r '.channel // empty' <<<"$rl")
permanent=$(jq -r '.permanent // false' <<<"$rl")
```

## Step 7d: CLI review spawn

```bash
# Bash(run_in_background=true, timeout=TIMEOUT*1000):
#   BASE=$BASE PR_NUM=$PR_NUM ITER=$ITER CONFIG_FILES="CLAUDE.md AGENTS.md" \
#     bash $SKILL_DIR/scripts/cr-cli-spawn.sh
# Monitor returns one JSON line: {jsonl:"...", exit:N, emitted_complete:bool, incomplete:bool}
# incomplete=true: no `complete` event, or it carries outcome "failed" / unreviewedFileCount > 0
cli_invocations=$((cli_invocations + 1))
```

## Step 7e: HEAD verdict wait

```bash
# No round fetches, judges or pushes before every reviewer this run has on judged
# HEAD: CodeRabbit drops a review in progress when a new push lands. Also where a
# stop Step 13 held after its push sees the new HEAD's verdicts.
await_head_verdicts
case "$hv_state" in
  ready) : ;;
  codex_failed) final_state=codex_failed; break ;;
  # Budget spent. A held stop keeps its state; Step 14 files the follow-up issue and
  # the Step 15 gate finds no verdict on HEAD, so the PR is not merged.
  *) HEAD_VERDICT=timeout; final_state="${HOLD_STATE:-timeout}"; break ;;
esac
```

## Step 8: fetch CR threads

```bash
cr_records=$(bash $SKILL_DIR/scripts/fetch-cr-threads.sh "$OWNER" "$REPO" "$PR_NUM") \
  || { final_state=failure; break; }
# Outside-diff findings live only in review bodies; add them, merged with any
# thread on the same path and line. An unreadable block fails the round.
cr_processed=$(jq -c '.cr_processed_reviews // []' "$STATE_FILE") || { final_state=failure; break; }
cr_records=$(bash $SKILL_DIR/scripts/fetch-cr-outside-diff.sh "$OWNER" "$REPO" "$PR_NUM" "$cr_processed" <<<"$cr_records") \
  || { final_state=failure; break; }
```

## Step 8b: fetch Codex inline comments

```bash
# A failed fetch is not "Codex said nothing": stop rather than judge a partial set.
codex_records=$(bash $SKILL_DIR/scripts/fetch-codex-comments.sh "$OWNER" "$REPO" "$PR_NUM" "$codex_review_id_to_process") \
  || { final_state=failure; break; }
```

## Step 8c: engagement gate

```bash
# Only a round with no records at all is gated here; records go on to Step 9a, which
# also resolves a held stop on them.
records_n=$(jq -s 'add | length' <(echo "${cr_records:-[]}") <(echo "${codex_records:-[]}")) \
  || { final_state=failure; break; }
cr_engagement=""; cr_verdict=""
if [ "$records_n" = 0 ]; then
  # A held stop whose new HEAD brought nothing to fetch ends as held.
  if [ -n "$HOLD_STATE" ]; then final_state="$HOLD_STATE"; break; fi
  cr_engagement=$(bash $SKILL_DIR/scripts/engagement-gate.sh "$OWNER" "$REPO" "$PR_NUM" "$PUSH_TIME")
  # Exit non-zero = could not look, which is not "no verdict".
  cr_verdict=$(bash $SKILL_DIR/scripts/cr-head-verdict.sh "$OWNER" "$REPO" "$PR_NUM" "$CUR_SHA") \
    || { final_state=failure; break; }
fi
```

## Step 8d: CLI JSONL to records

```bash
cli_records=$(bash $SKILL_DIR/scripts/parse-cr-cli-jsonl.sh "$jsonl_path")
cr_records=$cli_records
```

## Step 9a: classify

```bash
all=$(jq -c -s 'add' <(echo "$cr_records") <(echo "$codex_records"))
classified=$(echo "$all" | jq -c '.[]' \
  | while IFS= read -r rec; do printf '%s\n' "$rec" | ITER=$ITER SKIP_MINOR=$SKIP_MINOR bash $SKILL_DIR/scripts/classify-item.sh; done \
  | jq -s '.')
# A stop Step 13 held resolves here, on the new HEAD's findings: only one that needs
# a decision (gated, a late-P2 defer, or unreadable) earns the extra round.
if [ -n "$HOLD_STATE" ]; then
  if [ "$(jq '[.[] | select(.tier == "gated" or .tier == "defer" or .tier == "review")] | length' <<<"$classified")" = 0 ]; then
    final_state="$HOLD_STATE"; break
  fi
  HOLD_STATE=""
fi
```

## Step 9c.1: path-trust gate

```bash
bash $SKILL_DIR/scripts/path-trust.sh "$REPO_ROOT" "$path" || {
  log "untrusted path: $path" >&2
  auto_judge_skip=$((auto_judge_skip+1))
  # The log entry is part of the gate, not an afterthought: a skip with no record
  # breaks the Verification invariant that auto_judge_stats matches the log.
  tmp=$(mktemp); jq --arg p "$path" --argjson i "$ITER" \
    '.auto_judge_log += [{iter:$i, src:"cr", path:$p, action:"skip", reason:"untrusted-path"}]' \
    "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
  continue
}
```

## Step 9c.4: churn scope

```bash
bash $SKILL_DIR/scripts/churn-scope.sh "$PREV_SHA" "origin/$BASE" "$path" "$line"
```

## Step 9c.6: verify the fix

Wraps each `apply`: `snap` before the first Edit of the finding, `check` after its 9c.6 generalization.

```bash
[ "$VERIFICATION_GATE" = on ] && snap=$(bash "$SKILL_DIR/scripts/verify-fix.sh" snapshot)
# ... Edit the fix and its same-file siblings ...
if [ "$VERIFICATION_GATE" = on ] \
   && [ "$(bash "$SKILL_DIR/scripts/verify-fix.sh" check "$snap" "$VERIFY_CMD")" = fail ]; then
  # Reverted to $snap. The apply becomes a defer, reason `verification-failed`.
  applied_this_cycle=$((applied_this_cycle-1)); auto_judge_apply=$((auto_judge_apply-1))
  deferred_this_cycle=$((deferred_this_cycle+1)); auto_judge_defer=$((auto_judge_defer+1))
fi
```

## Step 9c.7: persist Codex review id

```bash
bash $SKILL_DIR/scripts/persist-codex-id.sh "$STATE_FILE" "$codex_review_id_to_process"
# CodeRabbit reviews whose outside-diff findings this round judged.
jq -r '[.[].review_id // empty] | unique | .[]' <<<"$cr_records" \
  | while IFS= read -r rid; do
      bash $SKILL_DIR/scripts/persist-codex-id.sh "$STATE_FILE" "$rid" cr_processed_reviews || exit 1
    done || { final_state=failure; break; }
```

## Step 10: stage and commit

```bash
res=$(bash $SKILL_DIR/scripts/stage-and-commit.sh "$TRACK_FILE" "$ITER")
# noop: every fix this cycle was reverted or nothing was applied -> no commit, so
# Step 11 is skipped and the Step 12 block pushes nothing.
```

## Step 12: push

```bash
# Step 10 noop: no commit this cycle, so nothing to push (a cycle of failed fixes).
if [ "$res" != noop ]; then
  # A rejected push leaves the loop (references/failure-modes.md); nothing below may
  # run for a head the PR never received.
  git push 2>&1 || { final_state=failure; break; }
  pushed_this_cycle=true
  : > "$TRACK_FILE"  # reset for next iter
  # Non-default base only (Step 2): this push will not be auto-reviewed.
  request_cr_review  # Step 2: skips when this head already has a request
fi
```

## Step 13: convergence ladder

Closes the per-iteration loop the Step 5 block opened.

```bash
applied_total=$((applied_total + applied_this_cycle))
# Late Codex P2s (tier defer) reach the follow-up issue through deferred_total but
# never count as this cycle's deferrals: they are policy, not undecided findings.
deferred_total=$((deferred_total + deferred_this_cycle + late_p2_this_cycle))
review_total=$((review_total + review_this_cycle))
stop=""
# Churn stop: from iter 2 on, every finding this cycle sat on material the loop
# itself produced, or outside the PR diff.
if [ "$ITER" -ge 2 ] && [ "$judged_this_cycle" -gt 0 ] \
   && [ "$churn_this_cycle" = "$judged_this_cycle" ]; then
  stop=churn
# Minor soft-stop: from iter 2 on, only low-severity fixes applied, none
# reassessed high, none deferred.
elif [ "$MINOR_STOP" = true ] && [ "$ITER" -ge 2 ] && [ "$applied_this_cycle" -gt 0 ] \
   && [ "$high_sev_this_cycle" = 0 ] && [ "$deferred_this_cycle" = 0 ] \
   && [ "$review_this_cycle" = 0 ]; then
  stop=minor_floor
# Only late Codex P2s left: a floor, not clean — clean files no follow-up issue.
elif [ "$applied_this_cycle" = 0 ] && [ "$deferred_this_cycle" = 0 ] \
   && [ "$review_this_cycle" = 0 ] && [ "$late_p2_this_cycle" -gt 0 ]; then
  stop=minor_floor
# clean also needs zero unread findings: a review-tier item is one nobody judged.
elif [ "$applied_this_cycle" = 0 ] && [ "$deferred_this_cycle" = 0 ] \
   && [ "$review_this_cycle" = 0 ]; then stop=clean
elif [ "$applied_this_cycle" = 0 ]; then stop=user_declined
fi
if [ -n "$stop" ]; then
  # A stop right after this cycle's push has not seen the new HEAD's verdicts: hold
  # it. The next iteration's Step 7e waits for them and ends the run as held unless
  # a new finding that needs a decision arrives (Step 9a).
  if [ "$pushed_this_cycle" = true ] && [ "$ITER" -lt "$MAX_ITER" ]; then HOLD_STATE="$stop"; continue; fi
  final_state="$stop"; break
fi
done  # end of for-iter
```

## Step 14: last-push HEAD verdicts and follow-up trigger

```bash
[ -n "${final_state:-}" ] || final_state=iteration_cap
# The last iteration pushed: its HEAD has not been judged. Wait here (Step 2). The
# loop has no round left for findings on it, so they go to the follow-up issue and
# the run ends at iteration_cap, which never merges.
if [ "$pushed_this_cycle" = true ]; then
  case "$final_state" in
    minor_floor|churn|iteration_cap)
      await_head_verdicts
      case "$hv_state" in
        ready) if [ "$(jq -r '.findings' <<<"$hv")" = true ]; then HEAD_VERDICT=unread; final_state=iteration_cap; fi ;;
        codex_failed) final_state=codex_failed ;;
        *) HEAD_VERDICT=timeout ;;
      esac ;;
  esac
fi
# One follow-up issue for whatever the run leaves behind: deferred findings, from
# this cycle or an earlier one (a later clean cycle records none of them), findings
# nobody could read, or a HEAD without every verdict. Block: references/failure-modes.md.
followup_needed=false
case "$final_state" in
  churn|minor_floor|iteration_cap|user_declined|clean|timeout)
    if [ "$deferred_total" -gt 0 ] || [ "$review_total" -gt 0 ] || [ -n "$HEAD_VERDICT" ]; then
      followup_needed=true
    fi ;;
esac
```

## Step 15: auto-merge gate

```bash
HEAD_SHA=$(git rev-parse HEAD)
# The gate re-reads every HEAD verdict (one look, no wait: Steps 7e and 14 waited).
reviewers_on
gate=$(FINAL_STATE="$final_state" CR_ON="$cr_on" CODEX_ON="$codex_on" \
       FOLLOWUP_ISSUE="$(jq -r '.followup_issue.number // empty' "$STATE_FILE")" DEFERRED_TOTAL="$deferred_total" \
       FOLLOWUP_APPEND_FAILED="$([ "$deferred_total" -gt 0 ] && jq -r '.followup_issue.append_failed // false' "$STATE_FILE" || echo false)" \
       bash $SKILL_DIR/scripts/auto-merge-gate.sh "$OWNER" "$REPO" "$PR_NUM" "$HEAD_SHA")
eligible=$(jq -r '.eligible' <<<"$gate")
cr_state=$(jq -r '.cr_state' <<<"$gate")
blocking=$(jq -r '.blocking_checks' <<<"$gate")
proto=$(jq -r '.protection_http' <<<"$gate")
base=$(jq -r '.base_branch' <<<"$gate")
if [ "$eligible" != "true" ]; then
  echo "auto-merge: $(jq -r '.ineligible_reason' <<<"$gate")" >&2; exit 0
fi
# Allow-list. A push this cycle leaves CR pending and `--auto` waits for it, so `pending`
# qualifies — but `none` / `unknown` mean CR was never observed on this SHA, which must
# never merge, and a deny-list would let them through.
case "$cr_state" in success|pending) : ;; *) echo "auto-merge: cr_state=$cr_state is not a merge-approved state" >&2; exit 0;; esac
[ "$blocking" = 0 ] || exit 0
if [ "$proto" = 200 ]; then
  gh pr merge "$PR_NUM" --auto --squash --delete-branch && merged=true
elif [ "$proto" = 404 ]; then
  # Interactive gate (see Hard constraints): Merge now / Skip merge / Cancel, on
  # "Base branch '$base' has no protection rules; --auto would merge immediately."
  # On "Merge now": gh pr merge "$PR_NUM" --squash --delete-branch && merged=true
  # With no interaction tool on the runtime, skip the merge and leave the PR open.
else
  # protection_http=0: the probe itself failed (network/auth/5xx) — never
  # merge on an unverified protection state; surface and leave the PR open.
  echo "auto-merge: branch-protection probe failed — merge not attempted" >&2
fi
```
