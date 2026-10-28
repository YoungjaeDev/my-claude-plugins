---
name: deck-check
description: "Build and QA a house-format deck (deck/shell.html + deck/sections/*.html): assemble index.html, run the Korean copy check against the banned-pattern table in .claude/rules/deck-copy.md, check that section text matches deck/outline.md, check images against captures.md records and broken asset paths, compare the stamped rule copies with the deck plugin, render every slide to PNG and PDF at 1920x1080 with overflow and font checks, run the keyboard/hash/panel/motion interaction check, and report; a quick mode renders chosen slides only. Use on '덱 검사', '덱 빌드', '빌드하고 확인', '렌더 확인', 'deck QA', 'check the deck', 'render the deck', '/deck:deck-check', and before any deploy. Writes only deck/index.html and deck/renders/. Not for generic presentations made with frontend-slides."
---

# deck-check

## Overview

One QA pass over a house-format deck. Every tool runs from the plugin, against `./deck` and the repo's `.claude/rules/`. Output is a short report: slide count, copy and outline violations, rule-copy status, render and interaction status, and what the rendered PNGs show.

## When to use

- After editing sections, `shell.html`, motions or assets, and always before `deck-deploy`.
- When the user asks whether the deck builds, whether copy rules pass, or whether rule copies are current.
- Not for a deck that lacks `deck/shell.html` + `deck/sections/` (that is not the house format).

## Procedure

Run every block from the repo root (the directory that holds `deck/`). Call the tools through the deck's launcher `sh .githooks/deck <command> [args]`: one line, no resolver, and it always picks the newest installed plugin, so never hard-code a `~/.claude/plugins/cache/.../deck/<version>` path.

No `.githooks/deck` (a deck scaffolded before the launcher shipped): ask the user to run `deck-sync` once, which adds it. Until then put the resolver below at the top of each block and run the tool directly, mapping `build`, `copy`, `outline`, `assets`, `check`, `dev` to `"$PY" "$PLUGIN_ROOT/scripts/<build.py | check_copy.py | check_outline.py | check_assets.py | kit.py check . | dev.py>"` and `render`, `interaction`, `frames` to `node "$PLUGIN_ROOT/scripts/<render-deck.cjs | check-deck-interaction.cjs | motion-frames.cjs>"`.

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
   sh .githooks/deck build || rc=1
   sh .githooks/deck copy || rc=1
   sh .githooks/deck outline || rc=1
   sh .githooks/deck assets || rc=1   # exit 3: the launcher or plugin predates check_assets.py
   sh .githooks/deck check || rc=1
   [ "$rc" -eq 0 ]
   ```

   Observable results:
   - `slides: N`. Keep N for step 2.
   - `violations: 0`. Otherwise each line names file, slide id, rule and text. Fix the section (and `deck/outline.md`, the copy source) rather than the checker. `cannot read banned patterns` means `.claude/rules/deck-copy.md` is missing or lost its `### 금지 표기` table: run `deck-sync`. The deck's own bans go in a `### 덱 금지 표기` table of `.claude/rules/deck-local.md`, same columns (`| 쓰지 않는다 | 대신 | 검사식 |`); `patterns: N from ... and deck-local.md` shows it was read, and `cannot read deck bans` means that table is malformed. A line ending in `alt="..."` or `aria-label="..."` is screen-reader text: only the banned patterns apply there, not the comma or counting checks.
   - `assets: 0 failed`. A failure line names the file: a raw screenshot or `.zip` name (keep the original outside the repo, commit a renamed, blurred copy), an image with no row in the nearest `captures.md` of its folder (a folder under `deck/assets/` that holds a `captures.md` records every capture: file name, screen, date, what was blurred), or an `assets/...` path that a section, the shell or a motion loads but that does not exist. `unused (...)`: images nothing names; warning only, delete them or leave them.
   - `outline: 0 missing of T`. Every h2, `p.lead`, `li` and `.fbox` text piece (its `strong`, its own text, its `span`) must appear verbatim somewhere in `deck/outline.md`. A miss line names file, slide id, kind and text: bring the outline and the section back to the same words (the outline is the source; a dev-server edit belongs in it too). `none of the T texts is in` means a wrong path or an outline that paraphrases instead of quoting. Mockups (`.term`, `.tr-win`, `.browser-win`), `svg`, `pre`, panels and `[data-outline-skip]` are not checked.
   - One `rules: <file> <status>` line per rule copy. `stale` or `missing` means run `deck-sync`; `edited` means someone changed a copy by hand: the deck-specific lines belong in `.claude/rules/deck-local.md`. Add `--diff` to see the change.
   - `vendor:` and `shell.html:` lines. A shell that differs from the template is normal (the deck owns it) and is info only.
   - `frontend-slides: installed|missing`. Warning only, never a failure: relay the printed install commands when missing.

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

   Each tool prints one JSON line (`"status":"verified"` or `"failed"`), then one line per problem, and writes `render-report.json` / `interaction-report.json`. Render problem lines read `slide 12 S3-04 <kind>: <detail> [<passes>]`, the same problem from several viewports listed once. Kinds:
   - `overflow`: an element's own text is larger than its box. `clip`: text cut off inside an `overflow: hidden|clip` box such as a mockup page; shorten the content or enlarge the box, or mark a deliberate crop with `data-intentional-clip`. The mockup pointer `.cursor` is ignored by both.
   - `out-of-bounds`, `footer-overlap`, `font-fallback`, `single-slide`, `pdf-pages`.
   - Interaction `motion-early: slide N ID: <element> visible at 0s ...`: an element shows before its turn because a later `fromTo` rendered its start values at creation. Add `immediateRender: false` to that `fromTo` (the authored end state then keeps it hidden until its turn), and look at the frames below.

