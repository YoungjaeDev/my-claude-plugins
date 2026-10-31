#!/usr/bin/env bash
# Usage: bash scripts/words-json.sh "coderabbit codex"
# Prints the shell word list as a JSON array of strings (any whitespace separates,
# empty words dropped): the one reader of the run's dropped_reviewers, used by
# head-verdicts.sh, auto-merge-gate.sh, emit-final-json.sh and run-blocks.md Step 15.
set -u
jq_lf="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../scripts/jq-lf.sh"; if [ -f "$jq_lf" ]; then . "$jq_lf"; fi  # drops CR from Windows jq output; absent in test copies
jq -nc --arg s "${1:-}" '[$s | splits("\\s+") | select(length > 0)]'
