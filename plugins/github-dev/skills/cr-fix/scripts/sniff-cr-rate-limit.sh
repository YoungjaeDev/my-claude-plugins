#!/usr/bin/env bash
# Usage: bash scripts/sniff-cr-rate-limit.sh OWNER REPO PR_NUM PUSH_TIME
# Detects CodeRabbit rate-limit signal across three channels:
#   1. issue-comment body created OR updated after PUSH_TIME (catches in-place edits)
#   2. review body submitted after PUSH_TIME
#   3. commit-status `description` on the latest CodeRabbit context (newer CR variant —
#      "Review skipped: free tier disabled")
# Exit 0 = detected (emits JSON: {hits, reset_minutes_estimate, channel}).
# Exit 1 = no match.
#
# --paginate is used on all REST calls per plugins/github-dev/CLAUDE.md (default per_page=30
# can drop early rows on PRs with >30 comments / >30 statuses).
set -euo pipefail

OWNER="${1:?owner required}"; REPO="${2:?repo required}"; PR_NUM="${3:?pr required}"; PUSH_TIME="${4:?push time required}"

# Channel 1+2: issue-comments + reviews
# updated_at > push_time matters because CR edits its in-flight comment to add the
# rate-limit notice rather than posting a new one (PR #30 case study).
bodies=$(
  {
    gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUM/comments" 2>/dev/null \
      | jq -s --arg t "$PUSH_TIME" 'add // []
          | [ .[] | select(.user.login | test("coderabbit"; "i"))
                  | select(.created_at > $t or .updated_at > $t)
                  | .body // "" ]'
    gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUM/reviews" 2>/dev/null \
      | jq -s --arg t "$PUSH_TIME" 'add // []
          | [ .[] | select(.user.login | test("coderabbit"; "i"))
                  | select(.submitted_at > $t)
                  | .body // "" ]'
  } | jq -s 'add // []'
)

# Channel 3: commit-status description on the most recent CodeRabbit context for PR_NUM's HEAD SHA.
# Pulled SHA-scoped via the PR object so we don't confuse statuses from old SHAs.
status_desc=""
if pr_obj=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUM" 2>/dev/null); then
  head_sha=$(jq -r '.head.sha // ""' <<<"$pr_obj")
  if [ -n "$head_sha" ]; then
    status_desc=$(gh api --paginate "repos/$OWNER/$REPO/commits/$head_sha/statuses" 2>/dev/null \
      | jq -sr 'add // []
                | [ .[] | select(.context | test("CodeRabbit"; "i")) ]
                | sort_by(.created_at) | reverse | .[0].description // ""')
  fi
fi

# 4 patterns now: 3 historic + 1 free-tier-disabled
pattern='auto-generated comment: rate limited by coderabbit\.ai|More reviews will be available in|Review limit reached|Review skipped: free tier disabled'

hits=$(jq --arg p "$pattern" '[ .[] | select(test($p; "i")) ] | length' <<<"$bodies")
desc_hit=0
if [ -n "$status_desc" ] && jq -nr --arg d "$status_desc" --arg p "$pattern" '$d | test($p; "i")' \
       | grep -q true 2>/dev/null; then
  desc_hit=1
fi

total=$((hits + desc_hit))
if [ "$total" -eq 0 ]; then exit 1; fi

# Determine reset estimate from any source.
# jq `capture()` THROWS on non-match (not null) — `// empty` only catches null/false.
# Wrap in `try ... catch empty` so non-matching bodies don't kill the script under
# `set -euo pipefail`.
reset=$(jq -r '[ .[] | (try capture("More reviews will be available in (?<m>[0-9]+) minutes?"; "i").m catch empty) ] | first // empty' <<<"$bodies")
if [ -z "$reset" ] && [ -n "$status_desc" ]; then
  reset=$(jq -nr --arg d "$status_desc" \
    'try ($d | capture("More reviews will be available in (?<m>[0-9]+) minutes?"; "i").m) catch empty')
fi
reset="${reset:-null}"

if [ "$hits" -gt 0 ] && [ "$desc_hit" -gt 0 ]; then channel="both"
elif [ "$hits" -gt 0 ]; then channel="comment"
else channel="description"
fi

printf '{"hits":%s,"reset_minutes_estimate":%s,"channel":"%s"}\n' "$total" "$reset" "$channel"
