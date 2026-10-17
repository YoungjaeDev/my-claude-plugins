#!/usr/bin/env bash
# Usage: bash scripts/next-check.sh AGE LEFT IN_PROGRESS [INTERVAL=30]
# Prints the seconds until a review wait's next look, chosen from what it observed:
#   AGE          seconds since the push (or review request) the wait counts from
#   LEFT         seconds left in the nearest budget still running
#   IN_PROGRESS  true when a reviewer shows it is working on HEAD
#                (Codex summary Running, CodeRabbit status pending)
# Rules, from the Codex turnaround ADR 0002 measured (codex-turnaround.sh):
#   in progress            INTERVAL/3: the verdict is close, and a full gap after it
#                          lands reads as a hang (PR #308)
#   AGE < CODEX_FASTEST    the rest of that time: no verdict came sooner
#   AGE > CODEX_SLOWEST    2 x INTERVAL: past every observed turnaround a stuck
#                          reviewer is likelier, so spare the API quota the other
#                          sessions share
#   otherwise              INTERVAL
# Never more than LEFT, never less than 1. A non-numeric AGE or LEFT reads as unknown.
# Every poller sleeps by it: head-verdicts.sh, poll-cr-status.sh, poll-codex-grace.sh, ci-checks.sh.
# shortcut: thresholds are the Codex numbers, CodeRabbit has no measured turnaround; replace them when it does.
set -u
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/codex-turnaround.sh"

num() { case "$1" in ''|*[!0-9]*) echo "$2" ;; *) echo "$1" ;; esac; }
age=$(num "${1:-}" -1); left=$(num "${2:-}" 0); busy="${3:-false}"; interval=$(num "${4:-30}" 30)

if [ "$busy" = true ]; then n=$(( (interval + 2) / 3 ))
elif [ "$age" -ge 0 ] && [ "$age" -lt "$CODEX_FASTEST" ]; then n=$(( CODEX_FASTEST - age ))
elif [ "$age" -gt "$CODEX_SLOWEST" ]; then n=$(( interval * 2 ))
else n=$interval; fi

[ "$n" -le "$left" ] || n=$left
[ "$n" -ge 1 ] || n=1
echo "$n"
