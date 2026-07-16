# Visual Patterns Reference

> **Applicability:**
> - **Minimal**: Glassmorphism Effect (Section 5), Absolute Position Decorative Elements (Section 8), Scoped CSS basics (Section 9 - footnote, v-click blur)
> - **Rich**: All patterns. Requires `css: unocss` headmatter and `presetAttributify()` in `uno.config.ts`. All code examples use attributify syntax (no `class=""` wrapping).

---

## 1. Glassmorphism Card Pattern (Core)

The fundamental card formula from BaizeAI/nekomeowww KubeCon presentations. Used 30+ times per deck.

```html
<div border="2 solid {color}-800" bg="{color}-800/20" rounded-lg overflow-hidden>
  <div bg="{color}-800/40" px-4 py-2 flex items-center>
    <div i-carbon:xxx text-{color}-300 text-xl mr-2 />
    <span font-bold>Card Title</span>
  </div>
  <div px-4 py-3>
    <!-- Content -->
  </div>
</div>
```

**Formula breakdown:**
- Outer: `border="2 solid {color}-800"` + `bg="{color}-800/20"` + `rounded-lg overflow-hidden`
- Header bar: `bg="{color}-800/40"` (slightly more opaque than body) + `flex items-center`
- Body: `px-4 py-3` for consistent padding

---

## 2. Color Semantics System

Consistent color meaning applied throughout entire presentations. Never mix semantics within a deck.

| Color | Meaning | Context |
|-------|---------|---------|
| `white` | Neutral/info | General information cards (`white/5` for glassmorphism) |
| `red` | Problems/warnings | Before, downsides, risks, traditional approaches |
| `green` | Solutions/benefits | After, advantages, solutions |
| `blue` | Technical/architecture | System structure, tech details |
| `purple` | Code/compiler | Code-related topics |
| `yellow` | Caution/"reality" | Caveats, tradeoffs, warnings |
| `cyan` | Container/infra | Docker, cloud infrastructure |
| `sky` | Cloud/Kubernetes | Kubernetes, cloud services |
| `indigo` | Advanced features | Advanced features, infrastructure |
| `lime` | Positive alternatives | Green variants when green is taken |
| `pink` | Persistence/data | Data, storage topics |

---

## 3. Before/After Comparison Pattern

Red vs Green 2-column grid. The primary pattern for showing problem-to-solution transitions.

```html
<div grid grid-cols-2 gap-6>
  <!-- Before card (red = problem) -->
  <div v-click border="2 solid red-800" bg="red-800/20" rounded-lg overflow-hidden>
    <div bg="red-800/40" px-4 py-2 flex items-center>
      <div i-carbon:warning-alt text-red-300 text-xl mr-2 />
      <span font-bold>Before</span>
    </div>
    <div px-4 py-3>
      <!-- problems, downsides, traditional approach -->
    </div>
  </div>
  <!-- After card (green = solution) -->
  <div v-click border="2 solid green-800" bg="green-800/20" rounded-lg overflow-hidden>
    <div bg="green-800/40" px-4 py-2 flex items-center>
      <div i-carbon:checkmark-filled text-green-300 text-xl mr-2 />
      <span font-bold>After</span>
    </div>
    <div px-4 py-3>
      <!-- solutions, benefits, new approach -->
    </div>
  </div>
</div>
```

---

## 4. 3-Column Feature Grid

For challenges, features, or team cards. Wrap with `<v-clicks>` for sequential reveal.

```html
<div grid grid-cols-3 gap-4>
  <div v-click border="2 solid blue-800" bg="blue-800/20" rounded-lg overflow-hidden>
    <div bg="blue-800/40" px-4 py-2 flex items-center>
      <div i-carbon:cube text-blue-300 text-xl mr-2 />
      <span font-bold>Feature 1</span>
    </div>
    <div px-4 py-3>
      <!-- content -->
    </div>
  </div>
  <div v-click border="2 solid blue-800" bg="blue-800/20" rounded-lg overflow-hidden>
    <div bg="blue-800/40" px-4 py-2 flex items-center>
      <div i-carbon:chip text-blue-300 text-xl mr-2 />
      <span font-bold>Feature 2</span>
    </div>
    <div px-4 py-3>
      <!-- content -->
    </div>
  </div>
  <div v-click border="2 solid blue-800" bg="blue-800/20" rounded-lg overflow-hidden>
    <div bg="blue-800/40" px-4 py-2 flex items-center>
      <div i-carbon:arrow-right text-blue-300 text-xl mr-2 />
      <span font-bold>Feature 3</span>
    </div>
    <div px-4 py-3>
      <!-- content -->
    </div>
  </div>
</div>
```

