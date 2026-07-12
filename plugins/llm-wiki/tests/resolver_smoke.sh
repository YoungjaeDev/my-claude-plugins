#!/usr/bin/env bash
# Smoke test — bootstrap-wiki cross-runtime PLUGIN_ROOT resolver (issue #111).
# Extracts the resolver block from SKILL.md (so doc drift breaks the test) and
# asserts it resolves under the Codex plugin-cache layout (no CLAUDE_PLUGIN_ROOT,
# foreign cwd) and the source tree, and aborts loudly when nothing resolves.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
PLUGIN_DIR=$(cd "$HERE/.." && pwd)                 # plugins/llm-wiki
REPO_ROOT=$(cd "$PLUGIN_DIR/../.." && pwd)
SKILL="$PLUGIN_DIR/skills/bootstrap-wiki/SKILL.md"
CHK="skills/bootstrap-wiki/assets/templates"
fail=0; pass(){ echo "  PASS: $1"; }; die(){ echo "  FAIL: $1"; fail=1; }

RES=$(awk '/# --- Plugin root resolution/{f=1} f{print} /plugin root not resolved/{if(f)exit}' "$SKILL" | sed 's/^[[:space:]]*//')
[ -n "$RES" ] || { echo "  FAIL: could not extract resolver from $SKILL"; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/cache/mkt/llm-wiki" "$TMP/foreign"
ln -s "$PLUGIN_DIR" "$TMP/cache/mkt/llm-wiki/2.5.0"

# Codex: no CLAUDE_PLUGIN_ROOT, foreign cwd, fake plugin cache
OUT=$(cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/cache" bash -c "$RES"$'\n''echo "$PLUGIN_ROOT"')
{ [ -n "$OUT" ] && [ -f "$OUT/$CHK/wiki-skeleton/index.md" ]; } && pass "Codex cache -> $OUT" || die "Codex cache resolution ($OUT)"

# Source tree: from repo root, no env
OUT=$(cd "$REPO_ROOT" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/none" bash -c "$RES"$'\n''echo "$PLUGIN_ROOT"')
[ "$OUT" = "plugins/llm-wiki" ] && pass "source tree -> $OUT" || die "source tree resolution ($OUT)"

# Nothing resolves: must abort nonzero, not silently proceed
if (cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/none" bash -c "$RES") 2>/dev/null; then die "should have aborted with no root"; else pass "aborts when unresolved"; fi

[ "$fail" = 0 ] && echo "llm-wiki resolver smoke: ALL PASS" || { echo "llm-wiki resolver smoke: FAILURES"; exit 1; }
