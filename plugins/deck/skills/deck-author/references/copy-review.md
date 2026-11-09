# Copy review

The brief for the separate copy reviewer of `deck-author` step 2, and for the optional `humanize-korean` pass after it. The main session hands this file to the reviewer agent.

## What the reviewer reads

- `.claude/rules/deck-copy.md`, `.claude/rules/deck-authoring.md` and `.claude/rules/korean-style.md`.
- `.claude/rules/deck-report.md` when present.
- The before/after case table in `.claude/rules/deck-local.md` when present. The cases win where they and a principle read differently.

The reviewer skips the 금지 표기 tables of `deck-copy.md` and `deck-local.md` (`check_copy.py` covers them) and applies the `deck-report.md` vocabulary table itself.

## Per-slide judgement

It judges every sentence of those slides (title, label, lead, items and the text inside figures and mockups) and the slide's form against these rules:

- an explanation slide drawn as a picture, mockup or motion before a text list;
- a service flow in the stack-diagram look;
- a capture title naming the screen plainly;
- a chat capture redrawn as a mockup when its content is the point;
- a gloss on each technical term and an everyday analogy for a development concept when the audience has no development background;
- a number that says what it counts;
- a deck title or section name that names what is learned ("does this title alone say what the audience learns?");
- a panel button name that says what opens;
- case-person voice only on case slides, never on a section-cover lead or a practice goal;
- in a report deck, no `.statement` slide without evidence and no 1st-person narration.

## Report deck as a whole

A report deck is also judged as a whole against `deck-report.md`. Report deck-level misses before the per-slide hits.

- The first section explains the domain (topic tree, question examples, what each source tells) before any result.
- A system or procedure is shown by one real input carried end to end.
- No `.hero-num` slide without a preceding example or figure of what was counted, and audit counts sit in the appendix.
- No internal work name (잠정 승인, 유닛, 회귀 평가, 감사) on a body slide without the audience's word for it.
- An AI product has a system-prompt summary slide with the original in a panel.

## What it returns

Per slide ID:

- each hit: the original sentence or slide form, the rule or case it hits, one fix;
- the first question a newcomer would ask on that slide, and whether the slide answers it;
- technical statements that need a source, and any that a second "why?" would show as wrong.

Apply the fixes to the outline, then show the user.

## humanize-korean pass

When the `humanize-korean` plugin is installed, run it after the content is settled, as a second reviewer for what the regex checks miss (long chained clauses, stacked modifiers, vague verbs, paired parallel clauses, transformation formulas).

- **Input**: only visible slide copy extracted from `deck/outline.md` (title, sub, lead, line under a figure, list items, card text), one field per line, slides separated by a blank line. Panel prompts, logos, buttons and mockup text stay out. A separate `map.json` ties each line to its slide ID and field; never put IDs into the input text.
- **Mode**: run strict (heavy) once for a whole-deck pass, fast (light) on a whole section after later edits. Give `--run-dir` a scratch path so the repo stays clean.
- **Priority** when advice conflicts: facts and instructor instructions, then `deck-local.md`, then `deck-report.md` in a report deck, then `deck-copy.md` and its 금지 표기 table, then `korean-style.md`, then humanize-korean.
- **Take**: long clauses split (E-5), stacked modifiers (A-18), vague verbs (A-15), noun-clause subjects (D-5), paired parallels (C-8), transformation formulas (D-7), parenthetical noise (J-4).
- **Reject**: lists turned into prose (C-2), long-sentence mixing (E-1, E-4), ending variety across list items (E-2), removing a metaphor the outline fixes for the deck (D-14), title noun endings (A-13), any change to product names, menu text, `==mark==` or ` / ` notation, and any line that no longer fits one 1920px line.
- **Apply**: show the instructor a per-slide take/reject table; apply only the chosen lines to the outline, then to the sections, and re-run the copy and outline checks.
