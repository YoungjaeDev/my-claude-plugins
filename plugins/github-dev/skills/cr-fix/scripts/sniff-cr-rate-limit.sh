#!/usr/bin/env bash
# Usage: bash scripts/sniff-cr-rate-limit.sh OWNER REPO PR_NUM PUSH_TIME
# Detects CodeRabbit rate-limit comment posted after PUSH_TIME.
# Exit 0 = detected (emits JSON: {hits, reset_minutes_estimate}). Exit 1 = no match.
set -euo pipefail

OWNER="${1:?owner required}"; REPO="${2:?repo required}"; PR_NUM="${3:?pr required}"; PUSH_TIME="${4:?push time required}"

bodies=$(gh pr view "$PR_NUM" --repo "$OWNER/$REPO" --json comments,reviews 2>/dev/null \
  | jq --arg t "$PUSH_TIME" '
    [ (.comments[]? | select(.author.login | test("coderabbit"; "i")) | select(.createdAt > $t) | .body // ""),
      (.reviews[]?  | select(.author.login | test("coderabbit"; "i")) | select(.submittedAt > $t) | .body // "") ]
  ')

# 3 patterns per references/rate-limit-fallback.md
hits=$(jq '[ .[] | select(test("auto-generated comment: rate limited by coderabbit\\.ai|More reviews will be available in|Review limit reached"; "i")) ] | length' <<<"$bodies")

if [ "$hits" -eq 0 ]; then exit 1; fi

reset=$(jq -r '[ .[] | capture("More reviews will be available in (?<m>[0-9]+) minutes?"; "i").m // empty ] | first // empty' <<<"$bodies")
reset="${reset:-null}"
printf '{"hits":%s,"reset_minutes_estimate":%s}\n' "$hits" "$reset"
