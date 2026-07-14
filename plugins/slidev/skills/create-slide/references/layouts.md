# Slidev layout reference guide

This document contains complete usage examples for all of Slidev's built-in layouts and the apple-basic theme's dedicated layouts.

## Contents

- [Built-in layouts](#built-in-layouts)
- [Apple-Basic theme layouts](#apple-basic-theme-layouts)
- [Slot Sugar syntax](#slot-sugar-syntax)

---

## Built-in layouts

The default layouts included in the Slidev core.

### 1. default

The basic content layout. Displays a title and body.

**Frontmatter options:**
- `layout: default` (omittable, the default)
- all common slide options usable

**Slot:**
- `default`: the main content area

**Usage example:**

```md
---
layout: default
---

# Slide title

Write general content here.

- Item 1
- Item 2
- Item 3

You can use code blocks too:

\`\`\`js
console.log('Hello Slidev')
\`\`\`
```

---

### 2. center

Places all content in the center.

**Frontmatter options:**
- `layout: center`

**Slot:**
- `default`: content to be center-aligned

**Usage example:**

```md
---
layout: center
---

# Center-aligned title

An important message shown in the center

**Emphasized text** is also center-aligned
```

---

### 3. cover

The presentation's cover slide. The default layout for the first slide.

**Frontmatter options:**
- `layout: cover`
- `background`: background image or color

**Slot:**
- `default`: the title and subtitle area

**Usage example:**

```md
---
layout: cover
background: https://source.unsplash.com/collection/94734566/1920x1080
---

# Slidev Presentation

Presentation subtitle

<div class="pt-12">
  <span @click="$slidev.nav.next" class="px-2 py-1 rounded cursor-pointer" hover="bg-white bg-opacity-10">
    Get started <carbon:arrow-right class="inline"/>
  </span>
</div>
```

---

### 4. intro

The introduction slide. Displays a title along with presenter information.

**Frontmatter options:**
- `layout: intro`

**Slot:**
- `default`: the introduction content

**Usage example:**

```md
---
layout: intro
---

# Project Introduction

## An innovative AI platform

<div class="absolute bottom-10">
  <span class="font-700">
    Presenter: Hong Gildong
  </span>
</div>

<div class="abs-br m-6 flex gap-2">
  <a href="https://github.com/slidevjs/slidev" target="_blank" alt="GitHub"
    class="text-xl icon-btn opacity-50 !border-none !hover:text-white">
    <carbon-logo-github />
  </a>
</div>
```

---

### 5. section

A section-divider slide. Used when starting a new topic.

**Frontmatter options:**
- `layout: section`
- `background`: background color or image

**Slot:**
- `default`: the section title

**Usage example:**

```md
---
layout: section
background: '#1e293b'
---

# Section 1

Introducing the key features
```

---

### 6. statement

Displays an emphasized statement full-screen.

**Frontmatter options:**
- `layout: statement`

**Slot:**
- `default`: the emphasized statement

**Usage example:**

```md
---
layout: statement
---

# "Innovation begins in the details"

Steve Jobs
```

---

### 7. fact

Highlights an important data point or statistic.

**Frontmatter options:**
- `layout: fact`

**Slot:**
- `default`: the key fact

**Usage example:**

```md
---
layout: fact
---

# 95%

User satisfaction
```

---

### 8. quote

Displays a quotation.

**Frontmatter options:**
- `layout: quote`

**Slot:**
- `default`: the quotation content

**Usage example:**

```md
---
layout: quote
---

# "Programming is an art"

Donald Knuth, The Art of Computer Programming
```

---

### 9. end

The final slide of the presentation.

**Frontmatter options:**
- `layout: end`

**Slot:**
- `default`: the closing message

**Usage example:**

```md
---
layout: end
---

# Thank you

Please reach out with any questions

contact@example.com
```

---

### 10. full

Full-screen content. Uses the whole area with no margins.

**Frontmatter options:**
- `layout: full`

**Slot:**
- `default`: the full-screen content

**Usage example:**

```md
---
layout: full
---

<div class="w-full h-full flex items-center justify-center bg-gradient-to-r from-blue-500 to-purple-600">
  <h1 class="text-6xl text-white">Full-screen content</h1>
</div>
```

---

### 11. none

Applies no styling. Use it when you need a fully custom layout.

**Frontmatter options:**
- `layout: none`

**Slot:**
- `default`: all content

**Usage example:**

```md
---
layout: none
---

<div class="absolute inset-0 flex items-center justify-center">
  <div class="text-center">
    <h1 class="text-8xl font-bold">100%</h1>
    <p class="text-2xl mt-4">Custom design</p>
  </div>
</div>
```

---

### 12. image

Displays a full-screen image.

**Frontmatter options:**
- `layout: image`
- `image`: image URL (required)
- `backgroundSize`: the CSS background-size property (default: `cover`)

**Slot:**
- none (image only)

**Usage example:**

```md
---
layout: image
image: https://source.unsplash.com/collection/94734566/1920x1080
backgroundSize: contain
---
```

---

### 13. image-left

Places an image on the left and content on the right.

**Frontmatter options:**
- `layout: image-left`
- `image`: image URL (required)
- `class`: CSS class applied to the content area
- `backgroundSize`: the image's background-size (default: `cover`)

**Slot:**
- `default`: the right-side content area

**Usage example:**

```md
---
layout: image-left
image: https://source.unsplash.com/collection/94734566/800x600
class: my-cool-content
---

# Left-image layout

Write content on the right.

- Show an image and text together
- Good for visual material that needs explanation
- Works responsively

<style>
.my-cool-content {
  padding: 2rem;
}
</style>
```

---

### 14. image-right

Places content on the left and an image on the right.

**Frontmatter options:**
- `layout: image-right`
- `image`: image URL (required)
- `class`: CSS class applied to the content area
- `backgroundSize`: the image's background-size (default: `cover`)

**Slot:**
- `default`: the left-side content area

**Usage example:**

```md
---
layout: image-right
image: https://source.unsplash.com/collection/94734566/800x600
---

# Right-image layout

Write content on the left.

```ts
// code examples can be included too
interface User {
  name: string
  email: string
}
```

The image is automatically shown on the right.
```

---

### 15. iframe

Embeds a web page.

**Frontmatter options:**
- `layout: iframe`
- `url`: the URL to embed (required)

**Slot:**
- none (iframe only)

**Usage example:**

```md
---
layout: iframe
url: https://slidev.dev
---
```

---

### 16. iframe-left

Places an iframe on the left and content on the right.

**Frontmatter options:**
- `layout: iframe-left`
- `url`: the URL to embed (required)
- `class`: CSS class applied to the content area

**Slot:**
- `default`: the right-side content area

**Usage example:**

```md
---
layout: iframe-left
url: https://www.youtube.com/embed/dQw4w9WgXcQ
---

# Explanation with video

A YouTube video shows on the left, and you can write the explanation on the right.

- Explanation with a demo video
- Live-site preview
- Interactive content
```

---

### 17. iframe-right

Places content on the left and an iframe on the right.

**Frontmatter options:**
- `layout: iframe-right`
- `url`: the URL to embed (required)
- `class`: CSS class applied to the content area

**Slot:**
- `default`: the left-side content area

**Usage example:**

```md
---
layout: iframe-right
url: https://codepen.io/pen/
---

# Code demo

Write the explanation on the left and show a live code example on the right.

- CodePen embed
- StackBlitz project
- Interactive documentation
```

---

### 18. two-cols

Splits content into two columns.

**Frontmatter options:**
- `layout: two-cols`

**Slot:**
- `default` or `left`: the left column
- `right`: the right column

**Usage example:**

```md
---
layout: two-cols
---

# Left column

This is the left column.

- Item 1
- Item 2
- Item 3

::right::

# Right column

This is the right column.

```ts
const greeting = 'Hello'
console.log(greeting)
```

You can place code or images on the right.
```

---

### 19. two-cols-header

A layout with a header and two columns.

**Frontmatter options:**
- `layout: two-cols-header`

**Slot:**
- `default`: the header area
- `left`: the left column
- `right`: the right column

**Usage example:**

```md
---
layout: two-cols-header
---

# Shared header

This header is shown above the two columns.

::left::

## Left section

- Before state
- The existing way
- Problems

::right::

## Right section

- After state
- The improved way
- The solution
```

---

## Apple-Basic theme layouts

Additional layouts available only when using `theme: apple-basic`.

### 1. intro (Apple-Basic Override)

An Apple Keynote-style title slide. There is an author/date area at the bottom.

**Frontmatter options:**
- `layout: intro`
- `theme: apple-basic` (required)

**Slot:**
- `default`: the title and subtitle

**Usage example:**

```md
---
theme: apple-basic
layout: intro
---

# Innovative product launch

The next-generation AI platform

<div class="absolute bottom-10">
  <p class="text-sm opacity-75">
    Hong Gildong | February 11, 2024
  </p>
</div>
```

---

### 2. intro-image

Overlays a title on a full background image.

**Frontmatter options:**
- `layout: intro-image`
- `theme: apple-basic` (required)
- `image`: background image URL (required)

**Slot:**
- `default`: the title to overlay

**Usage example:**

```md
---
theme: apple-basic
layout: intro-image
image: https://source.unsplash.com/collection/94734566/1920x1080
---

<div class="absolute top-1/3 left-10 right-10">
  <h1 class="text-7xl font-bold text-white drop-shadow-lg">
    A journey toward the future
  </h1>
  <p class="text-3xl text-white mt-8 drop-shadow">
    The new world AI creates
  </p>
</div>
```

---

### 3. intro-image-right

Places a title on the left and an image on the right.

**Frontmatter options:**
- `layout: intro-image-right`
- `theme: apple-basic` (required)
- `image`: right-side image URL (required)

**Slot:**
- `default`: the left title area

**Usage example:**

```md
---
theme: apple-basic
layout: intro-image-right
image: https://source.unsplash.com/collection/94734566/800x1080
---

<div class="flex flex-col justify-center h-full pl-20">
  <h1 class="text-6xl font-bold mb-8">
    The beginning of innovation
  </h1>
  <p class="text-2xl opacity-75">
    A shift to a new paradigm
  </p>
  <p class="text-lg mt-12 opacity-50">
    February 11, 2024
  </p>
</div>
```

---

### 4. image-right (Apple-Basic Override)

A version with content, a right-aligned image, and subtitle support added.

**Frontmatter options:**
- `layout: image-right`
- `theme: apple-basic` (required)
- `image`: image URL (required)

**Slot:**
- `default`: the left content area

**Usage example:**

```md
---
theme: apple-basic
layout: image-right
image: https://source.unsplash.com/collection/94734566/800x600
---

# Key features

## An innovative user experience

- An intuitive interface
- Fast response time
- Powerful customization

Displays neatly organized content alongside the image on the right.
```

---

### 5. bullets

Displays only bullet points with a minimal design.

**Frontmatter options:**
- `layout: bullets`
- `theme: apple-basic` (required)

**Slot:**
- `default`: the bullet list

**Usage example:**

```md
---
theme: apple-basic
layout: bullets
---

# Key summary

- First key point
- Second key point
- Third key point
- Fourth key point

A layout optimized for delivering a concise, clear message.
```

---

### 6. 3-images

Arranges three images in a grid. One large image on the left, two images stacked vertically on the right.

**Frontmatter options:**
- `layout: 3-images`
- `theme: apple-basic` (required)
- `imageLeft`: left large-image URL (required)
- `imageTopRight`: top-right image URL (required)
- `imageBottomRight`: bottom-right image URL (required)

**Slot:**
- `default`: title or caption (optional)

**Usage example:**

```md
---
theme: apple-basic
layout: 3-images
imageLeft: https://source.unsplash.com/800x1200?nature
imageTopRight: https://source.unsplash.com/800x600?technology
imageBottomRight: https://source.unsplash.com/800x600?architecture
---

# Multiple perspectives

The project seen from three angles
```

---

## Slot Sugar syntax

Slidev provides a sugar syntax for conveniently using named slots.

### Basic slot markers

- `::right::` - start of the right slot
- `::left::` - start of the left slot
- `::bottom::` - start of the bottom slot
- `::slot-name::` - start of a custom slot

### two-cols example

```md
---
layout: two-cols
---

# Left column title

All the content shown on the left.

- List item 1
- List item 2

```js
// a code block works too
const left = 'content'
```

::right::

# Right column title

All the content shown on the right.

![Image](https://source.unsplash.com/400x300?code)

**Emphasized text** is usable too.
```

### Full two-cols-header example

```md
---
layout: two-cols-header
---

# Comparative analysis

Comparing two approaches.

::left::

## Approach A

### Pros
- Fast to implement
- Low complexity
- Easy maintenance

### Cons
- Limited scalability
- Possible performance issues

```python
# Approach A code example
def simple_approach():
    return "quick but limited"
```

::right::

## Approach B

### Pros
- High scalability
- Excellent performance
- Flexible architecture

### Cons
- Complex to implement
- Long development time

```python
# Approach B code example
class AdvancedApproach:
    def __init__(self):
        self.scalable = True

    def execute(self):
        return "complex but powerful"
```
```

### Custom slot example

You can use arbitrary slot names when building a custom layout.

```md
---
layout: my-custom-layout
---

This is the default content area.

::header::

# Custom header

This part goes into the header slot.

::footer::

<div class="text-sm opacity-50">
  Page footer info
</div>

::sidebar::

- Sidebar item 1
- Sidebar item 2
- Sidebar item 3
```

### Multiple-slot combination example

```md
---
layout: two-cols-header
class: px-8
---

# Product comparison table

Comparing the key features of three products.

::left::

## Product A

| Feature | Supported |
|------|-----------|
| Feature 1 | ✓ |
| Feature 2 | ✓ |
| Feature 3 | ✗ |
| Feature 4 | ✓ |

**Price:** $99/month

::right::

## Product B

| Feature | Supported |
|------|-----------|
| Feature 1 | ✓ |
| Feature 2 | ✓ |
| Feature 3 | ✓ |
| Feature 4 | ✓ |

**Price:** $199/month

<div class="mt-8 p-4 bg-green-100 rounded">
  <strong>Recommended</strong>: when you need all the features
</div>
```

---

## Layout selection guide

| Purpose | Recommended layout |
|------|---------------|
| cover | `cover` |
| section divider | `section` |
| general content | `default` |
| important message | `center`, `statement` |
| statistic/data emphasis | `fact` |
| quotation | `quote` |
| image-focused | `image`, `image-left`, `image-right` |
| comparison | `two-cols`, `two-cols-header` |
| web embed | `iframe`, `iframe-left`, `iframe-right` |
| closing | `end` |
| Apple-style title | `intro` (apple-basic) |
| image gallery | `3-images` (apple-basic) |

---

## Layout customization

Every layout can be customized via the frontmatter `class` property.

```md
---
layout: center
class: text-white bg-gradient-to-r from-blue-500 to-purple-600
---

# Gradient background

A center-aligned slide with custom styling applied
```

### Adding scoped styles

You can apply unique styling to each slide.

```md
---
layout: default
---

# Custom-styled slide

<div class="my-custom-box">
  A box with special styling
</div>

<style>
.my-custom-box {
  padding: 2rem;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 1rem;
  color: white;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
}
</style>
```

---

## Per-Slide Class Patterns

From real KubeCon presentations, the most common per-slide class patterns:

```yaml
class: py-10        # Most common (18/28 slides in KubeCon talks)
class: py-4         # Code-heavy slides (less vertical padding)
class: px-24        # Intro layouts (extra horizontal padding)
class: px-35        # Wide intro layouts
class: text-center  # Center layout helper
```

## layoutClass Frontmatter

`layoutClass` applies CSS classes to the layout wrapper (not the slide content):

```yaml
---
layoutClass: gap-16
---
```

This is useful for adjusting the gap in `two-cols` layouts.

## Official Theme Layout Structure

All official Slidev theme layouts follow this pattern:

```html
<div class="slidev-layout {layout-name}">
  <div class="my-auto">
    <slot />
  </div>
</div>
```

- `.slidev-layout` is the root class on all layouts
- `my-auto` provides vertical centering
- Named slots: `::right::`, `::left::`, `::items::`, `::bottom::`

## Grid-Based Split Layouts

For custom split layouts beyond two-cols:

```html
<div grid grid-cols-2 gap-8>
  <div>
    <!-- Left content -->
  </div>
  <div>
    <!-- Right content -->
  </div>
</div>
```

3-column grid:

```html
<div grid grid-cols-3 gap-4>
  <div>Column 1</div>
  <div>Column 2</div>
  <div>Column 3</div>
</div>
```

## Figure Layout (Academic Theme)

Available with `theme: academic`:

```yaml
---
layout: figure
figureCaption: "Container Lifecycle"
figureUrl: /architecture.png
figureFootnoteNumber: 1
---
```

## Table of Contents Layout (Academic Theme)

```yaml
---
layout: table-of-contents
hideInToc: true
---
```

Auto-generates agenda from slide headings. The `hideInToc: true` prevents recursive TOC entry.

---

## Notes

1. **Theme dependency**: apple-basic-only layouts work only when using that theme.
2. **Slot order**: a slot marker (`::right::`, etc.) must be written on a line above a blank line.
3. **Image paths**: store local images in the `public/` folder and reference them as `/image.png`.
4. **Responsive**: all built-in layouts work responsively by default.
5. **PDF export**: some interactive features may not work when exporting to PDF.
