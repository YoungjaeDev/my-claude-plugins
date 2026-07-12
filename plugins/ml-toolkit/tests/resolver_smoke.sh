#!/usr/bin/env bash
# Smoke test — gpu-parallel-pipeline cross-runtime SKILL_DIR resolver (issue #111).
# The pre-fix ladder had no Codex plugin-cache branch and a blind final else, so
# from a foreign cwd it pointed SKILL_DIR at a nonexistent ~/.hermes path and
# python failed (exit 2). Extract the ladder from SKILL.md and assert it resolves
# the Codex cache + source tree, and aborts loudly when nothing resolves.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
PLUGIN_DIR=$(cd "$HERE/.." && pwd)                 # plugins/ml-toolkit
REPO_ROOT=$(cd "$PLUGIN_DIR/../.." && pwd)
SKILL="$PLUGIN_DIR/skills/gpu-parallel-pipeline/SKILL.md"
fail=0; pass(){ echo "  PASS: $1"; }; die(){ echo "  FAIL: $1"; fail=1; }

RES=$(awk '/# Codex 0.135 does not export/{f=1} f{print} /skill dir not resolved/{if(f)exit}' "$SKILL")
[ -n "$RES" ] || { echo "  FAIL: could not extract ladder from $SKILL"; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/cache/mkt/ml-toolkit" "$TMP/foreign"
ln -s "$PLUGIN_DIR" "$TMP/cache/mkt/ml-toolkit/1.4.0"

# Codex: no CLAUDE_PLUGIN_ROOT, foreign cwd, fake plugin cache
OUT=$(cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/cache" bash -c "$RES"$'\n''echo "$SKILL_DIR"')
{ [ -n "$OUT" ] && [ -f "$OUT/scripts/check_gpu_memory.py" ]; } && pass "Codex cache -> $OUT" || die "Codex cache resolution ($OUT)"

# Source tree
OUT=$(cd "$REPO_ROOT" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/none" bash -c "$RES"$'\n''echo "$SKILL_DIR"')
[ "$OUT" = "plugins/ml-toolkit/skills/gpu-parallel-pipeline" ] && pass "source tree -> $OUT" || die "source tree resolution ($OUT)"

# Nothing resolves: must abort nonzero (the pre-fix bug proceeded to a dead path)
if (cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/none" bash -c "$RES") 2>/dev/null; then die "should have aborted with no skill dir"; else pass "aborts when unresolved"; fi

[ "$fail" = 0 ] && echo "ml-toolkit resolver smoke: ALL PASS" || { echo "ml-toolkit resolver smoke: FAILURES"; exit 1; }
