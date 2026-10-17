#!/usr/bin/env bash
# Usage: [FINAL_STATE=clean] [FOLLOWUP_ISSUE=<number>] [DEFERRED_TOTAL=N] \
#        [CR_ON=true|false] [CODEX_ON=auto|true|false] [FOLLOWUP_APPEND_FAILED=true|false] \
#        [STATE_FILE=<state json>] [FIX_ITER=N] [VERIFICATION_GATE=on|...] [MINOR_STOP=true|false] \
#        [DROPPED_REVIEWERS="coderabbit codex"] bash scripts/auto-merge-gate.sh OWNER REPO PR_NUM HEAD_SHA
# The loop's end-of-cycle and end-of-run decisions, as one JSON line on stdout:
#   {"cr_state":"success|pending|none|unknown|failure|error", "blocking_checks":N,
#    "ci_state":"<ci-checks.sh state>", "failing_checks":[names], "base_branch":"...",
#    "protection_http":200|404|0, "eligible":bool, "ineligible_reason":"..."|null,
#    "next_action":"rereview_push|merge_then_main_push", "file_issue":bool,
#    "dropped_reviewers":[names]}
# `dropped_reviewers`: the reviewers the HEAD verdict wait dropped (ADR 0006). The
# caller passes them as off (CR_ON / CODEX_ON), so the HEAD axis judges without
# them; Step 15 asks before any merge they did not see.
# `next_action` (ADR 0006): who reviews the fixes iteration FIX_ITER applied (its
# `apply` records in STATE_FILE's auto_judge_log). One from a Critical/High/Major,
# Security or Codex P0-P1 finding, or reassessed high, goes back to the PR for
# re-review. When all are Minor or lower, the reviewed HEAD merges and the fixes go
# straight to the base, which needs an unprotected base (404: a protected one takes
# no direct push), the build/test gate on and MINOR_STOP not false. Anything
# unreadable re-reviews.
# `file_issue`: a state that files the follow-up issue left something behind
# (DEFERRED_TOTAL, deferred plus unread; unset reads as some). A HEAD without every
# verdict and failing CI alone file none: the final report carries them.
# `eligible` covers two axes. Convergence: `clean`, `minor_floor` and `churn`
# qualify once the follow-up issue exists whenever one is due. HEAD verdicts: every
# reviewer that is on (CR_ON, CODEX_ON, as scripts/head-verdicts.sh reads them) gave
# HEAD_SHA findings or clean; a HEAD with no verdict, or only a rate-limit notice,
# does not qualify (ADR 0002). The caller still enforces cr_state / blocking_checks /
# protection_http before merging (references/run-blocks.md, Step 15).
# This script does NOT call gh pr merge — separation of probe vs action.
set -euo pipefail

OWNER="${1:?}"; REPO="${2:?}"; PR_NUM="${3:?}"; HEAD_SHA="${4:?}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${FINAL_STATE:=unknown}"; : "${FOLLOWUP_ISSUE:=}"
left="${DEFERRED_TOTAL:-unknown}"

file_issue=false
case "$FINAL_STATE" in
  churn|minor_floor|iteration_cap|user_declined|clean|timeout|ci_failing)
    [ "$left" = 0 ] || file_issue=true ;;
esac

# Convergence axis. Findings left behind must be recorded in an issue before the
# merge, so a failed `gh issue create` keeps the PR open by construction.
case "$FINAL_STATE" in
  clean|minor_floor|churn)
    eligible=true; reason=""
    # Only a positive integer counts: a failed create can leave "null", "", or error text behind.
    if [ "$file_issue" = true ]; then
      case "$FOLLOWUP_ISSUE" in
        ""|*[!0-9]*|0*) eligible=false; reason="$FINAL_STATE with $left finding(s) left behind and no valid follow-up issue number" ;;
      esac
    fi ;;
  # Codex reported Failed on HEAD: HEAD has no Codex verdict, and the loop never asks for one.
  codex_failed)       eligible=false; reason="codex_failed: Codex reported Failed on HEAD, so HEAD has no Codex verdict" ;;
  ci_failing)         eligible=false; reason="ci_failing: CI checks failed on HEAD" ;;
  # Everything else, `reviewers_unavailable` included: no reviewer looked, so stopping is not convergence.
  *)                  eligible=false; reason="final_state=$FINAL_STATE is not a merge-eligible convergence" ;;
esac
# A re-run that could not append its new defers to the inherited issue has findings
# recorded nowhere a person will look; that blocks the merge like a failed create.
if [ "${FOLLOWUP_APPEND_FAILED:-false}" = true ]; then eligible=false; reason="follow-up issue append failed"; fi

