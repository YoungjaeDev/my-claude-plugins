#!/usr/bin/env bash
# Usage: [CAP=seconds] [INTERVAL=30] [PUSH_TIME=ISO8601] bash scripts/ci-checks.sh PR_NUM
#
# Summarizes the CI check conclusions on the PR's HEAD (issue #317) and prints one
# JSON line:
#   {"state":"pass|fail|pending|none|error", "failing":[names], "pending":[names], "waited":N}
#
#   fail     at least one check is in gh's `fail` or `cancel` bucket
#   pending  nothing failed, but a check is in any other bucket when the cap runs out
#   pass     every check is in the `pass` or `skipping` bucket
#   none     the PR reports no checks at all
#   error    the lookup itself failed (network, auth, API): not a failing check
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

PR_NUM="${1:?pr required}"
: "${CAP:=0}"; : "${INTERVAL:=30}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
push_epoch=$(jq -n --arg t "${PUSH_TIME:-}" 'try ($t | fromdateiso8601 | floor) catch -1')
errf=$(mktemp); trap 'rm -f "$errf"' EXIT

emit() { jq -nc --arg s "$1" --argjson r "$2" --argjson w "$SECONDS" \
  '{state:$s, failing:[$r[] | select(.b == "fail") | .name],
    pending:[$r[] | select(.b == "pending") | .name], waited:$w}'; }

SECONDS=0
while :; do
  # A JSON array on stdout is the answer whatever the exit status says (the status
  # is not a check-state signal to rely on). Without one, a PR with no checks is
  # `none` (gh reports it as an error) and anything else is a failed lookup.
  out=$(gh pr checks "$PR_NUM" --json name,bucket 2>"$errf")
  if ! jq -e 'type == "array"' <<<"$out" >/dev/null 2>&1; then
    if grep -q 'no checks reported' "$errf"; then emit none '[]'; else emit error '[]'; fi
    exit 0
  fi
  rows=$(jq -c '[.[]
      | select((.name // "") | test("^(coderabbit( / review)?|codex|chatgpt-codex-connector)$"; "i") | not)
      | {name, b: (if (.bucket | IN("pass", "skipping")) then "pass"
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
  emit "$state" "$rows"; exit 0
done
