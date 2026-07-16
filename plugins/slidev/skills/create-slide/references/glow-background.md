# Glow Background System

> **Rich visual level only.** The Minimal level does not use any of the glow content in this file.

A seeded-random polygon gradient background system based on nekomeowww's KubeCon HK 2024 presentation pattern. Each slide gets a unique ambient glow that transitions smoothly, and it requires the `seedrandom` npm dependency.

Credits: original pattern by `@pi0`, `@Atinux` (Nuxt team).

---

## Installation

```bash
npm add -D seedrandom
```

TypeScript type support may need a separate install:

```bash
npm add -D @types/seedrandom
```

---

## Full `global-bottom.vue` Code

Create a `global-bottom.vue` file at the project root. Slidev automatically injects this file as a layer beneath every slide.

```vue
<script setup lang="ts">
import { computed } from 'vue'
import seedrandom from 'seedrandom'

const currentPage = computed(() => $slidev?.nav?.currentPage ?? 1)
const frontmatter = computed(() => $slidev?.nav?.currentSlideRoute?.meta?.slide?.frontmatter ?? {})

const glowSeed = computed(() => frontmatter.value.glowSeed ?? currentPage.value)
const glowOpacity = computed(() => frontmatter.value.glowOpacity ?? 0.12)
const glowHue = computed(() => frontmatter.value.glowHue ?? 0)
const glowPosition = computed(() => frontmatter.value.glow ?? 'full')

// Generate seeded random polygon points
// seed offset differentiates the three layers so they don't overlap identically
function generatePolygon(seed: number | string, pointCount: number, positionBias?: string): string {
  const rng = seedrandom(String(seed))
  const points: string[] = []

  for (let i = 0; i < pointCount; i++) {
    let x = Math.floor(rng() * 120) - 10  // -10% to 110% (bleed beyond edges)
    let y = Math.floor(rng() * 120) - 10

    // Apply position bias to concentrate the glow in a region
    if (positionBias === 'bottom') y = Math.floor(rng() * 60) + 40
    else if (positionBias === 'top') y = Math.floor(rng() * 60) - 10
    else if (positionBias === 'right') x = Math.floor(rng() * 60) + 40
    else if (positionBias === 'left') x = Math.floor(rng() * 60) - 10

    points.push(`${x}% ${y}%`)
  }

  return `polygon(${points.join(', ')})`
}

const polygon1 = computed(() => generatePolygon(glowSeed.value, 10, glowPosition.value))
const polygon2 = computed(() => generatePolygon(Number(glowSeed.value) + 1, 6, glowPosition.value))
const polygon3 = computed(() => generatePolygon(Number(glowSeed.value) + 2, 3, glowPosition.value))
</script>

<template>
  <!-- Glow polygon background (Rich visual level) -->
  <div class="glow-container" :style="{ '--glow-opacity': glowOpacity, '--glow-hue': `${glowHue}deg` }">
    <div class="glow glow-1" :style="{ clipPath: polygon1 }" />
    <div class="glow glow-2" :style="{ clipPath: polygon2 }" />
    <div class="glow glow-3" :style="{ clipPath: polygon3 }" />
  </div>

  <!-- Page number footer: hidden on cover slide (page 1) -->
  <footer v-if="currentPage > 1" class="slide-footer">
    <span>{{ $slidev.configs.author }}</span>
    <span>{{ $nav.currentPage }} / {{ $nav.total }}</span>
  </footer>
</template>

<style scoped>
.glow-container {
  position: fixed;
  inset: 0;
  pointer-events: none;
  z-index: -1;
  overflow: hidden;
  filter: blur(70px) hue-rotate(var(--glow-hue, 0deg));
}

.glow {
  position: absolute;
  inset: -50%;
  opacity: var(--glow-opacity, 0.12);
  transition: clip-path 2.5s ease, opacity 2.5s ease;
}

/* Layer 1: Primary accent - blue */
.glow-1 {
  background: linear-gradient(135deg, #3b82f6 0%, #1a67ed 100%);
}

/* Layer 2: Secondary accent - magenta */
.glow-2 {
  background: linear-gradient(225deg, #d02ebf 0%, #ed0ed6 100%);
}

/* Layer 3: Tertiary pastel mix */
.glow-3 {
  background: linear-gradient(315deg, #feaffd 0%, #aaf7ff 50%, #fbbf24 100%);
  opacity: calc(var(--glow-opacity, 0.12) * 1.5);  /* slightly more visible */
}

.slide-footer {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 12px 24px;
  display: flex;
  justify-content: space-between;
  font-size: 0.75rem;
  opacity: 0.5;
  pointer-events: none;
  z-index: 10;
}
</style>
```

---

## Per-Slide Frontmatter Control

Control the glow behavior finely with per-slide frontmatter.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `glowSeed` | number | slide number | the random seed that determines the polygon shape. The same seed always gives the same shape |
| `glow` | string | `full` | glow distribution hint: `bottom`, `right`, `top`, `left`, `full` |
| `glowOpacity` | number | `0.12` | glow layer opacity (0-1). Raising it on the cover slide increases impact |
| `glowHue` | number | `0` | extra hue-rotate (in degrees). Use it to shift the tone per presentation section |

