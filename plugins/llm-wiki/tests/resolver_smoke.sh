#!/usr/bin/env bash
# Smoke test — llm-wiki cross-runtime PLUGIN_ROOT resolvers (issue #111 + #129 review).
# Covers: bootstrap-wiki resolves under Codex-cache / source tree / aborts when
# unresolved; a stale CLAUDE_PLUGIN_ROOT falls through (review #1); an incomplete
# higher cache version is skipped for a complete lower one (review #2); and
# PLUGIN_ROOT is DEFINED and resolves in all 5 llm-wiki skills (review #4).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
PLUGIN_DIR=$(cd "$HERE/.." && pwd)                 # plugins/llm-wiki
REPO_ROOT=$(cd "$PLUGIN_DIR/../.." && pwd)
fail=0; pass(){ echo "  PASS: $1"; }; die(){ echo "  FAIL: $1"; fail=1; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/foreign" "$TMP/stale" "$TMP/none"

# Extract a SKILL.md resolver into a runnable script that echoes PLUGIN_ROOT.
# start = canonical resolver comment; end = the abort guard ("... not resolved").
runner_for(){ local f="$TMP/run.$((++n)).sh"
  awk '/# --- Plugin root resolution/{f=1} f{print} /not resolved/{if(f)exit}' "$1" \
    | sed 's/^[[:space:]]*//' > "$f"
  printf 'printf "%%s" "$PLUGIN_ROOT"\n' >> "$f"; printf '%s' "$f"; }
n=0

# Codex plugin cache pointing llm-wiki -> the real plugin tree (has both markers).
mkdir -p "$TMP/cache/mkt/llm-wiki"; ln -s "$PLUGIN_DIR" "$TMP/cache/mkt/llm-wiki/2.5.1"

BW=$(runner_for "$PLUGIN_DIR/skills/bootstrap-wiki/SKILL.md")

# Codex cache resolution
OUT=$(cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/cache" bash "$BW")
[ "$OUT" = "$TMP/cache/mkt/llm-wiki/2.5.1" ] && pass "bootstrap: Codex cache -> $OUT" || die "bootstrap Codex cache ($OUT)"

# Source tree
OUT=$(cd "$REPO_ROOT" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/none" bash "$BW")
[ "$OUT" = "plugins/llm-wiki" ] && pass "bootstrap: source tree -> $OUT" || die "bootstrap source tree ($OUT)"

# review #1 — a stale/wrong CLAUDE_PLUGIN_ROOT (no marker under it) must NOT win;
# resolver falls through to the working cache.
OUT=$(cd "$TMP/foreign" && env -u HERMES_HOME CLAUDE_PLUGIN_ROOT="$TMP/stale" CODEX_PLUGIN_CACHE="$TMP/cache" bash "$BW")
[ "$OUT" = "$TMP/cache/mkt/llm-wiki/2.5.1" ] && pass "stale CLAUDE_PLUGIN_ROOT falls through to cache" || die "stale env should fall through ($OUT)"

# review #2 — an incomplete higher version (2.9.0, empty) must be skipped for the
# complete lower version (2.5.1).
mkdir -p "$TMP/cache2/mkt/llm-wiki/2.9.0"; ln -s "$PLUGIN_DIR" "$TMP/cache2/mkt/llm-wiki/2.5.1"
OUT=$(cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/cache2" bash "$BW")
[ "$OUT" = "$TMP/cache2/mkt/llm-wiki/2.5.1" ] && pass "incomplete 2.9.0 skipped, picked complete 2.5.1" || die "incomplete-version skip ($OUT)"

# Nothing resolves: must abort nonzero
if (cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/none" bash "$BW") 2>/dev/null; then die "should abort with no root"; else pass "bootstrap: aborts when unresolved"; fi

# review #4 — PLUGIN_ROOT is DEFINED and resolves in all 5 llm-wiki skills.
for sk in bootstrap-wiki query-wiki ingest-finding lint-wiki migrate-wiki; do
  SKILL="$PLUGIN_DIR/skills/$sk/SKILL.md"
  grep -q 'PLUGIN_ROOT=' "$SKILL" || { die "$sk: no PLUGIN_ROOT definition"; continue; }
  R=$(runner_for "$SKILL")
  OUT=$(cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/cache" bash "$R" 2>/dev/null)
  { [ -n "$OUT" ] && [ -e "$OUT" ]; } && pass "$sk: PLUGIN_ROOT defined & resolves -> $OUT" || die "$sk: PLUGIN_ROOT unresolved ($OUT)"
done

[ "$fail" = 0 ] && echo "llm-wiki resolver smoke: ALL PASS" || { echo "llm-wiki resolver smoke: FAILURES"; exit 1; }
