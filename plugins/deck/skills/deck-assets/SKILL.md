---
name: deck-assets
description: "Prepare assets at the start of a house-format deck (deck/shell.html + deck/sections/*.html, assets in deck/assets/): inventory the outline, collect logos in the stack-diagram source order (svgl, devicon, gilbarbara, the brand's own file; never Simple Icons) with a sources.json record, generate icon sheets (pixel style for monitor, soft 3D for ralphdev-light) and Ralph mascot variants through codex-image, slice sheets into cells, capture real app screens and web pages (fresh Playwright context; Google results by hand in incognito) and redact screenshots, and gate where cuts may be used. Triggers: 덱 에셋, 로고 수집, 픽셀아트 아이콘, 아이콘 시트, 캐릭터 변형, 화면 캡처, 스크린샷 마스킹, deck assets, collect logos, icon sheet, mascot variants, capture app screen, redact screenshot. For a one-off image request outside a deck, use codex-image directly. Generation spends quota and writes files, so confirm counts first."
---

# deck-assets

Run once at deck start, re-runnable. Leaves `deck/assets/` with logos, sliced icon cells, mascot cells, sidecars and a usage map. Never generate a brand logo, a screen/UI/terminal, or an image with readable text; real screens are captured (step 7).

Ask with `AskUserQuestion` on Claude Code or `request_user_input` on Codex; when neither is available, run only the no-cost steps, then stop and report. Codex does not export `CLAUDE_PLUGIN_ROOT`, so resolve the root first:

```bash
PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
[ -z "$PLUGIN_ROOT" ] && [ -d plugins/deck/skills/deck-assets/scripts ] && PLUGIN_ROOT=plugins/deck
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
SCRIPTS="$PLUGIN_ROOT/skills/deck-assets/scripts"
[ -d "$SCRIPTS" ] || { echo "deck-assets scripts not found; export PLUGIN_ROOT"; exit 1; }
PY=$(command -v python3 || command -v python)
```

Scripts need Python 3; the slicer needs Pillow (`uv run --with pillow python3 ...` if missing).

## 1. Inventory (no cost)

Read `deck/outline.md`. List:

- tools/products named (each needs a logo),
- concept slides that could carry one icon cell; in a `ralphdev-light` deck every section cover gets
  one (`deck-design.md`), so start from the outline header's `- 아이콘:` line, or when it is missing
  propose sections + concept slides and ask before step 3,
- emotional beats that could carry one mascot cut (see `references/usage.md`).

Write the draft to `deck/assets/manifest.json` (`logos`, `icons`, `mascot` arrays). Show the counts to the user and get confirmation before steps 3 and 5. Sheets hold 9/16/25 cells, so round the icon count up to the next sheet size, or ask the user which concepts to drop.

## 2. Logos

Read `references/logos.md` before fetching: it holds the source order (the `stack-diagram` order: svgl, devicon, gilbarbara/logos, the brand's own file), file naming, the `fetch-logo.py` command and the `sources.json` fields.

- Simple Icons is never a file source. A brand with no hit anywhere, or whose terms bar logo use in teaching material, is written as text.
- Save every logo unmodified: never redraw, recolor, crop, convert or generate one. A white mark goes on a dark tile.
- Record every file in `deck/assets/logos/sources.json` through `fetch-logo.py`, then run `"$PY" "$SCRIPTS/check-logos.py" deck/assets/logos` and fix every failure before any slide references a logo.

## 3. Icon sheets (costs quota)

Build the prompt from `references/style-lock.md`: the pixel STYLE LOCK on flat `#1F2226` for a `monitor` deck, the 3D STYLE LOCK on flat `#FDFDFD` for a `ralphdev-light` deck (the template is in the `deck/shell.html` stamp); no transparency. One sheet per 9/16/25 concepts, 1920x1920 so cells divide evenly (3x3=640, 4x4=480, 5x5=384). One line per row naming each cell; one object per cell, generous margin, nothing crossing borders.

Generate through `codex-image` (`--size 1920x1920 --quality high --out deck/assets/generated/sprites`). Use the first approved sheet as `--ref` for later sheets to hold the style. Read the image and check: no letters, every cell inside its border, palette respected.

Write `sheet-NN-<topic>.md` next to each image (template in `references/sidecar.md`): prompt, tool + version, size, date, reference images, post-processing.

Lost or failed copy: never re-run, a re-run bills again. Recover from `${CODEX_HOME:-$HOME/.codex}/generated_images/<session>/` (`ls -t`, match by time) and copy it in.

codex-image is the default path. When it hits quota, fall back to agy, then Higgsfield (optional, only if connected), and record which path produced the file in the sidecar.

A safety refusal is not a fallback case: re-asking another provider after a refusal is a policy bypass, so stop and ask the user whether to revise the prompt.

## 4. Slice

```bash
"$PY" "$SCRIPTS/slice-sheet.py" SHEET.png ROWS COLS OUT_DIR PREFIX [--trim N]
```

Equal division, `--trim` px dropped from every cell edge (default 2, use 6 for 480 px cells with grid lines), output `OUT_DIR/PREFIX-r{row}c{col}.png` 1-based. Self-test: `"$PY" "$SCRIPTS/slice-sheet.py" --self-test`.

SVG conversion is not bundled. Only on request, snap to the pixel grid, quantize to the palette and merge rects (a naive trace of these pixel-style sheets gives noisy paths).

## 5. Mascot variants (costs quota)

Only the `monitor` template has a mascot; a `ralphdev-light` deck skips this step.

- `deck/assets/ralph.png` is the user's own Ralph character. Pass it with `--ref deck/assets/ralph.png`; never name or compare it to another franchise and never raise copyright.
- One style per role, never mixed on one slide: a pixel sheet for small cuts (expressions 4x3, poses 4x3), a voxel single image for large concept illustrations (1920x1280, empty space reserved for slide text).
- Prompts are in `references/style-lock.md`; the sidecar and recovery rules of step 3 apply.

## 6. Usage gate

- Apply `references/usage.md` when a cut is placed on a slide.
- Record every placement in `deck/assets/sprites/README.md` (cell map + used-on table, layout in `references/usage.md`).
- Every logo on a slide must have a `sources.json` record.

## 7. Captures (no quota)

Real result screens and app UI are captured, never generated. Read `references/captures.md` first: it has the usage lines, the row template and the web and search-result procedures.

- Capture a running app or web page with `"$SCRIPTS/capture-page.cjs"` (node) in a fresh Playwright context before Claude in Chrome; a Google result page is captured by a person in an incognito window, since Google blocks automation with a CAPTCHA.
- Clean provided screenshots with `"$SCRIPTS/redact-image.py"`. Faces, names, IDs and private data are redacted first; personal-account originals stay outside the repo.
- Both tools write into `deck/assets/<source>/`. Read each output image, then add its `captures.md` row (file, screen, capture date, redaction).

## Output

Report:

- files written (captures with their `captures.md` rows) and counts generated vs confirmed,
- the `check-logos.py` result, any `official: false` logos with their reasons, and tools left as text,
- sheets recovered or generated through a fallback.