# HEAD verdict axis: one look (CAP=0), never a wait — the loop already waited.
if [ "$eligible" = true ]; then
  hv=$(OWNER="$OWNER" REPO="$REPO" PR_NUM="$PR_NUM" CUR_SHA="$HEAD_SHA" CAP=0 \
       CR_ON="${CR_ON:-true}" CODEX_ON="${CODEX_ON:-auto}" \
       bash "$SCRIPT_DIR/head-verdicts.sh" 2>/dev/null || true)
  hv_state=$(jq -r '.state // "error"' <<<"$hv" 2>/dev/null || echo error)
  if [ "$hv_state" != ready ]; then
    eligible=false
    reason="HEAD verdict missing on $HEAD_SHA ($(jq -r '"cr=\(.cr // "?"), codex=\(.codex // "?")"' <<<"$hv" 2>/dev/null || echo unreadable))"
  fi
fi

# CR state must come from the SAME dual-surface reader the rest of review-loop uses.
# CodeRabbit reports through EITHER the commit-status API OR a check-run,
# per install. This gate read /statuses only, so on a check-run repo it saw
# no CR row and reported cr_state:"unknown" forever — Step 15 then never merged
# on `--auto-merge` even though CR had completed. cr-commit-state.sh already
# unifies both surfaces (14 fixture cases); delegate to it, don't re-derive.
# (self-found on PR #122 merge verify — the missed sibling of the same
# check-run trap fixed in pre-flight/poll-cr-status/sniff. Rationale:
# docs/adr/0002-review-loop-waits-for-head-verdicts.md.)
cr_state=$(bash "$SCRIPT_DIR/cr-commit-state.sh" "$OWNER" "$REPO" "$HEAD_SHA" 2>/dev/null \
  | jq -r '.state // "unknown"' || echo "unknown")
cr_state="${cr_state:-unknown}"

# Pending checks are not blocking: `gh pr merge --auto` waits for them. Only a check
# that has already failed, errored, or been cancelled blocks the merge. One look
# (CAP=0) through the same summary Step 14 uses, CodeRabbit and Codex left out.
ci=$(CAP=0 bash "$SCRIPT_DIR/ci-checks.sh" "$PR_NUM" 2>/dev/null) || ci=""
ci_state=$(jq -r '.state // "error"' <<<"$ci" 2>/dev/null | tr -d '\r') || ci_state=error
failing=$(jq -c '.failing // []' <<<"$ci" 2>/dev/null) || failing='[]'
[ -n "$failing" ] || failing='[]'
blocking=$(jq 'length' <<<"$failing" | tr -d '\r')
# A lookup we could not make reports 1 so the caller refuses to merge on an
# unverified check state.
case "$ci_state" in error|"") ci_state=error; blocking=1 ;; esac

# A failed lookup still prints the JSON (Step 14 needs file_issue); the empty base
# then reports protection_http 0, which refuses the merge.
base=$(gh pr view "$PR_NUM" --json baseRefName --jq '.baseRefName' 2>/dev/null) || base=""

# An unprotected base returns 404: gh api exits non-zero AND its `-i` status line
# prints `404`. Piping straight into `... || echo 404` under `set -o pipefail`
# then emitted BOTH (`404\n404`), which --argjson rejects as invalid JSON and the
# whole gate died silently. Capture the status line in one step (so pipefail can't
# double it), then parse — a single clean value for both 200 and 404.
http=0
if [ -n "$base" ]; then
  proto_line=$(gh api "repos/$OWNER/$REPO/branches/$base/protection" --silent -i 2>/dev/null | head -1 || true)
  http=$(awk '{print $2}' <<<"$proto_line")
fi
# Only 200 (protected) and 404 (unprotected) are trusted probe outcomes. An
# empty or other status (network, auth, 5xx) must not masquerade as
# "unprotected" — report 0 so Step 15 refuses to merge on an unverified state.
case "$http" in 200|404) : ;; *) http=0 ;; esac

# This cycle's fixes from a severe finding. An unreadable log prints nothing: re-review.
severe=$(jq --argjson it "${FIX_ITER:-0}" '[.auto_judge_log[]?
    | select(.iter == $it and .action == "apply")
    | select(((.category // "") | test("Security"; "i"))
             or ((.badge_or_sev // "") | tostring | test("^P?[01]$|Critical|High|Major"; "i"))
             or (.judgment.severity_reassess? == "high"))] | length' "${STATE_FILE:-/nonexistent}" 2>/dev/null) || severe=""
next_action=rereview_push
if [ "$severe" = 0 ] && [ "$http" = 404 ] && [ "${VERIFICATION_GATE:-}" = on ] && [ "${MINOR_STOP:-true}" != false ]; then
  next_action=merge_then_main_push
fi

jq -nc \
  --arg cr "$cr_state" \
  --argjson bc "$blocking" \
  --arg ci "$ci_state" \
  --argjson failing "$failing" \
  --arg base "$base" \
  --argjson http "$http" \
  --argjson eligible "$eligible" \
  --arg reason "$reason" \
  --arg next "$next_action" \
  --argjson file_issue "$file_issue" \
  --arg dropped "${DROPPED_REVIEWERS:-}" \
  '{cr_state:$cr, blocking_checks:$bc, ci_state:$ci, failing_checks:$failing, base_branch:$base,
    protection_http:$http, eligible:$eligible, ineligible_reason:(if $reason == "" then null else $reason end),
    next_action:$next, file_issue:$file_issue,
    dropped_reviewers:($dropped | split(" ") | map(select(length > 0)))}'
