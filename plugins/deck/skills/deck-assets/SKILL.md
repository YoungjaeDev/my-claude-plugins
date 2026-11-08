---
name: deck-assets
description: "Prepare assets at the start of a house-format deck (deck/shell.html + deck/sections/*.html, assets in deck/assets/): inventory the outline, collect logos in the stack-diagram source order (svgl, devicon, gilbarbara, the brand's own file; never Simple Icons) with a sources.json record, generate icon sheets (pixel style for monitor, soft 3D for ralphdev-light) and Ralph mascot variants through codex-image, slice sheets into cells, capture real app screens and web pages (fresh Playwright context; Google results by hand in incognito) and redact screenshots, and gate where cuts may be used. Triggers: 덱 에셋, 로고 수집, 픽셀아트 아이콘, 아이콘 시트, 캐릭터 변형, 화면 캡처, 스크린샷 마스킹, deck assets, collect logos, icon sheet, mascot variants, capture app screen, redact screenshot. For a one-off image request outside a deck, use codex-image directly. Generation spends quota and writes files, so confirm counts first."
---

# deck-assets

Run once at deck start, re-runnable. Leaves `deck/assets/` with logos, sliced icon cells, mascot cells, sidecars and a usage map. Never generate a brand logo, a screen/UI/terminal, or an image with readable text; real screens are captured (step 7).

Interaction gate: Claude uses `AskUserQuestion`; Codex asks in plain text and waits. Codex does not export `CLAUDE_PLUGIN_ROOT`, so resolve the root first:

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

Use the source order of the `stack-diagram` skill's `scripts/fetch_icons.py`, so a deck and a diagram of the same stack carry the same marks. Per tool, first hit wins:

