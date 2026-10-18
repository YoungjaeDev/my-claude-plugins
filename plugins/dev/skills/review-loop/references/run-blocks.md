# review-loop run blocks

The shell each step of `SKILL.md` runs, in run order. SKILL.md keeps the step sequence and each step's decision rule; each section below is named in the step that runs it and is run verbatim. Later blocks read variables earlier ones set, so the run needs one shell: a runtime whose shell calls do not share state (Claude Code's Bash tool, a zsh default) runs each block under `bash` and carries the variables in a file: it sources the file at the top of every call and writes back every variable the block set before the call ends (sourcing alone saves nothing); the Step 2 functions go in a file sourced the same way. The Step 5 `for` loop cannot span calls either, so the agent drives it: it runs Steps 5a-13 once per iteration, leaves out the Step 5 `for` line and the Step 13 `done`, ends a block where it reaches a loop-level `continue` or `break` (a standalone shell does not stop there), reads a loop-level `continue` as "start the next iteration" (the Step 9c.1 `continue` only moves on to the next finding) and `break` as "leave the loop for Step 14". The Step 2 EXIT trap would fire when its own call ends, so it is set in the call that ends the run. It still runs every step in order — skipping Step 5 pre-flight on a later iteration hides a rate limit until the Step 7e wait has spent its whole budget. Every `scripts/` path resolves against `SKILL_DIR` from Step 1.

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
# REVIEWED_SHA: set when Step 12 held a cycle's Minor-or-lower fixes back for the base
# (merge_then_main_push): the PR head they wait on, which Step 15 merges.
REVIEWED_SHA=""
# dropped_reviewers: reviewers a HEAD verdict wait dropped (ADR 0006), space-separated.
# CR_BASE_REQUESTED: the base, once this run posted the non-default-base review request.
# pending_decision: the question a runner leaves for the main session (SKILL.md "Runner").
dropped_reviewers=""; CR_BASE_REQUESTED=""; pending_decision=""
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
# CodeRabbit will not auto-review this base (Step 2), or, with `paused` / `stuck`, it
# paused automatic reviews or gave no verdict within its budget (any base, ADR 0006).
request_cr_review() {  # GitHub comments are the record; no state file
  local since decision
  case "$CR_SOURCE" in auto|pr-bot) : ;; *) return 0 ;; esac
  [ "$CR_REVIEW_REQUEST" = request ] || [ -n "${1:-}" ] || return 0
  since=$(bash "$SKILL_DIR/scripts/push-time.sh" "$OWNER" "$REPO" "$(git rev-parse HEAD)")
  # Exit 1 = comments unreadable: do not post blind (the script logs why).
  decision=$(bash "$SKILL_DIR/scripts/cr-review-posted.sh" "$OWNER" "$REPO" "$PR_NUM" "$since") || return 0
  [ "$decision" = post ] || return 0
  gh pr comment "$PR_NUM" --body "@coderabbitai review" || return 0
  # The final report suggests adding this base to CodeRabbit's auto-review list (Step 16).
  if [ -z "${1:-}" ]; then CR_BASE_REQUESTED="$BASE"; fi
}
# Which reviewers are on now (Step 2b and pre-flight can drop one): cr_on, codex_on.
reviewers_on() {
  cr_on=false; case "$CR_SOURCE" in auto|pr-bot) cr_on=true ;; esac
  codex_on=auto; if [ "$NO_CODEX" = true ] || [ "$codex_active" = disabled ]; then codex_on=false; fi
}
# Waits, inside the existing caps (TIMEOUT for CodeRabbit, the Codex wait budget),
# until every reviewer this run has on gave HEAD a verdict. Sets hv (one JSON line,
# scripts/head-verdicts.sh) and hv_state: ready | timeout | codex_failed. A paused
# CodeRabbit (auto_pause_after_reviewed_commits), or one silent for half its budget
# (stuck), gets one `@coderabbitai review` for this HEAD. After a pause the wait
# resumes with the CodeRabbit budget counted from that request (it starts the
# review); after a stuck nudge it keeps the first wait's deadline (cr_deadline), so
# the whole wait stays inside one TIMEOUT. A reviewer the wait dropped (ADR 0006) is
# off for the rest of the run, as Step 2b drops one, and named in dropped_reviewers.
await_head_verdicts() {
  local sha pt round cr_on codex_on r tmp crdl=""
  sha=$(git rev-parse HEAD)
  pt=$(bash "$SKILL_DIR/scripts/push-time.sh" "$OWNER" "$REPO" "$sha")
  reviewers_on
  for round in 1 2; do
    # Bash(run_in_background=true) + Monitor: one JSON line. The script keeps its own
    # deadlines; on each wake read its output file, not a completion notification.
    hv=$(OWNER="$OWNER" REPO="$REPO" PR_NUM="$PR_NUM" CUR_SHA="$sha" PUSH_TIME="$pt" \
         CR_ON="$cr_on" CODEX_ON="$codex_on" TIMEOUT="$TIMEOUT" INTERVAL="$INTERVAL" \
         CODEX_GRACE="$CODEX_GRACE" CR_DEADLINE="$crdl" bash "$SKILL_DIR/scripts/head-verdicts.sh")
    hv_state=$(jq -r '.state // empty' <<<"$hv" 2>/dev/null) || hv_state=""
    [ -n "$hv_state" ] || hv_state=timeout  # no line: the wait was cut off
    case "$hv_state" in
      paused|stuck)
        # Posts only when this HEAD has no request yet.
        if [ "$round" = 1 ]; then request_cr_review "$hv_state"; fi
        if [ "$hv_state" = stuck ]; then crdl=$(jq -r '.cr_deadline // empty' <<<"$hv" 2>/dev/null) || crdl=""; fi
        continue ;;
    esac
    for r in $(jq -r '.dropped[]?' <<<"$hv" 2>/dev/null); do
      case " $dropped_reviewers " in *" $r "*) continue ;; esac
      dropped_reviewers="${dropped_reviewers:+$dropped_reviewers }$r"
      case "$r" in
        codex) NO_CODEX=true; codex_active=disabled ;;
        coderabbit)
          CR_SOURCE=codex-only
          if [ -f "${STATE_FILE:-}" ]; then
            tmp=$(mktemp); jq '.cr_source = "codex-only"' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
          fi ;;
      esac
    done
    return 0
  done
  hv_state=timeout  # still paused or stuck: the request did not land
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
# A PR the loop ran on before the cr-fix -> review-loop rename: read (never move) its old state.
if [ -z "$PRIOR_STATE" ]; then
  PRIOR_STATE=".claude/state/cr-fix-${PR_NUM}.json"
  [ -f "$PRIOR_STATE" ] || PRIOR_STATE=$(ls -1t ".claude/state/archive/cr-fix-${PR_NUM}-"*.json 2>/dev/null | head -1 || true)
