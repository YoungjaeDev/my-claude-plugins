#!/usr/bin/env bash
# Usage: bash scripts/auto-merge-gate.sh OWNER REPO PR_NUM HEAD_SHA
# Returns JSON on stdout summarizing the 4 gates:
#   {"cr_state":"success|...", "blocking_checks":N, "base_branch":"...", "protection_http":200|404|0}
# Caller (SKILL.md Step 15) decides:
#   - protection_http == 200 → `gh pr merge --auto --squash --delete-branch`
#   - protection_http == 404 → AskUserQuestion (Merge now / Skip / Cancel)
#   - protection_http == 0   → probe failed (network/auth/5xx) — no merge
# This script does NOT call gh pr merge — separation of probe vs action.
set -euo pipefail

OWNER="${1:?}"; REPO="${2:?}"; PR_NUM="${3:?}"; HEAD_SHA="${4:?}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# CR state must come from the SAME dual-surface reader the rest of cr-fix uses.
# CodeRabbit reports through EITHER the commit-status API OR a check-run,
# per install. This gate read /statuses only, so on a check-run repo it saw
# no CR row and reported cr_state:"unknown" forever — Step 15 then never merged
# on `--auto-merge` even though CR had completed. cr-commit-state.sh already
# unifies both surfaces (14 fixture cases); delegate to it, don't re-derive.
# (self-found on PR #122 merge verify — the missed sibling of the same
# check-run trap fixed in pre-flight/poll-cr-status/sniff. See .llmwiki
# detector-cannot-look-vs-nothing-wrong.)
cr_state=$(bash "$SCRIPT_DIR/cr-commit-state.sh" "$OWNER" "$REPO" "$HEAD_SHA" 2>/dev/null \
  | jq -r '.state // "unknown"' || echo "unknown")
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
# Only 200 (protected) and 404 (unprotected) are trusted probe outcomes. An
# empty or other status (network, auth, 5xx) must not masquerade as
# "unprotected" — report 0 so Step 15 refuses to merge on an unverified state.
case "$http" in 200|404) : ;; *) http=0 ;; esac

jq -nc \
  --arg cr "$cr_state" \
  --argjson bc "$blocking" \
  --arg base "$base" \
  --argjson http "$http" \
  '{cr_state:$cr, blocking_checks:$bc, base_branch:$base, protection_http:$http}'
