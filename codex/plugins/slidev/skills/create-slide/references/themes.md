# Slidev Theme Reference

Slidev provides various official and community themes. Each theme has its own design system and layouts. Themes are automatically installed when you specify them in your frontmatter—no manual npm install needed.

## 1. apple-basic (Default Theme)

**Package:** `@slidev/theme-apple-basic` (official, v0.25.1)

A clean, minimal design inspired by Apple Keynote. This is Slidev's default theme.

### Installation

Slidev automatically installs themes when you specify them in your frontmatter. No manual npm install needed.

### Frontmatter Configuration

```yaml
---
theme: apple-basic
# Theme configuration is optional (this is the default theme, so you can omit it)
---
```

### Layouts

| Layout | Description | Props |
|--------|-------------|-------|
| `intro` | Title slide with subtitle and bottom metadata area | - |
| `intro-image` | Full-bleed background image with overlay text | `image` |
| `intro-image-right` | Split layout: text left, image right | `image` |
| `image-right` | Content with bullets left, image right | `image` |
| `default` | Standard title, subtitle, and bullet points | - |
| `bullets` | Bullet points only, no title | - |
| `section` | Section divider with large centered title | - |
| `statement` | Large centered text for emphasis | - |
| `fact` | Extra-large number/statistic with description | - |
| `quote` | Formatted quote with attribution | - |
| `3-images` | Three photos: one left, two stacked right | `imageLeft`, `imageTopRight`, `imageBottomRight` |
| `image` | Single full-screen, full-bleed image | `image` |
| `center` | Generic centered content utility layout | - |

### Custom Components

This theme does not include custom components (empty components directory).

### CSS Variables

- `--slidev-theme-primary` - Primary theme color
- `--prism-background` - Code block background

### Font Configuration

Default fonts: Helvetica Neue

```yaml
---
theme: apple-basic
fonts:
  sans: 'Helvetica Neue'
  serif: 'Georgia'
  mono: 'Menlo'
---
```

### Complete Example

```yaml
---
theme: apple-basic
title: Presentation Title
background: https://source.unsplash.com/collection/94734566/1920x1080
class: text-center
highlighter: shiki
lineNumbers: false
info: |
  ## Slidev Presentation
  Presentation description
drawings:
  persist: false
transition: slide-left
---
```

### Best Use Cases

- Clean and minimal presentations
- Business presentations
- Product introductions
- Technical talks
- General-purpose presentations

---

## 2. seriph

**Package:** `@slidev/theme-seriph` (official)

A classic and elegant design based on serif fonts. Provides an academic and professional feel with excellent readability for longer text content.

### Installation

Slidev automatically installs themes when specified in frontmatter.

### Frontmatter Configuration

```yaml
---
theme: seriph
background: https://source.unsplash.com/collection/94734566/1920x1080
class: text-center
highlighter: shiki
lineNumbers: false
info: |
  ## Academic Presentation
  Research presentation
drawings:
  persist: false
transition: slide-left
css: unocss
---
```

### Font Configuration

```yaml
---
theme: seriph
fonts:
  sans: 'Roboto'
  serif: 'Roboto Slab'
  mono: 'Fira Code'
---
```

### Key Features

- Serif font based design
- Classic and elegant aesthetics
- Excellent readability for long text
- Academic atmosphere
- Traditional presentation feel

### Best Use Cases

- Academic presentations
- Research paper presentations
- Formal lectures
- Official events
- Conference talks requiring gravitas

---

## 3. geist (Vercel Design System)

**Package:** `slidev-theme-geist` (community theme, v0.8.1)

A modern, clean theme inspired by the Vercel/Geist Design System. Developer-focused with dual theme support (dark/light) and custom syntax highlighting. Last updated February 2022, requires Slidev ≥0.20.

### Installation

Slidev automatically installs themes when specified in frontmatter.

### Frontmatter Configuration

```yaml
---
theme: geist
title: Web Development
titleTemplate: '%s - Slidev'
background: https://source.unsplash.com/collection/94734566/1920x1080
class: text-center
highlighter: shiki
lineNumbers: true
info: |
  ## Frontend Technology Talk
  Introduction to modern web technologies
drawings:
  persist: false
transition: slide-left
---
```

### Layouts

| Layout | Description |
|--------|-------------|
| `cover` | Full-height centered layout for title/hero slides. H1 gets text-6xl, paragraphs text-2xl |
| `split` | Two-column equal grid with gap-8 spacing |

### Custom Components