fi
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
DIRTY_BASE="/tmp/review-loop-${PR_NUM}-dirty-base.list"  # Step 5 rewrites it every iteration
```

## Step 2: final-JSON trap

```bash
trap 'ITER=${ITER:-0} APPLIED_TOTAL=$applied_total DEFERRED_TOTAL=$deferred_total \
  SKIPPED_TOTAL=$skipped_total CODEX_STATE=$codex_active FINAL_STATE=${final_state:-unknown} \
  MERGED=${merged:-false} PR_NUM=$PR_NUM LAST_SHA=$(git rev-parse HEAD 2>/dev/null) \
  CR_SOURCE=$CR_SOURCE CLI_INVOCATIONS=$cli_invocations RATE_LIMIT_HITS=$rate_limit_hits \
  AUTO_JUDGE_APPLY=$auto_judge_apply AUTO_JUDGE_DEFER=$auto_judge_defer AUTO_JUDGE_SKIP=$auto_judge_skip \
  TRACK_FILE=$TRACK_FILE STATE_FILE=$STATE_FILE VERIFICATION_GATE=$VERIFICATION_GATE \
  CI_FAILING_CHECKS=${ci_failing_checks:-[]} HEAD_VERDICT=$HEAD_VERDICT \
  DROPPED_REVIEWERS="$dropped_reviewers" CR_BASE_REQUESTED="$CR_BASE_REQUESTED" PENDING_DECISION="$pending_decision" \
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
  # Merged or closed outside the run (PR #308): nothing left to review or push to. The
  # last iteration pushed its fixes, so none are waiting. An unreadable state goes on.
  case "$(gh pr view "$PR_NUM" --json state --jq '.state' 2>/dev/null)" in
    MERGED|CLOSED) final_state=merged_externally; break ;;
  esac
  # Step 5a, before CUR_SHA is taken.
  if [ "$(gh pr view "$PR_NUM" --json mergeable --jq '.mergeable')" = CONFLICTING ]; then
    # references/merge-conflicts.md: merge origin/$BASE, resolve, re-check, commit, push.
    request_cr_review
    continue  # the merge commit is this iteration's one commit
  fi
  CUR_SHA=$(git rev-parse HEAD)
  # Per iteration: kept, the next Step 6b skips discovery and Step 8b fetches this
  # iteration's Codex review again. Pre-flight below may set it for this HEAD.
  codex_review_id_to_process=""
  # What is dirty before any fix: Step 10 commits the other files a fix changed (its
  # test, a fixture) with it, and leaves these alone.
  { git diff HEAD --name-only -z; git ls-files --others --exclude-standard -z; } > "$DIRTY_BASE"
  pushed_this_cycle=false
  applied_this_cycle=0; deferred_this_cycle=0; high_sev_this_cycle=0
  churn_this_cycle=0; judged_this_cycle=0; review_this_cycle=0
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
  # Bash(run_in_background=true) + Monitor; the poller stops itself at TIMEOUT:
  #   OWNER=... REPO=... SHA=$CUR_SHA PR_NUM=... INTERVAL=$INTERVAL PUSH_TIME=$PUSH_TIME TIMEOUT=$TIMEOUT \
  #     bash $SKILL_DIR/scripts/poll-cr-status.sh
  # One JSON line: {state:"success"|"failure"|"rate_limited"|"error"|"timeout", ...}
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
# Outside-diff findings live only in review bodies; add them, merged only into a
# thread that is a confirmed copy (same path, line, header and title). An
# unreadable block fails the round.
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
# One stdin stream, not two <(…) paths: native jq.exe on Git Bash cannot open those (#309).
records_n=$(printf '%s\n%s\n' "${cr_records:-[]}" "${codex_records:-[]}" | jq -s 'add | length') \
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
# A thread judged earlier in this run stays unresolved (deferred, skipped, or applied
# and not re-reviewed yet) and is fetched again: judged twice, its defer counts twice,
# minor_floor never fires and the follow-up issue lists it twice. Drop it by the
# comment id its auto_judge_log record carries.
judged_ids=$(jq -c '[.auto_judge_log[]?.comment_id // empty]' "$STATE_FILE") || { final_state=failure; break; }
all=$(printf '%s\n%s\n' "$cr_records" "$codex_records" | jq -c -s --argjson j "$judged_ids" \
  'add | [.[] | select((.databaseId // .comment_id // null) as $id | $id == null or ($j | index($id) | not))]')
