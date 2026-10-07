#!/usr/bin/env bash
# Usage: bash scripts/persist-codex-id.sh STATE_FILE REVIEW_ID [KEY]
# Appends REVIEW_ID to .KEY in STATE_FILE atomically. KEY defaults to
# codex_processed_reviews; cr_processed_reviews holds the CodeRabbit reviews whose
# outside-diff findings were judged (scripts/fetch-cr-outside-diff.sh).
# Uses --argjson because pull_request_review_id is a JSON number.
set -euo pipefail

STATE="${1:?state file required}"
RID="${2:?review id required}"
KEY="${3:-codex_processed_reviews}"

[ -z "$RID" ] && exit 0
[ "$RID" = "null" ] && exit 0

case "$KEY" in
  codex_processed_reviews|cr_processed_reviews) ;;
  *) echo "error: unknown processed-review key: $KEY" >&2; exit 1 ;;
esac

[ -f "$STATE" ] || { echo "error: state file $STATE not found" >&2; exit 1; }

# Per-invocation tmp file so parallel persist calls on the same STATE don't race.
tmp=$(mktemp "${STATE}.XXXXXX")
trap 'rm -f "$tmp"' EXIT
jq --argjson rid "$RID" --arg key "$KEY" \
  '.[$key] = ((.[$key] // []) + [$rid] | unique)' \
  "$STATE" > "$tmp"
mv "$tmp" "$STATE"
trap - EXIT
