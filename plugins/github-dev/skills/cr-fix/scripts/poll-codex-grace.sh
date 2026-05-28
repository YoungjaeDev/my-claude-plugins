#!/usr/bin/env bash
# Usage: OWNER=... REPO=... PR_NUM=... PROCESSED='[123,456]' INTERVAL=15 bash scripts/poll-codex-grace.sh
# Background poll for an unprocessed Codex review id. Caller wraps with Bash(timeout=CODEX_GRACE*1000).
# Emits exactly one terminal JSON line:
#   {"codex_review_id":NUM,"pr":NUM}    (found)
# If grace expires (caller timeout), no line emitted; SKILL.md handles via Monitor.
set -euo pipefail

: "${OWNER:?}"; : "${REPO:?}"; : "${PR_NUM:?}"; : "${PROCESSED:=[]}"; : "${INTERVAL:=15}"

until id=$(gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUM/reviews" 2>/dev/null \
    | jq -s --argjson processed "$PROCESSED" '
        add // []
        | [ .[]
            | select(.user.login == "chatgpt-codex-connector[bot]")
            | select(.state == "COMMENTED" or .state == "CHANGES_REQUESTED")
            | select(.id as $i | $processed | index($i) | not) ]
        | sort_by(.submitted_at) | last | .id // ""'); \
      [ -n "$id" ] && [ "$id" != "null" ]; do
  sleep "$INTERVAL"
done

printf '{"codex_review_id":%s,"pr":%s}\n' "$id" "$PR_NUM"
