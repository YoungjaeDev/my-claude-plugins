#!/usr/bin/env bash
# Smoke test — tally-form script path resolution (issue #111 + #129 review).
# tally-form runs via `Bash(uv run *)`. The Claude path is the cwd-independent
# ${CLAUDE_PLUGIN_ROOT}/skills/tally-form/scripts/... form; under Codex (no
# CLAUDE_PLUGIN_ROOT) a resolver block finds the REAL plugin-cache path — the old
# ~/.agents/skills/tally-form path was fictional (review #3).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
PLUGIN_DIR=$(cd "$HERE/.." && pwd)                 # plugins/tally-form
SKILL="$PLUGIN_DIR/skills/tally-form/SKILL.md"
fail=0; pass(){ echo "  PASS: $1"; }; die(){ echo "  FAIL: $1"; fail=1; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Doc coupling: Claude path present; fictional ~/.agents path gone; real cache resolver present.
grep -q '${CLAUDE_PLUGIN_ROOT}/skills/tally-form/scripts/build_tally_form.py' "$SKILL" && pass "SKILL.md uses \${CLAUDE_PLUGIN_ROOT} path" || die "missing \${CLAUDE_PLUGIN_ROOT} path"
grep -qE 'uv run +~?/?.agents/skills/tally-form' "$SKILL" && die "fictional ~/.agents/skills invocation still present" || pass "no fictional ~/.agents/skills invocation"
grep -q 'TALLY_SCRIPT=' "$SKILL" && pass "Codex plugin-cache resolver present" || die "no plugin-cache resolver (TALLY_SCRIPT)"

# review #3 — the resolver finds the real plugin-cache script from a foreign cwd.
RUN="$TMP/run.sh"
awk '/^S="skills\/tally-form/{f=1} f{print} /build script not resolved/{exit}' "$SKILL" > "$RUN"
printf 'printf "%%s" "$TALLY_SCRIPT"\n' >> "$RUN"
mkdir -p "$TMP/cache/mkt/tally-form" "$TMP/foreign"; ln -s "$PLUGIN_DIR" "$TMP/cache/mkt/tally-form/1.2.1"
OUT=$(cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/cache" bash "$RUN")
{ [ -n "$OUT" ] && [ -f "$OUT" ]; } && pass "Codex cache resolves real script -> $OUT" || die "Codex cache resolution ($OUT)"

# review #2 — incomplete higher version skipped for complete lower one.
mkdir -p "$TMP/cache2/mkt/tally-form/9.9.9"; ln -s "$PLUGIN_DIR" "$TMP/cache2/mkt/tally-form/1.2.1"
OUT=$(cd "$TMP/foreign" && env -u CLAUDE_PLUGIN_ROOT -u HERMES_HOME CODEX_PLUGIN_CACHE="$TMP/cache2" bash "$RUN")
case "$OUT" in */1.2.1/*) pass "incomplete 9.9.9 skipped, picked complete 1.2.1";; *) die "incomplete-version skip ($OUT)";; esac

if ! command -v uv >/dev/null 2>&1; then echo "  SKIP: uv not installed — runtime assertion skipped"; else
  export CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR"
  MD="$CLAUDE_PLUGIN_ROOT/skills/tally-form/assets/example-dev-survey.md"
  OUT=$(cd "$TMP/foreign" && uv run "${CLAUDE_PLUGIN_ROOT}/skills/tally-form/scripts/build_tally_form.py" --md "$MD" --dry-run --out "$TMP/p.json" 2>&1); rc=$?
  { [ "$rc" = 0 ] && printf '%s' "$OUT" | grep -q 'built payload'; } && pass "uv run works from foreign cwd (\${CLAUDE_PLUGIN_ROOT})" || die "uv run failed from foreign cwd (rc=$rc)"
fi

[ "$fail" = 0 ] && echo "tally-form resolver smoke: ALL PASS" || { echo "tally-form resolver smoke: FAILURES"; exit 1; }
