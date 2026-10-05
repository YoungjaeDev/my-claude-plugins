# Shell HTML contract

What a section file may contain and how `deck/shell.html` reads it. What to write is in
`.claude/rules/deck-copy.md`; design and procedure decisions are in `.claude/rules/deck-authoring.md`.
This file owns markup only.

## Contents

- Section files and inline style
- One slide
- Class vocabulary
- Message layouts
- Mockups and flow diagrams
- Panels
- Screen description card
- Motion
- Dev server edit mode

## Section files and inline style

- `deck/sections/NN-*.html` holds `<section class="slide">` blocks and nothing else. The build splices
  them into `<!-- SECTIONS -->` in `shell.html` in file-name order and puts `deck/motions/*.js` into
  `<!-- MOTION_SCRIPTS -->`. Never edit the built `deck/index.html`.
- No `<style>`, no CSS classes of your own. Use shell classes only.
- Images: reference `assets/<file>` only.
- Inline `style` is allowed only for these properties, and never on an element that carries `data-anim`
  (the dev server strips it on save; put the layout on the parent):

| Property | Where |
|---|---|
| `width`, `height`, `max-width` | any container, `figure.shot`, `.orca-win`, an `img` or inline SVG |
| `margin`, `margin-top`, `margin-bottom` | any container or button, for vertical rhythm |
| `grid-template-columns` | a `.split` or `.notes` that needs a different ratio |
| `grid-column` | a `div.reveal-group` spanning a grid body (`grid-column:1 / -1`) |
| `position:absolute` + `left` + `top` (+ `width`/`height`) | only on a direct child of a `.boxflow`, in the same pixel space as its `svg.links` viewBox |

Anything else repeated twice belongs in `shell.html` as a class.

- `<br>` is allowed in two places only: inside `.lead`, at the start of the second subject when a
  two-subject lead would wrap (see deck-copy "한 줄"), and inside `.fbox` box text. Titles never take
  `<br>`; the shell balances them.
- Close every inline SVG element with an end tag (`<path ...></path>`). A self-closing `/>` is expanded
  by the browser on save and produces a diff.
- Inside panels and attributes write `<`, `>`, `&` as `&lt;`, `&gt;`, `&amp;`.

## One slide

```html
<section class="slide" data-section="S2" aria-label="S2-04 메모 앱의 로그인 흐름">
  <span class="kind">개념 · 인증 방식</span>
  <h2>메모 앱의 로그인 흐름</h2>
  <p class="lead">처음 로그인하면 앱이 기기마다 토큰을 따로 저장한다.</p>
  <div class="body split">
    <ul class="points">
      <li>이메일 링크를 누르면 앱이 열린다.</li>
      <li>토큰이 만료되면 다시 링크를 보낸다.</li>
      <li>로그아웃하면 그 기기의 토큰만 지운다.</li>
    </ul>
    <figure class="shot"><img src="assets/s02-login-link-v01.png" alt="이메일 로그인 링크를 누른 뒤 열린 앱 화면"></figure>
  </div>
</section>
```

- `aria-label` is the slide ID plus the `h2` text.
- `data-section="S1".."Sn"` drives the footer progress line and the "S2 섹션명 2 / 5" text. Section
  names live only in the shell `SECTIONS` array. Which slides carry it is decided in deck-authoring
  ("디자인은 셸에"); a slide without it shows a dimmed progress line.
- The shell injects the footer (progress, Ralph character, wordmark, page number), the section number
  and big progress bar on section covers, and the section rows of the agenda. Never write them.
- Runtime elements are `deck-*` elements or classes with `data-runtime`. Never write `deck-` or
  `data-runtime` in a section file. Authoring classes have no prefix.

## Class vocabulary

