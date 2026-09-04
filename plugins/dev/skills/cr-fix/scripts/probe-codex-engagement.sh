#!/usr/bin/env bash
# Usage: bash scripts/probe-codex-engagement.sh OWNER REPO PR_NUM
# Prints "active" / "inactive" on stdout. Exits 0 always (caller decides).
# On gh api failure: prints "inactive" and warns on stderr (non-sticky — see references/codex-state-machine.md).
set -euo pipefail

OWNER="${1:?owner required}"; REPO="${2:?repo required}"; PR_NUM="${3:?pr required}"

if ! pages=$(gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUM/reviews" 2>/dev/null); then
  echo "warn: Codex engagement probe failed (gh api error); reporting inactive (non-sticky)" >&2
  printf 'inactive\n'
  exit 0
fi

# Pipe form per plugins/dev/CLAUDE.md gh / jq invariants; jq -s slurps the
# multi-document --paginate stream into a single array before counting Codex authors.
count=$(jq -s 'add // []
               | map(select(.user.login == "chatgpt-codex-connector[bot]"))
               | length' <<< "$pages")
if [ "${count:-0}" -gt 0 ]; then printf 'active\n'; else printf 'inactive\n'; fi
