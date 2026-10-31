#!/usr/bin/env bash
# Usage: bash scripts/sniff-cr-inprogress.sh OWNER REPO PR_NUM PUSH_TIME
# Prints count of "Come back again in a few minutes" bodies posted after PUSH_TIME.
# Caller decides whether to sleep + re-poll Step 6.
set -euo pipefail

jq_lf="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../scripts/jq-lf.sh"; if [ -f "$jq_lf" ]; then . "$jq_lf"; fi  # drops CR from Windows jq output; absent in test copies
OWNER="${1:?owner required}"; REPO="${2:?repo required}"; PR_NUM="${3:?pr required}"; PUSH_TIME="${4:?push time required}"

# `gh pr view --json comments,reviews` runs one GraphQL query with a 100-node
# default page size and no pagination knob — on long-lived PRs the in-progress
# marker can be silently dropped past the cutoff. Use --paginate against the
# REST endpoints and slurp via `jq -s 'add // []'` so nothing is missed.
# No `|| echo '[]'`: a failed fetch exits nonzero (pipefail) instead of reading as "0 in progress".
issue_comments=$(gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUM/comments" | jq -s 'add // []')
pr_reviews=$(gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUM/reviews" | jq -s 'add // []')

# Comments and reviews go through stdin, not --argjson: a long PR outgrows ARG_MAX.
{ printf '%s\n' "$issue_comments"; printf '%s\n' "$pr_reviews"; } \
| jq -s --arg t "$PUSH_TIME" '
  .[0] as $comments | .[1] as $reviews
  | [ ($comments[]? | select((.user.login // "") | test("^coderabbitai(\\[bot\\])?$"; "i"))
                  | select(.created_at > $t) | .body // ""),
    ($reviews[]?  | select((.user.login // "") | test("^coderabbitai(\\[bot\\])?$"; "i"))
                  | select(.submitted_at > $t) | .body // "") ]
  | map(select(test("Come back again in a few minutes"; "i")))
  | length
'
