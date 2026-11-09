---
name: deck-check
description: "Build and QA a house-format deck (deck/shell.html + deck/sections/*.html): assemble index.html, run the Korean copy check against the banned-pattern table in .claude/rules/deck-copy.md, check that section text matches deck/outline.md, check images against captures.md records and broken asset paths, compare the stamped rule copies with the deck plugin, render every slide to PNG and PDF at 1920x1080 with overflow and font checks, run the keyboard/hash/panel/motion interaction check, and report; a quick mode renders chosen slides only. Use on '덱 검사', '덱 빌드', '빌드하고 확인', '렌더 확인', 'deck QA', 'check the deck', 'render the deck', '/deck:deck-check', and before any deploy. Writes only deck/index.html and deck/renders/. Not for generic presentations made with frontend-slides."
---

# deck-check

One QA pass over a house-format deck, run after editing sections, `shell.html`, motions or assets and always before `deck-deploy`. Every tool runs from the plugin against `./deck` and the repo's `.claude/rules/`, and the result is a short report: slide count, copy and outline violations, rule-copy status, render and interaction status, and what the rendered PNGs show. A deck without `deck/shell.html` + `deck/sections/` is not the house format and is out of scope.

Read `references/output.md` before acting on any line that is not a pass (`violations: 0`, `outline: 0 missing`, `assets: 0 failed`, `rules: ... ok`, `"status":"verified"`): it says what each line means and what to fix.

## Procedure

Run every block from the repo root (the directory that holds `deck/`). Call the tools through the deck's launcher `sh .githooks/deck <command> [args]`: one line, no resolver, and it always picks the newest installed plugin, so never hard-code a `~/.claude/plugins/cache/.../deck/<version>` path.

No `.githooks/deck` (a deck scaffolded before the launcher shipped): ask the user to run `deck-sync` once, which adds it. Until then put the resolver below at the top of each block and call the script for each command: `build.py`, `check_copy.py`, `check_outline.py`, `check_assets.py`, `kit.py check .` and `dev.py` with `"$PY" "$PLUGIN_ROOT/scripts/..."`, and `render-deck.cjs`, `check-deck-interaction.cjs` and `motion-frames.cjs` with `node "$PLUGIN_ROOT/scripts/..."`.

```bash
PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
[ -z "$PLUGIN_ROOT" ] && [ -f plugins/deck/scripts/kit.py ] && PLUGIN_ROOT=plugins/deck
if [ -z "$PLUGIN_ROOT" ]; then
  # find, not a glob: zsh aborts on an unmatched glob and does not split an unquoted list.
  found=$(find "$HOME/.claude/plugins/cache" "${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}" \
    -mindepth 3 -maxdepth 3 -type d -path '*/deck/*' 2>/dev/null | awk -F/ '{print $NF "\t" $(0)}')
  if sort -V </dev/null >/dev/null 2>&1; then
    PLUGIN_ROOT=$(printf '%s\n' "$found" | sort -V | tail -1 | cut -f2-)
  else
    PLUGIN_ROOT=$(printf '%s\n' "$found" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1 | cut -f2-)
  fi
fi
[ -f "$PLUGIN_ROOT/scripts/kit.py" ] || { echo "deck plugin scripts not found; export PLUGIN_ROOT=<path to plugins/deck>"; exit 1; }
PY=$(command -v python3 || command -v python)
```

1. Build, copy check, outline check, asset check, rule copies.

   ```bash
   # Run every check even after a failure, then fail the block if any of them failed.
   rc=0
   # Warn on every run while the commit hooks are off: without them no commit runs these checks.
   [ "$(git config core.hooksPath)" = .githooks ] || echo "hooks: off (core.hooksPath is not .githooks); commit checks do not run. Enable with: git config core.hooksPath .githooks"
   sh .githooks/deck build || rc=1
   sh .githooks/deck copy || rc=1
   sh .githooks/deck outline || rc=1
   sh .githooks/deck assets || rc=1   # exit 3: the launcher or plugin predates check_assets.py
   sh .githooks/deck check || rc=1
   [ "$rc" -eq 0 ]
   ```

   - A `hooks: off` line goes at the top of the report on every run. Ask the user whether to run `git config core.hooksPath .githooks`, and run it only on a yes: it changes the repo's git config. Ask with `AskUserQuestion` on Claude Code or `request_user_input` on Codex; when neither is available, leave the hooks off and say so.
   - Keep N from `slides: N` for step 2.
   - On a violation, fix the section and `deck/outline.md` (the copy source), never the checker.

