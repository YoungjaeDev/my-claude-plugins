# Slidev built-in component reference

A detailed guide to every built-in component Slidev provides.

---

## Navigation & Structure

### 1. Toc - table-of-contents component

Automatically generates a slide table of contents.

**Props:**
- `columns`: number of columns (default: 1)
- `maxDepth`: maximum heading depth (default: Infinity)
- `minDepth`: minimum heading depth (default: 1)
- `mode`: display mode - 'all' | 'onlyCurrentTree' | 'onlySiblings' (default: 'all')
- `listClass`: list CSS class

**Example:**
```vue
---
layout: intro
---

# Table of Contents

<Toc columns="2" maxDepth="2" minDepth="1" mode="all" />
```

### 2. Link - slide navigation link

Creates a link that jumps to a specific slide.

**Props:**
- `to`: target slide number or path
- `title`: link text (optional)

**Example:**
```vue
<Link to="5">Go to slide 5</Link>
<Link to="intro">To the Intro slide</Link>
```

### 3. SlideCurrentNo - current slide number

Displays the current slide's number.

**Example:**
```vue
<div class="absolute bottom-4 right-4">
  <SlideCurrentNo /> / <SlidesTotal />
</div>
```

### 4. SlidesTotal - total slide count

Displays the total number of slides in the presentation.

**Example:**
```vue
<footer>
  Page <SlideCurrentNo /> of <SlidesTotal />
</footer>
```

### 5. TitleRenderer - render a slide title

Fetches and displays a specific slide's title.

**Props:**
- `no`: slide number

**Example:**
```vue
<div class="toc-entry">
  <Link to="3">
    <TitleRenderer no="3" />
  </Link>
</div>
```

---

## Visual Elements

### 6. Arrow - draw an arrow

Draws an arrow on the slide.

**Props:**
- `x1`: start x coordinate (px or %)
- `y1`: start y coordinate
- `x2`: end x coordinate
- `y2`: end y coordinate
- `width`: line thickness (default: 2)
- `color`: color (default: 'currentColor')
- `two-way`: two-way arrow (default: false)

**Example:**
```vue
<Arrow x1="400" y1="300" x2="600" y2="400" width="3" color="#ff0000" />
<Arrow x1="10%" y1="50%" x2="90%" y2="50%" two-way />
```

### 7. VDragArrow - draggable arrow

An arrow whose position can be adjusted by dragging.

**Example:**
```vue
<VDragArrow x1="200" y1="200" x2="400" y2="300" color="#42b883" />
```

### 8. AutoFitText - auto-sizing text

Automatically adjusts text size to fit the container.

**Props:**
- `max`: maximum font-size (default: 100px)
- `min`: minimum font-size (default: 10px)

**Example:**
```vue
<AutoFitText :max="200" :min="20" class="w-full h-40">
  This text auto-adjusts its size
</AutoFitText>
```

### 9. Transform - transform wrapper

Scales or transforms an element.

**Props:**
- `scale`: scale ratio (default: 1)
- `origin`: transform origin (default: 'center')

**Example:**
```vue
<Transform :scale="2" origin="top left">
  <img src="/diagram.png" />
</Transform>

<Transform :scale="0.5">
  <div class="code-block">
    Show long code scaled down
  </div>
</Transform>
```

### 10. VDrag - draggable element

Makes an element movable by dragging.

**Example:**
```vue
<VDrag>
  <div class="bg-blue-500 p-4 rounded">
    Drag this box
  </div>
</VDrag>

<VDrag x="100" y="200">
  <img src="/logo.png" width="100" />
</VDrag>
```

---

## Media

### 11. SlidevVideo - video embed

Inserts a video into a slide.

**Props:**
- `controls`: whether to show controls (default: true)
- `autoplay`: autoplay (default: false)
- `autoreset`: reset when leaving the slide (default: true)
- `poster`: poster image URL
- `timestamp`: start time (seconds)

