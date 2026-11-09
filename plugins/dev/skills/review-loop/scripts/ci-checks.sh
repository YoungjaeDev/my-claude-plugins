#!/usr/bin/env bash
# Usage: [CAP=seconds] [INTERVAL=30] [PUSH_TIME=ISO8601] bash scripts/ci-checks.sh PR_NUM
#
# Summarizes the CI check conclusions on the PR's HEAD (issue #317) and prints one
# JSON line:
#   {"state":"pass|fail|not_started|pending|none|error", "failing":[names], "pending":[names],
#    "waited":N, "reason":"no_trigger"|null, "annotation":"<message>"|null}
#
#   fail         at least one check is in gh's `fail` or `cancel` bucket
#   not_started  every failing check is a GitHub Actions job that never started (no
#                step, no runner: run 41364746682, a billing lock). `failing` still
#                names them, so the merge stays blocked as for `fail`; `annotation`
#                quotes the check run's failure annotation, the only place GitHub
#                says why (#393)
#   pending      nothing failed, but a check is in any other bucket when the cap runs out
#   pass         every check is in the `pass` or `skipping` bucket
#   none         the PR reports no checks at all. `reason` is `no_trigger` when no
#                workflow run exists on the PR's head commit: no workflow triggers on
#                this branch and event (PR #387). Null when that could not be read
#   error        the lookup itself failed (network, auth, API): not a failing check
#
# Checks are sorted by gh's normalized `bucket` field (`gh pr checks --help`), not a
# copy of raw states, so a state gh adds later reads as pending, never as a pass.
# CodeRabbit's and Codex's own checks are left out: they are reviewers, read by the
# HEAD verdict path. Names are matched whole (`CodeRabbit` status, `CodeRabbit / Review`
# check run), so a CI job named `coderabbit-lint` still counts. While a check is
# pending and nothing failed, the script polls again after next-check.sh's gap (from
# INTERVAL and the push age in PUSH_TIME, unknown without it), never sleeping past CAP
# (default 0: one look); the caller passes an existing cap (TIMEOUT), never a new one.
# A pending CI job is not "a reviewer at work": a build runs for minutes, so it does
# not get the short in-progress gap. Used by Step 14 and auto-merge-gate.sh.
set -uo pipefail

jq_lf="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../scripts/jq-lf.sh"; if [ -f "$jq_lf" ]; then . "$jq_lf"; fi  # drops CR from Windows jq output; absent in test copies
PR_NUM="${1:?pr required}"
: "${CAP:=0}"; : "${INTERVAL:=30}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
push_epoch=$(jq -n --arg t "${PUSH_TIME:-}" 'try ($t | fromdateiso8601 | floor) catch -1')
errf=$(mktemp); trap 'rm -f "$errf"' EXIT

emit() { jq -nc --arg s "$1" --argjson r "$2" --argjson w "$SECONDS" --arg why "${3:-}" --arg ann "${4:-}" \
  '{state:$s, failing:[$r[] | select(.b == "fail") | .name],
    pending:[$r[] | select(.b == "pending") | .name], waited:$w,
    reason:(if $why == "" then null else $why end), annotation:(if $ann == "" then null else $ann end)}'; }

# Why a PR has no check: no workflow run at all on its head commit means no workflow
# triggers on this branch and event. Prints nothing when that cannot be read.
no_check_reason() {
  local sha runs
  sha=$(gh pr view "$PR_NUM" --json headRefOid --jq '.headRefOid' 2>/dev/null) || return 0
  [ -n "$sha" ] || return 0
  runs=$(gh run list --commit "$sha" --json databaseId 2>/dev/null | jq 'length' 2>/dev/null) || return 0
  [ "$runs" != 0 ] || echo no_trigger
}

# An Actions job that completed with no step and no runner, neither skipped nor
# cancelled, never started: the predicate release's ci-run-check.sh uses. Prints the
# check run's failure annotation (the job id is its check-run id), or "annotation
# unread" when that lookup fails; exits 1 when the job ran or could not be read, so
# an unknown job counts as a real failure.
never_started() {
  local ann
  gh api "repos/{owner}/{repo}/actions/jobs/$1" 2>/dev/null \
    | jq -e '.status == "completed" and (.conclusion | IN("skipped", "cancelled") | not)
             and ((.steps // []) | length) == 0 and ((.runner_id // 0) == 0)' >/dev/null 2>&1 || return 1
  if ann=$(gh api "repos/{owner}/{repo}/check-runs/$1/annotations" 2>/dev/null) \
     && ann=$(jq -r '[.[] | select(.annotation_level == "failure") | .message][0] // ""' <<<"$ann" 2>/dev/null); then
    printf '%s' "$ann"
  else
    printf 'annotation unread'
  fi
  return 0
}

SECONDS=0
while :; do
  # A JSON array on stdout is the answer whatever the exit status says (the status
  # is not a check-state signal to rely on). Without one, a PR with no checks is
  # `none` (gh reports it as an error) and anything else is a failed lookup.
  out=$(gh pr checks "$PR_NUM" --json name,bucket,link 2>"$errf")
  if ! jq -e 'type == "array"' <<<"$out" >/dev/null 2>&1; then
    if grep -q 'no checks reported' "$errf"; then emit none '[]' "$(no_check_reason)"; else emit error '[]'; fi
    exit 0
  fi
  rows=$(jq -c '[.[]
      | select((.name // "") | test("^(coderabbit( / review)?|codex|chatgpt-codex-connector)$"; "i") | not)
      | {name, link: (.link // ""), b: (if (.bucket | IN("pass", "skipping")) then "pass"
                   elif (.bucket | IN("fail", "cancel")) then "fail"
                   else "pending" end)}]' <<<"$out" 2>/dev/null) && [ -n "$rows" ] \
    || { emit error '[]'; exit 0; }
  state=$(jq -r 'if any(.[]; .b == "fail") then "fail" elif any(.[]; .b == "pending") then "pending"
                 elif length == 0 then "none" else "pass" end' <<<"$rows" | tr -d '\r')
  left=$((CAP - SECONDS))
  if [ "$state" = pending ] && [ "$left" -gt 0 ]; then
    if [ "$push_epoch" -ge 0 ]; then age=$(( $(date +%s) - push_epoch )); else age=-1; fi
    sleep "$(bash "$HERE/next-check.sh" "$age" "$left" false "$INTERVAL")"; continue
  fi
  why=""; ann=""
  [ "$state" != none ] || why=$(no_check_reason)
  if [ "$state" = fail ]; then
    state=not_started
    while IFS= read -r link; do
      id=$(sed -n 's#.*/actions/runs/[0-9]*/job/\([0-9][0-9]*\).*#\1#p' <<<"$link")
      if [ -n "$id" ] && msg=$(never_started "$id"); then [ -n "$ann" ] || ann=$msg
      else state=fail; ann=""; break; fi
    done <<<"$(jq -r '.[] | select(.b == "fail") | .link' <<<"$rows")"
  fi
  emit "$state" "$rows" "$why" "$ann"; exit 0
done
