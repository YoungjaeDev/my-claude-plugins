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
#   - After EARLY_CHECK_WINDOW seconds without seeing status, probe rate-limit body.
#   - If rate-limit detected, emit rate_limited JSON and exit 0 → SKILL.md Step 7c.
#   - Otherwise keep polling status.
set -euo pipefail

: "${OWNER:?}"; : "${REPO:?}"; : "${SHA:?}"; : "${PR_NUM:?}"; : "${INTERVAL:=60}"; : "${PUSH_TIME:?}"
EARLY_CHECK_WINDOW="${EARLY_CHECK_WINDOW:-30}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

elapsed=0
while true; do
  s=$(gh api "repos/$OWNER/$REPO/commits/$SHA/status" \
    --jq '.statuses[] | select(.context | test("CodeRabbit"; "i")) | .state' 2>/dev/null \
    | head -n1 || true)

  if [ "$s" = "success" ] || [ "$s" = "failure" ]; then
    target=$(gh api "repos/$OWNER/$REPO/commits/$SHA/status" \
      --jq '.statuses[] | select(.context | test("CodeRabbit"; "i")) | .target_url' 2>/dev/null \
      | head -n1 || true)
    printf '{"state":"%s","sha":"%s","pr":%s,"target_url":"%s","source":"poll"}\n' "$s" "$SHA" "$PR_NUM" "$target"
    exit 0
  fi

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
  elapsed=$((elapsed + INTERVAL))
done
