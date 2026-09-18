# cr-fix run blocks

The shell each step of `SKILL.md` runs, in run order. SKILL.md keeps the step sequence and each step's decision rule; each section below is named in the step that runs it and is run verbatim, in the one shell session the whole run shares (variables set in one block are read by later ones). Every `scripts/` path resolves against `SKILL_DIR` from Step 1.

## Step 2: repo, PR and counters

```bash
REPO_ROOT=$(git rev-parse --show-toplevel); cd "$REPO_ROOT"
START_SHA=$(git rev-parse HEAD)
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')
PR_NUM=$(gh pr list --head "$(git branch --show-current)" --state open --json number --jq '.[0].number // empty')
applied_total=0; deferred_total=0; skipped_total=0
verification_blocking=false
codex_active=unknown; codex_review_id_to_process=""
cli_invocations=0; rate_limit_hits=0
auto_judge_apply=0; auto_judge_defer=0; auto_judge_skip=0
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
request_cr_review() {  # GitHub comments are the record; no state file
  local since decision
  since=$(bash "$SKILL_DIR/scripts/push-time.sh" "$OWNER" "$REPO" "$(git rev-parse HEAD)")
  # Exit 1 = comments unreadable: do not post blind (the script logs why).
  decision=$(bash "$SKILL_DIR/scripts/cr-review-posted.sh" "$OWNER" "$REPO" "$PR_NUM" "$since") || return 0
  [ "$decision" = post ] && gh pr comment "$PR_NUM" --body "@coderabbitai review"
}
# Before iter 1: the PR's opening push was never auto-reviewed.
if [ "$CR_REVIEW_REQUEST" = request ] && { [ "$CR_SOURCE" = auto ] || [ "$CR_SOURCE" = pr-bot ]; }; then
  request_cr_review
fi
```

## Step 2: state init

```bash
mkdir -p .claude/state/archive
PRIOR_PROCESSED='[]'; PRIOR_ISSUE='null'
# Step 16's EXIT trap archives the live file, so on the next run the live path is
# usually absent — fall back to the newest archive or the Codex dedupe resets.
# `|| true`: a first run has no archive at all.
PRIOR_STATE=".claude/state/cr-fix-${PR_NUM}.json"
[ -f "$PRIOR_STATE" ] || PRIOR_STATE=$(ls -1t ".claude/state/archive/cr-fix-${PR_NUM}-"*.json 2>/dev/null | head -1 || true)
if [ -n "$PRIOR_STATE" ] && [ -f "$PRIOR_STATE" ]; then
  # Fail loud before creating a new state file: a silently reset dedupe re-judges
  # every already-processed Codex review.
  # The follow-up issue is inherited too, or every re-run on the same PR opens another one.
  PRIOR_ISSUE=$(jq -c '.followup_issue // null' "$PRIOR_STATE" 2>/dev/null) || PRIOR_ISSUE='null'
  PRIOR_PROCESSED=$(jq -c '.codex_processed_reviews // []' "$PRIOR_STATE" 2>/dev/null) || {
    echo "cr-fix: prior state $PRIOR_STATE unparseable — aborting before the Codex dedupe is reset" >&2
    exit 1
  }
  # Only the live file is archived; the $$ suffix keeps a same-second or parallel
  # run from clobbering an archive.
  if [ "$PRIOR_STATE" = ".claude/state/cr-fix-${PR_NUM}.json" ]; then
    mv "$PRIOR_STATE" ".claude/state/archive/cr-fix-${PR_NUM}-$(date +%Y%m%d-%H%M%S)-$$.json" \
      || { echo "cr-fix: failed to archive prior state" >&2; exit 1; }
  fi
fi
STATE_FILE=".claude/state/cr-fix-${PR_NUM}.json"
jq -n --arg sha "$START_SHA" --argjson prior "$PRIOR_PROCESSED" --argjson issue "$PRIOR_ISSUE" --arg src "$CR_SOURCE" \
  '{start_sha:$sha,iter:0,applied_total:0,deferred_total:0,codex_processed_reviews:$prior,followup_issue:$issue,cr_source:($src // "pending"),pre_flight_decisions:[],auto_judge_log:[]}' \
  > "$STATE_FILE"

TRACK_FILE="/tmp/cr-fix-${PR_NUM}-modified.list"; : > "$TRACK_FILE"
```

## Step 2: final-JSON trap

```bash
trap 'ITER=${ITER:-0} APPLIED_TOTAL=$applied_total DEFERRED_TOTAL=$deferred_total \
  SKIPPED_TOTAL=$skipped_total CODEX_STATE=$codex_active FINAL_STATE=${final_state:-unknown} \
  MERGED=${merged:-false} PR_NUM=$PR_NUM LAST_SHA=$(git rev-parse HEAD 2>/dev/null) \
  CR_SOURCE=$CR_SOURCE CLI_INVOCATIONS=$cli_invocations RATE_LIMIT_HITS=$rate_limit_hits \
  AUTO_JUDGE_APPLY=$auto_judge_apply AUTO_JUDGE_DEFER=$auto_judge_defer AUTO_JUDGE_SKIP=$auto_judge_skip \
  TRACK_FILE=$TRACK_FILE STATE_FILE=$STATE_FILE \
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
  echo "cr-fix: reviewer availability not checked (comment fetch failed); keeping the normal wait path" >&2
fi
```

## Step 5: loop head and pre-flight

Opens the per-iteration loop. Steps 5a to 13 run inside it; the Step 13 block closes it with `done`.

