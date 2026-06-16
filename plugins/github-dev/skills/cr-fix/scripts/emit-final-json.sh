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
: "${AUTO_JUDGE_APPLY:=0}"; : "${AUTO_JUDGE_DEFER:=0}"; : "${AUTO_JUDGE_SKIP:=0}"
: "${TRACK_FILE:=}"; : "${STATE_FILE:=}"

# Capture the LAST pre-flight decision before STATE_FILE is archived; the full
# history remains in the archive copy for audit.
PRE_FLIGHT_LAST='null'
if [ -n "$STATE_FILE" ] && [ -f "$STATE_FILE" ]; then
  PRE_FLIGHT_LAST=$(jq -c '.pre_flight_decisions // [] | .[-1] // null' "$STATE_FILE" 2>/dev/null || echo 'null')
fi

if [ -n "$STATE_FILE" ] && [ -f "$STATE_FILE" ]; then
  # Persist the final summary fields into the state file BEFORE archiving so the
  # archived copy is self-describing — post-merge Step 1.5 reads final_state +
  # auto_judge_stats from it (otherwise they are only assembled into stdout below,
  # never written back, and the archived file would surface "0 deferred / unknown").
  tmp=$(mktemp)
  if jq --arg final "$FINAL_STATE" \
        --argjson apply "$AUTO_JUDGE_APPLY" --argjson defer "$AUTO_JUDGE_DEFER" --argjson skip "$AUTO_JUDGE_SKIP" \
        --argjson applied "$APPLIED_TOTAL" --argjson deferred "$DEFERRED_TOTAL" \
        '.final_state=$final | .auto_judge_stats={apply:$apply,defer:$defer,skip:$skip} | .applied_total=$applied | .deferred_total=$deferred' \
        "$STATE_FILE" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$STATE_FILE"
  else
    rm -f "$tmp"  # keep the un-enriched state file rather than lose it (trap context)
  fi
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
  --argjson aj_apply  "$AUTO_JUDGE_APPLY" \
  --argjson aj_defer  "$AUTO_JUDGE_DEFER" \
  --argjson aj_skip   "$AUTO_JUDGE_SKIP" \
  --argjson pf_last   "$PRE_FLIGHT_LAST" \
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
    rate_limit_hits: $rl_hits,
    auto_judge_stats: { apply: $aj_apply, defer: $aj_defer, skip: $aj_skip },
    pre_flight_last: $pf_last
  }'
