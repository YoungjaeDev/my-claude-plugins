#!/usr/bin/env bash
# Usage: bash scripts/probe-codex-engagement.sh OWNER REPO PR_NUM
# Prints "active" / "inactive" on stdout. Exits 0 always (caller decides).
# On gh api failure: prints "inactive" and warns on stderr (non-sticky — see references/codex-state-machine.md).
set -euo pipefail

OWNER="${1:?owner required}"; REPO="${2:?repo required}"; PR_NUM="${3:?pr required}"

if ! ids=$(gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUM/reviews" \
    --jq '.[] | select(.user.login == "chatgpt-codex-connector[bot]") | .id' 2>/dev/null); then
  echo "warn: Codex engagement probe failed (gh api error); reporting inactive (non-sticky)" >&2
  printf 'inactive\n'
  exit 0
fi

count=$(awk 'NF{c++} END{print c+0}' <<< "$ids")
if [ "$count" -gt 0 ]; then printf 'active\n'; else printf 'inactive\n'; fi