### Example frontmatter

Basic content slide:
```yaml
---
class: py-10
glowSeed: 368
glow: bottom
---
```

Cover slide (glow emphasis):
```yaml
---
layout: center
glowSeed: 228
glowOpacity: 0.18
---
```

Section-transition slide (hue change):
```yaml
---
layout: center
glowSeed: 120
glowHue: 45
---
```

Set the default seed in the global headmatter:
```yaml
glowSeed: 228
```

---

## Required CSS

This must be added to the scoped style block of `slides.md` or a separate `style.css`. Without this CSS, the slide's default background hides the glow entirely.

```css
/* In dark mode, make the slide background transparent so the glow shows through */
.dark #slide-content {
  background-color: transparent !important;
}
```

How to add it at the bottom of `slides.md`:

```md
<style>
.dark #slide-content {
  background-color: transparent !important;
}
</style>
```

Setting `colorSchema: dark` in the headmatter always renders in dark mode, so the CSS above always applies.

---

## Customizing Colors

Change the three layers' gradient colors to match the presentation theme. Avoid AI-cliche color combinations (purple-green, excessive neon).

**Default (KubeCon pattern):**
- Layer 1: blue `#3b82f6` → `#1a67ed`
- Layer 2: magenta `#d02ebf` → `#ed0ed6`
- Layer 3: pastel `#feaffd` → `#aaf7ff` → `#fbbf24`

**Green-themed presentation (e.g. environment/sustainability topics):**
```css
.glow-1 { background: linear-gradient(135deg, #10b981 0%, #059669 100%); }
.glow-2 { background: linear-gradient(225deg, #34d399 0%, #6ee7b7 100%); }
.glow-3 { background: linear-gradient(315deg, #a7f3d0 0%, #67e8f9 50%, #fbbf24 100%); }
```

**Orange/amber-themed presentation (e.g. warning/security topics):**
```css
.glow-1 { background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); }
.glow-2 { background: linear-gradient(225deg, #ef4444 0%, #dc2626 100%); }
.glow-3 { background: linear-gradient(315deg, #fde68a 0%, #fca5a5 50%, #c4b5fd 100%); }
```

**Indigo/violet-themed presentation (e.g. AI/ML topics):**
```css
.glow-1 { background: linear-gradient(135deg, #6366f1 0%, #4f46e5 100%); }
.glow-2 { background: linear-gradient(225deg, #8b5cf6 0%, #7c3aed 100%); }
.glow-3 { background: linear-gradient(315deg, #c4b5fd 0%, #a5b4fc 50%, #67e8f9 100%); }
```

Color-selection principles:
- Layers 1 and 2 use the presentation's primary/secondary accent colors
- Layer 3 uses a pastel family to create a natural blending effect
- Choose a color combination that is not jarring when the three layers overlap

---

## Position Hints Implementation

A position hint like `glow: bottom` is implemented via the `positionBias` parameter of the `generatePolygon` function. When bias is applied, the polygon point distribution skews toward that direction.

| `glow` value | Effect |
|-----------|------|
| `full` | even distribution across the whole slide (default) |
| `bottom` | glow concentrated at the bottom. A "teasing the next section" feel |
| `top` | concentrated at the top. A header-emphasis effect |
| `right` | concentrated on the right. Emphasizes the image side in a two-column layout |
| `left` | concentrated on the left |

Real usage examples (nekomeowww KubeCon pattern):
```yaml
---
class: py-10
glow: bottom
glowSeed: 368
---
```

```yaml
---
class: py-10
glow: right
glowSeed: 205
---
```

---

## Minimal Alternative

At the Minimal level, `global-bottom.vue` shows only the page number, without glow:

```vue
<script setup lang="ts">
import { computed } from 'vue'

const currentPage = computed(() => $slidev?.nav?.currentPage ?? 1)
</script>

<template>
  <footer v-if="currentPage > 1" class="slide-footer">
    <span>{{ $slidev.configs.author }}</span>
    <span>{{ $nav.currentPage }} / {{ $nav.total }}</span>
  </footer>
</template>

<style scoped>
.slide-footer {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 12px 24px;
  display: flex;
  justify-content: space-between;
  font-size: 0.75rem;
  opacity: 0.5;
  pointer-events: none;
  z-index: 10;
}
</style>
```

No need to install the `seedrandom` dependency.

---

## Quick Reference: CSS Values

The core CSS values of the glow system (per spec — do not change arbitrarily):

| Property | Value | Reason |
|----------|-------|------|
| `filter: blur(...)` | `70px` | blurry enough that no boundary is visible |
| `transition: clip-path` | `2.5s ease` | a natural polygon change on slide transition |
| `transition: opacity` | `2.5s ease` | synchronized with clip-path |
| `inset` on `.glow` | `-50%` | fill to the screen edges even after blur |
| `glowOpacity` default | `0.12` | subtle, without hurting content readability |
| Layer 3 opacity multiplier | `1.5x` | prevents the pastel layer from looking too weak |
