---
name: readme
description: Generate or analyze README files with CRO best practices
argument-hint: "[generate|analyze] [--type TYPE]"
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Task
  - Skill
---

# README Command

Generate or analyze README files using patterns from awesome-readme.

## Arguments

- `generate` - Create new README from template
- `analyze` - Analyze existing README and suggest improvements

## Options

- `--type TYPE` - Project type for generation:
  - `cli` - Command-line tool
  - `library` - npm/pip package
  - `react-component` - React UI component
  - `mcp-plugin` - Claude Code plugin
  - `saas` - Web application
  - `desktop` - Desktop application
  - `internal` - Company-internal repository: R&D or PoC, edge hardware, ML training

## Instructions

### For `generate`

0. Load `Skill("docs:doc-guides")` and follow its `## README` section
1. Determine project type from argument or by analyzing project structure
2. Read the appropriate template from `references/TEMPLATES.md`
3. Gather project info:
   - Package name from package.json, setup.py, Cargo.toml, etc.
   - Description from package config
   - Existing commands/API
4. **Generate visual assets** with `/codex-image:codex-image`, following `## Visual Assets Generation`
   below: a text-free banner pair (`assets/banner-light.png`, `assets/banner-dark.png`) by default,
   or a logo (`assets/logo.png`) when the user wants a logo header instead.
5. Generate README customized for the project
6. Apply CRO best practices from `references/CRO_CHECKLIST.md`

### For `analyze`

0. Load `Skill("docs:doc-guides")` and follow its `## README` section
1. Read existing README.md
2. Check against patterns in `references/README_PATTERNS.md`
3. Evaluate using `references/CRO_CHECKLIST.md`
4. Provide specific improvement suggestions with examples
5. Score each category:
   - Header (banner or logo, badges, tagline; banner against the `CRO_CHECKLIST.md` Banner Check)
   - Demo (directly under the badges; result image or measured table when there is no UI)
   - Quick Start (time to first success)
   - Features (benefit-oriented)
   - Examples (progressive complexity)
   - Trust signals (social proof, transparency)

## Output Format

### For generate

Write README.md to project root with:
- Appropriate template structure
- Placeholder comments for user to fill
- All CRO elements included

### For analyze

Provide markdown report:
```markdown
## README Analysis

### Score: X/10

### Strengths
- ...

### Improvements Needed
- [ ] Issue 1 - Suggested fix
- [ ] Issue 2 - Suggested fix

### Quick Wins
1. ...
2. ...
```


## Visual Assets Generation

Facts and sources behind these steps: `references/README_PATTERNS.md` `## Banner`.

### Banner

Default goal: corporate trust and one clear message. Use the pop style (one object or mascot,
2-3 saturated colors, thick outlines) only when the user asks for it.

1. **Write the message first.** A headline of one sentence, 8 words or fewer, that states the value
   or the result, plus an optional proof line with one measured number and its condition. Confirm
   both with the user; they are the banner's content.
2. **Generate the light visual, text-free**, with `/codex-image:codex-image` and the default prompt
   below. Copy the result to `assets/banner-light-raw.png`.
3. **Make the dark visual as an edit of the light one** (`--edit assets/banner-light-raw.png`, dark
   prompt below) so both share one layout. Copy it to `assets/banner-dark-raw.png`.
4. **Measure and crop by script.** Codex's built-in tool fixes `size: "auto"`, so a `--size` passed
   to codex-image does not set the output size; read the real size before cropping. The script
   prints size, mode and alpha range, then keeps the vertical middle band at 3:1 and caps the width
   at 2400 (no upscaling):

   ```python
   from PIL import Image
   for theme in ("light", "dark"):
       im = Image.open(f"assets/banner-{theme}-raw.png"); w, h = im.size
       print(theme, im.size, im.mode, im.getextrema()[-1] if im.mode == "RGBA" else "no alpha")
       ch = w // 3; top = (h - ch) // 2
       assert ch <= h, "output is wider than 3:1; crop the width instead"
       out = im.crop((0, top, w, top + ch))
       if out.width > 2400: out = out.resize((2400, 800), Image.LANCZOS)
       out.save(f"assets/banner-{theme}-art.png"); print(theme, "->", out.size)
   ```

   An exact 2400x800 or 3072x1024 source needs the API-key path of Codex's bundled `imagegen`
   skill (`scripts/image_gen.py --size`), which bills the API.
5. **Typeset the headline deterministically** onto each crop: an SVG or HTML/CSS layout captured
   with Playwright (`deviceScaleFactor: 2`, once per theme), or Pillow with a font file that covers
   the headline's script (a Korean headline needs a Korean font):

   ```python
   from PIL import Image, ImageDraw, ImageFont
   HEADLINE, PROOF, FONT = "<headline>", "<proof line or empty>", "<path/to/font.ttf>"
   for theme, ink in (("light", "#1F2328"), ("dark", "#F0F6FC")):
       im = Image.open(f"assets/banner-{theme}-art.png").convert("RGB"); d = ImageDraw.Draw(im); s = im.height / 800
       d.text((120 * s, 330 * s), HEADLINE, font=ImageFont.truetype(FONT, int(72 * s)), fill=ink)
       if PROOF: d.text((120 * s, 440 * s), PROOF, font=ImageFont.truetype(FONT, int(36 * s)), fill=ink)
       im.save(f"assets/banner-{theme}.png"); print(theme, im.size)
   ```

   Move the text box to the empty zone the prompt reserved. Check the accent and ink contrast on
   both backgrounds with a WCAG ratio script, not by eye.
6. **Open both finished files** and confirm the headline sits in the empty zone, nothing is clipped
   at the top or bottom, and no generated glyphs appear in the visual.
7. **Social preview (optional)** is a repository setting, not the README: a separate 1280x640 file
   under 1 MB.

Default prompt (light):

```text
Use case: stylized-concept
Asset type: GitHub README banner, light theme; will be cropped to a 3:1 strip; the headline is added later as real text
Primary request: calm, corporate visual for <project domain, e.g. edge AI video analytics>
Scene/backdrop: flat off-white background with a very subtle soft gradient, no horizon
Subject: <one simple object that stands for the domain, e.g. a small compute board and a camera as clean geometric shapes>
Style/medium: clean flat-3D product illustration, soft even lighting, precise geometry, matte surfaces
Composition/framing: very wide landscape; all objects inside the middle 50% of the image height; objects in the right 40%, the left 60% left empty for the headline
Color palette: white, light grey and charcoal neutrals, plus <brand accent hex> as the only accent, on one element
Constraints: no text, no letters, no numbers, no logos or trademarks, no mascot, no watermark
```

Dark version (edit of the light result):

```text
Edit Image 1. Change only the background from off-white to a very dark neutral close to #0D1117, and change the light-grey surfaces to dark grey. Keep the objects, the accent color and where it appears, the layout, the empty headline area, and the size unchanged. No text, no new objects, no watermark.
```

### Logo

Only when the user wants a logo header instead of a banner.

- **Format**: square (1:1), minimal, one accent color
- **Prompt template**: `minimal tech logo for [project-name], [project-domain] tool, clean vector style, single color accent, white background, square 1:1 aspect, no text`

### Asset Placement

Banner (default):

```html
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/banner-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="assets/banner-light.png">
  <img alt="<headline>" src="assets/banner-light.png">
</picture>
```

Logo header (instead of the banner, not under it): `README_PATTERNS.md` Header Pattern A, a
centered `<img src="assets/logo.png" width="120" alt="<project-name>">` above the `<h1>`.
