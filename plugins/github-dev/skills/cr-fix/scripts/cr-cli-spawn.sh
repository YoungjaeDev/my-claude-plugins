#!/usr/bin/env bash
# Usage: BASE=<base-branch> PR_NUM=N ITER=N CONFIG_FILES="CLAUDE.md AGENTS.md" bash scripts/cr-cli-spawn.sh
# Spawns `coderabbit review --agent --type committed --base $BASE` in foreground,
# writing JSONL to /tmp/cr-cli-review-${PR_NUM}-iter${ITER}.jsonl.
# Caller wraps this script with Bash(run_in_background=true, timeout=TIMEOUT*1000).
# Prints terminal JSON marker on stdout: {"jsonl":"<path>","exit":N,"emitted_complete":bool}
set -euo pipefail

: "${BASE:?BASE base-branch required}"; : "${PR_NUM:?}"; : "${ITER:?}"
: "${CONFIG_FILES:=CLAUDE.md AGENTS.md}"

OUT="/tmp/cr-cli-review-${PR_NUM}-iter${ITER}.jsonl"
: > "$OUT"

# shellcheck disable=SC2086  # CONFIG_FILES is intentionally word-split
set +e
coderabbit review --agent --type committed --base "$BASE" --config $CONFIG_FILES > "$OUT" 2>&1
rc=$?
set -e

emitted_complete=$(grep -c '"type":"complete"' "$OUT" 2>/dev/null || echo 0)
[ "$emitted_complete" -gt 0 ] && ec=true || ec=false

printf '{"jsonl":"%s","exit":%d,"emitted_complete":%s}\n' "$OUT" "$rc" "$ec"
