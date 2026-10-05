---
name: deck-assets
description: "Prepare assets at the start of a house-format deck (deck/shell.html + deck/sections/*.html, assets in deck/assets/): inventory the outline, collect official SVG logos with a sources.json record, generate pixel-style icon sheets and Ralph mascot variants through codex-image, slice sheets into cells, and gate where cuts may be used. Triggers: 덱 에셋, 로고 수집, 픽셀아트 아이콘, 아이콘 시트, 캐릭터 변형, deck assets, collect logos, icon sheet, mascot variants. For a one-off image request outside a deck, use codex-image directly. Generation spends quota and writes files, so confirm counts first."
---

# deck-assets

Run once at deck start, re-runnable. Leaves `deck/assets/` with logos, sliced icon cells, mascot cells, sidecars and a usage map. Never generate a brand logo, a screen/UI/terminal, or an image with readable text.

Interaction gate: Claude uses `AskUserQuestion`; Codex asks in plain text and waits. Codex does not export `CLAUDE_PLUGIN_ROOT`, so resolve the root first:

```bash
PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
[ -z "$PLUGIN_ROOT" ] && [ -d plugins/deck/skills/deck-assets/scripts ] && PLUGIN_ROOT=plugins/deck
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
SCRIPTS="$PLUGIN_ROOT/skills/deck-assets/scripts"
[ -d "$SCRIPTS" ] || { echo "deck-assets scripts not found; export PLUGIN_ROOT"; exit 1; }
```

Scripts need Python 3; the slicer needs Pillow (`uv run --with pillow python3 ...` if missing).

## 1. Inventory (no cost)

Read `deck/outline.md`. List:

- tools/products named (each needs a logo),
- concept slides that could carry one icon cell,
- emotional beats that could carry one mascot cut (see `references/usage.md`).

Write the draft to `deck/assets/manifest.json` (`logos`, `icons`, `mascot` arrays). Show the counts to the user and get confirmation before steps 3 and 5. Sheets hold 9/16/25 cells, so round the icon count to the nearest sheet.

## 2. Official SVG logos

Fixed source priority per tool, first hit wins:

1. The brand's own press/brand page or product domain.
2. svgl.app API: `https://api.svgl.app/?search=<name>`, follow `brandUrl`/`url` to the brand's own file, fall back to the `route` SVG. Cache responses, the API is throttled.
3. Simple Icons: record `source`, `guidelines`, `license` from its JSON. CC0 covers the file, not the trademark.
4. Anything else: keep it with `official: false`.

Save to `deck/assets/logos/<slug>[-mono].svg` unmodified. Never redraw, recolor or generate a logo. Look up Claude Code/Codex marks at run time, do not assume. Record each file in `deck/assets/logos/sources.json` (array):

`file, name, source_url, official (bool), license, guidelines_url, variant (color|mono|wordmark), sha256, retrieved (YYYY-MM-DD)`

Then verify:

```bash
python3 "$SCRIPTS/check-logos.py" deck/assets/logos
```

It checks file/record parity, sha256, and that each SVG has no `<script>`, `on*=` handler, `<foreignObject>` or external `href`. Fix every failure before any slide references a logo. Self-test: `python3 "$SCRIPTS/check-logos.py" --self-test`.

## 3. Icon sheets (costs quota)

Build the prompt from `references/style-lock.md` (STYLE LOCK block, deck palette on flat `#1F2226`, no transparency). One sheet per 9/16/25 concepts, 1920x1920 so cells divide evenly (3x3=640, 4x4=480, 5x5=384). One line per row naming each cell; one object per cell, generous margin, nothing crossing borders.

Generate through `codex-image` (`--size 1920x1920 --quality high --out deck/assets/generated/sprites`). Use the first approved sheet as `--ref` for later sheets to hold the style. Read the image and check: no letters, every cell inside its border, palette respected.

Write `sheet-NN-<topic>.md` next to each image (template in `references/sidecar.md`): prompt, tool + version, size, date, reference images, post-processing.

Lost or failed copy: never re-run, a re-run bills again. Recover from `~/.codex/generated_images/<session>/` (`ls -t`, match by time) and copy it in.

Fallback order when the first path hits quota or a safety refusal: agy, then codex-image, then Higgsfield (optional, only if connected). Record which path produced the file in the sidecar.

## 4. Slice

```bash
python3 "$SCRIPTS/slice-sheet.py" SHEET.png ROWS COLS OUT_DIR PREFIX [--trim N]
```

Equal division, `--trim` px dropped from every cell edge (default 2, use 6 for 480 px cells with grid lines), output `OUT_DIR/PREFIX-r{row}c{col}.png` 1-based. Self-test: `python3 "$SCRIPTS/slice-sheet.py" --self-test`.

SVG conversion is opt-in and not bundled. These sheets are pixel-style, not true pixel art, so a naive trace gives noisy paths. Only on request: snap to the pixel grid, quantize to the palette, merge rects.

## 5. Mascot variants (costs quota)

`deck/assets/ralph.png` is the user's own Ralph character. Pass it with `--ref deck/assets/ralph.png`; never name or compare it to another franchise and never raise copyright. One style per role: pixel sheet for small cuts (expressions 4x3, poses 4x3), voxel single image for large concept illustrations (1920x1280, empty space reserved for slide text). Do not mix styles on one slide. Prompts in `references/style-lock.md`. Same sidecar and recovery rules.

## 6. Usage gate

Apply `references/usage.md` when a cut is placed on a slide. Record every placement in `deck/assets/sprites/README.md` (cell map + used-on table, layout in `references/usage.md`). Every logo on a slide must have a `sources.json` record.

## Output

Report: files written, counts generated vs confirmed, `check-logos.py` result, any `official:false` logos and their reasons, sheets recovered or fell back.
