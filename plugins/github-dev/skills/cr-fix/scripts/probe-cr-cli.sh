#!/usr/bin/env bash
# Usage: bash scripts/probe-cr-cli.sh
# Exits 0 if `coderabbit` CLI present AND authenticated.
# Prints one JSON line summarizing status.
set -euo pipefail

if ! command -v coderabbit >/dev/null 2>&1; then
  printf '{"installed":false,"authed":false,"hint":"Install: curl -fsSL https://cli.coderabbit.ai/install.sh | sh (or brew install coderabbit)"}\n'
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
