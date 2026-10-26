# Mockup states and the hops motion

Markup for a browser window mockup, a state change inside a mockup or flow, and the `hops` motion
shipped in `deck/motions/basic.js`. The general rules (inline style, `data-anim`, `immediateRender`) are
in `shell-contract.md`.

## Browser window mockup (`.browser-win`)

Draws an F12 panel, a page source view, a link preview or any page of a fictional site. Content is
fictional (deck-copy rules on example names apply).

```html
<div class="body split">
  <ul class="points">
    <li>저장 버튼을 누르면 메모 수가 바로 바뀐다.</li>
  </ul>
  <div class="browser-win" style="height:520px" role="img" aria-label="저장 버튼을 누르자 메모 수가 3개로 바뀐 메모 앱 목업">
    <div class="bar"><i></i><i></i><i></i><span class="url">memo.example.com/new</span></div>
    <div class="page">
      <h3>새 메모</h3>
      <p>메모 <span class="swap" data-anim="hop"><span>2</span><span>3</span></span>개</p>
      <span class="field">제목</span>
      <span class="btn"><span>저장</span><svg class="cursor" viewBox="0 0 24 24"><path d="M4 2 L4 20 L9 15.5 L12.5 22.5 L15.5 21 L12 14 L18.5 14 Z"></path></svg></span>
    </div>
  </div>
</div>
```

- Where: beside text in `.body.split`, alone in `.body`, or as a positioned child of a `.boxflow`.
  Inline `height` sets the size; always add `role="img"` and an `aria-label` describing the end state.
- `.page` children: `h3`, `p`, `span.field` (input box), `span.btn` (button). Up to 5 rows; text cut off
  inside `.page` fails the render check as `clip:`.
- `.page.raw` draws the same page with HTML only (browser defaults: white page, thin inputs, grey button).
- `.page.before` is an earlier look of the page, the sibling right after `.page`, laid over it. Hidden in
  the end state; a motion shows it then fades it out ("Earlier states").
- `.swap` holds the old value then the new one in one cell (`span.swap > span + span`). The first child
  is hidden in the end state. Works anywhere, also in `.fbox` text and in `.url`.
- `.cursor` is a mouse pointer resting on the bottom-right of a `.btn`. The button text goes in its own
  `span` (`<span class="btn"><span>저장</span><svg class="cursor">`): the render check reads elements
  that hold text directly, and a `.btn` holding both text and the pointer counts as overflow.

## Earlier states

The authored DOM is the end state, so an earlier state lives in the end state as a hidden element, and the
motion shows it from the first frame then hides it on its turn:

- `.page.before` (a whole earlier page) and the first child of `.swap` (an old value) are `opacity: 0` in
  the shell. The motion runs `fromTo({ opacity: 1 }, { opacity: 0 })` with the default
  `immediateRender`, so the earlier state shows at once and fades out on its turn; the new value of a
  `.swap` fades in at the same time.
- Never make the earlier state the authored one and the end state hidden: `?static=1`, print, reduced
  motion and a failed motion would then all show the wrong state.

## The `hops` motion

`hops` draws a flow: boxes and lines appear, then each step plays in turn.

| Attribute | On | Does |
|---|---|---|
| `data-anim="node"` | `.fbox` | fades up first, staggered |
| `data-anim="link"` | `path`, `text` in `svg.links` | fades in after the nodes |
| `data-anim="hop"` | any element | one step, played in order |
| `data-order="N"` | a hop | turn number; equal numbers keep DOM order; hops without one play last |
| `data-from="x,y x,y ..."` | a hop | travels from these offsets (start, then each corner) to its authored spot. A `circle` hop is a packet dot: author it `opacity="0"`; it shows while travelling and fades out at the end |
| `data-width="N"` | an svg `rect` hop | grows or shrinks from this width to its authored `width` |
| `data-anim="case"` | `p.flow-case` | shows last |

What a hop does depends on the element: with `data-from` it travels; a `.swap` swaps old for new; a
`.page.before` fades out; with `data-width` it resizes; anything else fades in. A `.cursor` with
`data-from` (authored `opacity="0"`) moves onto its button. `opacity="0"` is an SVG attribute, not inline
`style`, so it is allowed on a `data-anim` element.