| Slide type | Structure |
|---|---|
| Cover | `section.slide.cover > header.brandbar(img.monogram + img.wordmark + .logos) + h1 + p.subtitle + div.cover-ralph > img` |
| Agenda | `h2 + ol.agenda`. The shell adds one row per `SECTIONS` entry. Extra rows only: `li > span.no + h3`; a row before the sections is `li.pre` |
| Section cover | `section.slide.section-cover[data-section] > h2 + p.lead + .logos` |
| Concept | `h2 + .body > ul.points`, or `.flow > .flow-step(strong + text)`; `.split` puts a figure beside it |
| Procedure | `h2 + .body > ol.steps > li`; a command goes in `pre.code` inside the `li` |
| Capture | `.body.split > (ul.points, figure.shot > img)`. Text longer than the image: `.split.wide-text`. Wide capture: `figure.shot` (inline `height`) then `.notes > p + p` |
| Compare | `.body.compare > .col(.off/.on) > h3 + p`; `.on` on the column this deck uses. Numbers: `table.data` (`th.num`, `td.num`, `tr.hl`) |
| Checkpoint | `span.kind` "체크포인트" `+ h2 + .body > ol.checklist > li` |
| Misconception | `span.kind` "오해 바로잡기" `+ h2 + .body > ul.points` |
| Prompt | `span.kind` "프롬프트" `+ h2 + .body > pre.code.scroll` (long text scrolls inside the box) |
| Closing | no `data-section`, no `span.kind`; `h2 + .body > ul.points` or a `.statement` |

Slide label: one `span.kind` immediately before `h2` on every content slide; wording and the slides that
take none are in deck-copy ("듣는 사람 자리에서"). `deck-check` enforces both.

Shared classes: `.lead` (one or two sentences under the title), `.body` (fills the remaining height; a
text-only body is centered vertically), `.split` (`.even`, `.wide-text`), `code` (inline command or field),
`pre.code` (`span.k` highlight, `span.c` comment), `.accent` (the accent-colour text of deck-copy
"표기는 하나로"), `.key` (the yellow emphasis of the same rule), `.logos`.

`figure.cut > img` is a small pixel-art cut pinned bottom-right, placed as the sibling after `.body`.
Where and how often is decided by the `deck-assets` skill.

Not used: `p.source` (source line) and `ul.tags` (cover tag chips), even if the shell still styles them.
Sources go in a panel.

**Every copyable command or prompt is one `pre.code`**, on a slide or in a panel. The shell draws it as a
terminal window and puts the copy button in its bar. Write only `<pre class="code">원문</pre>`; add
`data-label="PowerShell"` to name the bar. `.term` is for expected-output mockups that are not copied.

## Message layouts

`.statement` and `.quote` go on `section.slide`; `.versus`, `.hero-num`, `.grid4` go on `.body`. Layout is
on the containers only, so any child may carry `data-anim`. All five center vertically and end above
y 900 when the counts below hold. These counts are the per-layout exceptions to the deck-copy 3–5 rule.

| Layout | Use | Counts |
|---|---|---|
| `.statement` | one conclusion sentence, 98px, centered. `h2 + p.sub` (optional, one line). No `.body`, no `span.kind` | one per section at most; title within two lines; no `<br>` |
| `.versus` | two parties side by side. `.body.versus > .side > h3 + ul.points` | exactly 2 `.side`; 2–4 items per side; `.side.on` on one side or none |
| `.hero-num` | a remembered word or a verified number. `.body.hero-num > div > strong + p` | 2–3 items; with 3, `strong` fits about 5 Hangul or 8 Latin characters |
| `.quote` | a verified external quote. `blockquote > p` then sibling `p.cite > a` | within 3 lines; longer goes to a `data-kind="text"` panel |
| `.grid4` | four items of equal weight, 2×2. `.body.grid4 > .card > span.icon + h3 + p` | exactly 4 cards; `span.icon` optional |

`.statement` and `.versus` are the only slides whose title may state the conclusion (deck-copy "사실만").

```html
<section class="slide statement" data-section="S3" aria-label="S3-09 배포 전 확인은 사람이 한다">
  <h2>배포 전 확인은 <span class="key">사람이 한다</span></h2>
  <p class="sub">에이전트는 체크리스트를 채우고 사람은 결과를 보고 승인한다</p>
</section>
```

```html
<section class="slide" data-section="S3" aria-label="S3-10 사람은 완료 기준을 정하고 AI는 그 기준대로 만든다">
  <span class="kind">개념 · 사람과 AI의 역할</span>
  <h2>사람은 완료 기준을 정하고 AI는 그 기준대로 만든다</h2>
  <div class="body versus">
    <div class="side on">
      <h3>사람</h3>
      <ul class="points">
        <li data-anim="item">완료 기준을 적는다</li>
        <li data-anim="item">결과를 기준과 대조해 merge한다</li>
      </ul>
    </div>
    <div class="side">
      <h3>AI</h3>
      <ul class="points">
        <li data-anim="item">티켓을 구현하고 테스트한다</li>
        <li data-anim="item">리뷰 지적을 반영한다</li>
      </ul>
    </div>
  </div>
</section>
```