2. Render and interaction check (Playwright with the system Chrome, plus `pdfinfo` for the PDF page check). While editing, render only the slides you touched in quick mode (1920x1080 only, no PDF, a few seconds per slide); run the full render before a commit and always before `deck-deploy`.

   ```bash
   OUT="deck/renders/$(date +%Y%m%d-%H%M%S)"
   # While editing: sh .githooks/deck render --input deck/index.html --output-dir "$OUT/render" --expected-slides N --quick --slides 12,S3-04
   rc=0
   sh .githooks/deck render --input deck/index.html --output-dir "$OUT/render" --expected-slides N || rc=1
   sh .githooks/deck interaction --input deck/index.html --output-dir "$OUT/interaction" --expected-slides N || rc=1
   # Keep the newest three runs; renders pile up fast (hundreds of MB).
   find deck/renders -mindepth 1 -maxdepth 1 -type d -name '20*' | sort -r | tail -n +4 | while IFS= read -r old; do rm -rf "$old"; done
   [ "$rc" -eq 0 ]
   ```

   Replace `N` with the slide count from step 1. `--slides` takes 1-based numbers or slide ids (the `aria-label` prefix) and skips the PDF; `--quick` drops the 1280, 390 and reduced-motion passes and the PDF. Chrome defaults to the platform's standard path; pass `--chrome PATH` or set `CHROME` otherwise.

3. Look at the slides. Open the contact sheets `"$OUT/render/previews/sheet-*.png"` first (8 slides each, captioned with number and id), then the single `slide-<NN>-<ID>.png` for anything doubtful. Check what the reports cannot: one line per title and list item, nothing crowding the footer (body ends above y 900), no stray placeholder text, panels not needed to understand a slide. For a motion, capture its mid-states (the timeline is seeked, so late times cost nothing):

   ```bash
   sh .githooks/deck frames --input deck/index.html --output-dir deck/renders/frames --slide S3-08 --at 0,800,1600,end
   ```

   `0` is the state right after the motion is built: nothing should show there that waits for a later turn.

4. Report to the user: the `hooks:` line when present, slide count, copy and outline violations, rule-copy statuses, render and interaction status with the problem lines, what the PNGs showed, and the frontend-slides line.

5. Local review, when the user wants to see the deck or fix wording in the browser. Start the dev server in the background and give the URL:

   ```bash
   # dev.py serves until killed: detach it so this block returns.
   mkdir -p deck/renders
   nohup sh .githooks/deck dev deck --port 8765 >deck/renders/dev.log 2>&1 </dev/null &
   echo "http://127.0.0.1:8765  stop: kill $!  log: deck/renders/dev.log"
   ```

   `E` toggles text edit mode and Cmd/Ctrl+S writes the section file back. Copy changed text into `deck/outline.md`, then rerun step 1 (the outline check catches a missed copy). Only text can be edited; moving or resizing boxes is not supported yet.

## Verification

- Pass means: no `hooks: off` line (or the user declined the hooks), `violations: 0`, `outline: 0 missing`, `assets: 0 failed`, every `rules:` line `ok`, `vendor: ok`, both render tools `"status":"verified"` on a full (not `--quick`) run, and the PNGs look right.
- A launcher exit 3, `MissingPlaywright` or a `pdfinfo` failure is a tool problem, not a deck problem: `references/output.md` "Tool failures" has the fix.
- The pre-commit hook runs the build, copy, outline, assets and rule-copy checks on the staged files (not the working tree), and the raw screenshot name check on every commit. A deck's own commit checks go in `.githooks/local-checks.sh`: the hook runs it first on every commit and fails the commit on a non-zero exit.
