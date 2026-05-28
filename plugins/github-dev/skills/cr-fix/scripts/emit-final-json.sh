#!/usr/bin/env bash
# Usage: ITER=N APPLIED_TOTAL=N DEFERRED_TOTAL=N SKIPPED_TOTAL=N CODEX_STATE=... \
#        FINAL_STATE=... MERGED=true|false PR_NUM=N LAST_SHA=... \
#        CR_SOURCE=auto|pr-bot|cli|codex-only CLI_INVOCATIONS=N RATE_LIMIT_HITS=N \
#        TRACK_FILE=/tmp/... STATE_FILE=.claude/state/... \
#        bash scripts/emit-final-json.sh
#
# Idempotent: archives STATE_FILE if present, removes TRACK_FILE, prints one JSON line.
# Designed to be hooked into bash `trap ... EXIT` so the JSON always emits even on early exit.
set -euo pipefail

: "${ITER:=0}"; : "${APPLIED_TOTAL:=0}"; : "${DEFERRED_TOTAL:=0}"; : "${SKIPPED_TOTAL:=0}"
: "${CODEX_STATE:=unknown}"; : "${FINAL_STATE:=unknown}"; : "${MERGED:=false}"
: "${PR_NUM:=0}"; : "${LAST_SHA:=}"
: "${CR_SOURCE:=auto}"; : "${CLI_INVOCATIONS:=0}"; : "${RATE_LIMIT_HITS:=0}"
: "${TRACK_FILE:=}"; : "${STATE_FILE:=}"

if [ -n "$STATE_FILE" ] && [ -f "$STATE_FILE" ]; then
  mkdir -p "$(dirname "$STATE_FILE")/archive"
  mv "$STATE_FILE" "$(dirname "$STATE_FILE")/archive/$(basename "$STATE_FILE" .json)-$(date +%Y%m%d-%H%M%S).json"
fi

[ -n "$TRACK_FILE" ] && rm -f "$TRACK_FILE"

if [ -z "$LAST_SHA" ]; then
  LAST_SHA=$(git rev-parse HEAD 2>/dev/null || echo "")
fi

jq -nc \
  --argjson iters     "$ITER" \
  --argjson applied   "$APPLIED_TOTAL" \
  --argjson deferred  "$DEFERRED_TOTAL" \
  --argjson skipped   "$SKIPPED_TOTAL" \
  --arg     codex     "$CODEX_STATE" \
  --arg     final     "$FINAL_STATE" \
  --argjson merged    "$( [ "$MERGED" = "true" ] && echo true || echo false )" \
  --argjson pr        "$PR_NUM" \
  --arg     sha       "$LAST_SHA" \
  --arg     src       "$CR_SOURCE" \
  --argjson cli_inv   "$CLI_INVOCATIONS" \
  --argjson rl_hits   "$RATE_LIMIT_HITS" \
  '{
    iterations: $iters,
    applied_total: $applied,
    deferred_total: $deferred,
    skipped_total: $skipped,
    codex_state: $codex,
    final_state: $final,
    merged: $merged,
    pr: $pr,
    last_sha: $sha,
    cr_source: $src,
    cli_invocations: $cli_inv,
    rate_limit_hits: $rl_hits
  }'
