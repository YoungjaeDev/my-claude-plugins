# README Patterns Reference

Analyzed from awesome-readme examples. Use as reference when creating or reviewing README files.

---

## Analyzed Projects (9 total)

| Project | Type | Key Pattern |
|---------|------|-------------|
| ai/size-limit | CLI Tool | User segmentation, "Who Uses" section |
| gofiber/fiber | Web Framework | Benchmarks, Limitations transparency |
| httpie/cli | CLI Tool | GIF demo, progressive examples |
| release-it/release-it | CLI Tool | Multi-path install, schema-driven config |
| dbt-labs/dbt-core | Data Tool | Visual architecture, analogy-driven |
| PostHog/posthog | SaaS | Cloud-first, feature density |
| ryanoasis/nerd-fonts | Font Collection | Decision tree, platform matrix |
| electron-markdownify | Desktop App | Hero GIF, dual install paths |
| react-parallax-tilt | React Component | Props table, external demos |

---

## Universal Structure

```
1. Header (Logo + Badges + Tagline)
2. Quick Start (3 steps max)
3. Features (Benefits, not specs)
4. Installation (Detailed)
5. Usage/Examples (Progressive complexity)
6. Configuration (If applicable)
7. API/Props (If applicable)
8. Contributing
9. License
```

This order assumes an open-source project courting outside adopters. For a repository that is not
distributed, use the next section.

---

## Internal Repo Structure

For a company-internal repository (R&D, PoC, edge hardware, ML training). The sections that win
outside adopters drop out (Contributing, License, Code of Conduct, Used By, download or star
badges). The sections that let a teammate trust the current state and reproduce it come in.

| # | Section | Content | Basis |
|---|---------|---------|-------|
| 1 | Banner | `<picture>` dark + light pair, `alt` = the headline | standard-readme Banner slot; GitHub Docs `<picture>` |
| 2 | `# Name` + one-line summary | what it does, on which hardware or data | standard-readme Title, Short Description |
| 3 | Badges, 3-4 | stage (PoC, E2E), hardware, language, CI | standard-readme Badges |
| 4 | Demo or Results | see `## Demo and Screenshots Placement` | readme.so Demo, Screenshots |
| 5 | Current status | dated table: value, conditions (model, resolution, host, duration), next step | existing internal READMEs |
| 6 | Quick start | copy-paste commands that run as written | Best-README-Template Getting Started |
| 7 | Structure | directory tree, one line per entry | existing internal READMEs |
| 8 | Verification | test, lint, e2e commands a reviewer runs | existing internal READMEs |
| 9 | Risks and open questions | one bold sentence each, with an evidence pointer | existing internal READMEs |
| 10 | Docs map | `Document / Question it answers` table, or a link to the MOC (`/docs:moc`) | existing internal READMEs |
| 11 | Owner | team or person, contact channel | readme.so Authors, Support |

