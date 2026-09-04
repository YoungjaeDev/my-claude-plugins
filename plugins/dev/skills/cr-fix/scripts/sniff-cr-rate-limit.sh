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
# --paginate is used on all REST calls per plugins/dev/CLAUDE.md (default per_page=30
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

# Channel 3: CR's reported description for PR_NUM's HEAD SHA — commit-status
# `description`, or the check-run `output.title` when the install reports there
# instead. cr-commit-state.sh owns that choice (issue #105); reading /statuses
# directly here left check-run repos with a permanently empty description.
# SHA-scoped via the PR object so we don't confuse rows from old SHAs.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
status_desc=""
if pr_obj=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUM" 2>/dev/null); then
  head_sha=$(jq -r '.head.sha // ""' <<<"$pr_obj")
  if [ -n "$head_sha" ]; then
    status_desc=$(bash "$SCRIPT_DIR/cr-commit-state.sh" "$OWNER" "$REPO" "$head_sha" 2>/dev/null \
      | jq -r '.description // ""' 2>/dev/null || echo "")
  fi
fi

# 5 patterns now: 3 historic + free-tier-disabled + refill phrasing ("Next review
# available in" appears alone in Fair-Usage comments; without it here RESET_RE
# below never runs because hits stays 0)
pattern='auto-generated comment: rate limited by coderabbit\.ai|More reviews will be available in|Next review available in|Review limit reached|Review skipped: free tier disabled'

hits=$(jq --arg p "$pattern" '[ .[] | select(test($p; "i")) ] | length' <<<"$bodies")
desc_hit=0
if [ -n "$status_desc" ] && jq -nr --arg d "$status_desc" --arg p "$pattern" '$d | test($p; "i")' \
       | grep -q true 2>/dev/null; then
  desc_hit=1
fi

total=$((hits + desc_hit))
if [ "$total" -eq 0 ]; then exit 1; fi

# Determine reset estimate from any source.
# Two phrasings are in the wild, and the newer one is wrapped in markdown bold:
#   "More reviews will be available in 41 minutes"
#   "**Next review available in:** **41 minutes**"
# `[^0-9]{0,12}` bridges the `:** **` between the phrase and the number, so the
# minute count survives whatever punctuation CR wraps it in. Only matching the
# older phrasing is why `reset_minutes_estimate` came back null on a comment that
# plainly stated 41 minutes (issue #105).
#
# jq `capture()` yields NO OUTPUT on a non-match — it neither throws nor returns
# null. `try ... catch empty` therefore changes nothing here, but it is kept so a
# genuinely malformed body (invalid regex input) cannot abort the array build.
# The `[ ... ] | first // empty` around it is what turns "no match" into a value.
RESET_RE='(?:More reviews will be available in|Next review available in)[^0-9]{0,12}(?<m>[0-9]+)\s*minutes?'
reset=$(jq -r --arg re "$RESET_RE" '[ .[] | (try capture($re; "i").m catch empty) ] | first // empty' <<<"$bodies")
if [ -z "$reset" ] && [ -n "$status_desc" ]; then
  reset=$(jq -nr --arg d "$status_desc" --arg re "$RESET_RE" \
    'try ($d | capture($re; "i").m) catch empty')
fi
reset="${reset:-null}"

if [ "$hits" -gt 0 ] && [ "$desc_hit" -gt 0 ]; then channel="both"
elif [ "$hits" -gt 0 ]; then channel="comment"
else channel="description"
fi

printf '{"hits":%s,"reset_minutes_estimate":%s,"channel":"%s"}\n' "$total" "$reset" "$channel"
