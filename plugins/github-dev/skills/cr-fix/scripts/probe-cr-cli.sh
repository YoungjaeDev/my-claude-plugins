#!/usr/bin/env bash
# Usage: bash scripts/probe-cr-cli.sh
# Exits 0 if `coderabbit` CLI present AND authenticated.
# Prints one JSON line summarizing status. The install hint is platform-aware:
# Windows has a native PowerShell installer (no WSL, no admin — docs.coderabbit.ai/cli/windows),
# so pointing a Windows user at install.sh sends them down the wrong path.
set -euo pipefail

install_hint() {
  case "$(uname -s 2>/dev/null || echo unknown)" in
    MINGW*|MSYS*|CYGWIN*)
      echo 'Install (PowerShell, no admin): irm https://cli.coderabbit.ai/install.ps1 | iex — then: coderabbit auth login' ;;
    Darwin)
      echo 'Install: brew install coderabbit (or curl -fsSL https://cli.coderabbit.ai/install.sh | sh) — then: coderabbit auth login' ;;
    *)
      echo 'Install: curl -fsSL https://cli.coderabbit.ai/install.sh | sh — then: coderabbit auth login' ;;
  esac
}

if ! command -v coderabbit >/dev/null 2>&1; then
  jq -cn --arg hint "$(install_hint)" '{installed:false, authed:false, hint:$hint}'
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
