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

  if jq -e '.errors // (.data.repository // empty | not)' <<<"$response" >/dev/null 2>&1; then
    echo "GraphQL fetch returned errors or null repository:" >&2
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