| Component | Description | Props |
|-----------|-------------|-------|
| `Button` | Interactive button with inverted hover colors | - |
| `KBD` | Keyboard shortcut display with macOS modifier symbols | `command`, `shift`, `option`, `control` (booleans) |
| `Note` | Callout/annotation box for highlighting important information | - |

### Key Features

- Dual theme support (dark/light modes)
- Modern typography with Inter font family
- Custom Shiki syntax highlighting
- Vercel/Geist Design System color palette
- Developer-centric design language

### Color System

- `--geist-error`: #e00
- `--geist-success`: #0070f3
- `--geist-warning`: #f5a623
- `--geist-violet`: #7928ca
- `--geist-cyan`
- `--geist-highlight-purple`: #f81ce5

### Font Configuration

Default fonts: Inter (sans), Fira Code (mono)

```yaml
---
theme: geist
fonts:
  sans: 'Inter'
  mono: 'Fira Code'
---
```

### Best Use Cases

- Frontend/backend technology talks
- Web development workshops
- Developer conferences
- Product demos (tech-focused)
- Modern tech presentations
- API documentation walkthroughs

---

## 4. purplin

**Package:** `slidev-theme-purplin` (community theme)

An energetic modern theme featuring vibrant purple gradients and contemporary design elements.

### Installation

Slidev automatically installs themes when specified in frontmatter.

### Frontmatter Configuration

```yaml
---
theme: purplin
title: Product Launch
background: https://source.unsplash.com/collection/94734566/1920x1080
class: text-center
highlighter: shiki
lineNumbers: false
info: |
  ## New Product Announcement
  Introducing innovative products
drawings:
  persist: false
transition: slide-left
---
```

### Key Features

- Purple gradient color scheme
- Energetic and vibrant design
- Modern and trendy aesthetic
- Visually striking presentation style
- High visual impact

### Font Configuration

```yaml
---
theme: purplin
fonts:
  sans: 'Poppins'
  mono: 'Fira Code'
---
```

### Best Use Cases

- Product demos and launches
- Startup pitches
- Marketing presentations
- Creative presentations
- Brand announcements
- High-energy talks

---

## 5. academic

**Package:** `slidev-theme-academic` (community theme, v2.1.0)

Academic paper-style layouts with comprehensive citation support, footnotes, and figure management. Designed for formal research presentations following academic standards.

### Installation

Slidev automatically installs themes when specified in frontmatter.

### Frontmatter Configuration

```yaml
---
theme: academic
title: Research Paper Presentation
themeConfig:
  paginationX: 'r'
  paginationY: 't'
  paginationPagesDisabled: [1, 2]
background: https://source.unsplash.com/collection/94734566/1920x1080
class: text-center
highlighter: shiki
lineNumbers: false
info: |
  ## Academic Research Presentation
  Research topic and methodology
bibliography: ./references.bib
drawings:
  persist: false
transition: slide-left
---
```

### Layouts

| Layout | Description | Props |
|--------|-------------|-------|
| `cover` | Title slide with author, date, optional background | `coverAuthor`, `coverAuthorUrl`, `coverBackgroundUrl`, `coverBackgroundSource`, `coverBackgroundSourceUrl`, `coverDate` |
| `intro` | Simple centered content for section introductions | - |
| `table-of-contents` | Auto-generated table of contents (slides with `hideInToc: true` excluded) | - |
| `index` | General-purpose list for figures, references, tables | `indexEntries` (array of `{title, uri}`), `indexRedirectType` ('internal'/'external') |
| `figure` | Full-width image with caption and footnote support | `figureUrl` (required), `figureCaption`, `figureFootnoteNumber` |
| `figure-side` | Image positioned left or right with text content | `figureUrl` (required), `figureCaption`, `figureFootnoteNumber`, `figureX` ('l'/'r', default 'r') |

### Custom Components

| Component | Description | Props |
|-----------|-------------|-------|
| `Footnotes` | Container for footnotes at slide bottom | `filled`, `separator`, `x` ('l'/'r'), `y` ('col'/'row') |
| `Footnote` | Individual footnote entry | `number` |
| `Pagination` | Page numbering with flexible positioning | `classNames`, `x` ('l'/'r'), `y` ('b'/'t') |
| `FigureWithOptionalCaption` | Internal figure rendering component | - |
| `TextWithOptionalLink` | Internal link handling component | - |

### Theme Configuration

```yaml
themeConfig:
  paginationX: 'r'              # Pagination horizontal position: 'l' (left) or 'r' (right)
  paginationY: 't'              # Pagination vertical position: 'b' (bottom) or 't' (top)
  paginationPagesDisabled: [1, 2]  # Pages to hide pagination on (e.g., title and TOC slides)
```

### Key Features

