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
- `.claude/rules/deck-design.md`: the deck template's brand, palette and mascot rules (missing in an older deck: run `deck-sync`).
- `.claude/rules/korean-style.md`: Korean sentence verdicts.
- `.claude/rules/deck-report.md`, present only in a report deck (`- deck_kind: report` in the outline
  header): report vocabulary, presenter voice, statement slides.
- `deck/outline.md`: the header (deck thesis, sections, files, command source file) and the rows for
  the slides you touch.
- `references/shell-contract.md`: the markup contract. Read the parts for the slide types you write.

If the rule copies are missing from `.claude/rules/`, the repo was not set up with `deck-new`/`deck-sync`;
read the originals in this plugin's `templates/rules/` and tell the user.

## Procedure

1. **Outline first** (deck-authoring "원고가 기준"): change `deck/outline.md`, then carry its title and
   body text into the section verbatim. In a `ralphdev-light` deck, when the outline is first shown
   (new deck or a section rework), propose an icon count (one per section cover plus each concept
   slide that opens a topic, rounded up to a 9-cell sheet) and ask the user before the draft is
   settled; `deck-design.md` gives the rule. Record the answer in the outline header
   (`- 아이콘: <N개, 시트 M장 | 없음>`) so `deck-assets` step 1 starts from it.
2. **Copy review** before the draft goes to the user, run by a separate reviewer agent so the author
   does not grade its own draft. Who starts the reviewer depends on the session:
   - A session that can spawn a subagent (the main session) starts the reviewer itself.
   - A session that cannot (an author running as a subagent) finishes the draft in the outline, then
     stops and returns `검토 대기: <slide IDs>` with the outline path. The caller starts the reviewer
     with the brief below and hands the result back, or applies it itself.

   Every draft reaches the user with a review result or under `검토 대기`; the report names which.
   The reviewer reads `.claude/rules/deck-copy.md`, `.claude/rules/deck-authoring.md`,
   `.claude/rules/korean-style.md`, `.claude/rules/deck-report.md` when present, and the
   before/after case table in `.claude/rules/deck-local.md` when present (the cases win where they and
   a principle read differently). It judges every sentence of those slides (title, label, lead, items
   and the text inside figures and mockups) and the slide's form against these judgement rules:
   an explanation slide drawn as a picture, mockup or motion before a text list; a service flow in the
   stack-diagram look; a capture title naming the screen plainly; a chat capture redrawn as a mockup
   when its content is the point; a gloss on each technical term and an everyday analogy for a
   development concept when the audience has no development background; a number that says what it
   counts; a deck title or section name that names what is learned ("does this title alone say what
   the audience learns?"); a panel button name that says what opens; case-person voice only on case
   slides, never on a section-cover lead or a practice goal; in a report deck, no `.statement` slide
   without evidence and no 1st-person narration.
   A report deck is also judged as a whole against `deck-report.md`: the first section explains the
   domain (topic tree, question examples, what each source tells) before any result; a system or
   procedure is shown by one real input carried end to end; no `.hero-num` slide without a preceding
   example or figure of what was counted, and audit counts sit in the appendix; no internal work name
   (잠정 승인, 유닛, 회귀 평가, 감사) on a body slide without the audience's word for it; an AI product
   has a system-prompt summary slide with the original in a panel. Report deck-level misses before
   the per-slide hits.
   It returns, per slide ID:
   - each hit: the original sentence or slide form, the rule or case it hits, one fix;
   - the first question a newcomer would ask on that slide, and whether the slide answers it;
   - technical statements that need a source, and any that a second "why?" would show as wrong.
   The reviewer skips the 금지 표기 tables of `deck-copy.md` and `deck-local.md` (`check_copy.py`
   covers them) and applies the `deck-report.md` vocabulary table itself. Apply the fixes to the
   outline, then show the user.
   When the `humanize-korean` plugin is installed, run it after the content is settled, as a second
   reviewer for what the regex checks miss (long chained clauses, stacked modifiers, vague verbs,
   paired parallel clauses, transformation formulas):
   - Input: only visible slide copy extracted from `deck/outline.md` (title, sub, lead, line under a
     figure, list items, card text), one field per line, slides separated by a blank line. Panel prompts,
     logos, buttons and mockup text stay out. A separate `map.json` ties each line to its slide ID and
     field; never put IDs into the input text.
   - Run strict (heavy) once for a whole-deck pass, fast (light) on a whole section after later edits.
     Give `--run-dir` a scratch path so the repo stays clean.
   - Priority when advice conflicts: facts and instructor instructions, then `deck-local.md`, then
     `deck-report.md` in a report deck, then `deck-copy.md` and its 금지 표기 table, then `korean-style.md`, then humanize-korean.
   - Take: long clauses split (E-5), stacked modifiers (A-18), vague verbs (A-15), noun-clause subjects
     (D-5), paired parallels (C-8), transformation formulas (D-7), parenthetical noise (J-4).
   - Reject: lists turned into prose (C-2), long-sentence mixing (E-1, E-4), ending variety across list
     items (E-2), removing a metaphor the outline fixes for the deck (D-14), title noun endings (A-13),
     any change to product names, menu text, `==mark==` or ` / ` notation, and any line that no longer
     fits one 1920px line.
   - Show the instructor a per-slide take/reject table; apply only the chosen lines to the outline,
     then to the sections, and re-run the copy and outline checks.
3. **Write the section** per `references/shell-contract.md`, touching only the slides asked for.
4. **Motion** only where deck-authoring "흐름은 움직임으로" allows it, registered as the contract's
   Motion section describes.
5. **Check** with `deck-check` (build, copy check, render) and fix every finding.
6. **Look** at every rendered PNG of the changed slides against `references/qa.md`.
7. **Record corrections**: every wording or slide-form correction the user gives adds one row (slide,
   before, after, rule hit) to the case table in `.claude/rules/deck-local.md`, created on first use, in
   the same change that applies it. A correction that fits a fixed pattern also adds a row to that file's
   `### 덱 금지 표기` table so `check_copy` catches it next time; one that would hold for every deck goes
   to the plugin's rule originals instead.
8. **Report** the slide IDs changed, the files written, the copy review result (or the `검토 대기`
   slide IDs), and anything not verified. Deployment is not
   part of this skill (deck-authoring "원고가 기준", `deck-deploy`).

## References

| File | Read when |
|---|---|
| `references/shell-contract.md` | writing or reviewing any section markup, panel, mockup, box flow or motion |
| `references/mockups-motion.md` | writing a browser or phone mockup, a state change, or a hop motion |
| `references/qa.md` | deciding whether a change passes, or briefing a subagent to write a section |

Assets (logos, icon cells, mascot cuts) are the `deck-assets` skill. Rule copies are refreshed by
`deck-sync`.
