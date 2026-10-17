#!/usr/bin/env bash
# Usage: bash scripts/words-json.sh "coderabbit codex"
# Prints the shell word list as a JSON array of strings (any whitespace separates,
# empty words dropped): the one reader of the run's dropped_reviewers, used by
# head-verdicts.sh, auto-merge-gate.sh, emit-final-json.sh and run-blocks.md Step 15.
set -u
jq -nc --arg s "${1:-}" '[$s | splits("\\s+") | select(length > 0)]'
