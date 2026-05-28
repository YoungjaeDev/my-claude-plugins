#!/usr/bin/env bash
# Usage: eval "$(bash scripts/parse-args.sh "$@")"
# Emits KEY=VAL export lines for caller to eval.
# Validates --cr-source and threshold values.
set -euo pipefail

MAX_ITER=5; TIMEOUT=1800; INTERVAL=60; AUTO_MERGE=false; PASTE=""; NO_BUILD=false
CODEX_GRACE=30; NO_CODEX=false; SKIP_MINOR=false
CR_SOURCE=auto; SMALL_DIFF_LOC=200; SMALL_DIFF_FILES=5

while [ $# -gt 0 ]; do
  case "$1" in
    --max-iterations) MAX_ITER="$2"; shift 2;;
    --timeout) TIMEOUT="$2"; shift 2;;
    --interval) INTERVAL="$2"; shift 2;;
    --auto-merge) AUTO_MERGE=true; shift;;
    --paste) PASTE="$2"; shift 2;;
    --no-build-check) NO_BUILD=true; shift;;
    --codex-grace) CODEX_GRACE="$2"; shift 2;;
    --no-codex) NO_CODEX=true; shift;;
    --skip-minor) SKIP_MINOR=true; shift;;
    --cr-source) CR_SOURCE="$2"; shift 2;;
    --small-diff-threshold-loc) SMALL_DIFF_LOC="$2"; shift 2;;
    --small-diff-threshold-files) SMALL_DIFF_FILES="$2"; shift 2;;
    *) echo "warn: ignoring unknown arg $1" >&2; shift;;
  esac
done

case "$CR_SOURCE" in
  auto|pr-bot|cli|codex-only) ;;
  *) echo "error: --cr-source must be one of auto|pr-bot|cli|codex-only (got '$CR_SOURCE')" >&2; exit 2;;
esac

for v in MAX_ITER TIMEOUT INTERVAL CODEX_GRACE SMALL_DIFF_LOC SMALL_DIFF_FILES; do
  if ! [[ "${!v}" =~ ^[0-9]+$ ]]; then
    echo "error: $v must be a non-negative integer (got '${!v}')" >&2; exit 2
  fi
done

for v in MAX_ITER TIMEOUT INTERVAL AUTO_MERGE PASTE NO_BUILD CODEX_GRACE NO_CODEX SKIP_MINOR CR_SOURCE SMALL_DIFF_LOC SMALL_DIFF_FILES; do
  printf '%s=%q\n' "$v" "${!v}"
done
