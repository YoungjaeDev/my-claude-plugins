#!/usr/bin/env bash
# Usage: bash scripts/fetch-codex-comments.sh OWNER REPO PR_NUM REVIEW_ID
# Emits JSON array of Codex inline comments under the given review id.
# Filter: pull_request_review_id == REVIEW_ID (stable across SHA progression).
# See references/codex-state-machine.md for the rationale.
set -euo pipefail

OWNER="${1:?owner required}"; REPO="${2:?repo required}"; PR_NUM="${3:?pr required}"; RID="${4:?review id required}"

if [ -z "$RID" ] || [ "$RID" = "null" ]; then printf '[]\n'; exit 0; fi

gh api "repos/$OWNER/$REPO/pulls/$PR_NUM/comments" --paginate 2>/dev/null \
  | jq -s --argjson rid "$RID" '
    add // []
    | [ .[]
        | select(.user.login == "chatgpt-codex-connector[bot]")
        | select(.pull_request_review_id == $rid)
        | {
            source: "codex",
            path: .path,
            line: .line,
            body: .body,
            comment_id: .id,
            p_badge: ((.body | capture("!\\[P(?<p>[123]) Badge\\]").p) // "none")
          }
      ]'