**Example:**
```vue
<SlidevVideo controls autoplay>
  <source src="/demo.mp4" type="video/mp4" />
</SlidevVideo>

<SlidevVideo
  controls
  :autoplay="false"
  poster="/thumbnail.jpg"
  :timestamp="10"
>
  <source src="/presentation.mp4" />
</SlidevVideo>
```

### 12. Youtube - YouTube embed

Inserts a YouTube video.

**Props:**
- `id`: YouTube video ID (required)
- `width`: width (default: 100%)
- `height`: height (default: auto)

**Example:**
```vue
<Youtube id="dQw4w9WgXcQ" width="640" height="360" />

<Youtube id="dQw4w9WgXcQ" class="w-full h-80" />
```

### 13. Tweet - Twitter/X embed

Inserts a tweet into a slide.

**Props:**
- `id`: tweet ID (required)
- `scale`: scale ratio (default: 1)
- `conversation`: show the conversation thread (default: 'none')
- `cards`: whether to show cards (default: 'visible')

**Example:**
```vue
<Tweet id="1234567890123456789" />

<Tweet
  id="1234567890123456789"
  :scale="0.8"
  conversation="all"
  cards="hidden"
/>
```

---

## Conditional Rendering

### 14. LightOrDark - theme-based conditional rendering

Displays different content depending on Light/Dark mode.

**Slots:**
- `#dark`: shown in Dark mode
- `#light`: shown in Light mode

**Example:**
```vue
<LightOrDark>
  <template #dark>
    <img src="/logo-dark.png" />
  </template>
  <template #light>
    <img src="/logo-light.png" />
  </template>
</LightOrDark>

<LightOrDark>
  <template #dark>
    <div class="bg-gray-900 text-white p-4">
      Dark mode content
    </div>
  </template>
  <template #light>
    <div class="bg-white text-gray-900 p-4">
      Light mode content
    </div>
  </template>
</LightOrDark>
```

### 15. RenderWhen - context-based conditional rendering

Displays content only in a specific rendering context.

**Props:**
- `context`: rendering context
  - `main`: the main slide
  - `visible`: the currently visible slide
  - `print`: print/PDF output
  - `slide`: slide view
  - `overview`: overview mode
  - `presenter`: presenter mode
  - `previewNext`: next-slide preview

**Example:**
```vue
<RenderWhen context="presenter">
  <div class="notes">
    Notes only the presenter can see
  </div>
</RenderWhen>

<RenderWhen context="print">
  <footer>Footer for printing</footer>
</RenderWhen>

<RenderWhen context="main">
  <div class="animations">
    Animation that runs only in the main view
  </div>
</RenderWhen>
```

---

## Animation Components

### 16. VClick - click-based visibility

Reveals an element on each click.

**Example:**
```vue
<div>
  <p>Always-visible text</p>
  <VClick>
    <p>Appears on the first click</p>
  </VClick>
  <VClick>
    <p>Appears on the second click</p>
  </VClick>
</div>
```

### 17. VClicks - sequential reveal of children

Reveals child elements one at a time on each click.

**Example:**
```vue
<VClicks>
  <p>First click</p>
  <p>Second click</p>
  <p>Third click</p>
</VClicks>

<!-- sequential reveal of list items -->
<VClicks>
  <ul>
    <li>Item 1</li>
    <li>Item 2</li>
    <li>Item 3</li>
  </ul>
</VClicks>
```

### 18. VAfter - reveal after the previous click

Displayed after the previous VClick/VClicks.

**Example:**
```vue
<VClick>
  <p>First</p>
</VClick>

<VAfter>
  <p>Shown together with the first</p>
</VAfter>

<VClick>
  <p>Second</p>
</VClick>
```

### 19. VSwitch - click-based slot switching

Displays a different slot on each click.

**Props:**
- `unmount`: whether to unmount the previous slot (default: true)
- `tag`: wrapper tag (default: 'div')
- `childTag`: child wrapper tag (default: 'div')
- `transition`: Transition name