- `.versus` vs others: before/after of one thing is `.compare`; numbers are `table.data`. A button row
  under the sides is `div.reveal-group` with `style="grid-column:1 / -1"`.
- `.hero-num`: `strong` is 122px with 2 items and 98px with 3. One `span.key` inside a `strong` at most.
- `.quote`: keep an English original as is; a translation may follow as a second `p` inside
  `blockquote`. The cite name links to the original. The shell draws the opening quote mark.
- `.grid4`: `h3` is one word or noun phrase in the same form across all four; `p` is one line.
  `span.icon` is a 64×64 cell holding a line-icon SVG (`viewBox="0 0 64 64"`, stroked by the shell) or an
  `img` from `assets/logos/`. Ordered items are `ol.steps`; a flow is `.boxflow`.

## Mockups and flow diagrams

| Class | Draws | Structure |
|---|---|---|
| `.term` | terminal output, not copied | `.term > .bar(i, i, i, span title) + pre`; in `pre`: `span.p` prompt, `span.m` muted, `span.ok` success |
| `.tr-win` | chat window | `.tr-win > .bar + .msg.user + .msg.agent`; `.msg > span.who` for the speaker |
| `.orca-win` | ADE/IDE window with three columns | `.orca-win > .orca-side + .orca-main + .orca-panel`. Side: `.orca-head(i×3 + b)`, `.orca-search`, `.orca-nav`, `.orca-label`, `.orca-repo(.orca-badge)`, `.orca-wt(.on)`. Main: `.orca-tabs > span(.on)`, `pre.orca-term(.orca-p, .orca-ok, .orca-dot)`, `.orca-status`. Panel: `.orca-tabs`, `.orca-tree(.d1, .d2, .m, .u > em)`, `.orca-sc(.orca-sc-row, .orca-pr)`. Inline `height` sets the size; add `role="img"` and an `aria-label` |
| `.flow` | static steps in a row | `.flow > .flow-step > strong + text` |
| `.boxflow` | boxes joined by lines | `.boxflow > svg.links + .fbox(.on) > strong + text + span.out` |

`.boxflow` rules:

- Boxes are HTML (`.fbox`); lines are `path` elements in `svg.links`, which covers the whole `.boxflow`
  (`position:absolute; inset:0`). Arrowheads are short `path`s too, never a `→` glyph.
- A row of boxes flows by flex. For a free layout, set the outer `.boxflow` height and place each box
  in its own child `.boxflow` with inline `position:absolute;left;top;width;height`, in the same pixel
  space as the `svg.links` `viewBox` (`viewBox="0 0 1680 350"` for a 1680×350 box). Moving a box means
  recomputing its paths.
- More than 5 boxes: split the slide (deck-authoring). `.fbox.on` marks the box the slide is about.
- `data-anim` goes on `.fbox` or on SVG children, never on the positioned wrapper.

## Panels

```html
<section class="slide" data-section="S2" aria-label="S2-06 도구 3개의 설치 확인">
  <span class="kind">실습 · 설치 확인</span>
  <h2>도구 3개의 설치 확인</h2>
  <button class="reveal-btn qa" data-panel="q-s2-06" aria-label="세션 질문 보기">Q&amp;A</button>
  <div class="body">
    <ul class="points"><li>버전 확인 명령으로 3개가 모두 설치됐는지 본다.</li></ul>
    <div class="reveal-group">
      <button class="reveal-btn" data-panel="p-s2-06">명령 보기</button>
      <button class="reveal-btn" data-panel="p-s2-06-tip">자주 하는 실수</button>
    </div>
  </div>
  <template class="panel" id="p-s2-06" data-kind="text" data-title="설치 확인 명령">
    <pre class="code" data-label="터미널">git --version
uv --version
gh --version</pre>
  </template>
  <template class="panel" id="p-s2-06-tip" data-kind="text" data-title="자주 하는 실수">
    <p>설치한 뒤 터미널을 새로 열지 않으면 PATH가 갱신되지 않는다.</p>
  </template>
  <template class="panel" id="q-s2-06" data-kind="qa" data-title="이미 설치돼 있으면 어떻게 하나요?">
    <p><strong>질문</strong> 이미 설치된 도구도 다시 설치해야 하나요?</p>
    <p><strong>답</strong> 버전이 출력되면 그대로 쓰고 없는 것만 설치합니다.</p>
  </template>
</section>
```

