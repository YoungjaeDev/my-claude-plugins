#!/usr/bin/env bash
# Smoke test — e2e-setup Step 0 cross-runtime PLUGIN_ROOT resolver (issue #111).
# Pre-fix the cp steps used a bare ${CLAUDE_PLUGIN_ROOT}/assets/... which expands
# empty under Codex. Extract the Step 0 resolver from SKILL.md and assert it
# resolves the Codex plugin cache + source tree, and aborts under a skill-level
# install (plugin-root assets/ is not bundled there).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
PLUGIN_DIR=$(cd "$HERE/.." && pwd)                 # plugins/e2e-harness
REPO_ROOT=$(cd "$PLUGIN_DIR/../.." && pwd)
SKILL="$PLUGIN_DIR/skills/e2e-setup/SKILL.md"
CHK="assets"
fail=0; pass(){ echo "  PASS: $1"; }; die(){ echo "  FAIL: $1"; fail=1; }

RES=$(awk '/# Claude exports CLAUDE_PLUGIN_ROOT; Codex 0.135 does not/{f=1} f{print} /plugin root not resolved/{if(f)exit}' "$SKILL" | sed 's/^[[:space:]]*//')
[ -n "$RES" ] || { echo "  FAIL: could not extract resolver from $SKILL"; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/cache/mkt/e2e-harness" "$TMP/foreign" "$TMP/hermes/skills/e2e-setup"
ln -s "$PLUGIN_DIR" "$TMP/cache/mkt/e2e-harness/0.1.1"

# Codex: no CLAUDE_PLUGIN_ROOT, foreign cwd, fake plugin cache
OUT=$(cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/cache" bash -c "$RES"$'\n''echo "$PLUGIN_ROOT"')
{ [ -n "$OUT" ] && [ -f "$OUT/$CHK/e2e-guidelines.template.md" ]; } && pass "Codex cache -> $OUT" || die "Codex cache resolution ($OUT)"

# Source tree
OUT=$(cd "$REPO_ROOT" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/none" bash -c "$RES"$'\n''echo "$PLUGIN_ROOT"')
[ "$OUT" = "plugins/e2e-harness" ] && pass "source tree -> $OUT" || die "source tree resolution ($OUT)"

# Hermes skill-level install carries the skill but NOT the plugin-root assets/ ->
# resolver must abort rather than resolve to a path without the templates.
if (cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT HERMES_HOME="$TMP/hermes" CODEX_PLUGIN_CACHE="$TMP/none" bash -c "$RES") 2>/dev/null; then die "should abort under skill-level install (no plugin-root assets)"; else pass "aborts under skill-level install"; fi

[ "$fail" = 0 ] && echo "e2e-harness resolver smoke: ALL PASS" || { echo "e2e-harness resolver smoke: FAILURES"; exit 1; }