**Example:**
```vue
<VSwitch>
  <template #0>
    <div>Initial state</div>
  </template>
  <template #1>
    <div>After the first click</div>
  </template>
  <template #2>
    <div>After the second click</div>
  </template>
</VSwitch>

<VSwitch transition="fade" :unmount="false">
  <template #0>
    <img src="/step1.png" />
  </template>
  <template #1>
    <img src="/step2.png" />
  </template>
  <template #3-5>
    <img src="/step3-5.png" />
  </template>
</VSwitch>
```

---

## Branding

### 20. PoweredBySlidev - Slidev branding link

A branding link to the official Slidev site.

**Example:**
```vue
<div class="absolute bottom-2 right-2 text-xs opacity-50">
  <PoweredBySlidev />
</div>
```

---

## Combined example

A practical example combining several components:

```vue
---
layout: center
---

# Product Intro

<VClicks>

- Feature 1: fast performance
- Feature 2: intuitive UI
- Feature 3: extensible

</VClicks>

<VClick>
<Transform :scale="1.5" class="mt-8">
  <AutoFitText :max="60" :min="20" class="text-blue-500">
    Get started now!
  </AutoFitText>
</Transform>
</VClick>

<Arrow x1="200" y1="400" x2="600" y2="400" color="#42b883" />

---
layout: two-cols
---

# Demo Video

<SlidevVideo controls autoplay>
  <source src="/demo.mp4" type="video/mp4" />
</SlidevVideo>

::right::

# Key Points

<VClicks>

1. Simple installation
2. Powerful features
3. Community support

</VClicks>

<VAfter>
<div class="mt-4 p-4 bg-blue-100 rounded">
  <Link to="10">Learn more →</Link>
</div>
</VAfter>

---

# Responsive Content

<LightOrDark>
  <template #dark>
    <div class="bg-gray-800 p-8 rounded">
      <h2 class="text-white">Optimized for Dark mode</h2>
      <Youtube id="dQw4w9WgXcQ" class="mt-4" />
    </div>
  </template>
  <template #light>
    <div class="bg-white p-8 rounded shadow">
      <h2 class="text-gray-900">Optimized for Light mode</h2>
      <Youtube id="dQw4w9WgXcQ" class="mt-4" />
    </div>
  </template>
</LightOrDark>

<RenderWhen context="presenter">
  <div class="notes mt-4 p-4 bg-yellow-100 rounded">
    Presenter note: emphasize the demo here
  </div>
</RenderWhen>
```

---

## Arrow - Pointing to Code/Elements

From KubeCon presentations, Arrow is used to connect explanations to code:

```html
<Arrow x1="400" y1="250" x2="300" y2="180" width="2" color="red" />
```

Combined with v-click for sequential reveals:

```html
<Arrow v-click x1="400" y1="250" x2="300" y2="180" width="2" color="#42b883" />
```

---

## Footnotes and Footnote (Academic Theme)

Available with `theme: academic`:

```html
<Footnotes separator>
  <Footnote number=1>
    <a href="https://example.com" rel="noopener noreferrer">Source Name</a>
  </Footnote>
</Footnotes>
```

The `separator` prop adds a horizontal line above the footnotes.

---

## Transform - Practical Usage

Scale down large diagrams or code blocks:

```html
<Transform :scale="0.8">
  <!-- Large mermaid diagram or code block -->
</Transform>
```

Scale up for emphasis:

```html
<Transform :scale="1.5" origin="center">
  <div text-6xl font-bold>Key Number</div>
</Transform>
```

---

## VSwitch - Click-Based Content Replacement

Show different content for each click:

```html
<VSwitch>
  <template #0>
    <div>Initial state</div>
  </template>
  <template #1>
    <div>After first click</div>
  </template>
  <template #2>
    <div>After second click</div>
  </template>
</VSwitch>
```

With transition effect:

```html
<VSwitch transition="fade">
  <template #0>Step 1 content</template>
  <template #1>Step 2 content</template>
</VSwitch>
```
