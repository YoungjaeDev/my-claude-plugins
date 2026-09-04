#!/usr/bin/env bash
# Usage: bash scripts/persist-codex-id.sh STATE_FILE REVIEW_ID
# Appends REVIEW_ID to .codex_processed_reviews in STATE_FILE atomically.
# Uses --argjson because pull_request_review_id is a JSON number.
set -euo pipefail

STATE="${1:?state file required}"
RID="${2:?review id required}"

[ -z "$RID" ] && exit 0
[ "$RID" = "null" ] && exit 0

[ -f "$STATE" ] || { echo "error: state file $STATE not found" >&2; exit 1; }

# Per-invocation tmp file so parallel persist calls on the same STATE don't race.
tmp=$(mktemp "${STATE}.XXXXXX")
trap 'rm -f "$tmp"' EXIT
jq --argjson rid "$RID" \
  '.codex_processed_reviews = ((.codex_processed_reviews // []) + [$rid] | unique)' \
  "$STATE" > "$tmp"
mv "$tmp" "$STATE"
trap - EXIT
