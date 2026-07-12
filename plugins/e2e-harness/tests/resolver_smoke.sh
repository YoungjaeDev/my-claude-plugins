#!/usr/bin/env bash
# Smoke test — e2e-setup Step 0 cross-runtime PLUGIN_ROOT resolver (issue #111 + #129 review).
# Covers: Codex-cache + source-tree resolution; a stale CLAUDE_PLUGIN_ROOT falls
# through (review #1); an incomplete higher cache version is skipped (review #2);
# and a skill-level install (no plugin-root assets/) aborts rather than mis-resolve.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
PLUGIN_DIR=$(cd "$HERE/.." && pwd)                 # plugins/e2e-harness
REPO_ROOT=$(cd "$PLUGIN_DIR/../.." && pwd)
SKILL="$PLUGIN_DIR/skills/e2e-setup/SKILL.md"
CHK="assets"
fail=0; pass(){ echo "  PASS: $1"; }; die(){ echo "  FAIL: $1"; fail=1; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/foreign" "$TMP/stale" "$TMP/none" "$TMP/hermes/skills/e2e-setup"

# Extract the Step 0 resolver into a runnable script that echoes PLUGIN_ROOT.
RUN="$TMP/run.sh"
awk '/# Claude exports CLAUDE_PLUGIN_ROOT; Codex 0.135 does not/{f=1} f{print} /plugin root not resolved/{if(f)exit}' "$SKILL" \
  | sed 's/^[[:space:]]*//' > "$RUN"
printf 'printf "%%s" "$PLUGIN_ROOT"\n' >> "$RUN"

mkdir -p "$TMP/cache/mkt/e2e-harness"; ln -s "$PLUGIN_DIR" "$TMP/cache/mkt/e2e-harness/0.1.2"

# Codex cache
OUT=$(cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/cache" bash "$RUN")
{ [ -n "$OUT" ] && [ -f "$OUT/$CHK/e2e-guidelines.template.md" ]; } && pass "Codex cache -> $OUT" || die "Codex cache resolution ($OUT)"

# Source tree
OUT=$(cd "$REPO_ROOT" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/none" bash "$RUN")
[ "$OUT" = "plugins/e2e-harness" ] && pass "source tree -> $OUT" || die "source tree resolution ($OUT)"

# review #1 — a stale/wrong CLAUDE_PLUGIN_ROOT (no assets/ under it) must NOT win.
OUT=$(cd "$TMP/foreign" && env -u HERMES_HOME CLAUDE_PLUGIN_ROOT="$TMP/stale" CODEX_PLUGIN_CACHE="$TMP/cache" bash "$RUN")
[ "$OUT" = "$TMP/cache/mkt/e2e-harness/0.1.2" ] && pass "stale CLAUDE_PLUGIN_ROOT falls through to cache" || die "stale env should fall through ($OUT)"

# review #2 — incomplete higher version skipped for complete lower one.
mkdir -p "$TMP/cache2/mkt/e2e-harness/9.9.9"; ln -s "$PLUGIN_DIR" "$TMP/cache2/mkt/e2e-harness/0.1.2"
OUT=$(cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/cache2" bash "$RUN")
[ "$OUT" = "$TMP/cache2/mkt/e2e-harness/0.1.2" ] && pass "incomplete 9.9.9 skipped, picked complete 0.1.2" || die "incomplete-version skip ($OUT)"

# Hermes skill-level install carries the skill but NOT the plugin-root assets/ -> abort.
if (cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT HERMES_HOME="$TMP/hermes" CODEX_PLUGIN_CACHE="$TMP/none" bash "$RUN") 2>/dev/null; then die "should abort under skill-level install (no plugin-root assets)"; else pass "aborts under skill-level install"; fi

[ "$fail" = 0 ] && echo "e2e-harness resolver smoke: ALL PASS" || { echo "e2e-harness resolver smoke: FAILURES"; exit 1; }
