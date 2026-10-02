# Analyzed Examples Summary

Quick reference of all 9 analyzed awesome-readme projects.

---

## 1. ai/size-limit

**Type**: CLI Tool (Performance Budget)
**URL**: https://github.com/ai/size-limit

### Key Patterns

- **"Who Uses"** section with major project logos (MobX, Material-UI, Ant Design)
- **"How It Works"** numbered explanation (5 steps)
- **User segmentation**: Different paths for JS Apps / Big Libs / Small Libs
- **Plugin ecosystem** table with download badges

### Structure

```
Logo + Badge
Tagline
Who Uses (social proof)
How It Works (visual explanation)
Usage by User Type
Plugins Table
Configuration
```

### Takeaway

User segmentation + social proof upfront = high trust, clear paths.

---

## 2. gofiber/fiber

**Type**: Web Framework (Go)
**URL**: https://github.com/gofiber/fiber

### Key Patterns

- **Dark/light mode logos** (theme-aware branding)
- **Benchmark images** with TechEmpower comparison
- **Limitations section** (builds trust through transparency)
- **Feature list** with brief descriptions (12 items)

### Structure

```
Logo (themed)
Badges (6)
Tagline ("Express inspired...")
Installation (2 lines)
Quickstart (Hello World)
Zero Allocation
Benchmarks (images)
Features (list)
Philosophy
Limitations
Examples
```

### Takeaway

Benchmarks + limitations = credibility through transparency.

---

## 3. httpie/cli

**Type**: CLI Tool (HTTP Client)
**URL**: https://github.com/httpie/cli

### Key Patterns

- **Product family badges** (Desktop | Web & Mobile | CLI)
- **Hero GIF** immediately after header
- **Progressive examples** (basic -> headers -> advanced)
- **"We Lost 54k Stars"** section (radical transparency)

### Structure

```
Logo (centered)
Product badges
Status badges
Description
GIF Demo
Getting Started (just 2 links)
Features (9 bullets)
Examples (4 levels)
Community
Contributing
```

### Takeaway

Visual demo + progressive examples + transparency = trust + understanding.

---

## 4. release-it/release-it

**Type**: CLI Tool (Release Automation)
**URL**: https://github.com/release-it/release-it

### Key Patterns

- **Multi-path installation** (npm init, manual, containerized, global)
- **JSON Schema reference** for IDE autocomplete
- **Hook execution order** table
- **Heavy cross-referencing** with anchor links

### Structure

```
Logo + Badge
Feature list (7 bullets)
Badges
Sponsorship CTA
Installation (multiple methods)
Usage
Videos/Articles
Configuration (schema-driven)
Feature sections (CI, Git, npm, GitHub...)
Hooks
Plugins ecosystem
```

### Takeaway

Multiple entry points + schema-driven config = developer flexibility.

---

## 5. dbt-labs/dbt-core

**Type**: Data Tool
**URL**: https://github.com/dbt-labs/dbt-core

### Key Patterns

- **Analogy-driven positioning** ("same practices as software engineers")
- **Visual architecture** diagram before explanation
- **DAG visualization** showing model relationships
- **User-centric framing** ("Analysts can..." not "dbt allows...")

### Structure

```
Logo (centered, large)
Badges (CI, Best Practices)
Value proposition (one sentence)
Architecture diagram
Understanding dbt
DAG visualization
Getting started (2 bullets only)
Community (before contribution)
Reporting bugs
Code of Conduct
```

### Takeaway

Bridge analogy + visuals + minimal text = accessible complexity.

---

## 6. PostHog/posthog

**Type**: SaaS (Product Analytics)
**URL**: https://github.com/PostHog/posthog

### Key Patterns

- **Cloud-first positioning** (self-hosted as secondary)
- **Free tier prominence** with specific limits
- **Feature density** (11 features, one line each)
- **SDK matrix** table (Frontend | Mobile | Backend)

### Structure

```
Logo
Trust badges
Navigation bar
Video demo
Cloud signup (recommended)
Self-hosted option (with caveats)
Features (dense list)
SDK support matrix
Contributing
Hiring CTA
```

### Takeaway

Cloud-first + feature density + clear limitations = honest SaaS pitch.

---

## 7. ryanoasis/nerd-fonts

**Type**: Font Collection
**URL**: https://github.com/ryanoasis/nerd-fonts

### Key Patterns

- **Decision tree installation** ("If you want X, do Y")
- **Platform matrix** (macOS, Windows, Linux, universal)
- **67+ font table** organized by status
- **Sankey diagram** for glyph relationships

### Structure

```
Logo + Badges
Tagline
TL;DR
Installation (10 methods as decision tree)
Features
Glyph sets
Patched fonts table
Variations
Font patcher
Developer info
Motivation
License
```

### Takeaway

Decision tree + platform coverage = empowered user choice.

---

## 8. amitmerchant1990/electron-markdownify

**Type**: Desktop Application
**URL**: https://github.com/amitmerchant1990/electron-markdownify