3. Look at the slides. Open the contact sheets `"$OUT/render/previews/sheet-*.png"` first (8 slides each, captioned with number and id), then the single `slide-<NN>-<ID>.png` for anything doubtful. Check what the reports cannot: one line per title and list item, nothing crowding the footer (body ends above y 900), no stray placeholder text, panels not needed to understand a slide. For a motion, capture its mid-states (the timeline is seeked, so late times cost nothing):

   ```bash
   sh .githooks/deck frames --input deck/index.html --output-dir deck/renders/frames --slide S3-08 --at 0,800,1600,end
   ```

   `0` is the state right after the motion is built: nothing should show there that waits for a later turn.

4. Report to the user: slide count, copy and outline violations, rule-copy statuses, render and interaction status with the problem lines, what the PNGs showed, and the frontend-slides line.

5. Local review, when the user wants to see the deck or fix wording in the browser. Start the dev server in the background and give the URL:

   ```bash
   # dev.py serves until killed: detach it so this block returns.
   mkdir -p deck/renders
   nohup sh .githooks/deck dev deck --port 8765 >deck/renders/dev.log 2>&1 </dev/null &
   echo "http://127.0.0.1:8765  stop: kill $!  log: deck/renders/dev.log"
   ```

   `E` toggles text edit mode and Cmd/Ctrl+S writes the section file back. Copy changed text into `deck/outline.md`, then rerun step 1 (the outline check catches a missed copy). Only text can be edited; moving or resizing boxes is not supported yet.

## Verification

- Pass means: `violations: 0`, `outline: 0 missing`, `assets: 0 failed`, every `rules:` line `ok`, `vendor: ok`, both render tools `"status":"verified"` on a full (not `--quick`) run, and the PNGs look right.
- `deck: plugin scripts not found` (exit 3) from the launcher: no deck plugin in the Claude or Codex cache; export `PLUGIN_ROOT`. `deck: <tool> is not in <root>`: the installed plugin is older than the launcher; update it.
- The pre-commit hook runs the build, copy, outline, assets and rule-copy checks on the staged files (not the working tree), and the raw screenshot name check on every commit. A deck's own commit checks go in `.githooks/local-checks.sh`: the hook runs it first on every commit and fails the commit on a non-zero exit.
- `MissingPlaywright`: the plugin's `package-lock.json` installs Playwright when Claude Code copies the plugin into its cache. A local source checkout or Codex does not. The launcher prefers, at the same version, the cached copy that has `node_modules`; an older `.githooks/deck` may pick the Codex copy (delete it and run `deck-sync` to refresh). Run `npm ci --ignore-scripts` in the plugin root (`sh .githooks/deck root` prints it), or point `NODE_PATH` at another `node_modules` that has `playwright` (browsers are not needed; the tools drive the system Chrome).
- `pdf-pages:` / `pdfinfo:` failures with no other problem mean `pdfinfo` (poppler) is missing; pass `--pdfinfo PATH` or install poppler.
