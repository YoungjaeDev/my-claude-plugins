#!/usr/bin/env bash
# Usage: OWNER=... REPO=... SHA=... PR_NUM=... INTERVAL=... PUSH_TIME=... TIMEOUT=...
#        bash scripts/poll-cr-status.sh
# Runs in background via Bash(run_in_background=true). Caller uses Monitor.
# Emits exactly one terminal JSON line:
#   {"state":"success|failure","target_url":"..."}                      (CR responded)
#   {"state":"rate_limited","reset_minutes_estimate":N,"hits":N}        (early escape — hang fix)
# Exits 0 on success/failure/rate_limited terminal; timeout governed by surrounding Bash timeout.
#
# Hang-fix design (Step 6, replaces 1800s unilateral spin):
#   - After EARLY_CHECK_WINDOW seconds of wall-clock without seeing status, probe rate-limit body.
#   - If rate-limit detected, emit rate_limited JSON and exit 0 → SKILL.md Step 7c.
#   - Otherwise keep polling status.
#
# Transient "free tier disabled" guard (CR_SKIP_GRACE):
#   CodeRabbit briefly publishes a *success* commit-status whose description is
#   "Review skipped: free tier disabled", then replaces it with "Review
#   completed" once the real review lands (observed ~5 min gap on a paid private
#   repo). The plain `state == success` check would return that transient row as
#   terminal success, so the skill fetches threads before any finding exists and
#   reports false convergence. We treat a success+free-tier-disabled row as
#   NON-terminal and keep polling until either the completed row arrives or
#   CR_SKIP_GRACE expires (then emit rate_limited → Step 7c fallback, so a
#   genuinely-disabled repo cannot hang).
set -euo pipefail

: "${OWNER:?}"; : "${REPO:?}"; : "${SHA:?}"; : "${PR_NUM:?}"; : "${INTERVAL:=8}"; : "${PUSH_TIME:?}"
EARLY_CHECK_WINDOW="${EARLY_CHECK_WINDOW:-30}"
SKIP_GRACE="${CR_SKIP_GRACE:-300}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wall-clock start: the EARLY_CHECK_WINDOW must compare against real seconds
# elapsed, not `elapsed` accumulated only after a full sleep. With a 60s INTERVAL
# the old `elapsed -ge 30` test first becomes true at t=60 (after one sleep),
# silently doubling the documented 30s rate-limit detection window.
start_ts=$(date +%s)
# First wall-clock second we saw a transient "free tier disabled" success row.
# Empty until observed; drives the CR_SKIP_GRACE budget below.
skip_first_ts=""

# Pull statuses ONCE per loop iteration; --paginate + pipe form per plugins/github-dev/CLAUDE.md
# gh / jq invariants. /statuses (plural) preserves the full history so we never miss
# the early `pending` row that /status (singular, latest-per-context) hides.
fetch_cr_state() {
  gh api --paginate "repos/$OWNER/$REPO/commits/$SHA/statuses" 2>/dev/null \
    | jq -s 'add // []
             | map(select(.context | test("CodeRabbit"; "i")))
             | sort_by(.created_at) | reverse
             | .[0] // {}'
}

while true; do
  cr_obj=$(fetch_cr_state)
  s=$(jq -r '.state // ""' <<<"$cr_obj")
  d=$(jq -r '.description // ""' <<<"$cr_obj")

  if [ "$s" = "success" ] || [ "$s" = "failure" ]; then
    # Transient "free tier disabled" guard: a success row with this description
    # is NOT terminal — CodeRabbit replaces it with "Review completed" shortly
    # after on a paid repo. Keep polling until the real row lands or CR_SKIP_GRACE
    # expires; on expiry emit rate_limited so a genuinely-disabled repo routes to
    # the Step 7c fallback instead of looping forever.
    if [ "$s" = "success" ] && printf '%s' "$d" | grep -qi "free tier disabled"; then
      now_ts=$(date +%s)
      [ -z "$skip_first_ts" ] && skip_first_ts="$now_ts"
      if [ "$((now_ts - skip_first_ts))" -ge "$SKIP_GRACE" ]; then
        printf '{"state":"rate_limited","sha":"%s","pr":%s,"reset_minutes_estimate":0,"hits":1,"reason":"free_tier_disabled_persisted","source":"poll"}\n' \
          "$SHA" "$PR_NUM"
        exit 0
      fi
      sleep "$INTERVAL"
      continue
    fi
    target=$(jq -r '.target_url // ""' <<<"$cr_obj")
    printf '{"state":"%s","sha":"%s","pr":%s,"target_url":"%s","source":"poll"}\n' "$s" "$SHA" "$PR_NUM" "$target"
    exit 0
  fi

  now_ts=$(date +%s)
  elapsed=$((now_ts - start_ts))
  if [ -z "$s" ] && [ "$elapsed" -ge "$EARLY_CHECK_WINDOW" ]; then
    if rl=$(bash "$SCRIPT_DIR/sniff-cr-rate-limit.sh" "$OWNER" "$REPO" "$PR_NUM" "$PUSH_TIME" 2>/dev/null); then
      reset=$(jq -r '.reset_minutes_estimate' <<<"$rl")
      hits=$(jq -r '.hits' <<<"$rl")
      printf '{"state":"rate_limited","sha":"%s","pr":%s,"reset_minutes_estimate":%s,"hits":%s,"source":"poll"}\n' \
        "$SHA" "$PR_NUM" "$reset" "$hits"
      exit 0
    fi
  fi

  sleep "$INTERVAL"
done
