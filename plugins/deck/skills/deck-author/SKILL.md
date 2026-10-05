---
name: deck-author
description: "Write or edit slides in a house-format HTML deck: deck/shell.html plus deck/sections/*.html assembled by the deck build, GSAP motions in deck/motions/*.js, panels as template.panel. Holds the section HTML contract (class vocabulary, message layouts, mockups, box flows, panels, motion registration, inline-style whitelist, dev-server save rules) and the 1920x1080 render pass criteria. Use when creating or changing deck/sections/*.html or deck/outline.md in a deck that has deck/shell.html. Triggers — 섹션 작성, 장표 추가, 장표 수정, 슬라이드 고쳐줘, 덱 문구 반영, outline 반영, write a deck section, add a slide, edit slides, update the outline. For a new presentation from scratch, a PPT conversion, or any deck without deck/shell.html, use frontend-slides instead. Scaffolding a new house deck is deck-new; checks and renders are deck-check."
---

# deck-author

Writes and edits `deck/sections/*.html` and `deck/outline.md` in a house-format deck. The deck is a
fixed shell (`deck/shell.html`) plus section files plus motion files, built into `deck/index.html`.

## When this applies

1. Check that `deck/shell.html` and `deck/sections/` exist. If they do not, this is not a house deck:
   stop and use `frontend-slides`, or `deck-new` when the user wants a new house deck.
2. If `frontend-slides` is also loaded, its defaults lose wherever `.claude/rules/deck-authoring.md`
   ("frontend-slides 기본값 덮어쓰기") says so. Do not run its style-preview or density questions.

## Read first

- `.claude/rules/deck-copy.md`: what to write, labels, item count, banned wording.
- `.claude/rules/deck-authoring.md`: procedure, design, motion, panel and deploy decisions.
- `.claude/rules/korean-style.md`: Korean sentence verdicts.
- `deck/outline.md`: the header (deck thesis, sections, files, command source file) and the rows for
  the slides you touch.
- `references/shell-contract.md`: the markup contract. Read the parts for the slide types you write.

If the rule copies are missing from `.claude/rules/`, the repo was not set up with `deck-new`/`deck-sync`;
read the originals in this plugin's `templates/rules/` and tell the user.

## Procedure

1. **Outline first** (deck-authoring "원고가 기준"): change `deck/outline.md`, then carry its title and
   body text into the section verbatim.
2. **Write the section** per `references/shell-contract.md`, touching only the slides asked for.
3. **Motion** only where deck-authoring "흐름은 움직임으로" allows it, registered as the contract's
   Motion section describes.
4. **Check** with `deck-check` (build, copy check, render) and fix every finding.
5. **Look** at every rendered PNG of the changed slides against `references/qa.md`.
6. **Report** the slide IDs changed, the files written, and anything not verified. Deployment is not
   part of this skill (deck-authoring "원고가 기준", `deck-deploy`).

## References

| File | Read when |
|---|---|
| `references/shell-contract.md` | writing or reviewing any section markup, panel, mockup, box flow or motion |
| `references/qa.md` | deciding whether a change passes, or briefing a subagent to write a section |

Assets (logos, icon cells, mascot cuts) are the `deck-assets` skill. Rule copies are refreshed by
`deck-sync`.
