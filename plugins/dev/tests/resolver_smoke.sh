#!/usr/bin/env bash
# Smoke test — e2e-setup Step 0 cross-runtime PLUGIN_ROOT resolver (issue #111 + #129 review).
# Covers: Codex-cache + source-tree resolution; a stale CLAUDE_PLUGIN_ROOT falls
# through (review #1); an incomplete higher cache version is skipped (review #2).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
PLUGIN_DIR=$(cd "$HERE/.." && pwd)                 # plugins/dev
REPO_ROOT=$(cd "$PLUGIN_DIR/../.." && pwd)
SKILL="$PLUGIN_DIR/skills/e2e-setup/SKILL.md"
CHK="assets"
fail=0; pass(){ echo "  PASS: $1"; }; die(){ echo "  FAIL: $1"; fail=1; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/foreign" "$TMP/stale" "$TMP/none"

# Extract the Step 0 resolver into a runnable script that echoes PLUGIN_ROOT.
RUN="$TMP/run.sh"
awk '/# Claude exports CLAUDE_PLUGIN_ROOT; Codex 0.135 does not/{f=1} f{print} /plugin root not resolved/{if(f)exit}' "$SKILL" \
  | sed 's/^[[:space:]]*//' > "$RUN"
printf 'printf "%%s" "$PLUGIN_ROOT"\n' >> "$RUN"

mkdir -p "$TMP/cache/mkt/dev"; ln -s "$PLUGIN_DIR" "$TMP/cache/mkt/dev/0.1.2"

# Codex cache
OUT=$(cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT CODEX_PLUGIN_CACHE="$TMP/cache" bash "$RUN")
{ [ -n "$OUT" ] && [ -f "$OUT/$CHK/e2e-guidelines.template.md" ]; } && pass "Codex cache -> $OUT" || die "Codex cache resolution ($OUT)"

# Source tree
OUT=$(cd "$REPO_ROOT" && env -u CLAUDE_PLUGIN_ROOT CODEX_PLUGIN_CACHE="$TMP/none" bash "$RUN")
[ "$OUT" = "plugins/dev" ] && pass "source tree -> $OUT" || die "source tree resolution ($OUT)"

# review #1 — a stale/wrong CLAUDE_PLUGIN_ROOT (no assets/ under it) must NOT win.
OUT=$(cd "$TMP/foreign" && env CLAUDE_PLUGIN_ROOT="$TMP/stale" CODEX_PLUGIN_CACHE="$TMP/cache" bash "$RUN")
[ "$OUT" = "$TMP/cache/mkt/dev/0.1.2" ] && pass "stale CLAUDE_PLUGIN_ROOT falls through to cache" || die "stale env should fall through ($OUT)"

# review #2 — incomplete higher version skipped for complete lower one.
mkdir -p "$TMP/cache2/mkt/dev/9.9.9"; ln -s "$PLUGIN_DIR" "$TMP/cache2/mkt/dev/0.1.2"
OUT=$(cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT CODEX_PLUGIN_CACHE="$TMP/cache2" bash "$RUN")
[ "$OUT" = "$TMP/cache2/mkt/dev/0.1.2" ] && pass "incomplete 9.9.9 skipped, picked complete 0.1.2" || die "incomplete-version skip ($OUT)"

[ "$fail" = 0 ] && echo "dev resolver smoke: ALL PASS" || { echo "dev resolver smoke: FAILURES"; exit 1; }