### Key Patterns

- **Hero GIF** showing live preview in action
- **"Feature - Benefit"** format
- **Dual install paths** (developer vs end user)
- **Credits section** listing all dependencies

### Structure

```
Logo (centered)
Tagline (mentions Electron)
Badges
Navigation links
Hero GIF
Key Features (benefit-oriented)
How To Use (developer setup)
Download (end user)
Emailware
Credits
Related projects
Support/Donate
License
Author footer
```

### Takeaway

Hero GIF + dual paths + credits = professional desktop app presentation.

---

## 9. mkosir/react-parallax-tilt

**Type**: React Component
**URL**: https://github.com/mkosir/react-parallax-tilt

### Key Patterns

- **External Storybook demos** (not embedded)
- **Props table** with type/default/description
- **Feature-specific demo links** ("demo" badge per section)
- **No iframe embeds** (keeps README fast)

### Structure

```
GIF demo
Badges
Feature list (emoji markers)
Install
Quick Start (minimal)
Props table (detailed)
Feature sections with demo links
Development setup
```

### Takeaway

External demos + structured props = lightweight yet comprehensive.

---

## Pattern Frequency

| Pattern | Projects Using | Frequency |
|---------|----------------|-----------|
| Centered header | 7/9 | 78% |
| Hero GIF/image | 6/9 | 67% |
| Badges 3-6 | 9/9 | 100% |
| Quick start first screen | 8/9 | 89% |
| Feature list | 9/9 | 100% |
| Tables for reference | 7/9 | 78% |
| Progressive examples | 6/9 | 67% |
| External demo links | 4/9 | 44% |
| "Used by" section | 2/9 | 22% |
| Limitations section | 2/9 | 22% |
| Platform matrix | 3/9 | 33% |

---

## By Project Type

### CLI Tools (size-limit, httpie, release-it)

Common patterns:
- Multi-path installation
- Progressive CLI examples
- Configuration file formats
- CI/CD integration section

### Libraries/Components (fiber, react-parallax-tilt)

Common patterns:
- Props/API table
- Minimal -> Advanced examples
- TypeScript support highlighted
- External playground links

### Desktop Apps (electron-markdownify)

Common patterns:
- Hero GIF showing app
- Platform download matrix
- Developer + End user paths
- Credits section

### SaaS/Complex Tools (PostHog, dbt-core)

Common patterns:
- Cloud vs self-hosted split
- Architecture diagrams
- SDK/integration tables
- Community before code

### Collections (nerd-fonts)

Common patterns:
- Decision tree navigation
- Comprehensive tables
- Platform-specific instructions
- TL;DR section

---

## Banner Examples (measured 2026-10-02)

First README image of each repository, measured with Pillow. Rules drawn from these are in
`README_PATTERNS.md` `## Banner`.

| Repo | Style | Size (measured) | Theme handling |
|------|-------|-----------------|----------------|
| [withastro/astro](https://github.com/withastro/astro) | dark neon grain ring, white slogan | 2110x684 JPG (3.08:1), 160,975 bytes | one dark opaque image, no `<picture>` |
| [excalidraw/excalidraw](https://github.com/excalidraw/excalidraw) | hand-drawn wordmark, doodle shapes | 1280x336 PNG x2 (3.81:1) | `<picture>`: dark `<source>`, light `<img>` default |
| [tldraw/tldraw](https://github.com/tldraw/tldraw) | solid background | 2560x1280 PNG x2; light 42,384 bytes, dark 46,992 bytes | `<picture>`: dark `<source>`, light `<img>` default |
| [TanStack/table](https://github.com/TanStack/table) | generated by `tanstack.com/api/readme/table.png`, `?theme=dark` | 1800x450 PNG (4:1) shown at `width=900` (2x) | `<picture>` over the URL parameter |
| [PostHog/posthog](https://github.com/PostHog/posthog#readme) | cream background, flat hedgehog mascot | 2428x332 PNG (7.31:1), 30 KB | one |
| [n8n-io/n8n](https://github.com/n8n-io/n8n#readme) | colored node tiles on navy | 1584x396 (4:1), 88 KB | one |
| [charmbracelet/vhs](https://github.com/charmbracelet/vhs#readme) | pop: 3D cassette, sticker wordmark | 1085x638 PNG x2 | `#gh-*-mode-only` fragments |
| [oven-sh/bun](https://github.com/oven-sh/bun#readme) | pop: black-outline mascot | 412x347 PNG, 22 KB, `height=170` | one |

- Astro, Excalidraw, tldraw and TanStack Table rows were confirmed 3-0 in a three-vote cross-check.
- Of 107 repositories sampled, 29 open with a banner or hero image. The 26 banners at 2.5:1 or wider
  have a median width of 1,775 px and a median size of 88 KB; animated GIFs run 0.27-2.6 MB.
- Deno, Zed, Ghostty, Ollama, uv, ruff and Vite open with a logo or icon only, so they are not
  banner examples.