Alternative: wrap all cards with `<v-clicks>` instead of individual `v-click`:

```html
<div grid grid-cols-3 gap-4 h-75>
<v-clicks>
  <div border="2 solid blue-800" bg="blue-800/20" rounded-lg overflow-hidden h-full>
    <!-- card -->
  </div>
  <div border="2 solid blue-800" bg="blue-800/20" rounded-lg overflow-hidden h-full>
    <!-- card -->
  </div>
  <div border="2 solid blue-800" bg="blue-800/20" rounded-lg overflow-hidden h-full>
    <!-- card -->
  </div>
</v-clicks>
</div>
```

---

## 5. Glassmorphism Effect (Dark Mode)

Simpler neutral card without color semantics. Used for challenge/info cards where no semantic color is needed.

```html
<div border="2 solid white/5" rounded-lg overflow-hidden bg="white/5" backdrop-blur-sm>
  <div flex items-center bg="white/10" backdrop-blur px-3 py-2>
    <div i-carbon:warning-alt text-amber-300 text-sm mr-2 />
    <div font-semibold>Card Title</div>
  </div>
  <div px-4 py-3>
    <div flex flex-col gap-3>
      <div>
        <div text-sm font-medium>Main point</div>
        <div text-xs opacity-70>Supporting detail</div>
      </div>
    </div>
  </div>
</div>
```

**Note:** Requires dark background (`colorSchema: dark` + `.dark #slide-content { background-color: transparent !important; }` in CSS) to be visible.

---

## 6. Code + Explanation Split Pattern

2-column layout: code block left, explanation points right. Ideal for showing "what the code does."

```html
<div grid grid-cols-2 gap-6>
  <div>
    ```python {all|1-3|5-8}
    # code here with line highlighting
    def example():
        pass
    ```
  </div>
  <div flex flex-col justify-center gap-3>
    <div v-click flex items-center gap-2>
      <div i-carbon:arrow-right text-green-400 />
      <span>Explanation point 1</span>
    </div>
    <div v-click flex items-center gap-2>
      <div i-carbon:arrow-right text-green-400 />
      <span>Explanation point 2</span>
    </div>
    <div v-click flex items-center gap-2>
      <div i-carbon:arrow-right text-green-400 />
      <span>Explanation point 3</span>
    </div>
  </div>
</div>
```

---

## 7. Skeleton Wireframe Pattern

Empty styled divs simulating a document or UI. Used to visualize "before" states or placeholder concepts without real screenshots.

```html
<div bg="gray-500/50" px-3 py-2 rounded w-full>
  <!-- Simulated title bar -->
  <div bg="gray-500/50" mb-2 mt-4 p-2 rounded w-50></div>
  <!-- Simulated content rows -->
  <div bg="gray-500/50" mb-2 rounded p-2 w-full></div>
  <div bg="gray-500/50" mb-2 rounded p-2 w-full></div>
  <!-- Simulated shorter row -->
  <div bg="gray-500/50" mb-2 rounded p-2 w-70></div>
</div>
```

Vary `w-{value}` to simulate natural text length variation. Use `opacity-50` on some rows for hierarchy.

---

## 8. Absolute Position Decorative Elements

Conference logos, QR codes, and result images positioned absolutely to avoid disrupting flow.

