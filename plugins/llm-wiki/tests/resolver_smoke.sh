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
OUT=$(cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT CODEX_PLUGIN_CACHE="$TMP/cache" bash "$BW")
[ "$OUT" = "$TMP/cache/mkt/llm-wiki/2.5.1" ] && pass "bootstrap: Codex cache -> $OUT" || die "bootstrap Codex cache ($OUT)"

# Source tree
OUT=$(cd "$REPO_ROOT" && env -u CLAUDE_PLUGIN_ROOT CODEX_PLUGIN_CACHE="$TMP/none" bash "$BW")
[ "$OUT" = "plugins/llm-wiki" ] && pass "bootstrap: source tree -> $OUT" || die "bootstrap source tree ($OUT)"

# review #1 — a stale/wrong CLAUDE_PLUGIN_ROOT (no marker under it) must NOT win;
# resolver falls through to the working cache.
OUT=$(cd "$TMP/foreign" && env CLAUDE_PLUGIN_ROOT="$TMP/stale" CODEX_PLUGIN_CACHE="$TMP/cache" bash "$BW")
[ "$OUT" = "$TMP/cache/mkt/llm-wiki/2.5.1" ] && pass "stale CLAUDE_PLUGIN_ROOT falls through to cache" || die "stale env should fall through ($OUT)"

# review #2 — an incomplete higher version (2.9.0, empty) must be skipped for the
# complete lower version (2.5.1).
mkdir -p "$TMP/cache2/mkt/llm-wiki/2.9.0"; ln -s "$PLUGIN_DIR" "$TMP/cache2/mkt/llm-wiki/2.5.1"
OUT=$(cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT CODEX_PLUGIN_CACHE="$TMP/cache2" bash "$BW")
[ "$OUT" = "$TMP/cache2/mkt/llm-wiki/2.5.1" ] && pass "incomplete 2.9.0 skipped, picked complete 2.5.1" || die "incomplete-version skip ($OUT)"

# Nothing resolves: must abort nonzero
if (cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT CODEX_PLUGIN_CACHE="$TMP/none" bash "$BW") 2>/dev/null; then die "should abort with no root"; else pass "bootstrap: aborts when unresolved"; fi

# spaces in cache path — a cache under a path with a space must resolve
# (the old `for d in $(ls ...)` word-split and returned nothing).
mkdir -p "$TMP/sp dir/mkt/llm-wiki"; ln -s "$PLUGIN_DIR" "$TMP/sp dir/mkt/llm-wiki/2.5.1"
OUT=$(cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT CODEX_PLUGIN_CACHE="$TMP/sp dir" bash "$BW")
[ "$OUT" = "$TMP/sp dir/mkt/llm-wiki/2.5.1" ] && pass "spaced cache path resolves" || die "spaced cache path ($OUT)"

# review #4 — PLUGIN_ROOT is DEFINED in all 5 llm-wiki skills AND resolves to a
# root that actually contains the target file the skill references.
for sk in bootstrap-wiki ingest-finding lint-wiki; do
  SKILL="$PLUGIN_DIR/skills/$sk/SKILL.md"
  grep -q 'PLUGIN_ROOT=' "$SKILL" || { die "$sk: no PLUGIN_ROOT definition"; continue; }
  case "$sk" in bootstrap-wiki) TGT="skills/bootstrap-wiki/assets/templates";; *) TGT="references/wiki-conventions.md";; esac
  R=$(runner_for "$SKILL")
  OUT=$(cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT CODEX_PLUGIN_CACHE="$TMP/cache" bash "$R" 2>/dev/null)
  { [ -n "$OUT" ] && [ -e "$OUT/$TGT" ]; } && pass "$sk: resolves real target ($TGT)" || die "$sk: target $TGT unresolved ($OUT)"
done

# ingest-finding #2 — a doc-skill resolver degrades QUIETLY when nothing resolves
# (supplementary reference), not a hard abort: exit 0 with empty PLUGIN_ROOT.
IF=$(runner_for "$PLUGIN_DIR/skills/ingest-finding/SKILL.md")
OUT=$(cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT CODEX_PLUGIN_CACHE="$TMP/none" bash "$IF" 2>/dev/null); rc=$?
{ [ "$rc" = 0 ] && [ -z "$OUT" ]; } && pass "doc skill degrades quietly when unresolved (rc=0, empty)" || die "doc skill should degrade quietly (rc=$rc, out=$OUT)"

[ "$fail" = 0 ] && echo "llm-wiki resolver smoke: ALL PASS" || { echo "llm-wiki resolver smoke: FAILURES"; exit 1; }