classified=$(echo "$all" | jq -c '.[]' \
  | while IFS= read -r rec; do printf '%s\n' "$rec" | SKIP_MINOR=$SKIP_MINOR bash $SKILL_DIR/scripts/classify-item.sh; done \
  | jq -s '.')
# A stop Step 13 held resolves here, on the new HEAD's findings: only one that needs
# a decision (gated, or unreadable) earns the extra round.
if [ -n "$HOLD_STATE" ]; then
  if [ "$(jq '[.[] | select(.tier == "gated" or .tier == "review")] | length' <<<"$classified")" = 0 ]; then
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
  # comment_id: the record's databaseId (CR thread) or comment_id (Codex), so Step 9a
  # does not judge it again this run.
  tmp=$(mktemp); jq --arg p "$path" --argjson i "$ITER" --arg cid "${comment_id:-}" \
    '.auto_judge_log += [{iter:$i, src:"cr", path:$p, action:"skip", reason:"untrusted-path",
       comment_id:($cid | tonumber? // null)}]' \
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
# Anything but `pass` fails: a check that died mid-revert prints nothing.
if [ "$VERIFICATION_GATE" = on ] \
   && [ "$(bash "$SKILL_DIR/scripts/verify-fix.sh" check "$snap" "$VERIFY_CMD")" != pass ]; then
  # Reverted to $snap (or partly, if the check died). The apply becomes a defer, reason `verification-failed`.
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
# A failed commit (a hook refused it) leaves the fixes staged and HEAD unchanged: stop
# here, before Step 12 marks a push or clears the track file.
# DIRTY_BASE (Step 5): the other files a fix changed go in with it, the user's do not.
res=$(bash $SKILL_DIR/scripts/stage-and-commit.sh "$TRACK_FILE" "$ITER" "$DIRTY_BASE") || { final_state=failure; break; }
# noop: every fix this cycle was reverted or nothing was applied -> no commit, so
# Step 11 is skipped and the Step 12 block pushes nothing.
```

## Step 12: push

```bash
# Step 10 noop: no commit this cycle, so nothing to push (a cycle of failed fixes).
if [ "$res" != noop ]; then
  # Who reviews this cycle's fixes (ADR 0006): with only Minor-or-lower ones the
  # reviewed HEAD is merged and they go to the base (Step 15); else back to the PR.
  # An unreadable answer pushes.
  next_action=$(STATE_FILE="$STATE_FILE" FIX_ITER="$ITER" VERIFICATION_GATE="$VERIFICATION_GATE" MINOR_STOP="$MINOR_STOP" \
    bash "$SKILL_DIR/scripts/auto-merge-gate.sh" "$OWNER" "$REPO" "$PR_NUM" "$CUR_SHA" 2>/dev/null \
    | jq -r '.next_action // empty' 2>/dev/null) || next_action=""
  if [ "$next_action" = merge_then_main_push ]; then
    REVIEWED_SHA="$CUR_SHA"  # Step 13 stops; the fixes stay on the local commit until Step 15
  else
    # Merged or closed while this cycle judged (PR #308): the fixes stay on the local
    # commit, which the final report names. Step 15 pushes nothing either.
    case "$(gh pr view "$PR_NUM" --json state --jq '.state' 2>/dev/null)" in
      MERGED|CLOSED)
        echo "review-loop: PR #$PR_NUM was merged or closed during iter $ITER; its fixes stay on local commit $(git rev-parse HEAD)" >&2
        # This break skips Step 13: count the cycle here, or Step 14 files no issue for its defers.
        applied_total=$((applied_total + applied_this_cycle)); deferred_total=$((deferred_total + deferred_this_cycle))
        review_total=$((review_total + review_this_cycle))
        final_state=merged_externally; break ;;
    esac
    # A rejected push leaves the loop (references/failure-modes.md); nothing below may
    # run for a head the PR never received.
    git push 2>&1 || { final_state=failure; break; }
    pushed_this_cycle=true
    : > "$TRACK_FILE"  # reset for next iter
    # Non-default base only (Step 2): this push will not be auto-reviewed.
    request_cr_review  # Step 2: skips when this head already has a request
  fi
