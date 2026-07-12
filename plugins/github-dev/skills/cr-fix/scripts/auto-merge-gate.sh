#!/usr/bin/env bash
# Usage: bash scripts/auto-merge-gate.sh OWNER REPO PR_NUM HEAD_SHA
# Returns JSON on stdout summarizing the 4 gates:
#   {"cr_state":"success|...", "blocking_checks":N, "base_branch":"...", "protection_http":200|404}
# Caller (SKILL.md Step 15) decides:
#   - protection_http == 200 → `gh pr merge --auto --squash --delete-branch`
#   - protection_http != 200 → AskUserQuestion (Merge now / Skip / Cancel)
# This script does NOT call gh pr merge — separation of probe vs action.
set -euo pipefail

OWNER="${1:?}"; REPO="${2:?}"; PR_NUM="${3:?}"; HEAD_SHA="${4:?}"

cr_state=$(
  gh api --paginate "repos/$OWNER/$REPO/commits/$HEAD_SHA/statuses" 2>/dev/null \
    | jq -r -s 'add // []
                | map(select(.context | test("CodeRabbit"; "i")))
                | sort_by(.created_at) | reverse
                | (.[0].state // "unknown")' \
  || echo "unknown")
cr_state="${cr_state:-unknown}"

blocking=$(gh pr checks "$PR_NUM" --json name,state \
  --jq '[.[] | select(.state != "SUCCESS" and .state != "SKIPPED")] | length' 2>/dev/null || echo 0)

base=$(gh pr view "$PR_NUM" --json baseRefName --jq '.baseRefName')

# An unprotected base returns 404: gh api exits non-zero AND its `-i` status line
# prints `404`. Piping straight into `... || echo 404` under `set -o pipefail`
# then emitted BOTH (`404\n404`), which --argjson rejects as invalid JSON and the
# whole gate died silently. Capture the status line in one step (so pipefail can't
# double it), then parse — a single clean value for both 200 and 404.
proto_line=$(gh api "repos/$OWNER/$REPO/branches/$base/protection" --silent -i 2>/dev/null | head -1 || true)
http=$(awk '{print $2}' <<<"$proto_line")
http="${http:-404}"

jq -nc \
  --arg cr "$cr_state" \
  --argjson bc "$blocking" \
  --arg base "$base" \
  --argjson http "$http" \
  '{cr_state:$cr, blocking_checks:$bc, base_branch:$base, protection_http:$http}'
