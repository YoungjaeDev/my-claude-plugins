#!/usr/bin/env bash
# Usage: bash scripts/probe-cr-cli.sh
# Exits 0 if `coderabbit` CLI present AND authenticated.
# Prints one JSON line summarizing status. The install hint names the vendor page, not
# one installer per OS: the page lists every platform's installer and stays current.
set -euo pipefail

jq_lf="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../scripts/jq-lf.sh"; if [ -f "$jq_lf" ]; then . "$jq_lf"; fi  # drops CR from Windows jq output; absent in test copies
if ! command -v coderabbit >/dev/null 2>&1; then
  jq -cn '{installed:false, authed:false, hint:"Install the CodeRabbit CLI for this platform per https://docs.coderabbit.ai/cli — then: coderabbit auth login"}'
  exit 1
fi

if coderabbit auth status >/dev/null 2>&1; then
  ver=$(coderabbit --version 2>/dev/null | head -n1 || echo unknown)
  # Use jq -n --arg so a version string containing quotes/newlines stays valid JSON.
  jq -cn --arg ver "$ver" '{installed:true, authed:true, version:$ver}'
  exit 0
else
  printf '{"installed":true,"authed":false,"hint":"Run: coderabbit auth login"}\n'
  exit 1
fi
