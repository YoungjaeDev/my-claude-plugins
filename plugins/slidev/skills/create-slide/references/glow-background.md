# Glow Background System

> **Rich visual level only.** Minimal 레벨에서는 이 파일의 glow 관련 내용을 사용하지 않는다.

nekomeowww의 KubeCon HK 2024 발표 패턴을 기반으로 한 seeded random polygon gradient 배경 시스템이다. 슬라이드마다 고유한 ambient glow가 부드럽게 전환되며, `seedrandom` npm 의존성이 필요하다.

Credits: `@pi0`, `@Atinux` (Nuxt team) 원작 패턴.

---

## Installation

```bash
npm add -D seedrandom
```

TypeScript 타입 지원을 위해 별도 설치가 필요할 수 있다:

```bash
npm add -D @types/seedrandom
```

---

## Full `global-bottom.vue` Code

프로젝트 루트에 `global-bottom.vue` 파일을 생성한다. Slidev는 이 파일을 모든 슬라이드 아래 레이어로 자동 주입한다.

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

슬라이드별 frontmatter로 glow 동작을 세밀하게 제어한다.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `glowSeed` | number | slide number | polygon shape를 결정하는 random seed. 같은 seed는 항상 같은 모양 |
| `glow` | string | `full` | glow 분포 힌트: `bottom`, `right`, `top`, `left`, `full` |
| `glowOpacity` | number | `0.12` | glow 레이어 투명도 (0~1). 커버 슬라이드에서 높이면 임팩트 증가 |
| `glowHue` | number | `0` | 추가 hue-rotate (도 단위). 발표 섹션별 색조 변화에 활용 |

### Example frontmatter

기본 콘텐츠 슬라이드:
```yaml
---
class: py-10
glowSeed: 368
glow: bottom
---
```

커버 슬라이드 (glow 강조):
```yaml
---
layout: center
glowSeed: 228
glowOpacity: 0.18
---
```

섹션 전환 슬라이드 (hue 변화):
```yaml
---
layout: center
glowSeed: 120
glowHue: 45
---
```

Global headmatter에서 기본 seed 설정:
```yaml
glowSeed: 228
```

---

## Required CSS

`slides.md`의 scoped style 블록 또는 별도 `style.css`에 반드시 추가해야 한다. 이 CSS가 없으면 슬라이드 기본 배경이 glow를 완전히 가린다.

```css
/* Dark mode에서 slide 배경을 투명하게 만들어 glow가 보이도록 */
.dark #slide-content {
  background-color: black !important;
}
```

`slides.md` 하단에 추가하는 방법:

```md
<style>
.dark #slide-content {
  background-color: black !important;
}
</style>
```

`colorSchema: dark`를 headmatter에 설정하면 항상 dark mode로 렌더링되므로 위 CSS가 항상 적용된다.

---

## Customizing Colors

세 레이어의 gradient 색상을 발표 테마에 맞게 변경한다. AI 클리셰 색상 조합 (보라-초록, 과도한 네온)은 피한다.

**기본값 (KubeCon 패턴):**
- Layer 1: blue `#3b82f6` → `#1a67ed`
- Layer 2: magenta `#d02ebf` → `#ed0ed6`
- Layer 3: pastel `#feaffd` → `#aaf7ff` → `#fbbf24`

**Green-themed 발표 (예: 환경/지속가능성 주제):**
```css
.glow-1 { background: linear-gradient(135deg, #10b981 0%, #059669 100%); }
.glow-2 { background: linear-gradient(225deg, #34d399 0%, #6ee7b7 100%); }
.glow-3 { background: linear-gradient(315deg, #a7f3d0 0%, #67e8f9 50%, #fbbf24 100%); }
```

**Orange/amber-themed 발표 (예: 경고/보안 주제):**
```css
.glow-1 { background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); }
.glow-2 { background: linear-gradient(225deg, #ef4444 0%, #dc2626 100%); }
.glow-3 { background: linear-gradient(315deg, #fde68a 0%, #fca5a5 50%, #c4b5fd 100%); }
```

**Indigo/violet-themed 발표 (예: AI/ML 주제):**
```css
.glow-1 { background: linear-gradient(135deg, #6366f1 0%, #4f46e5 100%); }
.glow-2 { background: linear-gradient(225deg, #8b5cf6 0%, #7c3aed 100%); }
.glow-3 { background: linear-gradient(315deg, #c4b5fd 0%, #a5b4fc 50%, #67e8f9 100%); }
```

색상 선택 원칙:
- Layer 1, 2는 발표의 주/보조 accent color 사용
- Layer 3은 pastel 계열로 자연스러운 혼합 효과 생성
- 세 레이어가 겹칠 때 어색하지 않은 색상 조합 선택

---

## Position Hints Implementation

`glow: bottom` 같은 position hint는 `generatePolygon` 함수의 `positionBias` 파라미터로 구현된다. bias가 적용되면 해당 방향으로 polygon point 분포가 치우친다.

| `glow` 값 | 효과 |
|-----------|------|
| `full` | 전체 슬라이드에 균등 분포 (기본값) |
| `bottom` | 하단에 glow 집중. 다음 섹션 예고 느낌 |
| `top` | 상단 집중. 헤더 강조 효과 |
| `right` | 우측 집중. 두 컬럼 레이아웃에서 이미지 쪽 강조 |
| `left` | 좌측 집중 |

실제 사용 예 (nekomeowww KubeCon 패턴):
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

Minimal 레벨에서 `global-bottom.vue`는 glow 없이 페이지 번호만 표시한다:

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

`seedrandom` 의존성 설치 불필요.

---

## Quick Reference: CSS Values

glow 시스템의 핵심 CSS 수치 (spec 기준, 임의 변경 금지):

| Property | Value | 이유 |
|----------|-------|------|
| `filter: blur(...)` | `70px` | 경계가 보이지 않도록 충분히 흐리게 |
| `transition: clip-path` | `2.5s ease` | 슬라이드 전환 시 자연스러운 polygon 변화 |
| `transition: opacity` | `2.5s ease` | clip-path와 동기화 |
| `inset` on `.glow` | `-50%` | blur 처리 후에도 화면 가장자리까지 채우도록 |
| `glowOpacity` default | `0.12` | 콘텐츠 가독성 방해 없이 subtle하게 |
| Layer 3 opacity multiplier | `1.5x` | pastel 레이어가 너무 약하게 보이는 것 방지 |