1. svgl: `https://api.svgl.app/?search=<name>`, taking only an item whose title equals the name after lowercasing and dropping non-alphanumerics (the search is fuzzy, so a loose hit ships another brand's logo). Its `route` is the file; a `{light, dark}` route gives both variants. Cache responses, the API is throttled.
2. devicon: `https://raw.githubusercontent.com/devicons/devicon/master/icons/<slug>/<slug>-original.svg`.
3. gilbarbara/logos: `https://cdn.jsdelivr.net/gh/gilbarbara/logos/logos/<slug>-icon.svg`, then `<slug>.svg`.
4. The brand's own file: its press or brand page, its GitHub repo pinned to a commit SHA (`logo*.svg` in the root, docs or assets), or its site's `/logo.svg` or `/favicon.svg`.

Simple Icons is never a file source: its glyphs are one-colour redraws, not the brand's marks. A brand with no hit anywhere, or whose terms bar logo use in teaching material, is written as text. A concept with no brand gets a Lucide line icon (`https://cdn.jsdelivr.net/npm/lucide-static/icons/<icon>.svg`) saved as `icon-<name>.svg`.

When the `stack-diagram` skill is installed, `python3 <stack-diagram>/scripts/fetch_icons.py <scratch dir> <name> ...` runs this chain in one call; its `manifest.json` gives each logo's `source` and `url`. Pass that `url` to `fetch-logo.py` below so the file lands in the deck with its record. The scratch dir stays outside the repo.

Save unmodified to `deck/assets/logos/<slug>[-mono|-dark].svg` or `.png`; take the light and dark variants together when the source has both. Never redraw, recolor, crop, convert or generate a logo; a white mark goes on a dark tile. Look up Claude Code/Codex marks at run time, do not assume.

- PNG only when the brand ships no SVG of that mark, transparent background, short side at least 256 px. Card images with a filled background are not logos.
- `-mono` marks a single-colour brand logo (the brand's mono file, or a brand whose only mark is one colour). Generic UI icons (Lucide and the like) are not brand logos: name them `icon-<name>.svg`, never `-mono`.

Fetch and record in one step (stdlib only, sets a User-Agent, `--member` pulls one file out of a zip brand kit):

```bash
"$PY" "$SCRIPTS/fetch-logo.py" <slug>.svg <url> [--member <path in zip>] --name <Name> \
  --official|--unofficial --license "<basis for use>" --guidelines <url> --variant color|mono|wordmark
```

It writes the file and upserts the `deck/assets/logos/sources.json` record (array, one per file, `retrieved` = today):

`file, name, source_url, official (bool), license, guidelines_url, variant (color|mono|wordmark), sha256, retrieved (YYYY-MM-DD)`

- `official: true` means the saved bytes came unmodified from svgl or from a place the brand controls: its domain, its brand kit, or its own repo at a pinned commit. svgl counts as official because `stack-diagram` treats it as the first official-mark source and both skills keep one standard. devicon, gilbarbara/logos, Wikimedia Commons and icon packs are `false`.
- `source_url` is the URL actually downloaded; with `--member` it is `<zip url>#<member>`.
- `guidelines_url` is the brand's logo/trademark guideline page (svgl's `brandUrl` often leads to it). When the brand publishes none, use the brand home page.
- `license` says the basis for use and how the file was obtained (for example a file saved from a logged-in browser session).

Then verify:

```bash
"$PY" "$SCRIPTS/check-logos.py" deck/assets/logos
```

It checks file/record parity for `.svg` and `.png`, sha256, the PNG short side, and that each SVG has no `<script>`, `on*=` handler, `<foreignObject>`, embedded raster (`data:` URI), external `href` or external CSS `url()`. Fix every failure before any slide references a logo. Self-tests: `"$PY" "$SCRIPTS/check-logos.py" --selftest`, `"$PY" "$SCRIPTS/fetch-logo.py" --selftest`.

## 3. Icon sheets (costs quota)

Build the prompt from `references/style-lock.md`: the pixel STYLE LOCK on flat `#1F2226` for a `monitor` deck, the 3D STYLE LOCK on flat `#FDFDFD` for a `ralphdev-light` deck (the template is in the `deck/shell.html` stamp); no transparency. One sheet per 9/16/25 concepts, 1920x1920 so cells divide evenly (3x3=640, 4x4=480, 5x5=384). One line per row naming each cell; one object per cell, generous margin, nothing crossing borders.

Generate through `codex-image` (`--size 1920x1920 --quality high --out deck/assets/generated/sprites`). Use the first approved sheet as `--ref` for later sheets to hold the style. Read the image and check: no letters, every cell inside its border, palette respected.

Write `sheet-NN-<topic>.md` next to each image (template in `references/sidecar.md`): prompt, tool + version, size, date, reference images, post-processing.

Lost or failed copy: never re-run, a re-run bills again. Recover from `${CODEX_HOME:-$HOME/.codex}/generated_images/<session>/` (`ls -t`, match by time) and copy it in.

codex-image is the default path. When it hits quota, fall back to agy, then Higgsfield (optional, only if connected). A safety refusal is not a fallback case: re-asking another provider after a refusal is a policy bypass, so stop and ask the user whether to revise the prompt. Record which path produced the file in the sidecar.

## 4. Slice

```bash
"$PY" "$SCRIPTS/slice-sheet.py" SHEET.png ROWS COLS OUT_DIR PREFIX [--trim N]
```

Equal division, `--trim` px dropped from every cell edge (default 2, use 6 for 480 px cells with grid lines), output `OUT_DIR/PREFIX-r{row}c{col}.png` 1-based. Self-test: `"$PY" "$SCRIPTS/slice-sheet.py" --self-test`.

SVG conversion is opt-in and not bundled. These sheets are pixel-style, not true pixel art, so a naive trace gives noisy paths. Only on request: snap to the pixel grid, quantize to the palette, merge rects.

## 5. Mascot variants (costs quota)

Only the `monitor` template has a mascot; a `ralphdev-light` deck skips this step and uses the 3D icon style lock in `references/style-lock.md` for its icon sheets. `deck/assets/ralph.png` is the user's own Ralph character. Pass it with `--ref deck/assets/ralph.png`; never name or compare it to another franchise and never raise copyright. One style per role: pixel sheet for small cuts (expressions 4x3, poses 4x3), voxel single image for large concept illustrations (1920x1280, empty space reserved for slide text). Do not mix styles on one slide. Prompts in `references/style-lock.md`. Same sidecar and recovery rules.

## 6. Usage gate

Apply `references/usage.md` when a cut is placed on a slide. Record every placement in `deck/assets/sprites/README.md` (cell map + used-on table, layout in `references/usage.md`). Every logo on a slide must have a `sources.json` record.

## 7. Captures (no quota)

Real result screens and app UI are captured, never generated. Capture a running app with `"$SCRIPTS/capture-page.cjs"` (node), clean provided screenshots with `"$SCRIPTS/redact-image.py"`. Both write into `deck/assets/<source>/`, with a `captures.md` row per image (file, screen, capture date, redaction). Faces, names, IDs and private data are redacted first; personal-account originals stay outside the repo. Read each output image before logging it. A web page is captured in a fresh Playwright context before Claude in Chrome; a Google result page is captured by a person in an incognito window, since Google blocks automation with a CAPTCHA. Usage lines, row template, the web and search-result procedures and rules: `references/captures.md`.

## Output

Report: files written (captures with their `captures.md` rows), counts generated vs confirmed, `check-logos.py` result, any `official: false` logos and their reasons, tools left as text, sheets recovered or fell back.
