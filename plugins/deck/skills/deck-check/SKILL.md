---
name: deck-check
description: "Build and QA a house-format deck (deck/shell.html + deck/sections/*.html): assemble index.html, run the Korean copy check against the banned-pattern table in .claude/rules/deck-copy.md, compare the stamped rule copies with the deck plugin, render every slide to PNG and PDF at 1920x1080 with overflow and font checks, run the keyboard/hash/panel/motion interaction check, and report. Use on '덱 검사', '덱 빌드', '빌드하고 확인', '렌더 확인', 'deck QA', 'check the deck', 'render the deck', '/deck:deck-check', and before any deploy. Writes only deck/index.html and deck/renders/. Not for generic presentations made with frontend-slides."
---

# deck-check

## Overview

One QA pass over a house-format deck. Every tool runs from the plugin, against `./deck` and the repo's `.claude/rules/`. Output is a short report: slide count, copy violations, rule-copy status, render and interaction status, and what the rendered PNGs show.

## When to use

- After editing sections, `shell.html`, motions or assets, and always before `deck-deploy`.
- When the user asks whether the deck builds, whether copy rules pass, or whether rule copies are current.
- Not for a deck that lacks `deck/shell.html` + `deck/sections/` (that is not the house format).

## Procedure

Shell state does not persist between tool calls. Put this resolver at the top of every command block below.

```bash
PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
[ -z "$PLUGIN_ROOT" ] && [ -f plugins/deck/scripts/kit.py ] && PLUGIN_ROOT=plugins/deck
if [ -z "$PLUGIN_ROOT" ]; then
  # find, not a glob: zsh aborts on an unmatched glob and does not split an unquoted list.
  found=$(find "$HOME/.claude/plugins/cache" "${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}" \
    -mindepth 3 -maxdepth 3 -type d -path '*/deck/*' 2>/dev/null | awk -F/ '{print $NF "\t" $0}')
  if sort -V </dev/null >/dev/null 2>&1; then
    PLUGIN_ROOT=$(printf '%s\n' "$found" | sort -V | tail -1 | cut -f2-)
  else
    PLUGIN_ROOT=$(printf '%s\n' "$found" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1 | cut -f2-)
  fi
fi
[ -f "$PLUGIN_ROOT/scripts/kit.py" ] || { echo "deck plugin scripts not found; export PLUGIN_ROOT=<path to plugins/deck>"; exit 1; }
PY=$(command -v python3 || command -v python)
```

1. Build, copy check, rule copies. Run from the repo root (the directory that holds `deck/`).

   ```bash
   # resolver block above goes here
   # Run every check even after a failure, then fail the block if any of them failed.
   rc=0
   "$PY" "$PLUGIN_ROOT/scripts/build.py" deck || rc=1
   "$PY" "$PLUGIN_ROOT/scripts/check_copy.py" deck || rc=1
   "$PY" "$PLUGIN_ROOT/scripts/kit.py" check . || rc=1
   [ "$rc" -eq 0 ]
   ```

   Observable results:
   - `slides: N`. Keep N for step 2.
   - `violations: 0`. Otherwise each line names file, slide id, rule and text. Fix the section (and `deck/outline.md`, the copy source) rather than the checker. `cannot read banned patterns` means `.claude/rules/deck-copy.md` is missing or lost its `### 금지 표기` table: run `deck-sync`.
   - One `rules: <file> <status>` line per rule copy. `stale` or `missing` means run `deck-sync`; `edited` means someone changed a copy by hand: the deck-specific lines belong in `.claude/rules/deck-local.md`. Add `--diff` to see the change.
   - `vendor:` and `shell.html:` lines. A shell that differs from the template is normal (the deck owns it) and is info only.
   - `frontend-slides: installed|missing`. Warning only, never a failure: relay the printed install commands when missing.

2. Render and interaction check (Playwright with the system Chrome, plus `pdfinfo` for the PDF page check).

   ```bash
   # resolver block above goes here
   (cd "$PLUGIN_ROOT/scripts" && node -e 'require.resolve("playwright")') || echo "playwright missing: see Verification"
   OUT="deck/renders/$(date +%Y%m%d-%H%M%S)"
   rc=0
   node "$PLUGIN_ROOT/scripts/render-deck.cjs" --input deck/index.html --output-dir "$OUT/render" --expected-slides N || rc=1
   node "$PLUGIN_ROOT/scripts/check-deck-interaction.cjs" --input deck/index.html --output-dir "$OUT/interaction" --expected-slides N || rc=1
   [ "$rc" -eq 0 ]
   ```

   Replace `N` with the slide count from step 1. Chrome defaults to the platform's standard path; pass `--chrome PATH` or set `CHROME` otherwise. Each tool prints one JSON line (`"status":"verified"` or `"failed"`) and writes `render-report.json` / `interaction-report.json` with every failure (overflow, out-of-bounds, footer overlap, font fallback, slide state, hash, panel, motion).

3. Look at the slides. Open `"$OUT/render/previews/slide-*.png"` with the image reader and check what the reports cannot: one line per title and list item, nothing crowding the footer (body ends above y 900), no stray placeholder text, panels not needed to understand a slide.

4. Report to the user: slide count, copy violations, rule-copy statuses, render and interaction status with failure lines, what the PNGs showed, and the frontend-slides line.

5. Local review, when the user wants to see the deck or fix wording in the browser. Start the dev server in the background and give the URL:

   ```bash
   # resolver block above goes here
   # dev.py serves until killed: detach it so this block returns.
   mkdir -p deck/renders
   nohup "$PY" "$PLUGIN_ROOT/scripts/dev.py" deck --port 8765 >deck/renders/dev.log 2>&1 </dev/null &
   echo "http://127.0.0.1:8765  stop: kill $!  log: deck/renders/dev.log"
   ```

   `E` toggles text edit mode and Cmd/Ctrl+S writes the section file back. Copy changed text into `deck/outline.md`, then rerun step 1. Only text can be edited; moving or resizing boxes is not supported yet.

## Verification

- Pass means: `violations: 0`, every `rules:` line `ok`, `vendor: ok`, both render tools `"status":"verified"`, and the PNGs look right.
- `MissingPlaywright`: the plugin's `package-lock.json` installs Playwright when Claude Code copies the plugin into its cache. A local source checkout or Codex does not. Run `npm ci --ignore-scripts` in the plugin root, or point `NODE_PATH` at another `node_modules` that has `playwright` (browsers are not needed; the tools drive the system Chrome).
- `pdf-pages:` / `pdfinfo:` failures with no other problem mean `pdfinfo` (poppler) is missing; pass `--pdfinfo PATH` or install poppler.
