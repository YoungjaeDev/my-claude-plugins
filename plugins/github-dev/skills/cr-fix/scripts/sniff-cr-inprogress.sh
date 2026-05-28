#!/usr/bin/env bash
# Usage: bash scripts/sniff-cr-inprogress.sh OWNER REPO PR_NUM PUSH_TIME
# Prints count of "Come back again in a few minutes" bodies posted after PUSH_TIME.
# Caller decides whether to sleep + re-poll Step 6.
set -euo pipefail

OWNER="${1:?owner required}"; REPO="${2:?repo required}"; PR_NUM="${3:?pr required}"; PUSH_TIME="${4:?push time required}"

gh pr view "$PR_NUM" --repo "$OWNER/$REPO" --json comments,reviews \
  | jq --arg t "$PUSH_TIME" '
    [
      (.comments[]? | select(.author.login | test("coderabbit"; "i")) | select(.createdAt > $t) | .body // ""),
      (.reviews[]?  | select(.author.login | test("coderabbit"; "i")) | select(.submittedAt > $t) | .body // "")
    ]
    | map(select(test("Come back again in a few minutes"; "i")))
    | length
  '
