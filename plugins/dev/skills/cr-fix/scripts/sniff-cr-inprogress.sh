#!/usr/bin/env bash
# Usage: bash scripts/sniff-cr-inprogress.sh OWNER REPO PR_NUM PUSH_TIME
# Prints count of "Come back again in a few minutes" bodies posted after PUSH_TIME.
# Caller decides whether to sleep + re-poll Step 6.
set -euo pipefail

OWNER="${1:?owner required}"; REPO="${2:?repo required}"; PR_NUM="${3:?pr required}"; PUSH_TIME="${4:?push time required}"

# `gh pr view --json comments,reviews` runs one GraphQL query with a 100-node
# default page size and no pagination knob — on long-lived PRs the in-progress
# marker can be silently dropped past the cutoff. Use --paginate against the
# REST endpoints and slurp via `jq -s 'add // []'` so nothing is missed.
issue_comments=$(gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUM/comments" 2>/dev/null \
  | jq -s 'add // []' || echo '[]')
pr_reviews=$(gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUM/reviews" 2>/dev/null \
  | jq -s 'add // []' || echo '[]')

jq -n --arg t "$PUSH_TIME" \
  --argjson comments "$issue_comments" \
  --argjson reviews  "$pr_reviews" '
  [ ($comments[]? | select((.user.login // "") | test("coderabbit"; "i"))
                  | select(.created_at > $t) | .body // ""),
    ($reviews[]?  | select((.user.login // "") | test("coderabbit"; "i"))
                  | select(.submitted_at > $t) | .body // "") ]
  | map(select(test("Come back again in a few minutes"; "i")))
  | length
'
