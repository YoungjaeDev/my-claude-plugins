# Slidev animation reference

Slidev provides a powerful animation system supporting click-based transitions, text marking, complex motion, code-change animation, and more.

## 1. v-click - basic click animation

Makes elements appear sequentially on each click.

### Tag form

```md
<v-click>

Appears on the first click

</v-click>

<v-click>

Appears on the second click

</v-click>

<v-click>

Appears on the third click

</v-click>
```

### Directive form (inline)

```md
<div v-click>Click 1</div>
<div v-click>Click 2</div>
<p v-click>Click 3</p>
```

### Specifying a number

You can specify a particular click order:

```md
<div v-click="3">Appears third</div>
<div v-click="1">Appears first</div>
<div v-click="2">Appears second</div>
```

### Hide after click

```md
<div v-click.hide>Appears on click, then disappears on the next click</div>
<div v-click>Now this appears</div>
```

### Custom click count

Specify the slide's total click count in frontmatter:

```md
---
clicks: 5
---

# Slide title

<div v-click="1">First</div>
<div v-click="2">Second</div>
<div v-click="3">Third</div>
<div v-click="4">Fourth</div>
<div v-click="5">Fifth</div>
```

### Practical example

```md
# Product features

<v-click>

## Fast performance
10x faster loading speed

</v-click>

<v-click>

## Reliability
99.9% uptime guaranteed

</v-click>

<v-click>

## Scalability
Unlimited user support

</v-click>
```

---

## 2. v-clicks - automatic sequential animation

Makes multiple child elements appear automatically in sequence.

### Basic usage

```md
<v-clicks>

- First item
- Second item
- Third item
- Fourth item

</v-clicks>
```

### Specifying depth

Control the depth of nested elements:

```md
<v-clicks depth="2">

- Level 1 item
  - Level 2 item (appears together)
  - Level 2 item (appears together)
- Level 1 item
  - Level 2 item (appears together)

</v-clicks>
```

### The every property

Reveal in groups of N:

```md
<v-clicks every="2">

- Item 1 (first click)
- Item 2 (first click)
- Item 3 (second click)
- Item 4 (second click)

</v-clicks>
```

### Compound example

```md
# Roadmap

<v-clicks>

## Q1 2024
- Launch feature A
- Start the beta test

## Q2 2024
- Official launch
- Marketing campaign

## Q3 2024
- Global expansion
- Sign partnerships

</v-clicks>
```

---

## 3. v-after - appear with the previous click

Makes an element appear at the same time as the previous click element.

### Basic usage

```md
<div v-click>Appears on the first click</div>
<div v-after>Appears together on the first click</div>
```

### Combined with v-click

```md
<div v-click="1">First</div>
<div v-after>With the first</div>
<div v-click="2">Second</div>
<div v-after>With the second</div>
```

### Practical example

```md
# Architecture

<div v-click>

## Frontend
React + TypeScript

</div>

<div v-after>

→ API Gateway

</div>

<div v-click>

## Backend
Node.js + Express

</div>

<div v-after>

→ Database

</div>
```

---

## 4. v-mark - inline text marking

Lets you emphasize or mark text.

### Basic mark types

```md
# Text emphasis

This is a <span v-mark>basic mark</span>.

This is an <span v-mark.underline>underline</span>.

This is a <span v-mark.circle>circle emphasis</span>.

This is a <span v-mark.highlight>highlight</span>.

This is a <span v-mark.box>box</span>.

This is a <span v-mark.strike-through>strikethrough</span>.
```

### Specifying color

```md
This is a <span v-mark.underline.red>red underline</span>.

This is a <span v-mark.highlight.yellow>yellow highlight</span>.

This is a <span v-mark.circle.green>green circle</span>.
```

### Combined with clicks