fi
```

## Step 13: convergence ladder

Closes the per-iteration loop the Step 5 block opened.

```bash
applied_total=$((applied_total + applied_this_cycle))
deferred_total=$((deferred_total + deferred_this_cycle))
review_total=$((review_total + review_this_cycle))
stop=""
# Step 12 held this cycle's Minor-or-lower fixes for the base: the reviewed HEAD is
# what merges, so no round is left to run.
if [ -n "$REVIEWED_SHA" ]; then
  stop=minor_floor
# Churn stop: from iter 2 on, every finding this cycle sat on material the loop
# itself produced, or outside the PR diff.
elif [ "$ITER" -ge 2 ] && [ "$judged_this_cycle" -gt 0 ] \
   && [ "$churn_this_cycle" = "$judged_this_cycle" ]; then
  stop=churn
# Minor soft-stop: from iter 2 on, only low-severity fixes applied, none
# reassessed high, none deferred.
elif [ "$MINOR_STOP" = true ] && [ "$ITER" -ge 2 ] && [ "$applied_this_cycle" -gt 0 ] \
   && [ "$high_sev_this_cycle" = 0 ] && [ "$deferred_this_cycle" = 0 ] \
   && [ "$review_this_cycle" = 0 ]; then
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
# A converged HEAD whose CI checks fail has not converged (#317). Pending checks are
# waited on under TIMEOUT; a lookup that fails keeps the state, and Step 15 re-reads.
case "$final_state" in
  clean|minor_floor|churn)
    # Bash(run_in_background=true, timeout=(TIMEOUT+60)*1000) + Monitor: one JSON line.
    # With fixes held for the base (Step 12), HEAD is a local commit GitHub never saw:
    # the PR's head is REVIEWED_SHA.
    ci=$(CAP="$TIMEOUT" INTERVAL="$INTERVAL" \
         PUSH_TIME="$(bash "$SKILL_DIR/scripts/push-time.sh" "$OWNER" "$REPO" "${REVIEWED_SHA:-$(git rev-parse HEAD)}")" \
         bash "$SKILL_DIR/scripts/ci-checks.sh" "$PR_NUM")
    case "$(jq -r '.state' <<<"$ci" 2>/dev/null | tr -d '\r')" in
      fail) final_state=ci_failing; ci_failing_checks=$(jq -c '.failing' <<<"$ci") ;;
      error|"") echo "review-loop: CI checks on HEAD could not be read; final_state kept" >&2 ;;
    esac ;;
