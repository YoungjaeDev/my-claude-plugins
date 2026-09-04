#!/usr/bin/env bash
# Usage: bash scripts/cr-commit-state.sh OWNER REPO SHA
#
# Emits exactly one JSON line describing CodeRabbit's reported state for SHA:
#   {"state":"success|failure|pending|none","description":"...","target_url":"...",
#    "created_at":"...","channel":"status|check_run|none"}
#
# WHY THIS EXISTS
# CodeRabbit reports through ONE of two GitHub surfaces, depending on how the app
# is installed on the repository: the legacy commit-status API, or a check-run.
# `pre-flight.sh`, `poll-cr-status.sh` and `sniff-cr-rate-limit.sh` each read only
# `/statuses`. On a check-run repo that endpoint returns an empty array forever, so
# pre-flight routes to `cr_state: none` -> `gate: cr_wait` and the poller spins to
# its 1800s timeout while the review has, in fact, completed and posted inline
# comments. The symptom reads as "CodeRabbit never answered", not "we asked the
# wrong endpoint". Measured on PR #107 (issue #105).
#
# Statuses are read first because their `description` field carries the rate-limit
# text the sniffer needs; check-runs are the fallback.
#
# TEST SEAM: set CR_STATE_STATUSES_FILE / CR_STATE_CHECKRUNS_FILE to fixture paths
# to replace the two `gh api` calls. Used by tests/run-tests.sh so the state
# mapping is verifiable without network or a live PR. The literal value __FAIL__
# simulates a fetch failure (auth/network/rate-limit).
set -euo pipefail

OWNER="${1:?owner required}"; REPO="${2:?repo required}"; SHA="${3:?sha required}"

error_state() { printf '{"state":"error","description":"%s","target_url":"","created_at":"","channel":"%s"}\n' "$1" "$2"; }

# --paginate emits one JSON document per page; `jq -s` slurps them into an array
# before flattening (plugins/dev/CLAUDE.md gh/jq invariants).
#
# A gh non-zero exit (or the __FAIL__ sentinel) is a fetch failure, NOT "no CR
# row": the old `|| echo '[]'` masked auth/network/rate-limit as an empty result
# that mapped to state:"none", indistinguishable from a repo where CodeRabbit
# simply hasn't reported. Propagate the failure so the caller can route it to a
# real error channel. See .llmwiki detector-cannot-look-vs-nothing-wrong.
fetch_statuses() {
  if [ "${CR_STATE_STATUSES_FILE:-}" = "__FAIL__" ]; then return 1; fi
  if [ -n "${CR_STATE_STATUSES_FILE:-}" ]; then cat "$CR_STATE_STATUSES_FILE"; return 0; fi
  gh api --paginate "repos/$OWNER/$REPO/commits/$SHA/statuses" 2>/dev/null
}
fetch_checkruns() {
  if [ "${CR_STATE_CHECKRUNS_FILE:-}" = "__FAIL__" ]; then return 1; fi
  if [ -n "${CR_STATE_CHECKRUNS_FILE:-}" ]; then cat "$CR_STATE_CHECKRUNS_FILE"; return 0; fi
  gh api --paginate "repos/$OWNER/$REPO/commits/$SHA/check-runs" 2>/dev/null
}

# ── Channel 1: commit-status (preferred — carries `description`) ─────────────
if ! statuses_raw=$(fetch_statuses); then error_state "fetch failed: commit statuses" "status"; exit 0; fi
status_row=$(jq -s 'add // []
  | [ .[] | select(.context // "" | test("CodeRabbit"; "i")) ]
  | sort_by(.created_at) | reverse | .[0] // {}' <<<"$statuses_raw" 2>/dev/null || echo '{}')

if [ "$(jq -r 'has("state")' <<<"$status_row" 2>/dev/null || echo false)" = "true" ]; then
  jq -c '{
    state: (.state // "none"),
    description: (.description // ""),
    target_url: (.target_url // ""),
    created_at: (.created_at // ""),
    channel: "status"
  }' <<<"$status_row"
  exit 0
fi

# ── Channel 2: check-run ─────────────────────────────────────────────────────
# `status` is the lifecycle (queued|in_progress|completed); `conclusion` is the
# outcome and is null until completed. Map both onto the commit-status vocabulary
# the callers already branch on, so nothing downstream has to learn a second one.
#
#   completed + success                                        -> success
#   completed + neutral | skipped                              -> success (CR ran, nothing to say)
#   completed + failure | timed_out | cancelled | action_required | stale
#                                                              -> failure
#   queued | in_progress                                       -> pending
# A queued run has started_at null; it is the NEWEST run, so null must sort
# last (highest), or an older completed run wins and reports success while a
# re-review is queued.
if ! checkruns_raw=$(fetch_checkruns); then error_state "fetch failed: check runs" "check_run"; exit 0; fi
check_row=$(jq -s '[ .[] | (.check_runs // []) ] | add // []
  | [ .[] | select(.name // "" | test("CodeRabbit"; "i")) ]
  | sort_by(.started_at // "9999-12-31T23:59:59Z") | reverse | .[0] // {}' <<<"$checkruns_raw" 2>/dev/null || echo '{}')

if [ "$(jq -r 'has("status")' <<<"$check_row" 2>/dev/null || echo false)" = "true" ]; then
  jq -c '
    (.status // "") as $st
    | (.conclusion // "") as $cc
    | {
        state: (
          if $st != "completed" then "pending"
          elif $cc == "success" or $cc == "neutral" or $cc == "skipped" then "success"
          elif $cc == "" then "pending"
          else "failure"
          end
        ),
        description: (.output.title // ""),
        target_url: (.details_url // ""),
        # A completed run reports when it FINISHED via completed_at; started_at is
        # older, so CR_SKIP_GRACE (which ages this timestamp) misfired when the run
        # had long since finished. Fall back to started_at for queued/in-progress.
        created_at: (.completed_at // .started_at // ""),
        channel: "check_run"
      }' <<<"$check_row"
  exit 0
fi

printf '{"state":"none","description":"","target_url":"","created_at":"","channel":"none"}\n'