Rows 1-3 follow standard-readme's opening order: Title, Banner, Badges, Short Description
([RichardLitt/standard-readme](https://github.com/RichardLitt/standard-readme), the only README
spec that gives a banner its own slot). Section-by-section choices from the readme.so menu are in
`README_SECTIONS.md`.

**Badges on a private repo.** A static shields.io badge
(`https://img.shields.io/badge/<label>-<message>-<color>`) encodes its text in the URL and renders
without repository access. The label and message travel to shields.io in the image request, so put
only values cleared for outside disclosure in a badge; show a private value as a repository-local
image instead. Whether shields.io dynamic badges or GitHub Actions status badges can
read a private repository's state is unverified; use static badges until that is checked.

---

## Header Patterns

### Pattern A: Centered (Most Common)

```html
<div align="center">
  <img src="logo.svg" width="120" alt="Name">
  <h1>Project Name</h1>
  <p>One-line value proposition</p>

  [Badge] [Badge] [Badge]

  [Link] | [Link] | [Link]
</div>
```

**Used by**: fiber, httpie, electron-markdownify, nerd-fonts

### Pattern B: Left-Aligned with Right Logo

```markdown
# Project Name

Description paragraph.

![Logo](logo.png) (floated right)

[Badges]
```

**Used by**: size-limit, release-it

### Pattern C: Badge-First

```markdown
[Badge row 1: Status indicators]
[Badge row 2: Social proof]

# Project Name

Description
```

**Used by**: PostHog, dbt-core

Use a banner or a centered logo as the top image, not both stacked.

---

## Banner

Default goal: corporate trust and one message that lands. A pop style is an option the user picks,
not the default.

### Composition

| Element | Rule |
|---------|------|
| Visual | text-free image from the image model |
| Headline | one sentence, 8 words or fewer, stating the value or the result; typeset, never generated |
| Proof line (optional) | one measured number with its condition |
| Color | one brand accent plus neutrals |
| Space | wide negative space; the headline zone stays empty in the visual |
| Ratio and size | 3:1 at about 2x display width, e.g. 2400x800 |
| Safe band | key elements inside the vertical middle 50% of the raw image |
| Themes | dark and light files swapped with `<picture>` |
| Decoration | no mascot, no ornament in the default style |

**Why the visual carries no text.** OpenAI's image generation guide lists text rendering and the
consistency of recurring brand elements as current limitations
([API image generation guide](https://developers.openai.com/api/docs/guides/image-generation)).
OpenAI's own web-hero recipe agrees: the web-hero samples in Codex's bundled `imagegen` skill all end
with "no text; no logos; no watermark" and ask for "usable negative space for page copy"
([imagegen skill](https://github.com/openai/codex/tree/main/codex-rs/skills/src/assets/samples/imagegen)).
Typesetting the headline afterwards makes spelling, contrast and rewording deterministic: a new
headline is a re-render, not a re-generation.

**Typesetting paths.** An SVG or HTML/CSS layout captured with Playwright, or Pillow drawing text
with a bundled font. Example: spokospace/zapiszprzepis PR #129 lays out a 1280x400 HTML/CSS banner
and captures it with Playwright at `deviceScaleFactor: 2`, once per theme, producing two 2560x800
WebP files of about 103-109 KB ([PR #129](https://github.com/spokospace/zapiszprzepis/pull/129)).

### Pop style (opt-in)

Among 107 popular READMEs surveyed on 2026-10-02 (first image measured with Pillow), the pop banners
share one object or mascot, two or three saturated colors, thick outlines, and a transparent or
single solid background (Charm's gum and vhs, Bun, Gleam, KAPLAY). That formula is an inference from
the sample, not a published rule. A transparent PNG with outlined shapes reads on both themes and
needs one file; a solid background needs the dark + light pair. Describe a style by technique
(halftone dots, two-color risograph, hard offset shadow), not by an artist's name.

### GitHub rendering rules

- **`<picture>` is the documented theme switch.** GitHub Docs shows `<source
  media="(prefers-color-scheme: dark)">`, a light `<source>`, and an `<img>` with `alt` and a
  default `src`, using a profile banner as the example
  ([GitHub Docs quickstart](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/quickstart-for-writing-on-github);
  announced 2022-05-19, [community #16910](https://github.com/orgs/community/discussions/16910)).
  "Responsive" there means theme switching, not screen width.
- **The sanitizer strips `style` and keeps `width`, `height`, `align`.** GitHub then adds
  `max-width: 100%` itself. `<picture>` is wrapped in `<themed-picture>`, each `srcset` is rewritten
  to the camo proxy, and every image is wrapped in a link to the raw image, so wrap it in your own
  `<a>` to link elsewhere. Checked on 2026-10-02 by sending test markup to the Markdown API
  (`gh api markdown -f mode=gfm`;
  [REST: Render a Markdown document](https://docs.github.com/en/rest/markdown/markdown)).
- **Use relative paths** for images committed to the repository
  ([GitHub Docs: basic formatting](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax)).
- **Name files by the theme they appear on** (`banner-dark.png` is the one shown on a dark page).
  Vite and oxc wire `*-light.svg` into the dark `<source>`, which is easy to copy backwards.
- **Prefer `<picture>` over the `#gh-dark-mode-only` / `#gh-light-mode-only` URL fragments.**
  Sources disagree on whether the fragments are deprecated
  ([changelog 2021-11-24](https://github.blog/changelog/2021-11-24-specify-theme-context-for-images-in-markdown/)),
  and whether github.com still hides them is unverified.
- **Mobile display width is unknown.** Published claims about the mobile column width and
  `max-width` source switching were rejected on cross-check; do not design for a number.
- **The social preview is a separate repository setting**, not the README banner: PNG, JPG or GIF
  under 1 MB, at least 640x320, 1280x640 recommended, solid background when transparency is in
  doubt
  ([GitHub Docs: social preview](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview)).

### Generating with Codex

- **The built-in tool cannot pick a size.** Codex's built-in image generation uses `gpt-image-2`
  ([Codex image generation](https://learn.chatgpt.com/docs/image-generation)). Its client source
  `codex-rs/ext/image-generation/src/tool.rs` fixes `size: "auto"` and `quality: Auto` for generate
  and edit, and the tool takes only `prompt`, `transparent_background`, `referenced_image_paths`
  (up to 5 absolute paths) and `num_last_images_to_include`
  ([tool.rs](https://github.com/openai/codex/blob/main/codex-rs/ext/image-generation/src/tool.rs),
  read 2026-10-02). Generate, read the actual size, then crop.
- **Why the middle 50% band.** Cropping a 1536x1024 output to 3:1 keeps 1536x512, half the height.
  What `auto` returns for a wide-banner prompt is unverified, so print the size before cropping.
- **Exact sizes need the API path.** The bundled skill's `scripts/image_gen.py` takes `--size` but
  requires `OPENAI_API_KEY` and bills the API. `gpt-image-2` sizes must keep the longest edge at
  3840 or less, both edges multiples of 16, a long:short ratio of 3:1 or less, and 655,360 to
  8,294,400 total pixels
  ([prompting guide](https://developers.openai.com/cookbook/examples/multimodal/image-gen-models-prompting-guide)).
  `3072x1024`, `2400x800`, `1920x640` and `1536x512` pass; 4:1 (`2560x640`) does not, so a 4:1
  banner is always a crop.
- **Transparency.** codex 0.158.0 added `transparent_background`
  ([rust-v0.158.0](https://github.com/openai/codex/releases/tag/rust-v0.158.0)); the bundled CLI
  docs still say the model lacks transparent backgrounds. Check the output's alpha channel with a
  script instead of trusting either.
- **Prompt order.** Scene or backdrop, subject, key details, constraints; name the use ("README
  banner"); state exclusions ("no text, no logos, no watermark"). For an edit, say "change only X"
  and repeat the full keep-list every time (prompting guide above).

The Codex rows above come from source code and the local codex-cli 0.158.0 install; they were not
part of the 2026-10-02 three-vote cross-check that confirmed the GitHub and template claims.

---

## Badge Strategy

### Essential Badges (Pick 3-5)

| Badge | Purpose | Priority |
|-------|---------|----------|
| Build/CI Status | Trust - "it works" | 1 |
| Version | Currency | 2 |
| License | Legal clarity | 3 |
| Downloads/Stars | Social proof | 4 |
| Coverage | Quality signal | 5 |

### Badge Placement

```
Header: 3-5 essential badges
README body: Contextual badges (e.g., plugin ecosystem table)
Footer: Optional social badges
```

### Anti-Pattern

10+ badges = "badge soup" = desperation signal

---

## Quick Start Patterns

### Pattern A: Minimal (size-limit, httpie)

```markdown
## Quick Start

```bash
npm install project-name
```

```javascript
project.run() // => "Hello!"
```

Done.
```

### Pattern B: Numbered Steps (nerd-fonts)

```markdown
## Quick Start

1. Install: `npm install project-name`
2. Configure: Create `config.json`
3. Run: `npm start`

You should see: [expected output]
```

### Pattern C: Decision Tree (release-it, nerd-fonts)

```markdown
## Installation

**If you want quick setup:**
```bash
npm init project-name
```

**If you want manual control:**
```bash
npm install -D project-name
# then configure...
```

**If you use Docker:**
```bash
docker run project-name
```
```

---

## Feature Presentation

### Pattern A: Benefit-Oriented List (electron-markdownify)

```markdown
## Features

- LivePreview - Make changes, see changes instantly
- Sync Scrolling - Auto-scroll to current edit location
- Cross Platform - Windows, macOS, Linux ready
```

Format: `Feature Name - User Benefit`

### Pattern B: Table Format (fiber, PostHog)

```markdown
## Features

| Feature | Description |
|---------|-------------|
| Routing | Express-style route handling |
| Static Files | Serve from filesystem |
| WebSockets | Real-time communication |
```

### Pattern C: Categorized (size-limit)

```markdown
## Features

**Performance**
- Tree-shaking support
- Real cost calculation

**Integration**
- GitHub Actions
- Circle CI
```

---

## Code Examples

### Progressive Complexity Pattern

```markdown
## Usage

### Basic
```javascript
const x = require('x');
x.run();
```

### With Options
```javascript
const x = require('x');
x.run({ option: true });
```

<details>
<summary>Advanced Configuration</summary>

```javascript
// Complex example here
```

</details>
```

### Commented Commands (electron-markdownify)

```bash
# Clone this repository
$ git clone https://github.com/user/repo

# Go into the repository
$ cd repo

# Install dependencies
$ npm install

# Run the app
$ npm start
```

---

## Trust Building Elements

### "Who Uses This" (size-limit)

```markdown
## Who Uses This

Used by [MobX](link), [Material-UI](link), [Ant Design](link).
```

### Benchmarks (fiber)

```markdown
## Benchmarks

![Benchmark](benchmark.png)

[See full results](link)
```

### Limitations Section (fiber)

```markdown
## Limitations

- Known limitation 1
- Known limitation 2

This builds trust through transparency.
```

---

## Visual Elements

### When to Use GIF

| Content | Use GIF | Use Screenshot |
|---------|---------|----------------|
| UI interaction | Yes | No |
| CLI output | Yes | Also OK |
| Static result | No | Yes |
| Complex workflow | Yes | No |

### GIF Specifications

- Duration: 5-15 seconds
- Size: Under 10MB
- Width: 600-800px
- Frame rate: 10-12 fps

### Placement

See `## Demo and Screenshots Placement`.

---

## Demo and Screenshots Placement

The demo goes in its own section directly under the badges, before Quick Start.

| Project | Heading | Content |
|---------|---------|---------|
| has a UI or demo material | `## Demo` (`## 데모` in a Korean README) | GIF of the main flow, or screenshots |
| no UI: ML training, hardware, pipeline | same slot; name it after what it shows, e.g. `## Results` (`## 결과`) | result image (detections, curves) or a measured table with date and conditions |

- readme.so ships `Demo` ("Insert gif or link to demo") and `Screenshots` as separate section
  templates ([octokatherine/readme.so](https://github.com/octokatherine/readme.so),
  `data/section-templates-en_EN.js`, MIT). When a README has both, fold the screenshots into the
  one demo section so the slot under the badges holds a single visual block.
- A measured table in this slot carries the same provenance as anywhere else: date, model or
  configuration, hardware, and how long it ran.

---

## API/Props Documentation (react-parallax-tilt)

### Format

```markdown
## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `boolean` | `true` | Enable/disable effect |
| `maxAngle` | `number` | `20` | Max tilt angle (0-90) |
```

### Alternative Format

```markdown
## Props

**enabled**: `boolean` (default: `true`)
Enable or disable the effect.

**maxAngle**: `number` (default: `20`)
Maximum tilt angle in degrees. Range: 0-90.
```

---

## Platform-Specific Installation (nerd-fonts)

```markdown
## Installation

### macOS

```bash
brew install project-name
```

### Windows

```bash
choco install project-name
```

### Linux

```bash
apt install project-name
```

### From Source

```bash
git clone ... && make install
```
```

---

## SaaS README Pattern (PostHog)

```markdown
[Header with product family badges]

## Cloud (Recommended)

[Sign up link] - Free tier: X events/month

## Self-Hosted

```bash
docker run ...
```

Note: Limited support for self-hosted deployments.

## Features

[Dense feature list - 10+ items, one line each]

## SDKs

| Frontend | Mobile | Backend |
|----------|--------|---------|
| JS | React Native | Python |
| React | iOS | Node |
```

---

## Desktop App Pattern (electron-markdownify)

```markdown
[Centered logo + name]
[Single tagline mentioning framework]
[Navigation: Features | How To Use | Download | Credits]

[Hero GIF showing app in action]

## Key Features
[Benefit-oriented list]

## How To Use
[Developer setup: clone, install, run]

## Download
[Link to releases page with platform list]

## Credits
[Dependencies list]

[Footer: Author links]
```

---

## CLI Tool Pattern (release-it, httpie)

```markdown
[Logo + tagline]
[Feature bullets - quick value scan]
[Badges]

## Install
[Package manager commands]

## Usage
```bash
tool-name [options]
```

## Configuration
[Multiple format support: JSON, YAML, JS]
[Schema reference for IDE support]

## CI/CD Integration
[GitHub Actions, etc.]

## Troubleshooting
[Debug flags, common issues]
```

---

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| No quick start | 2-min abandonment | Add 3-step install at top |
| Wall of text | No visual hierarchy | Use headers, bullets, tables |
| Assuming expertise | Excludes beginners | Define terms, link glossary |
| Dead links | Appears unmaintained | Quarterly link checks |
| "Coming soon" | Vaporware perception | Only document what exists |
| Badge soup | Desperation signal | Max 5 in header |
| No screenshots (UI) | Trust deficit | Add hero GIF/image |
| Outdated screenshots | Destroys trust | Date images or use version tags |

---

## Checklist

Before publishing:

- [ ] One-line description explains what AND why
- [ ] 3-5 essential badges
- [ ] Quick start in first screen
- [ ] Copy-paste commands work
- [ ] Features describe benefits, not specs
- [ ] Examples progress from simple to complex
- [ ] Prerequisites clearly stated
- [ ] License specified
- [ ] No dead links
- [ ] Visual demo for UI projects
