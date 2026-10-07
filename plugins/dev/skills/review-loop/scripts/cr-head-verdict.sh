#!/usr/bin/env bash
# Usage: bash scripts/cr-head-verdict.sh OWNER REPO PR_NUM HEAD_SHA
# Prints CodeRabbit's HEAD verdict (GLOSSARY "HEAD 판정") as one word:
#   findings  a CodeRabbit review on HEAD posted actionable comments
#   clean     a CodeRabbit review on HEAD posted 0 actionable comments, or the
#             walkthrough comment says "No actionable comments were generated"
#             for a range ending at HEAD (a clean re-review posts no review)
#   none      nothing CodeRabbit wrote is attached to HEAD
#
# The success status is deliberately NOT read: it stands on pushes CR never
# reviewed ("Review rate limited" passes by design), so it is no verdict. A
# rate-limit or skip notice is not one either. ADR 0002.
#
# Exit 1 with no stdout when a listing cannot be fetched — "could not look" must
# never read as "none".
set -uo pipefail

OWNER="${1:?owner required}"; REPO="${2:?repo required}"; PR_NUM="${3:?pr required}"; HEAD_SHA="${4:?head sha required}"
case "$HEAD_SHA" in *[!0-9a-f]*) echo "cr-head-verdict: HEAD_SHA is not a hex sha" >&2; exit 2 ;; esac

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cr-notices.sh"  # CR_NOTICE_RE

reviews=$(gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUM/reviews" 2>/dev/null) \
  || { echo "cr-head-verdict: could not list PR #$PR_NUM reviews" >&2; exit 1; }
comments=$(gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUM/comments" 2>/dev/null) \
  || { echo "cr-head-verdict: could not list PR #$PR_NUM comments" >&2; exit 1; }

# Listings go through stdin, not --argjson: a long PR's walkthroughs outgrow ARG_MAX.
{ jq -cs 'add // []' <<<"$reviews" && jq -cs 'add // []' <<<"$comments"; } \
| jq -rs --arg h "$HEAD_SHA" --arg n "$CR_NOTICE_RE" '
  .[0] as $reviews | .[1] as $comments
  | def cr: (.user.login // "") | test("^coderabbitai(\\[bot\\])?$"; "i");
  def not_notice: (.body // "") | test($n; "i") | not;
  [ $reviews[] | select(cr and .commit_id == $h and not_notice) ] as $on_head
  | if ($on_head | length) > 0 then
      # An unreadable count still means CR reviewed HEAD; the threads say what.
      if all($on_head[]; (.body // "") | test("Actionable comments posted:\\s*0\\b"; "i"))
      then "clean" else "findings" end
    elif any($comments[]; cr and not_notice
             and ((.body // "") | test("No actionable comments were generated"; "i"))
             and ((.body // "") | test("between [0-9a-f]+ and " + $h; "i")))
    then "clean"
    else "none" end' \
  || { echo "cr-head-verdict: could not parse PR #$PR_NUM listings" >&2; exit 1; }
