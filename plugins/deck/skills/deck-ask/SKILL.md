---
name: deck-ask
description: "Ask which deck skill fits right now and get a suggestion, not an action. Use on /deck:deck-ask, '덱 뭐 해', '덱 다음 단계', '덱 어떤 스킬', '덱 만드는 순서', '덱 작업 뭐부터', 'which deck skill', 'what next for the deck'. Reads where a house-format lecture deck (deck/shell.html + deck/sections/*.html) stands and suggests the next skill with one reason: deck-new, docs:interview-methodology for an unsettled thesis or outline, deck-assets, deck-author, deck-check, dev-server edit mode, deck-sync, deck-deploy on an explicit request only. Sends one-off generic talks and PPTX conversion to frontend-slides. Suggests only: runs no script and writes no file. For the GitHub issue flow use dev:flow."
---

# deck-ask

Suggest the next deck skill. Look, then answer in a few lines; the user or that skill acts.

## How to answer

1. Read only what tells the stage, cheapest first: does `deck/` exist, the `deck/outline.md` header
   and slide table, `git status --short deck/`, and the last `deck-check` output if it is in the
   conversation. Do not run builds or scripts.
2. Answer in this shape, in the user's language:

   ```text
   지금: <one line on where the deck stands>
   추천: /<plugin:skill> — <one reason tied to what you saw>
   대안: /<plugin:skill> — <when to pick it instead>   (only if a real alternative exists)
   ```

3. Stop. Do not start the suggested skill unless the user says so.

## House deck or not

- House deck: RALPHDEV lecture in a repo, `deck/shell.html` + `deck/sections/`, Vercel. Use the table.
- One-off generic talk, pitch, or PPTX conversion without the house shell: suggest `frontend-slides`.
- Both loaded in a house deck: `deck-author` and `.claude/rules/deck-authoring.md` win where they
  override `frontend-slides`.

## Situation → suggestion

| What you see | Suggest | Why |
|---|---|---|
| The request was dictated by voice and reads garbled | `docs:vp` | fix terms before choosing |
| No `deck/` yet, house format wanted | `deck-new` | scaffold + stamped rule copies |
| Thesis, audience or section list unsettled | `docs:interview-methodology` | decide before outlining; answers go to the outline header |
| Outline exists but needs stress-testing | `grilling` | Matt skill; change `deck/outline.md` first |
| Outline names tools or concept slides without assets | `deck-assets` | official logos, icon sheets, mascot cuts; confirms counts before spending quota |
| One image unrelated to the deck | `codex-image` | never for a brand logo |
| Slides to write or change | `deck-author` | outline first, then only the asked slides |
| Sections, shell, motions or assets changed since the last check | `deck-check` | build, copy check, rule drift, render, look at PNGs |
| `deck-check` said `rules: stale/missing/unstamped` or `vendor: differs` | `deck-sync` | never touches `deck-local.md` |
| `deck-check` said `rules: edited` | move deck-only lines to `.claude/rules/deck-local.md` | `deck-sync --force` only with the user's yes |
| User wants to look at the deck or fix wording by eye | dev-server edit mode (`deck-check` step 5) | text only; boxes cannot be moved yet |
| User reviewed locally and asked to deploy | `deck-deploy` | only on that request |
| A rule should change for every deck | edit the plugin's `templates/rules/`, then `deck-sync` per deck | one deck only: `deck-local.md` |
| A deck skill itself should change | `docs:skill-forge` | |

## Do not suggest

| Tempting | Instead |
|---|---|
| Deploy because the check passed | Deploy waits for the user's request every time. |
| Generate a logo with codex-image | Logos are collected official SVGs (`deck-assets`). |
| Fix the section now, the outline later | Outline first; edit-mode text goes back into the outline. |
| Another router's "ship" or "make-pdf" | In a house deck, deploy is `deck-deploy`; the PDF comes from `deck-check`'s render. |

## Verification

The answer names one suggested skill with a reason drawn from what was read, at most one
alternative, and nothing was run or written.
