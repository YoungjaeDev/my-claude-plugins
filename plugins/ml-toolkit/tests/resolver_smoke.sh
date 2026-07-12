#!/usr/bin/env bash
# Smoke test — gpu-parallel-pipeline cross-runtime SKILL_DIR resolver (issue #111 + #129 review).
# Covers: Codex plugin-cache + source-tree resolution; aborts loudly when nothing
# resolves (the pre-#111 blind else pointed python at a dead path); and an
# incomplete higher cache version is skipped for a complete lower one (review #2).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
PLUGIN_DIR=$(cd "$HERE/.." && pwd)                 # plugins/ml-toolkit
REPO_ROOT=$(cd "$PLUGIN_DIR/../.." && pwd)
SKILL="$PLUGIN_DIR/skills/gpu-parallel-pipeline/SKILL.md"
fail=0; pass(){ echo "  PASS: $1"; }; die(){ echo "  FAIL: $1"; fail=1; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/foreign" "$TMP/none"

# Extract the ladder into a runnable script that echoes SKILL_DIR.
RUN="$TMP/run.sh"
awk '/# Codex 0.135 does not export/{f=1} f{print} /skill dir not resolved/{if(f)exit}' "$SKILL" > "$RUN"
printf 'printf "%%s" "$SKILL_DIR"\n' >> "$RUN"

mkdir -p "$TMP/cache/mkt/ml-toolkit"; ln -s "$PLUGIN_DIR" "$TMP/cache/mkt/ml-toolkit/1.4.1"

# Codex cache resolution
OUT=$(cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/cache" bash "$RUN")
{ [ -n "$OUT" ] && [ -f "$OUT/scripts/check_gpu_memory.py" ]; } && pass "Codex cache -> $OUT" || die "Codex cache resolution ($OUT)"

# Source tree
OUT=$(cd "$REPO_ROOT" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/none" bash "$RUN")
[ "$OUT" = "plugins/ml-toolkit/skills/gpu-parallel-pipeline" ] && pass "source tree -> $OUT" || die "source tree resolution ($OUT)"

# review #2 — an incomplete higher version (2.9.0, no skill dir) must be skipped
# for the complete lower version (1.4.1).
mkdir -p "$TMP/cache2/mkt/ml-toolkit/2.9.0"; ln -s "$PLUGIN_DIR" "$TMP/cache2/mkt/ml-toolkit/1.4.1"
OUT=$(cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/cache2" bash "$RUN")
[ "$OUT" = "$TMP/cache2/mkt/ml-toolkit/1.4.1/skills/gpu-parallel-pipeline" ] && pass "incomplete 2.9.0 skipped, picked complete 1.4.1" || die "incomplete-version skip ($OUT)"

# Nothing resolves: must abort nonzero (pre-#111 bug proceeded to a dead path)
if (cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/none" bash "$RUN") 2>/dev/null; then die "should abort with no skill dir"; else pass "aborts when unresolved"; fi

[ "$fail" = 0 ] && echo "ml-toolkit resolver smoke: ALL PASS" || { echo "ml-toolkit resolver smoke: FAILURES"; exit 1; }
