#!/usr/bin/env bash
# Smoke test — tally-form cwd-independent script path (issue #111).
# tally-form runs via `Bash(uv run *)` only, so it uses a per-runtime absolute
# path rather than a bash resolver ladder. The Claude path must be
# ${CLAUDE_PLUGIN_ROOT}/skills/tally-form/scripts/... (cwd-independent), not the
# old repo-relative plugins/tally-form/... form (breaks from a foreign cwd).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
PLUGIN_DIR=$(cd "$HERE/.." && pwd)                 # plugins/tally-form
SKILL="$PLUGIN_DIR/skills/tally-form/SKILL.md"
fail=0; pass(){ echo "  PASS: $1"; }; die(){ echo "  FAIL: $1"; fail=1; }

# Doc coupling: the fixed literal is present and the pre-fix repo-relative form is gone.
grep -q '${CLAUDE_PLUGIN_ROOT}/skills/tally-form/scripts/build_tally_form.py' "$SKILL" && pass "SKILL.md uses \${CLAUDE_PLUGIN_ROOT} path" || die "SKILL.md missing \${CLAUDE_PLUGIN_ROOT} path"
grep -q 'uv run plugins/tally-form/skills/tally-form/scripts' "$SKILL" && die "SKILL.md still has repo-relative uv run" || pass "no repo-relative uv run remains"

if ! command -v uv >/dev/null 2>&1; then echo "  SKIP: uv not installed — runtime assertion skipped"; else
  TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
  export CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR"          # Claude Code sets this to the plugin root
  MD="$CLAUDE_PLUGIN_ROOT/skills/tally-form/assets/example-dev-survey.md"
  # Run from a foreign cwd; sidecar written to TMP so the repo stays clean.
  OUT=$(cd "$TMP" && uv run "${CLAUDE_PLUGIN_ROOT}/skills/tally-form/scripts/build_tally_form.py" --md "$MD" --dry-run --out "$TMP/p.json" 2>&1); rc=$?
  { [ "$rc" = 0 ] && printf '%s' "$OUT" | grep -q 'built payload'; } && pass "uv run works from foreign cwd (\${CLAUDE_PLUGIN_ROOT})" || die "uv run failed from foreign cwd (rc=$rc)"
  # Regression: the old repo-relative form must fail from a foreign cwd.
  (cd "$TMP" && uv run plugins/tally-form/skills/tally-form/scripts/build_tally_form.py --md "$MD" --dry-run >/dev/null 2>&1) && die "repo-relative form unexpectedly worked" || pass "repo-relative form fails from foreign cwd (as expected)"
fi

[ "$fail" = 0 ] && echo "tally-form resolver smoke: ALL PASS" || { echo "tally-form resolver smoke: FAILURES"; exit 1; }
