#!/usr/bin/env bash
# Usage: bash scripts/fetch-cr-outside-diff.sh OWNER REPO PR_NUM PROCESSED_JSON < thread-records.json
# Adds CodeRabbit's outside-diff findings to the thread records on stdin and
# prints the combined array. Those findings live only in a review body, in the
# "Outside diff range comments (N)" block, never in a thread, so without this the
# loop never judges them.
#
# Each finding becomes a record shaped like a thread record (scripts/fetch-cr-threads.sh)
# plus origin:"outside-diff" and review_id. PROCESSED_JSON is the state file's
# cr_processed_reviews array: those reviews are skipped. A finding on the same
# path and line as a thread is the same finding: the thread record is kept and
# gains the review_id, so the review still gets recorded as processed.
#
# The block format is undocumented (observed on PR #283, review 5427040251). A
# block whose finding count does not match its "(N)" fails loud (exit 1): an
# empty result would read as "nothing outside the diff". The body and path are
# untrusted; they go through path-trust and sanitization in Step 9c like any
# thread record.
set -euo pipefail

OWNER="${1:?owner required}"; REPO="${2:?repo required}"; PR_NUM="${3:?pr required}"
PROCESSED="${4:-[]}"
threads=$(cat)

# TEST SEAM: CR_REVIEWS_RESPONSE_FILE replaces the REST call with an array of pages.
# `jq -s`, not `gh --slurp`: --slurp needs gh 2.45+.
if [ -n "${CR_REVIEWS_RESPONSE_FILE:-}" ]; then pages=$(cat "$CR_REVIEWS_RESPONSE_FILE"); else
  pages=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUM/reviews?per_page=100" --paginate | jq -cs '.') \
    || { echo "error: reviews fetch failed" >&2; exit 1; }
fi

# Thread records and pages go through stdin, not --argjson: a long PR outgrows ARG_MAX.
{ printf '%s\n' "$threads"; printf '%s\n' "$pages"; } \
| jq -cs -L "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" \
   --argjson processed "$PROCESSED" 'include "cr-header";
  # One review -> its outside-diff records. The block is the run of `>`-quoted
  # lines starting at the heading; each finding inside it is
  # `<summary>…</summary><blockquote>` + `path:start-end` + header + body,
  # closed by `</blockquote></details>`.
  def outside_diff:
    .id as $rid
    | (.body // "" | split("\n")) as $L
    | (first(range(0; $L | length)
             | select($L[.] | test("^>.*Outside diff range comments \\(\\d+\\)")))
       // null) as $h
    | if $h == null then
        if (.body // "" | test("Outside diff range comments")) then
          error("review \($rid): outside-diff heading without a quoted \"(N)\" count")
        else [] end
      else
        ($L[$h] | capture("Outside diff range comments \\((?<n>\\d+)\\)").n | tonumber) as $n
        | (reduce $L[$h+1:][] as $l ({done: false, out: []};
             if .done then .
             elif ($l | startswith(">")) then .out += [$l | sub("^> ?"; "")]
             else .done = true end)
           | .out | join("\n")) as $block
        | [ $block | split("</blockquote></details>")[]
            | select(test("<blockquote>"))
            | sub("^[\\s\\S]*?<blockquote>"; "") | sub("^\\s+|\\s+$"; "")
            | . as $body
            | ($body | split("\n") | map(select(test("\\S"))) | .[0] // ""
               | capture("^`(?<path>[^`]+):(?<start>\\d+)(?:-(?<end>\\d+))?`\\s*$")) as $loc
            | { source: "cr", origin: "outside-diff", review_id: $rid,
                path: $loc.path,
                line: (($loc.end // $loc.start) | tonumber),
                startLine: ($loc.start | tonumber),
                originalLine: null, body: $body, databaseId: null }
              + ($body | cr_header) ]
        | if length != $n then
            error("review \($rid): read \(length) of \($n) outside-diff findings (unknown block format)")
          else . end
      end;

  .[0] as $threads | .[1] as $pages
  | [ ($pages | add // [])[]
    | select((.user.login // "") | test("^coderabbitai(\\[bot\\])?$"; "i"))
    | select(.id as $id | $processed | any(. == $id) | not)
    | outside_diff[] ] as $od
  | ($threads | map(. as $t
      | ([$od[] | select(.path == $t.path and .line == $t.line)][0].review_id // null) as $rid
      | if $rid != null and $t.review_id == null then . + {review_id: $rid} else . end))
  + [ $od[] | . as $o | select([$threads[] | select(.path == $o.path and .line == $o.line)] | length == 0) ]
' || { echo "error: outside-diff findings could not be read" >&2; exit 1; }
