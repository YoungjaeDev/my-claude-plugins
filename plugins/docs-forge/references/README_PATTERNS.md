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

```
After: Header + navigation links
Before: Features section
```

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
