#!/usr/bin/env bash
# Usage: [FINAL_STATE=clean] [FOLLOWUP_ISSUE=<number>] \
#          bash scripts/auto-merge-gate.sh OWNER REPO PR_NUM HEAD_SHA
# Returns JSON on stdout summarizing the gates:
#   {"cr_state":"success|...", "blocking_checks":N, "base_branch":"...",
#    "protection_http":200|404|0, "eligible":bool, "ineligible_reason":"..."|null}
# `eligible` covers the convergence axis only — `clean` always qualifies, and
# `minor_floor`/`churn` qualify once the follow-up issue carrying the deferred
# findings exists. The caller still enforces cr_state / blocking_checks /
# protection_http before merging.
# Caller (SKILL.md Step 15) decides:
#   - protection_http == 200 → `gh pr merge --auto --squash --delete-branch`
#   - protection_http == 404 → AskUserQuestion (Merge now / Skip / Cancel)
#   - protection_http == 0   → probe failed (network/auth/5xx) — no merge
# This script does NOT call gh pr merge — separation of probe vs action.
set -euo pipefail

OWNER="${1:?}"; REPO="${2:?}"; PR_NUM="${3:?}"; HEAD_SHA="${4:?}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${FINAL_STATE:=unknown}"; : "${FOLLOWUP_ISSUE:=}"

# Convergence axis. A run that stopped at the low-severity floor or on churn has
# real findings left behind; merging is allowed only once they are recorded in an
# issue, so a failed `gh issue create` keeps the PR open by construction.
case "$FINAL_STATE" in
  clean)              eligible=true;  reason="" ;;
  minor_floor|churn)
    # Only a positive integer counts: a failed create can leave "null", "", or error text behind.
    case "$FOLLOWUP_ISSUE" in
      ""|*[!0-9]*|0*) eligible=false; reason="$FINAL_STATE without a valid follow-up issue number" ;;
      *) eligible=true; reason="" ;;
    esac
    if [ "$eligible" = true ]; then :
    else eligible=false; reason="$FINAL_STATE without a follow-up issue"; fi ;;
  *)                  eligible=false; reason="final_state=$FINAL_STATE is not a merge-eligible convergence" ;;
esac

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
  --argjson eligible "$eligible" \
  --arg reason "$reason" \
  '{cr_state:$cr, blocking_checks:$bc, base_branch:$base, protection_http:$http,
    eligible:$eligible, ineligible_reason:(if $reason == "" then null else $reason end)}'
