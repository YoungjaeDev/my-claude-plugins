#!/usr/bin/env bash
# Usage: bash scripts/next-check.sh AGE LEFT IN_PROGRESS [INTERVAL=30]
# Prints the seconds until a review wait's next look, chosen from what it observed:
#   AGE          seconds since the push (or review request) the wait counts from
#   LEFT         seconds left in the nearest budget still running
#   IN_PROGRESS  true when a reviewer shows it is working on HEAD
#                (Codex summary Running, CodeRabbit status pending)
# Rules, from the turnaround ADR 0002 measured (Codex 68-726 s, median 224 s):
#   in progress  INTERVAL/3: the verdict is close, and a full gap after it lands
#                reads as a hang (PR #308)
#   AGE < 68     the rest of the first 68 s: no verdict came sooner
#   AGE > 726    2 x INTERVAL: past every observed turnaround a stuck reviewer is
#                likelier, so spare the API quota the other sessions share
#   otherwise    INTERVAL
# Never more than LEFT, never less than 1. A non-numeric AGE or LEFT reads as unknown.
# shortcut: thresholds are the Codex numbers, CodeRabbit has no measured turnaround; replace them when it does.
set -u

num() { case "$1" in ''|*[!0-9]*) echo "$2" ;; *) echo "$1" ;; esac; }
age=$(num "${1:-}" -1); left=$(num "${2:-}" 0); busy="${3:-false}"; interval=$(num "${4:-30}" 30)

if [ "$busy" = true ]; then n=$(( (interval + 2) / 3 ))
elif [ "$age" -ge 0 ] && [ "$age" -lt 68 ]; then n=$(( 68 - age ))
elif [ "$age" -gt 726 ]; then n=$(( interval * 2 ))
else n=$interval; fi

[ "$n" -le "$left" ] || n=$left
[ "$n" -ge 1 ] || n=1
echo "$n"
