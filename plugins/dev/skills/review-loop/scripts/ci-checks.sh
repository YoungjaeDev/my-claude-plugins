#!/usr/bin/env bash
# Usage: [CAP=seconds] [INTERVAL=30] bash scripts/ci-checks.sh PR_NUM
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
# pending and nothing failed, the script polls every INTERVAL seconds, never sleeping
# past CAP (default 0: one look); the caller passes an existing cap (TIMEOUT), never a
# new one. Used by Step 14 and auto-merge-gate.sh.
set -uo pipefail

PR_NUM="${1:?pr required}"
: "${CAP:=0}"; : "${INTERVAL:=30}"
errf=$(mktemp); trap 'rm -f "$errf"' EXIT

emit() { jq -nc --arg s "$1" --argjson r "$2" --argjson w "$SECONDS" \
  '{state:$s, failing:[$r[] | select(.b == "fail") | .name],
    pending:[$r[] | select(.b == "pending") | .name], waited:$w}'; }

SECONDS=0
while :; do
  # `--json` exits 0 whatever the checks say; 1 means the lookup failed, or the PR
  # has no checks at all, which gh reports as an error too.
  if out=$(gh pr checks "$PR_NUM" --json name,bucket 2>"$errf"); then :
  elif grep -q 'no checks reported' "$errf"; then emit none '[]'; exit 0
  else emit error '[]'; exit 0
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
    sleep "$(( INTERVAL < left ? INTERVAL : left ))"; continue
  fi
  emit "$state" "$rows"; exit 0
done
