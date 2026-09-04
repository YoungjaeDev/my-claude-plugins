#!/usr/bin/env bash
# Smoke test — deepwiki ask reference-path pointer (issue #111, P3 doc-only).
# The ask skill has no bundled script; it points the model at a plugin-root
# references/ file. Assert the target exists at the plugin root and the SKILL.md
# names both runtimes (Claude / Codex) for resolving it.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
PLUGIN_DIR=$(cd "$HERE/.." && pwd)                 # plugins/deepwiki
SKILL="$PLUGIN_DIR/skills/ask/SKILL.md"
fail=0; pass(){ echo "  PASS: $1"; }; die(){ echo "  FAIL: $1"; fail=1; }

[ -f "$PLUGIN_DIR/references/ask-procedure.md" ] && pass "references/ask-procedure.md exists at plugin root" || die "references/ask-procedure.md missing at plugin root"
grep -q 'CLAUDE_PLUGIN_ROOT' "$SKILL" && pass "names Claude runtime" || die "Claude runtime not named"
grep -qi 'Codex' "$SKILL" && pass "names Codex runtime" || die "Codex runtime not named"

[ "$fail" = 0 ] && echo "deepwiki resolver smoke: ALL PASS" || { echo "deepwiki resolver smoke: FAILURES"; exit 1; }
