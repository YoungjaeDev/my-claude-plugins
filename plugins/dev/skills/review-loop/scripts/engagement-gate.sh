#!/usr/bin/env bash
# Usage: bash scripts/engagement-gate.sh OWNER REPO PR_NUM PUSH_TIME
# Prints integer: count of CR reviews+comments posted on this PR after PUSH_TIME.
# Caller decides convergence vs cr_inactive per references/failure-modes.md.
set -euo pipefail

OWNER="${1:?owner required}"; REPO="${2:?repo required}"; PR_NUM="${3:?pr required}"; PUSH_TIME="${4:?push time required}"

# A rate-limit or skip notice is CodeRabbit saying it did NOT review, and CR
# edits that notice in place on every limited push — so with the updated_at
# anchor below, a notice edit read as engagement and Step 8c converged to a
# false clean (PR #223).
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cr-notices.sh"  # CR_NOTICE_RE

reviews=$(gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUM/reviews" 2>/dev/null \
  | jq -s 'add // []' \
  | jq --arg t "$PUSH_TIME" --arg n "$CR_NOTICE_RE" '[.[] | select((.user.login // "") | test("^coderabbitai(\\[bot\\])?$"; "i")) | select(.submitted_at > $t) | select((.body // "") | test($n; "i") | not)] | length')

# updated_at, not just created_at: when a re-review finds nothing, CR does not
# post a new comment — it edits its existing walkthrough in place, leaving
# created_at at the FIRST review. Counting created_at alone read that as "CR
# never looked at this push", so Step 8c waited out the iteration budget and
# ended in cr_inactive, making --auto-merge unreachable on the normal converged
# path. sniff-cr-rate-limit.sh:25 already anchors both ways for the same reason.
# (issue #184; reviews above keep submitted_at — a review body is not edited in
# place the way the walkthrough comment is. unverified, tracked in #184.)
comments=$(gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUM/comments" 2>/dev/null \
  | jq -s 'add // []' \
  | jq --arg t "$PUSH_TIME" --arg n "$CR_NOTICE_RE" '[.[] | select((.user.login // "") | test("^coderabbitai(\\[bot\\])?$"; "i")) | select(.created_at > $t or .updated_at > $t) | select((.body // "") | test($n; "i") | not)] | length')

printf '%d\n' "$((reviews + comments))"
