#!/usr/bin/env bash
# Usage: bash scripts/push-time.sh OWNER REPO SHA
# Prints ISO-8601 timestamp of earliest status on SHA (best proxy for push time).
# Falls back to commit committer.date if no statuses yet.
# See plugins/github-dev/AGENTS.md "gh / jq Invariants" for why /statuses (plural) + --paginate.
set -euo pipefail

OWNER="${1:?owner required}"; REPO="${2:?repo required}"; SHA="${3:?sha required}"

t=$(gh api --paginate "repos/$OWNER/$REPO/commits/$SHA/statuses" 2>/dev/null \
  | jq -sr 'add // [] | [.[].created_at] | sort | .[0] // empty')

if [ -z "$t" ]; then
  # Pipe form per plugins/github-dev/AGENTS.md gh / jq invariants; keeps the codebase
  # uniform with sibling scripts (auto-merge-gate, poll-cr-status, probe-codex-engagement).
  t=$(gh api "repos/$OWNER/$REPO/commits/$SHA" 2>/dev/null \
    | jq -r '.commit.committer.date // empty')
fi

printf '%s\n' "$t"
