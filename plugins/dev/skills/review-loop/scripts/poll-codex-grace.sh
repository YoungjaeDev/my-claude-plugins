#!/usr/bin/env bash
# Usage: OWNER=... REPO=... PR_NUM=... PROCESSED='[123,456]' INTERVAL=15 [CUR_SHA=...] \
#        bash scripts/poll-codex-grace.sh
# Background poll for an unprocessed Codex review id. Caller wraps with
# Bash(timeout=grace_cap*1000), grace_cap = codex-head-verdict.sh .wait_seconds.
# Emits exactly one terminal JSON line:
#   {"codex_review_id":NUM,"pr":NUM}                  (found)
#   {"codex_review_id":null,"pr":NUM,"verdict":V}     (CUR_SHA set and Codex's HEAD
#                                                      verdict is clean or failed:
#                                                      no review will arrive)
# An unreadable summary (verdict unknown) keeps plain review-id polling.
# If grace expires (caller timeout), no line emitted; SKILL.md handles via Monitor.
set -euo pipefail

: "${OWNER:?}"; : "${REPO:?}"; : "${PR_NUM:?}"; : "${PROCESSED:=[]}"; : "${INTERVAL:=15}"
CUR_SHA="${CUR_SHA:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
  if [ -n "$CUR_SHA" ]; then
    # rc 1 = verdict error (gh failed): transient, keep polling.
    if v=$(OWNER="$OWNER" REPO="$REPO" PR_NUM="$PR_NUM" CUR_SHA="$CUR_SHA" \
           bash "$HERE/codex-head-verdict.sh" 2>/dev/null); then
      verdict=$(jq -r '.verdict' <<<"$v")
      case "$verdict" in
        clean|failed)
          printf '{"codex_review_id":null,"pr":%s,"verdict":"%s"}\n' "$PR_NUM" "$verdict"
          exit 0 ;;
      esac
    fi
  fi
  sleep "$INTERVAL"
done

printf '{"codex_review_id":%s,"pr":%s}\n' "$id" "$PR_NUM"
