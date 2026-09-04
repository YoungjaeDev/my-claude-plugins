#!/usr/bin/env bash
# Usage: bash scripts/fetch-cr-threads.sh OWNER REPO PR_NUM
# Emits a JSON array of actionable CR threads (isResolved=false, isOutdated=false, author=coderabbit*).
# Each element has: {source:"cr", path, line, startLine, originalLine, body, databaseId, type, severity}.
# Exit non-zero on GraphQL error or null repository.
set -euo pipefail

OWNER="${1:?owner required}"; REPO="${2:?repo required}"; PR_NUM="${3:?pr required}"

all='[]'
cursor=""
while :; do
  args=(-F owner="$OWNER" -F repo="$REPO" -F pr="$PR_NUM")
  [ -n "$cursor" ] && args+=(-F cursor="$cursor")
  # TEST SEAM: CR_THREADS_RESPONSE_FILE replaces the GraphQL call with a captured
  # response so the null-repository detector is verifiable without network.
  if [ -n "${CR_THREADS_RESPONSE_FILE:-}" ]; then response=$(cat "$CR_THREADS_RESPONSE_FILE"); else
  response=$(gh api graphql "${args[@]}" -f query='query($owner:String!, $repo:String!, $pr:Int!, $cursor:String) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$pr) {
        title
        reviewThreads(first:100, after:$cursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            isResolved isOutdated
            comments(first:1) {
              nodes { databaseId body path line startLine originalLine author { login } }
            }
          }
        }
      }
    }
  }') || { echo "error: GraphQL request failed" >&2; exit 1; }
  fi

  # A healthy page has no top-level errors, an actual reviewThreads.nodes
  # array, AND coherent pagination. Guard the SUCCESS condition and fail on its
  # negation, so a null repository, a null pullRequest (wrong PR number,
  # deleted PR), or any malformed response lands here rather than exiting 4
  # unmatched and letting the loop project an empty array — a false "clean"
  # convergence. errors must be an absent key or an empty ARRAY (an object —
  # even {} — is an unknown shape and fails loud). pageInfo must be an object,
  # and hasNextPage=true requires a non-empty endCursor: a missing pageInfo
  # silently truncates multi-page threads, and a cursorless hasNextPage
  # re-reads the first page forever.
  # `null // empty | not` produced empty (exit 4), which the old `if jq -e` read
  # as "no error" and skipped this branch. See .llmwiki jq-capture-yields-empty.
  if ! jq -e '(.errors == null or ((.errors | type) == "array" and (.errors | length) == 0))
              and ((.data.repository.pullRequest.reviewThreads.nodes // null) | type == "array")
              and (.data.repository.pullRequest.reviewThreads.pageInfo as $pi
                   | (($pi | type) == "object")
                     and (($pi.hasNextPage != true)
                          or ((($pi.endCursor // "") | type) == "string" and (($pi.endCursor // "") | length) > 0)))' \
       <<<"$response" >/dev/null 2>&1; then
    echo "GraphQL fetch returned errors, a null repository/pullRequest, or malformed pagination:" >&2
    jq -r '.errors[]?.message // "no errors field"' <<<"$response" >&2
    exit 1
  fi

  all=$(jq -c --argjson r "$response" '. + $r.data.repository.pullRequest.reviewThreads.nodes' <<<"$all")
  has_next=$(jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage' <<<"$response")
  cursor=$(jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor // empty' <<<"$response")
  [ "$has_next" = "true" ] || break
done

# Filter + project into unified record. type/severity extracted from header.
jq -c '
  [ .[]
    | select(.isResolved == false and .isOutdated == false)
    | .comments.nodes[0] as $c
    | select(($c.author.login // "") | test("coderabbit"; "i"))
    | {
        source: "cr",
        path: $c.path,
        line: ($c.line // $c.startLine // $c.originalLine),
        startLine: $c.startLine,
        originalLine: $c.originalLine,
        body: $c.body,
        databaseId: $c.databaseId,
        # header regex: _Type_ | _Severity_
        type_emoji:     (($c.body | capture("_(?<t>[^_]+)_\\s*\\|\\s*_(?<s>[^_]+)_").t) // null),
        severity_emoji: (($c.body | capture("_(?<t>[^_]+)_\\s*\\|\\s*_(?<s>[^_]+)_").s) // null)
      }
  ]
' <<<"$all"
