#!/usr/bin/env bash
# Usage: bash scripts/engagement-gate.sh OWNER REPO PR_NUM PUSH_TIME
# Prints integer: count of CR reviews+comments posted on this PR after PUSH_TIME.
# Caller decides convergence vs cr_inactive per references/failure-modes.md.
set -euo pipefail

OWNER="${1:?owner required}"; REPO="${2:?repo required}"; PR_NUM="${3:?pr required}"; PUSH_TIME="${4:?push time required}"

reviews=$(gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUM/reviews" 2>/dev/null \
  | jq -s 'add // []' \
  | jq --arg t "$PUSH_TIME" '[.[] | select(.user.login | test("coderabbit"; "i")) | select(.submitted_at > $t)] | length')

comments=$(gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUM/comments" 2>/dev/null \
  | jq -s 'add // []' \
  | jq --arg t "$PUSH_TIME" '[.[] | select(.user.login | test("coderabbit"; "i")) | select(.created_at > $t)] | length')

printf '%d\n' "$((reviews + comments))"