- Academic paper-style layouts
- Citation and reference management
- BibTeX integration support
- Compliance with academic presentation standards
- Comprehensive footnote system
- Figure and table indexing
- Professional pagination control

### Font Configuration

```yaml
---
theme: academic
fonts:
  sans: 'Crimson Text'
  serif: 'Crimson Text'
  mono: 'Inconsolata'
---
```

### Best Use Cases

- Academic paper presentations
- Thesis and dissertation defenses
- Conference presentations
- Research seminars
- Grant proposal presentations
- Scientific symposiums

---

## 6. bricks

**Package:** `slidev-theme-bricks` (community theme)

A block-based structural design with clear hierarchical organization, ideal for architecture diagrams and system design presentations.

### Installation

Slidev automatically installs themes when specified in frontmatter.

### Frontmatter Configuration

```yaml
---
theme: bricks
title: System Architecture
background: https://source.unsplash.com/collection/94734566/1920x1080
class: text-center
highlighter: shiki
lineNumbers: true
info: |
  ## System Design
  Microservices architecture
drawings:
  persist: false
transition: slide-left
---
```

### Key Features

- Block and module-based layout system
- Structural and hierarchical design
- Diagram-friendly interface
- Clear visual dividing lines
- Modular content organization

### Font Configuration

```yaml
---
theme: bricks
fonts:
  sans: 'IBM Plex Sans'
  mono: 'IBM Plex Mono'
---
```

### Best Use Cases

- System architecture presentations
- Infrastructure structure explanations
- Modular design presentations
- Technology stack introductions
- Component relationship diagrams
- Enterprise architecture talks

---

## Theme Switching Guide

### How to Change Themes

Simply modify the `theme` field in your frontmatter. Slidev will automatically install the theme when you start the dev server or build.

```yaml
---
theme: seriph  # Changed from apple-basic to seriph
---
```

### Theme Naming Convention

You can omit the prefix from package names when specifying themes:

| Package Name | Used in Frontmatter |
|--------------|---------------------|
| `@slidev/theme-apple-basic` | `apple-basic` |
| `@slidev/theme-seriph` | `seriph` |
| `slidev-theme-geist` | `geist` |
| `slidev-theme-purplin` | `purplin` |
| `slidev-theme-academic` | `academic` |
| `slidev-theme-bricks` | `bricks` |

In other words, `@slidev/theme-` or `slidev-theme-` prefixes are automatically handled by Slidev.

### Local Theme Support

You can create custom themes inside your project for complete control:

```yaml
---
theme: ./themes/my-theme
---
```

Directory structure:

```
project/
├── slides.md
└── themes/
    └── my-theme/
        ├── styles/
        │   └── index.css
        ├── layouts/
        │   ├── default.vue
        │   └── cover.vue
        └── package.json
```

### Recommended Usage Scenarios by Theme

| Theme | Usage Scenario | Characteristics |
|-------|----------------|-----------------|
| `apple-basic` | General-purpose presentations | Minimal, clean, versatile, professional |
| `seriph` | Academic and formal presentations | Elegant, readable, trustworthy, traditional |
| `geist` | Developer conferences and tech talks | Modern, clean, code-focused, developer-centric |
| `purplin` | Product demos and startup pitches | Energetic, vibrant, visual impact, contemporary |
| `academic` | Research and scientific presentations | Academic standards, citations, footnotes, formal |
| `bricks` | System design and architecture | Structural, hierarchical, clear, organized |

### Theme Compatibility

All themes support Slidev's core features, but some layouts and components may differ by theme. When changing themes:

1. **Basic layouts** (`default`, `cover`, `intro`) work in all themes
2. **Theme-specific layouts** require consulting that theme's documentation
3. **Custom CSS** may need adjustment after theme changes
4. **Components** are theme-specific and may not transfer between themes

### Multi-Theme Projects

You can create multiple theme versions of the same content:

```bash
# Build with different themes
slidev build slides.md --theme seriph -o dist/seriph
slidev build slides.md --theme geist -o dist/geist
```

Or use separate configuration files:

```yaml
# slides-seriph.md
---
theme: seriph
---

# Content...
```

```yaml
# slides-geist.md
---
theme: geist
---

# Content...
```

### Theme Selection Tips

1. **Match your audience**: Academic themes for researchers, modern themes for developers
2. **Consider content type**: Code-heavy presentations benefit from developer-focused themes
3. **Brand alignment**: Choose colors and styles that match your organization
4. **Test compatibility**: Preview your content with different themes to find the best fit
5. **Performance**: Simpler themes (apple-basic, seriph) generally load faster
