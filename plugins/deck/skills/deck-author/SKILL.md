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

- The rule copies in `.claude/rules/`: `deck-copy.md`, `deck-authoring.md`, `deck-design.md` (missing
  in an older deck: run `deck-sync`), `korean-style.md`, and `deck-report.md` in a report deck
  (`- deck_kind: report` in the outline header).
- `deck/outline.md`: the header and the rows for the slides you touch.
- `references/shell-contract.md`: the parts for the slide types you write.

If the rule copies are missing from `.claude/rules/`, the repo was not set up with `deck-new`/`deck-sync`;
read the originals in this plugin's `templates/rules/` and tell the user.

## Procedure

1. **Outline first** (deck-authoring "원고가 기준"): change `deck/outline.md`, then carry its title and
   body text into the section verbatim. In a `ralphdev-light` deck, when the outline is first shown
   (new deck or a section rework), propose an icon count (one per section cover plus each concept
   slide that opens a topic, rounded up to a 9-cell sheet) and ask the user before the draft is
   settled; `deck-design.md` gives the rule. Record the answer in the outline header
   (`- 아이콘: <N개, 시트 M장 | 없음>`) so `deck-assets` step 1 starts from it.
   - Ask with `AskUserQuestion` on Claude Code or `request_user_input` on Codex; when neither is
     available, leave the icon line out of the header and report the proposed count.
2. **Copy review** before the draft goes to the user, run by a separate reviewer agent so the author
   does not grade its own draft. Who starts the reviewer depends on the session:
   - A session that can spawn a subagent (the main session) starts the reviewer itself.
   - A session that cannot (an author running as a subagent) finishes the draft in the outline, then
     stops and returns `검토 대기: <slide IDs>` with the outline path. The caller starts the reviewer
     with `references/copy-review.md` and hands the result back, or applies it itself.

   The reviewer works from `references/copy-review.md` (what it reads, the judgement rules, the
   return shape, the optional `humanize-korean` pass). Every draft reaches the user with a review
   result or under `검토 대기`, and the report names which.
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
| `references/copy-review.md` | starting the step 2 copy reviewer, or running the `humanize-korean` pass |