```md
# Key points

<div v-click>

Performance improved <span v-mark.highlight.yellow v-click>10x</span>.

</div>

<div v-click>

Cost reduced from <span v-mark.strike-through.red v-click>$100</span> to <span v-mark.highlight.green v-click>$50</span>.

</div>
```

### Practical example

```md
# Migration plan

<v-clicks>

- <span v-mark.box>Phase 1</span>: Data backup
- <span v-mark.box>Phase 2</span>: System cutover
- <span v-mark.box>Phase 3</span>: Verification and monitoring

</v-clicks>

<div v-click>

⚠️ <span v-mark.highlight.red>Caution</span>: expected downtime 2 hours

</div>
```

---

## 5. v-motion - complex motion animation

Animate CSS properties to create complex transition effects.

### Basic usage

```md
<div
  v-motion
  :initial="{ x: -80 }"
  :enter="{ x: 0 }">
  Slide in from the left
</div>
```

### Compound animation

```md
<div
  v-motion
  :initial="{ x: -80, opacity: 0 }"
  :enter="{ x: 0, opacity: 1, transition: { duration: 1000 } }"
  :leave="{ x: 80, opacity: 0 }">
  Fade + slide
</div>
```

### Click-based motion

```md
<div
  v-motion
  :initial="{ scale: 0 }"
  :enter="{ scale: 1 }"
  :click-1="{ scale: 1.5, rotate: 45 }"
  :click-2="{ scale: 1, rotate: 0 }">
  Scale and rotate on click
</div>
```

### Delay and timing

```md
<div
  v-motion
  :initial="{ y: -100, opacity: 0 }"
  :enter="{
    y: 0,
    opacity: 1,
    transition: {
      duration: 800,
      delay: 200,
      ease: 'easeOut'
    }
  }">
  Delay and easing applied
</div>
```

### Practical example: card animation

```md
# Product intro

<div class="grid grid-cols-3 gap-4">

<div
  v-motion
  :initial="{ y: 100, opacity: 0 }"
  :enter="{ y: 0, opacity: 1, transition: { delay: 0 } }">

## Feature 1
Fast performance

</div>

<div
  v-motion
  :initial="{ y: 100, opacity: 0 }"
  :enter="{ y: 0, opacity: 1, transition: { delay: 200 } }">

## Feature 2
Reliability

</div>

<div
  v-motion
  :initial="{ y: 100, opacity: 0 }"
  :enter="{ y: 0, opacity: 1, transition: { delay: 400 } }">

## Feature 3
Scalability

</div>

</div>
```

---

## 6. Slide Transitions - slide transition effects

Controls the transition animation between slides.

### Frontmatter transition setting

```md
---
transition: slide-left
---

# Slide 1

---
transition: slide-right
---

# Slide 2

---
transition: fade
---

# Slide 3
```

### Available transitions

```md
---
# slide to the left
transition: slide-left
---

---
# slide to the right
transition: slide-right
---

---
# slide up
transition: slide-up
---

---
# slide down
transition: slide-down
---

---
# fade
transition: fade
---

---
# use the View Transition API (Chrome 111+)
transition: view-transition
---

---
# no transition
transition: none
---
```

### Global transition setting

Apply a default transition to all slides:

```md
---
# first slide (global setting)
theme: apple-basic
transition: slide-left
---

# Slide 1

---

# Slide 2 (inherits the global setting)

---
transition: fade
---

# Slide 3 (a per-slide setting wins)
```

### Custom transition

Use a Vue transition component:

```md
---
transition: my-custom-transition
---

<style>
.my-custom-transition-enter-active,
.my-custom-transition-leave-active {
  transition: all 0.5s ease;
}

.my-custom-transition-enter-from {
  opacity: 0;
  transform: scale(0.9) rotate(-5deg);
}

.my-custom-transition-leave-to {
  opacity: 0;
  transform: scale(1.1) rotate(5deg);
}
</style>
```

---

## 7. Shiki Magic Move - code-change animation

Smoothly animates the changes between code blocks.