```bash
for ITER in $(seq 1 $MAX_ITER); do
  # Step 5a, before CUR_SHA is taken.
  if [ "$(gh pr view "$PR_NUM" --json mergeable --jq '.mergeable')" = CONFLICTING ]; then
    # references/merge-conflicts.md: merge origin/$BASE, resolve, re-check, commit, push.
    if [ "$CR_REVIEW_REQUEST" = request ] && { [ "$CR_SOURCE" = auto ] || [ "$CR_SOURCE" = pr-bot ]; }; then
      request_cr_review
    fi
    continue  # the merge commit is this iteration's one commit
  fi
  CUR_SHA=$(git rev-parse HEAD)
  applied_this_cycle=0; deferred_this_cycle=0; high_sev_this_cycle=0
  churn_this_cycle=0; judged_this_cycle=0; review_this_cycle=0
  # What the PREVIOUS iteration committed, for the Step 9c.4 in_prev_diff axis.
  # Empty on iter 1 or an empty diff both degrade to "no churn" — the safe side.
  PREV_SHA="${ITER_START_SHA:-}"; ITER_START_SHA="$CUR_SHA"
  PUSH_TIME=$(bash $SKILL_DIR/scripts/push-time.sh "$OWNER" "$REPO" "$CUR_SHA")

  if [ "$CR_SOURCE" = "auto" ] || [ "$CR_SOURCE" = "pr-bot" ]; then
    pf=$(OWNER="$OWNER" REPO="$REPO" PR_NUM="$PR_NUM" CUR_SHA="$CUR_SHA" \
         PUSH_TIME="$PUSH_TIME" STATE_FILE="$STATE_FILE" NO_CODEX="$NO_CODEX" \
         bash $SKILL_DIR/scripts/pre-flight.sh 2>/dev/null || echo '{"gate":"cr_wait"}')
    gate=$(jq -r '.gate' <<<"$pf")
    cr_state_pf=$(jq -r '.cr_state' <<<"$pf")
    codex_state_pf=$(jq -r '.codex_state' <<<"$pf")
    codex_latest_id_pf=$(jq -r '.codex_latest_id // empty' <<<"$pf")
    rate_limit_source=$(jq -r '.rate_limit_source' <<<"$pf")

    # Persist pre-flight decision into STATE_FILE for diagnostics.
    tmp=$(mktemp); jq --argjson pf "$pf" --argjson iter "$ITER" \
      '.pre_flight_decisions += [($pf + {iter:$iter})]' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"

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
# Monitor returns one JSON line: {jsonl:"...", exit:N, emitted_complete:bool}
cli_invocations=$((cli_invocations + 1))
```

## Step 8: fetch CR threads

```bash
cr_records=$(bash $SKILL_DIR/scripts/fetch-cr-threads.sh "$OWNER" "$REPO" "$PR_NUM") \
  || { final_state=failure; break; }
```

## Step 8b: fetch Codex inline comments

```bash
codex_records=$(bash $SKILL_DIR/scripts/fetch-codex-comments.sh "$OWNER" "$REPO" "$PR_NUM" "$codex_review_id_to_process")
```

## Step 8c: engagement gate

```bash
cr_engagement=$(bash $SKILL_DIR/scripts/engagement-gate.sh "$OWNER" "$REPO" "$PR_NUM" "$PUSH_TIME")
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
  | while IFS= read -r rec; do printf '%s\n' "$rec" | SKIP_MINOR=$SKIP_MINOR bash $SKILL_DIR/scripts/classify-item.sh; done \
  | jq -s '.')
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

## Step 9c.7: persist Codex review id

```bash
bash $SKILL_DIR/scripts/persist-codex-id.sh "$STATE_FILE" "$codex_review_id_to_process"
```

## Step 10: stage and commit

```bash
res=$(bash $SKILL_DIR/scripts/stage-and-commit.sh "$TRACK_FILE" "$ITER")
# If res == "noop", skip Steps 11-12 and jump to Step 13
if [ "$res" = "noop" ]; then : ; fi
```

## Step 12: push

```bash
# A rejected push leaves the loop (references/failure-modes.md); nothing below may
# run for a head the PR never received.
git push 2>&1 || { final_state=failure; break; }
: > "$TRACK_FILE"  # reset for next iter
# Non-default base only (Step 2): this push will not be auto-reviewed.
if [ "$CR_REVIEW_REQUEST" = request ] && { [ "$CR_SOURCE" = auto ] || [ "$CR_SOURCE" = pr-bot ]; }; then
  request_cr_review  # Step 2: skips when this head already has a request
fi
```

## Step 13: convergence ladder

Closes the per-iteration loop the Step 5 block opened.

```bash
applied_total=$((applied_total + applied_this_cycle))
deferred_total=$((deferred_total + deferred_this_cycle))
# Churn stop: from iter 2 on, every finding this cycle sat on material the loop
# itself produced, or outside the PR diff.
if [ "$ITER" -ge 2 ] && [ "$judged_this_cycle" -gt 0 ] \
   && [ "$churn_this_cycle" = "$judged_this_cycle" ]; then
  final_state=churn; break
# Minor soft-stop: from iter 2 on, only low-severity fixes applied, none
# reassessed high, none deferred. Safe: Step 12 already pushed them.
elif [ "$MINOR_STOP" = true ] && [ "$ITER" -ge 2 ] && [ "$applied_this_cycle" -gt 0 ] \
   && [ "$high_sev_this_cycle" = 0 ] && [ "$deferred_this_cycle" = 0 ] \
   && [ "$review_this_cycle" = 0 ]; then
  final_state=minor_floor; break
elif [ "$applied_this_cycle" = 0 ] && [ "$deferred_this_cycle" = 0 ]; then final_state=clean; break
elif [ "$applied_this_cycle" = 0 ]; then final_state=user_declined; break
fi
done  # end of for-iter
```

## Step 15: auto-merge gate

```bash
HEAD_SHA=$(git rev-parse HEAD)
gate=$(FINAL_STATE="$final_state" \
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
