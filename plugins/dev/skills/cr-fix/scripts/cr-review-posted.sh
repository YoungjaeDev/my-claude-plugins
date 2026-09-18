#!/usr/bin/env bash
# Usage: bash scripts/cr-review-posted.sh OWNER REPO PR_NUM SINCE
# Decides whether cr-fix may post `@coderabbitai review` for the current head.
# Prints `skip` when the PR already has a comment whose body is exactly
# `@coderabbitai review` (whitespace trimmed) created at or after SINCE (the head
# SHA's push time), so a re-run on an unchanged head does not request twice.
# Prints `post` otherwise.
#
# No author match: the requester is the user's own account, and the body is the
# whole signal. The PR's comments are the record; there is no state file.
#
# Exit 1 with no stdout when the comments cannot be read. The caller must then
# NOT post: an unchecked post is exactly the duplicate this script prevents.
set -uo pipefail

OWNER="${1:?owner required}"; REPO="${2:?repo required}"; PR_NUM="${3:?pr required}"; SINCE="${4:?push time required}"

raw=$(gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUM/comments" 2>/dev/null) \
  || { echo "cr-review-posted: could not list PR #$PR_NUM comments; not posting" >&2; exit 1; }

jq -rs --arg since "$SINCE" '
  (add // [])
  | if any(.[]; ((.body // "") | gsub("^\\s+|\\s+$"; "")) == "@coderabbitai review"
                and (.created_at // "") >= $since)
    then "skip" else "post" end' <<<"$raw" \
  || { echo "cr-review-posted: could not parse PR #$PR_NUM comments; not posting" >&2; exit 1; }