### Basic usage

````md
# Code Evolution

````md magic-move
```js
// Step 1: a basic function
function greet(name) {
  console.log('Hello ' + name);
}
```

```js
// Step 2: an ES6 template literal
function greet(name) {
  console.log(`Hello ${name}`);
}
```

```js
// Step 3: an arrow function
const greet = (name) => {
  console.log(`Hello ${name}`);
};
```

```js
// Step 4: the final version
const greet = (name) => console.log(`Hello ${name}!`);
```
````
````

### Multi-step change

````md
# Refactoring

````md magic-move
```js
// Before: monolithic
function processUser(user) {
  // validate
  if (!user.email) throw new Error('No email');

  // process
  const normalized = user.email.toLowerCase();

  // save
  db.save({ email: normalized });
}
```

```js
// After: modularized
function validateUser(user) {
  if (!user.email) throw new Error('No email');
}

function normalizeEmail(email) {
  return email.toLowerCase();
}

function saveUser(user) {
  db.save(user);
}

function processUser(user) {
  validateUser(user);
  user.email = normalizeEmail(user.email);
  saveUser(user);
}
```
````
````

### Combined with highlighting

````md
````md magic-move {lines: true}
```js {1}
// highlight the function declaration
function calculate(a, b) {
  return a + b;
}
```

```js {3}
// highlight the return statement
function calculate(a, b) {
  const result = a + b;
  return result;
}
```

```js {2-3}
// highlight the body
function calculate(a, b) {
  const result = a + b;
  console.log(`Result: ${result}`);
  return result;
}
```
````
````

### Practical example: API evolution

````md
# API improvement process

````md magic-move
```js
// v1: basic REST API
app.get('/users', (req, res) => {
  res.json(users);
});
```

```js
// v2: add pagination
app.get('/users', (req, res) => {
  const { page = 1, limit = 10 } = req.query;
  const start = (page - 1) * limit;
  res.json(users.slice(start, start + limit));
});
```

```js
// v3: add filtering
app.get('/users', (req, res) => {
  const { page = 1, limit = 10, role } = req.query;
  let filtered = role ? users.filter(u => u.role === role) : users;
  const start = (page - 1) * limit;
  res.json(filtered.slice(start, start + limit));
});
```

```js
// v4: error handling and type safety
app.get('/users', async (req, res) => {
  try {
    const { page = 1, limit = 10, role } = req.query;
    const query = { ...(role && { role }) };
    const users = await User.find(query)
      .skip((page - 1) * limit)
      .limit(limit);
    res.json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```
````
````

---

## 8. Click Markers in Notes - auto-scroll presenter notes

Add `[click]` markers to presenter notes to auto-scroll on each click.

### Basic usage

```md
# Product features

<v-clicks>

- Fast performance
- High reliability
- Easy to scale

</v-clicks>

<!--
[click] First feature: performance improved 10x.
[click] Second feature: guarantees 99.9% uptime.
[click] Third feature: horizontal scaling is possible.
-->
```

### Complex example

```md
# System architecture

<div v-click>

## Frontend Layer
React + TypeScript

</div>

<div v-click>

## API Gateway
Kong + Redis

</div>

<div v-click>

## Backend Services
- Auth Service
- User Service
- Payment Service

</div>

<div v-click>

## Database Layer
PostgreSQL + Redis

</div>

<!--
[click] Frontend: uses React 18, type safety with TypeScript

[click] API Gateway: rate limiting with Kong, session management with Redis

[click] Backend: microservice architecture, each service deployed independently

[click] Database: PostgreSQL for relational data, Redis for caching and sessions
-->
```

### Timing hints

```md
# Demo

<v-clicks>

1. Log in
2. Check the dashboard
3. Upload data
4. Generate a report

</v-clicks>

<!--
[click] Log in: uses OAuth 2.0 (expected time: 30s)

[click] Dashboard: check real-time metrics (expected time: 1 min)

[click] Data upload: drag and drop a CSV file (expected time: 1 min)

[click] Report: auto-generate and download PDF (expected time: 30s)

Total demo time: 3 min
-->
```