esac
# One follow-up issue, only when the run left findings behind: deferred ones from any
# cycle, or ones nobody could read (auto-merge-gate.sh `file_issue`). A HEAD without
# every verdict and failing CI checks alone go to the final report. An unreadable
# answer files it: losing a deferred finding costs more than an empty issue.
# Block: references/failure-modes.md.
reviewers_on
gate=$(FINAL_STATE="$final_state" DEFERRED_TOTAL="$((deferred_total + ${review_total:-0}))" \
       CR_ON="$cr_on" CODEX_ON="$codex_on" DROPPED_REVIEWERS="${dropped_reviewers:-}" \
       bash "$SKILL_DIR/scripts/auto-merge-gate.sh" "$OWNER" "$REPO" "$PR_NUM" "${REVIEWED_SHA:-$(git rev-parse HEAD)}")
followup_needed=$(jq -r '.file_issue' <<<"$gate" 2>/dev/null) || followup_needed=""
case "$followup_needed" in true|false) : ;; *) followup_needed=true ;; esac
[ -z "$HEAD_VERDICT" ] || echo "review-loop: HEAD $(git rev-parse HEAD) left unverified (HEAD_VERDICT=$HEAD_VERDICT); auto-merge stays off" >&2
```

## Step 15: auto-merge gate

```bash
# The PR's head is the reviewed one when Step 12 held the Minor fixes for the base.
FIX_SHA=$(git rev-parse HEAD); HEAD_SHA=${REVIEWED_SHA:-$FIX_SHA}
# The gate re-reads every HEAD verdict (one look, no wait: Steps 7e and 14 waited).
reviewers_on
# Unread (`review`-tier) findings need the follow-up issue as much as deferred ones.
left_behind=$((deferred_total + ${review_total:-0}))
gate=$(FINAL_STATE="$final_state" CR_ON="$cr_on" CODEX_ON="$codex_on" DROPPED_REVIEWERS="${dropped_reviewers:-}" \
       FOLLOWUP_ISSUE="$(jq -r '.followup_issue.number // empty' "$STATE_FILE")" DEFERRED_TOTAL="$left_behind" \
       FOLLOWUP_APPEND_FAILED="$([ "$left_behind" -gt 0 ] && jq -r '.followup_issue.append_failed // false' "$STATE_FILE" || echo false)" \
       bash $SKILL_DIR/scripts/auto-merge-gate.sh "$OWNER" "$REPO" "$PR_NUM" "$HEAD_SHA")
