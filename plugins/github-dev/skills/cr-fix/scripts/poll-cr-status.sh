#!/usr/bin/env bash
# Usage: OWNER=... REPO=... SHA=... PR_NUM=... INTERVAL=... PUSH_TIME=... TIMEOUT=...
#        bash scripts/poll-cr-status.sh
# Runs in background via Bash(run_in_background=true). Caller uses Monitor.
# Emits exactly one terminal JSON line:
#   {"state":"success|failure","target_url":"..."}                      (CR responded)
#   {"state":"rate_limited","reset_minutes_estimate":N,"hits":N}        (early escape — hang fix)
#   {"state":"error","channel":"status|check_run"}                      (persistent fetch failure)
# Exits 0 on success/failure/rate_limited/error terminal; timeout governed by surrounding Bash timeout.
#
# Hang-fix design (Step 6, replaces 1800s unilateral spin):
#   - After EARLY_CHECK_WINDOW seconds of wall-clock without seeing status, probe rate-limit body.
#   - If rate-limit detected, emit rate_limited JSON and exit 0 → SKILL.md Step 7c.
#   - Otherwise keep polling status.
set -euo pipefail

: "${OWNER:?}"; : "${REPO:?}"; : "${SHA:?}"; : "${PR_NUM:?}"; : "${INTERVAL:=8}"; : "${PUSH_TIME:?}"
EARLY_CHECK_WINDOW="${EARLY_CHECK_WINDOW:-30}"
# CodeRabbit briefly posts `success` + "Review skipped: free tier disabled" (an
# hourly fair-usage quota refill, transient ~5min) before the real "Review
# completed". Hold that row non-terminal for CR_SKIP_GRACE seconds; only if it
# never flips do we route to rate_limited (so we never wait forever).
CR_SKIP_GRACE="${CR_SKIP_GRACE:-300}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wall-clock start: the EARLY_CHECK_WINDOW must compare against real seconds
# elapsed, not `elapsed` accumulated only after a full sleep. With a 60s INTERVAL
# the old `elapsed -ge 30` test first becomes true at t=60 (after one sleep),
# silently doubling the documented 30s rate-limit detection window.
start_ts=$(date +%s)

# state:"error" from cr-commit-state.sh means the fetch itself failed (auth /
# network / secondary rate limit) — distinct from "CR has not responded". A
# single transient error self-heals next round; a streak means the credential
# or network is actually broken, so surface it instead of spinning to TIMEOUT.
ERROR_STREAK_MAX="${ERROR_STREAK_MAX:-3}"
err_streak=0

# Pull CR's reported state ONCE per loop iteration. cr-commit-state.sh reads the
# commit-status API first and falls back to check-runs, because CodeRabbit uses
# one surface or the other depending on the install. Polling /statuses alone made
# a check-run repo spin here until TIMEOUT even though the review had finished
# (issue #105). It normalizes both onto success|failure|pending|none.
fetch_cr_state() {
  bash "$SCRIPT_DIR/cr-commit-state.sh" "$OWNER" "$REPO" "$SHA" 2>/dev/null || echo '{}'
}

while true; do
  cr_obj=$(fetch_cr_state)
  # "none" (no CR row on either surface yet) and "pending" both mean "keep waiting";
  # the EARLY_CHECK_WINDOW rate-limit probe below tests for the empty string, so
  # normalize both to "" rather than letting "none" slip past it.
  s=$(jq -r 'if (.state // "none") == "none" or (.state // "") == "pending" then "" else .state end' <<<"$cr_obj")
  desc=$(jq -r '.description // ""' <<<"$cr_obj")

  if [ "$s" = "error" ]; then
    err_streak=$((err_streak + 1))
    if [ "$err_streak" -ge "$ERROR_STREAK_MAX" ]; then
      ch=$(jq -r '.channel // ""' <<<"$cr_obj")
      printf '{"state":"error","sha":"%s","pr":%s,"channel":"%s","source":"poll"}\n' "$SHA" "$PR_NUM" "$ch"
      exit 0
    fi
    sleep "$INTERVAL"
    continue
  fi
  err_streak=0

  # Free-tier transient: success row whose description is the quota-refill
  # placeholder (NOT genuine `Review limit reached`/`rate limited`). Keep
  # polling until it flips to `Review completed`, or grace expires.
  if [ "$s" = "success" ] && printf '%s' "$desc" | grep -qiE '^Review skipped: free tier disabled'; then
    now_ts=$(date +%s)
    : "${skip_first_ts:=$now_ts}"
    if [ "$((now_ts - skip_first_ts))" -ge "$CR_SKIP_GRACE" ]; then
      reset=null; hits=null
      if rl=$(bash "$SCRIPT_DIR/sniff-cr-rate-limit.sh" "$OWNER" "$REPO" "$PR_NUM" "$PUSH_TIME" 2>/dev/null); then
        reset=$(jq -r '.reset_minutes_estimate // "null"' <<<"$rl")
        hits=$(jq -r '.hits // "null"' <<<"$rl")
      fi
      printf '{"state":"rate_limited","sha":"%s","pr":%s,"reset_minutes_estimate":%s,"hits":%s,"source":"poll"}\n' \
        "$SHA" "$PR_NUM" "$reset" "$hits"
      exit 0
    fi
    sleep "$INTERVAL"
    continue
  fi

  if [ "$s" = "success" ] || [ "$s" = "failure" ]; then
    target=$(jq -r '.target_url // ""' <<<"$cr_obj")
    printf '{"state":"%s","sha":"%s","pr":%s,"target_url":"%s","source":"poll"}\n' "$s" "$SHA" "$PR_NUM" "$target"
    exit 0
  fi

  now_ts=$(date +%s)
  elapsed=$((now_ts - start_ts))
  if [ -z "$s" ] && [ "$elapsed" -ge "$EARLY_CHECK_WINDOW" ]; then
    if rl=$(bash "$SCRIPT_DIR/sniff-cr-rate-limit.sh" "$OWNER" "$REPO" "$PR_NUM" "$PUSH_TIME" 2>/dev/null); then
      # A rate-limit sniff on comment/description TEXT is not authoritative: the
      # commit-status may have flipped to a terminal success/failure between the
      # top-of-loop fetch and this probe (a stale rate-limit comment from an
      # earlier push lingers on the PR). Re-read the commit-state and let a fresh
      # terminal state win; only emit rate_limited when it is still non-terminal.
      fresh_obj=$(fetch_cr_state)
      fresh=$(jq -r 'if (.state // "none") == "none" or (.state // "") == "pending" then "" else .state end' <<<"$fresh_obj")
      if [ "$fresh" = "success" ] || [ "$fresh" = "failure" ]; then
        target=$(jq -r '.target_url // ""' <<<"$fresh_obj")
        printf '{"state":"%s","sha":"%s","pr":%s,"target_url":"%s","source":"poll"}\n' "$fresh" "$SHA" "$PR_NUM" "$target"
        exit 0
      fi
      reset=$(jq -r '.reset_minutes_estimate' <<<"$rl")
      hits=$(jq -r '.hits' <<<"$rl")
      printf '{"state":"rate_limited","sha":"%s","pr":%s,"reset_minutes_estimate":%s,"hits":%s,"source":"poll"}\n' \
        "$SHA" "$PR_NUM" "$reset" "$hits"
      exit 0
    fi
  fi

  sleep "$INTERVAL"
done
