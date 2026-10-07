#!/usr/bin/env bash
# Usage: BASE=<base-branch> PR_NUM=N ITER=N CONFIG_FILES="CLAUDE.md AGENTS.md" bash scripts/cr-cli-spawn.sh
# Spawns `coderabbit review --agent --committed --base $BASE` in foreground,
# writing JSONL to a mktemp-created /tmp/cr-cli-review-${PR_NUM}-iter${ITER}-XXXXXX file.
# Caller wraps this script with Bash(run_in_background=true, timeout=TIMEOUT*1000).
# Prints terminal JSON marker on stdout: {"jsonl":"<path>","exit":N,"emitted_complete":bool}
set -euo pipefail

: "${BASE:?BASE base-branch required}"; : "${PR_NUM:?}"; : "${ITER:?}"
: "${CONFIG_FILES:=CLAUDE.md AGENTS.md}"

# A predictable fixed /tmp name is symlink/TOCTOU bait — create atomically.
OUT=$(mktemp "/tmp/cr-cli-review-${PR_NUM}-iter${ITER}-XXXXXX")

# Split CONFIG_FILES on whitespace into a safe array so individual filenames
# cannot inject extra coderabbit flags via interpolation.
read -r -a CONFIG_FILES_ARR <<< "$CONFIG_FILES"

set +e
coderabbit review --agent --committed --base "$BASE" --config "${CONFIG_FILES_ARR[@]}" > "$OUT" 2>&1
rc=$?
set -e

# grep -c prints its count (0 on no match) AND exits 1 when the count is 0. The
# old `... || echo 0` then appended a second 0, yielding `0\n0` — a multi-line
# value that made `[ -gt ]` below error out. Rely on grep's own printed count and
# normalize any non-zero exit (no match, or missing file) to a clean single 0.
emitted_complete=$(grep -c '"type":"complete"' "$OUT" 2>/dev/null) || emitted_complete=0
[ "$emitted_complete" -gt 0 ] && ec=true || ec=false

# A `complete` event is not a finished review: `outcome: "failed"` or a positive
# `unreviewedFileCount` marks a partial run even when findings were emitted, and
# CLIs before 0.7.7 still exit 0 on it (docs.coderabbit.ai cli/agent-mode).
# `outcome: "completed_with_warnings"` with nothing unreviewed is complete. No
# `complete` event at all is incomplete. OUT mixes stderr in, so non-JSON lines
# are skipped; a jq failure leaves the default `true` — unknown is not complete.
incomplete=$(jq -R -n '[ inputs | fromjson? | select(type == "object" and .type == "complete") ] | last
  | if . == null then true
    else (.outcome == "failed") or (((.unreviewedFileCount // 0) | tonumber? // 1) > 0) end' "$OUT" 2>/dev/null) \
  || incomplete=true
case "$incomplete" in true|false) : ;; *) incomplete=true ;; esac

printf '{"jsonl":"%s","exit":%d,"emitted_complete":%s,"incomplete":%s}\n' "$OUT" "$rc" "$ec" "$incomplete"