---

## Animation combination patterns

### Pattern 1: sequential list

```md
# Implementation steps

<v-clicks>

- <span v-mark.box>Phase 1</span>: Requirements analysis
- <span v-mark.box>Phase 2</span>: Design and prototype
- <span v-mark.box>Phase 3</span>: Development and testing
- <span v-mark.box>Phase 4</span>: Deployment and monitoring

</v-clicks>
```

### Pattern 2: emphasized points

```md
# Key metrics

<div v-click>

Response time: <span v-mark.highlight.green>50ms</span>

</div>

<div v-click>

Throughput: <span v-mark.highlight.blue>10,000 req/s</span>

</div>

<div v-click>

Error rate: <span v-mark.highlight.red>0.01%</span>

</div>
```

### Pattern 3: comparison emphasis

```md
# Before vs After

<div class="grid grid-cols-2 gap-8">

<div v-click>

## Before
- <span v-mark.strike-through.red>Slow loading</span>
- <span v-mark.strike-through.red>High memory usage</span>
- <span v-mark.strike-through.red>Complex code</span>

</div>

<div v-click>

## After
- <span v-mark.highlight.green>Fast loading</span>
- <span v-mark.highlight.green>Low memory usage</span>
- <span v-mark.highlight.green>Concise code</span>

</div>

</div>
```

### Pattern 4: card animation

```md
# Team intro

<div class="grid grid-cols-3 gap-4">

<div
  v-motion
  :initial="{ scale: 0, rotate: -10 }"
  :enter="{ scale: 1, rotate: 0, transition: { delay: 0 } }">

## Frontend
3 people

</div>

<div
  v-motion
  :initial="{ scale: 0, rotate: -10 }"
  :enter="{ scale: 1, rotate: 0, transition: { delay: 200 } }">

## Backend
4 people

</div>

<div
  v-motion
  :initial="{ scale: 0, rotate: -10 }"
  :enter="{ scale: 1, rotate: 0, transition: { delay: 400 } }">

## DevOps
2 people

</div>

</div>
```

---

## Performance optimization

### Limit the number of animations

Keeping the click count per slide at 10 or fewer is recommended:

```md
---
clicks: 10  # limit explicitly
---
```

### Prefer transform

Use the `transform` property for performance:

```md
<!-- Good: GPU-accelerated -->
<div v-motion :initial="{ x: -100 }" :enter="{ x: 0 }">

<!-- Bad: layout reflow -->
<div v-motion :initial="{ left: '-100px' }" :enter="{ left: '0' }">
```

### Group complex animations

Wrap multiple elements in a container to animate them together:

```md
<div v-motion :initial="{ opacity: 0 }" :enter="{ opacity: 1 }">
  <div>Item 1</div>
  <div>Item 2</div>
  <div>Item 3</div>
</div>
```

---

## Debugging tips

### Check the click count

Check the current click state in devtools:

```js
// browser console
$slidev.nav.clicks
```

### Adjust animation speed

Adjust global animation speed with CSS:

```css
<style>
.slidev-vclick-target {
  transition: all 0.3s ease !important;
}
</style>
```

### Disable animation (for testing)

```md
---
clicks: 0  # skip all click animations
---
```

---

## $clicks Conditional Class Binding (Rich)

The most powerful animation pattern from KubeCon presentations. Combines v-click with reactive $clicks state for entrance animations:

```html
<div
  v-click flex flex-col gap-2 items-center transition duration-500 ease-in-out
  :class="$clicks < 1 ? 'translate-x--20 opacity-0' : 'translate-x-0 opacity-100'"
>
  Content slides in from left
</div>
```

Direction variants:

| Direction | Hidden Class | Visible Class |
|-----------|-------------|---------------|
| Left to right | `translate-x--20 opacity-0` | `translate-x-0 opacity-100` |
| Right to left | `translate-x-20 opacity-0` | `translate-x-0 opacity-100` |
| Top to bottom | `translate-y--20 opacity-0` | `translate-y-0 opacity-100` |
| Bottom to top | `translate-y-20 opacity-0` | `translate-y-0 opacity-100` |
| Scale in | `scale-80 opacity-0` | `scale-100 opacity-100` |

Multiple elements with sequential timing:

```html
<div v-click :class="$clicks < 1 ? 'translate-x--20 opacity-0' : 'translate-x-0 opacity-100'"
  transition duration-500 ease-in-out>
  First (appears on click 1)
</div>
<div v-click :class="$clicks < 2 ? 'translate-x--20 opacity-0' : 'translate-x-0 opacity-100'"
  transition duration-500 ease-in-out>
  Second (appears on click 2)
</div>
```

---

## v-mark with Colors and Types (Enhanced)

More precise control using object syntax (from nekomeowww KubeCon):

```html
<span v-mark="{ at: 2, color: 'rgb(144, 200, 255)', type: 'underline' }">keyword</span>
<span v-mark="{ at: 3, color: '#ef4444', type: 'circle' }">important</span>
<span v-mark="{ at: 4, color: 'rgb(100, 255, 150)', type: 'highlight' }">solution</span>
```

Available types: `underline`, `circle`, `highlight`, `box`, `strike-through`, `crossed-off`

---

## Staggered Delay Animation

Using v-for with computed v-click for sequential card reveals:

```html
<div v-for="(item, idx) in items" v-click="2 + idx"
  :class="$clicks < (2 + idx) ? 'opacity-0 translate-x--10' : 'opacity-100 translate-x-0'"
  transition duration-300 ease-in-out>
  {{ item }}
</div>
```

Using CSS delay classes (requires UnoCSS safelist):

```html
<div v-click transition duration-300 delay-100>First</div>
<div v-click transition duration-300 delay-200>Second</div>
<div v-click transition duration-300 delay-300>Third</div>
```

UnoCSS safelist for delay classes:

```ts
safelist: [
  ...Array.from({ length: 30 }, (_, i) => `delay-${(i + 1) * 100}`),
  'animate-pulse',
],
```

---

## v-clicks depth for Nested Lists

```html
<v-clicks depth="2">

- Main topic 1
  - Sub-point A (appears with main topic)
  - Sub-point B (appears with main topic)
- Main topic 2
  - Sub-point C
  - Sub-point D

</v-clicks>
```

Without depth, only top-level items get v-click. With `depth="2"`, nested items also animate independently.

---

## Custom Keyframe Animations

Define in scoped CSS, use with UnoCSS:

```html
<div class="animate-pulse" v-click>Pulsing element</div>

<style>
@keyframes float {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-10px); }
}
.animate-float {
  animation: float 3s ease-in-out infinite;
}
</style>
```

---

## fade-out Transition (Default)

The recommended default transition (replaces slide-left):

```css
.fade-out-leave-active {
  transition: opacity calc(var(--slidev-transition-duration) * 0.6) ease-out, filter 200ms ease;
}
.fade-out-enter-active {
  transition: opacity calc(var(--slidev-transition-duration) * 0.8) ease-in, filter 200ms ease;
  transition-delay: calc(var(--slidev-transition-duration) * 0.6);
}
.fade-out-enter-from, .fade-out-leave-to {
  opacity: 0;
  filter: blur(5px);
}
```

Set globally in headmatter: `transition: fade-out`

Override per slide: `transition: 'none'` (for slides with complex $clicks animations)

---

## Click Markers in Notes

Always include `[click]` markers in presenter notes for v-click elements:

```markdown
<!--
[click] First point explanation
[click] Second point - pause here
[click] Third point - check audience
-->
```