```html
<!-- Conference logo: bottom-right corner -->
<div w-full absolute bottom-0 left-0 flex items-center transform="translate-x--10 translate-y--10">
  <div w-full flex items-center justify-end gap-4>
    <img src="/KubeCon.svg" h-20 translate-y-4>
  </div>
</div>

<!-- Logo watermark: top-right -->
<img src="/logo.png" class="absolute top-4 right-4 w-12 opacity-50" />

<!-- QR code: bottom-right -->
<img src="/qr.png" class="absolute bottom-8 right-8 w-32" />

<!-- Result screenshot: positioned in slide -->
<img src="/result.png" class="absolute right-4 top-1/2 -translate-y-1/2 w-80 rounded-lg" />
```

---

## 9. Scoped CSS Patterns

Place in the slide's `<style scoped>` block or in a global `style.css`.

### v-click Blur Reveal (recommended for all Rich presentations)

```css
.slidev-vclick-target {
  transition: opacity 500ms ease, filter 200ms ease, color 300ms ease;
}

.slidev-vclick-hidden {
  opacity: 0;
  pointer-events: none;
  filter: blur(3px);
}
```

### Fade-Out Transition with Blur (pairs with `transition: fade-out` headmatter)

```css
.fade-out-leave-active {
  transition: opacity calc(var(--slidev-transition-duration) * 0.6) ease-out, filter 200ms ease;
}

.fade-out-enter-active {
  transition: opacity calc(var(--slidev-transition-duration) * 0.8) ease-in, filter 200ms ease;
  transition-delay: calc(var(--slidev-transition-duration) * 0.6);
}

.fade-out-enter-from,
.fade-out-leave-to {
  opacity: 0;
  filter: blur(5px);
}
```

### Code Block Glassmorphism

```css
:root {
  --slidev-code-padding: 8px 10px;
  --slidev-code-background: #16161690 !important;
}

.slidev-code {
  backdrop-filter: blur(10px);
  border: 1px solid #eee1;
}

.slidev-code .line {
  transition: opacity 200ms ease;
}
```

### Footnote Styling

```css
.footnotes-sep { display: none; }

.footnotes > .footnotes-list {
  margin-top: 12px;
  opacity: 0.9;
  font-size: 12px;
  font-family: sans-serif; /* prevents emoji font override on backlink arrows */
}
```

### Dark Mode Background Override (required for glow background)

```css
.dark #slide-content {
  background-color: transparent !important;
}
```

### v-mark Scale Correction (for `v-mark` rough annotations)

```css
.rough-annotation > path[stroke-width='2'] {
  stroke-width: calc(2px * var(--slidev-slide-scale));
}
```

---

## 10. Color Usage Guidelines

Derived from BaizeAI/nekomeowww Anti-AI design rules. Follow these to avoid AI-generated visual cliches.

### Card and UI Elements

```
bg="{color}-800/20"          /* card body: low opacity */
border="2 solid {color}-800" /* card border: full color */
bg="{color}-800/40"          /* card header bar: mid opacity */
text-{color}-300             /* icon and accent text in dark mode */
```

### Text Hierarchy

```
opacity-70    /* secondary body text */
opacity-50    /* tertiary/muted text */
text-zinc-300 /* neutral text - lightest */
text-zinc-400 /* neutral text - medium */
text-zinc-500 /* neutral text - darkest */
text-neutral-200 through text-neutral-700  /* layered hierarchy */
```

### Brand Colors (use official hex values, not Tailwind approximations)

```html
<span text="[#5791f7]">Kubernetes</span>
<span text="[#f6432f]">PyTorch</span>
<span text="[#ff6f00]">TensorFlow</span>
<span text="[#2496ED]">Docker</span>
<span text="[#326CE5]">K8s</span>
<span text="[#f97248]">Prometheus</span>
<span text="[#667fe3]">OpenTelemetry</span>
```

### Forbidden Patterns (Anti-AI rules)

| Forbidden | Why |
|-----------|-----|
| `from-purple-500 to-green-400` gradients | AI cliche |
| `#ff00ff`, `#00ffff` neon combinations | Oversaturated |
| Accent bars (top/bottom decorative bars) | AI cliche |
| Full-background gradients | Reserve for text only |
| 5+ colors on one slide | Incoherent palette |
| Direct neon glow on elements | Use blur(70px) polygon system instead |