eligible=$(jq -r '.eligible' <<<"$gate")
cr_state=$(jq -r '.cr_state' <<<"$gate")
blocking=$(jq -r '.blocking_checks' <<<"$gate")
proto=$(jq -r '.protection_http' <<<"$gate")
base=$(jq -r '.base_branch' <<<"$gate")
ci_state=$(jq -r '.ci_state' <<<"$gate" | tr -d '\r')
# Merged or closed outside the run while it waited (PR #308): nothing to merge. Held
# Minor fixes still reach an unprotected base after a merge (the Step 15 merge block).
pr_state=$(gh pr view "$PR_NUM" --json state --jq '.state' 2>/dev/null) || pr_state=""
case "$pr_state" in
  MERGED) final_state=merged_externally; merged=true ;;
  CLOSED) final_state=merged_externally ;;
esac
# A check that failed after Step 14 looked ends the run where Step 14 would have (#336).
if [ "$ci_state" = fail ]; then
  case "$final_state" in
    clean|minor_floor|churn) final_state=ci_failing; ci_failing_checks=$(jq -c '.failing_checks' <<<"$gate") ;;
  esac
fi
why=""
if [ "$final_state" = merged_externally ]; then why="PR #$PR_NUM was ${pr_state:-merged or closed} outside the run"
elif [ "$verification_blocking" = true ]; then why="a merge-conflict resolution broke the checks"
elif [ "$eligible" != "true" ]; then why=$(jq -r '.ineligible_reason' <<<"$gate")
# Allow-list. A push this cycle leaves CR pending and `--auto` waits for it, so `pending`
# qualifies — but `none` / `unknown` mean CR was never observed on this SHA, which must
# never merge, and a deny-list would let them through. A run that dropped CodeRabbit
# (codex-only, cli) does not read its status: the HEAD verdict axis judged without it.
elif [ "$cr_on" = true ] && [ "$cr_state" != success ] && [ "$cr_state" != pending ]; then
  why="cr_state=$cr_state is not a merge-approved state"
elif [ "$blocking" != 0 ] && [ "$ci_state" = error ]; then why="CI checks on HEAD could not be read; merge not attempted"
elif [ "$blocking" != 0 ]; then why="failing CI check(s) on HEAD: $(jq -r '.failing_checks | join(", ")' <<<"$gate")"
# protection_http=0: the probe itself failed (network/auth/5xx) — never merge on an
# unverified protection state; surface and leave the PR open.
elif [ "$proto" != 200 ] && [ "$proto" != 404 ]; then why="branch-protection probe failed — merge not attempted"
fi
# A finished review never ends silently: without --auto-merge, on a base with no
# protection rules (the merge is immediate), or with a reviewer the wait dropped
# (ADR 0006: HEAD has no verdict from it), the user decides.
if [ -z "$why" ] && { [ "$AUTO_MERGE" != true ] || [ "$proto" = 404 ] || [ -n "${dropped_reviewers:-}" ]; }; then
  # Interactive gate (see Hard constraints), one question: "auto-merge 할까요?" (Merge / Don't merge)
  # for PR #$PR_NUM into $base, adding "Base branch '$base' has no protection rules; it merges
  # now" on 404 and "No verdict on HEAD from: $dropped_reviewers" when one was dropped.
  # On "Merge": MERGE_ANSWER=yes. No interaction tool on the runtime: leave it unset.
  # A runner has none either: it leaves the question to the main session (SKILL.md "Runner").
  if [ "${RUNNER:-false}" = true ] && [ -z "${MERGE_ANSWER:-}" ]; then
    pending_decision=$(jq -nc --argjson pr "$PR_NUM" --arg base "$base" --argjson proto "$proto" \
      --arg rs "$REVIEWED_SHA" --arg fs "$FIX_SHA" --argjson iter "${ITER:-0}" --arg vc "${VERIFY_CMD:-}" \
      --argjson dr "$(bash "$SKILL_DIR/scripts/words-json.sh" "${dropped_reviewers:-}")" \
      '{question:"merge", pr:$pr, base:$base, protection_http:$proto, reviewed_sha:$rs, fix_sha:$fs,
        iter:$iter, verify_cmd:$vc, dropped_reviewers:$dr}')
    why="the merge question waits for the main session"
  elif [ "${MERGE_ANSWER:-}" != yes ]; then why="not merged: the user did not choose to merge"; fi