- Trigger: `button.reveal-btn[data-panel="<id>"]` opens `<template class="panel" id="<id>">` on the same
  slide. Ids are unique in the deck and contain the slide ID.
- `data-kind` is `prompt`, `qa` or `text`; `data-title` is the panel title.
- Prompt and command panels open from a labelled button in the body flow. Two or more buttons on one
  slide go in `div.reveal-group`; loose buttons in a centered text body stack and cover the title.
- Q&A uses `button.reveal-btn.qa` (`Q&amp;A`, small circle top-right) with an `aria-label`.
- The shell gives every `pre.code` a copy button; the copied text is the original without `span.k`,
  `span.c` or button text. A `prompt` panel without `pre.code` copies its whole body from the title bar.
- `<template>` does not render, so it never affects overflow, captures or edit-mode saves. The shell
  mounts `deck-panel` on open and removes it on close. Esc, outside click and the close button close
  it; arrow keys pause and focus stays inside; focus returns to the trigger.
- `?static=1` and print never open panels; print also hides the trigger buttons.
- The panel list for the deck lives in the outline's panel column (deck-authoring "원문은 패널로").

## Screen description card

Stands in for a capture that has not arrived. Same slot and size as `figure.shot`; the shell draws the
screen icon.

```html
<figure class="shot brief" style="height:560px">
  <h3>이 화면에서 확인할 것</h3>
  <ul class="points">
    <li>왼쪽 목록에 오늘 받은 항목이 날짜순으로 보인다.</li>
    <li>오른쪽 위 상태 표시가 완료로 바뀐다.</li>
  </ul>
</figure>
```

- 2–3 items naming what is visible where.
- When the capture arrives, drop `brief` from `class` and replace the inside with
  `<img src="assets/<file>" alt="...">`. Keep the inline `style` so the layout does not move.

## Motion

- `data-motion="<name>"` on a slide runs `window.DECK_MOTIONS[name](slide)` on entry; it returns one GSAP
  timeline. One timeline per slide.
- Each motion lives in its own `deck/motions/<name>.js`:

  ```js
  window.DECK_MOTIONS = Object.assign(window.DECK_MOTIONS || {}, {
    loginFlow(slide) {
      const tl = gsap.timeline();
      tl.from(slide.querySelectorAll('[data-anim="node"]'), { opacity: 0, y: 16, stagger: 0.4 });
      return tl;
    },
  });
  ```

  Do not add functions to the shell's own `MOTIONS` object.
- Use `from`/`fromTo` only, so the authored HTML is the end state. Without GSAP, or if a motion throws,
  the slide still shows its content. `prefers-reduced-motion: reduce` shows the end state at once.
- Every moving element carries `data-anim`. Never give it `style` or `transform` directly; on save the
  dev server strips `style`, `transform` and `data-svg-origin` from `data-anim` elements.
- `data-anim` alone does nothing; the slide needs `data-motion`.
- Render QA uses the end state: `?static=1` or `window.presentation.finishMotion()`.

## Dev server edit mode

The dev server rebuilds from `sections/*.html` on every request (no watcher; reload after editing). The
plugin script that starts it is documented in the `deck-check` skill.

- `E` or the small top-left badge turns on `contenteditable` for the text elements of the current slide
  and freezes motion at its end state. `Ctrl+S`/`Cmd+S` writes that section back to its
  `sections/*.html` file.
- Only the dev build carries `data-src`/`data-idx` and the edit script; the deployed `index.html` never
  does.
- On save the server strips `data-runtime` elements, `active`/`visible`/`aria-hidden`,
  `contenteditable`/`spellcheck`, `zoomed`, open `deck-panel` elements and GSAP attributes on
  `data-anim` elements. `<template>` blocks are saved as received.
- Not editable in place: shell-injected rows (agenda sections), elements holding `pre.code`, and panel
  text inside `<template>`. Edit those in the section file.
- Text edited here must also be copied into `deck/outline.md`.
