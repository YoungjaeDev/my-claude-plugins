#!/usr/bin/env bash
# Usage: ci-run-check.sh <tag>
#
# Reports, once and without waiting, the GitHub Actions runs a tag push created:
# each run's status, and every job that completed without ever starting (0 steps,
# no runner), quoting its failure annotation. A billing-locked account produces
# exactly that and nothing else surfaces it (v2.78.0, issue #394).
#
# Exit: 0 report printed (warnings included), 1 gh or jq failed (CI state unknown), 2 usage.
set -uo pipefail
jq_lf="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../scripts/jq-lf.sh"; if [ -f "$jq_lf" ]; then . "$jq_lf"; fi

TAG=${1:-}
[ -n "$TAG" ] || { echo "usage: ci-run-check.sh <tag>" >&2; exit 2; }

unknown() { echo "ci-run-check: $1; CI state for $TAG unknown" >&2; exit 1; }
# Slurped pages as one JSON value; stdout and rc are taken apart so an API error never reads as "no runs".
api() { local out; if ! out=$(gh api --paginate --slurp "$1"); then unknown "gh api $1 failed"; fi; printf '%s' "$out"; }

runs=$(api "repos/{owner}/{repo}/actions/runs?branch=$TAG&event=push&per_page=100") || exit 1
lines=$(jq -r '[.[].workflow_runs[]] | .[] | [.id, .name, .status, (.conclusion // ""), .html_url] | map(tostring) | join("\u001f")' <<<"$runs") \
  || unknown "unreadable runs response"
if [ -z "$lines" ]; then
  echo "ci: $TAG: no workflow run found (not created yet, or no workflow triggers on this tag)"
  exit 0
fi

billing=0
# \x1f, not a tab: tab is IFS whitespace, so an empty conclusion would collapse and shift the url.
while IFS=$'\x1f' read -r id name status conclusion url; do
  echo "ci: $TAG: $name run $id $status${conclusion:+/$conclusion} $url"
  jobs=$(api "repos/{owner}/{repo}/actions/runs/$id/jobs?filter=latest&per_page=100") || exit 1
  # Never started: completed with no step and no runner. Queued jobs are not there yet; skipped ones were meant not to run.
  dead=$(jq -r '[.[].jobs[]] | .[]
      | select(.status == "completed" and .conclusion != "skipped"
               and ((.steps // []) | length) == 0 and ((.runner_id // 0) == 0))
      | [.name, (.check_run_url // "" | sub("^.*/check-runs/"; ""))] | @tsv' <<<"$jobs") \
    || unknown "unreadable jobs response for run $id"
  [ -n "$dead" ] || continue
  while IFS=$'\t' read -r job check; do
    msg=""
    if [ -n "$check" ] && ann=$(gh api --paginate --slurp "repos/{owner}/{repo}/check-runs/$check/annotations" 2>/dev/null); then
      msg=$(jq -r '[.[][] | select(.annotation_level == "failure") | .message] | join(" ")' <<<"$ann" 2>/dev/null) || msg=""
    fi
    echo "ci: WARNING $TAG: job $job never started (0 steps, no runner): ${msg:-annotation unread, see $url}"
    case "$msg" in *[Bb]illing*) billing=1 ;; esac
  done <<<"$dead"
done <<<"$lines"

if [ "$billing" = 1 ]; then
  echo "ci: the account is billing-locked: unlock it in GitHub Settings -> Billing and plans (https://github.com/settings/billing), then re-run the failed jobs"
fi
exit 0