fi
[ -z "$why" ] || echo "auto-merge: $why" >&2
```

## Step 15: merge

Runs right after the gate block. The main session also runs it on its own, after it asked a runner's pending `merge` question (SKILL.md "Runner"), with `PR_NUM`, `base`, `proto` (`protection_http`), `REVIEWED_SHA`, `FIX_SHA`, `ITER` and `VERIFY_CMD` from `pending_decision`, `STATE_FILE` set to the newest `.claude/state/archive/review-loop-<PR>-*.json`, `pending_decision` empty, and `why` empty on "Merge" or `not merged: the user did not choose to merge` otherwise.

```bash
if [ -z "$why" ]; then
  mflag=""; [ "$proto" != 200 ] || mflag=--auto
  # The exit code is not the merge: gh merges, then fails to delete a local branch
  # another worktree has checked out (PR #334). The PR says: merged, or (protected
  # base) auto-merge armed. --match-head-commit: a push after the gate read the
  # verdicts makes gh refuse, so only the reviewed HEAD can land.
  gh pr merge "$PR_NUM" ${mflag:+"$mflag"} --squash --delete-branch --match-head-commit "${REVIEWED_SHA:-$FIX_SHA}" \
    || echo "review-loop: gh pr merge exited non-zero; reading the PR state" >&2
  if [ "$(gh pr view "$PR_NUM" --json state,autoMergeRequest \
          --jq 'if .state == "MERGED" or .autoMergeRequest != null then "yes" else "no" end' 2>/dev/null)" = yes ]; then
    merged=true
  fi
fi
# Minor fixes Step 12 held back (merge_then_main_push): onto the base once the merge
# has landed (scripts/base-push.sh: build/test and pre-commit there first), else back
# to the PR, whose review this run does not wait for. While the main session has not
# answered a runner's merge question they stay on the local commit.
if [ -n "$REVIEWED_SHA" ] && [ -n "${pending_decision:-}" ]; then
  echo "review-loop: Minor fixes stay on local commit $FIX_SHA until the merge question is answered" >&2
elif [ -n "$REVIEWED_SHA" ]; then
  if [ "${merged:-false}" = true ] && [ "$proto" = 404 ]; then
    if pushed=$(bash "$SKILL_DIR/scripts/base-push.sh" "$base" "$REVIEWED_SHA" "$FIX_SHA" "$VERIFY_CMD"); then
      tmp=$(mktemp); jq --arg b "$base" --arg s "$pushed" --argjson it "$ITER" \
        '.base_push = {branch:$b, sha:$s, fixes:[.auto_judge_log[]? | select(.iter == $it and .action == "apply")
           | {src, path, line, badge_or_sev}]}' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
    else
      echo "review-loop: Minor fixes not pushed to $base; they are on local commit $FIX_SHA" >&2
    fi
  elif [ "${final_state:-}" = merged_externally ]; then
    echo "review-loop: PR #$PR_NUM was merged or closed outside the run; Minor fixes stay on local commit $FIX_SHA" >&2
  elif [ "${merged:-false}" = true ]; then
    echo "review-loop: the merge waits on base protection; Minor fixes stay on local commit $FIX_SHA" >&2
  elif git push 2>&1; then
    echo "review-loop: not merged; Minor fixes pushed to PR #$PR_NUM, unreviewed — re-run review-loop" >&2
  else
    echo "review-loop: not merged and the push failed; Minor fixes are on local commit $FIX_SHA" >&2
  fi
fi
```
