#!/usr/bin/env bash
# Usage: OWNER=... REPO=... PR_NUM=... PROCESSED='[123,456]' INTERVAL=15 [CUR_SHA=...] \
#        [PUSH_TIME=ISO8601] [CAP=grace_cap] bash scripts/poll-codex-grace.sh
# Background poll for an unprocessed Codex review id, ending at its own deadline
# CAP (default CODEX_BUDGET_DEFAULT, codex-turnaround.sh): grace_cap =
# codex-head-verdict.sh .wait_seconds.
# Emits exactly one terminal JSON line:
#   {"codex_review_id":NUM,"pr":NUM}                  (found)
#   {"codex_review_id":null,"pr":NUM,"verdict":V}     (CUR_SHA set and Codex's HEAD
#                                                      verdict is clean or failed:
#                                                      no review will arrive)
# An unreadable summary (verdict unknown) keeps plain review-id polling.
# Grace expiry (CAP spent) exits 124 with no line; SKILL.md handles via Monitor.
# The next look is next-check.sh's: soon while Codex is Running on HEAD, backed off
# past its slowest turnaround (age from PUSH_TIME; unknown without it).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/codex-turnaround.sh"
: "${OWNER:?}"; : "${REPO:?}"; : "${PR_NUM:?}"; : "${PROCESSED:=[]}"; : "${INTERVAL:=15}"
: "${CAP:=$CODEX_BUDGET_DEFAULT}"
CUR_SHA="${CUR_SHA:-}"; PUSH_TIME="${PUSH_TIME:-}"
push_epoch=$(jq -n --arg t "$PUSH_TIME" 'try ($t | fromdateiso8601 | floor) catch -1')

# jq needs -r here: without it an empty result prints the JSON-encoded string
# '""' (two literal quote chars), which passes [ -n ] and terminated the until
# loop on round 1 — the grace poll never actually waited, and the caller
# received a fabricated empty review id. (self-found, reproduced live iter 5)
until id=$(gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUM/reviews" 2>/dev/null \
    | jq -sr --argjson processed "$PROCESSED" '
        add // []
        | [ .[]
            | select((.user.login // "") | test("^chatgpt-codex-connector(\\[bot\\])?$"; "i"))
            | select(.state == "COMMENTED" or .state == "CHANGES_REQUESTED")
            | select(.id as $i | $processed | index($i) | not) ]
        | sort_by(.submitted_at) | last | .id // ""'); \
      [ -n "$id" ] && [ "$id" != "null" ]; do
  busy=false
  if [ -n "$CUR_SHA" ]; then
    # rc 1 = verdict error (gh failed): transient, keep polling.
    if v=$(OWNER="$OWNER" REPO="$REPO" PR_NUM="$PR_NUM" CUR_SHA="$CUR_SHA" PUSH_TIME="$PUSH_TIME" \
           bash "$HERE/codex-head-verdict.sh" 2>/dev/null); then
      verdict=$(jq -r '.verdict' <<<"$v")
      case "$verdict" in
        clean|failed)
          printf '{"codex_review_id":null,"pr":%s,"verdict":"%s"}\n' "$PR_NUM" "$verdict"
          exit 0 ;;
        in_progress) busy=true ;;
      esac
    fi
  fi
  left=$((CAP - SECONDS))
  [ "$left" -gt 0 ] || exit 124
  if [ "$push_epoch" -ge 0 ]; then age=$(( $(date +%s) - push_epoch )); else age=-1; fi
  sleep "$(bash "$HERE/next-check.sh" "$age" "$left" "$busy" "$INTERVAL")"
done

printf '{"codex_review_id":%s,"pr":%s}\n' "$id" "$PR_NUM"
