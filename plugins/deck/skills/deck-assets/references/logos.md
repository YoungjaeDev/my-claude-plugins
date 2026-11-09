# Logo collection

The full procedure for `deck-assets` step 2: source order, file naming, the fetch-and-record command, the `sources.json` fields and the check. `$PY` and `$SCRIPTS` come from the resolver block in SKILL.md.

## Source order

Use the source order of the `stack-diagram` skill's `scripts/fetch_icons.py`, so a deck and a diagram of the same stack carry the same marks. Per tool, first hit wins:

1. svgl: `https://api.svgl.app/?search=<name>`, taking only an item whose title equals the name after lowercasing and dropping non-alphanumerics (the search is fuzzy, so a loose hit ships another brand's logo). Its `route` is the file; a `{light, dark}` route gives both variants. Cache responses, the API is throttled.
2. devicon: `https://raw.githubusercontent.com/devicons/devicon/master/icons/<slug>/<slug>-original.svg`.
3. gilbarbara/logos: `https://cdn.jsdelivr.net/gh/gilbarbara/logos/logos/<slug>-icon.svg`, then `<slug>.svg`.
4. The brand's own file: its press or brand page, its GitHub repo pinned to a commit SHA (`logo*.svg` in the root, docs or assets), or its site's `/logo.svg` or `/favicon.svg`.

Simple Icons is never a file source: its glyphs are one-colour redraws, not the brand's marks. A brand with no hit anywhere, or whose terms bar logo use in teaching material, is written as text. A concept with no brand gets a Lucide line icon (`https://cdn.jsdelivr.net/npm/lucide-static/icons/<icon>.svg`) saved as `icon-<name>.svg`.

When the `stack-diagram` skill is installed, `python3 <stack-diagram>/scripts/fetch_icons.py <scratch dir> <name> ...` runs this chain in one call; its `manifest.json` gives each logo's `source` and `url`. Pass that `url` to `fetch-logo.py` below so the file lands in the deck with its record. The scratch dir stays outside the repo.

## Save

Save unmodified to `deck/assets/logos/<slug>[-mono|-dark].svg` or `.png`; take the light and dark variants together when the source has both. Never redraw, recolor, crop, convert or generate a logo; a white mark goes on a dark tile. Look up Claude Code/Codex marks at run time, do not assume.

- PNG only when the brand ships no SVG of that mark, transparent background, short side at least 256 px. Card images with a filled background are not logos.
- `-mono` marks a single-colour brand logo (the brand's mono file, or a brand whose only mark is one colour). Generic UI icons (Lucide and the like) are not brand logos: name them `icon-<name>.svg`, never `-mono`.

## Fetch and record

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

## Verify

Then verify:

```bash
"$PY" "$SCRIPTS/check-logos.py" deck/assets/logos
```

It checks file/record parity for `.svg` and `.png`, sha256, the PNG short side, and that each SVG has no `<script>`, `on*=` handler, `<foreignObject>`, embedded raster (`data:` URI), external `href` or external CSS `url()`. Fix every failure before any slide references a logo. Self-tests: `"$PY" "$SCRIPTS/check-logos.py" --selftest`, `"$PY" "$SCRIPTS/fetch-logo.py" --selftest`.
