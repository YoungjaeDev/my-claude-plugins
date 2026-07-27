---
name: anti-slop-design
description: "Anti-AI-slop design guard for websites/SaaS landing, presentation decks (PPT), dashboards/admin UI, and marketing/UI copy. Detects and blocks the AI-generated look before generation and audits it after: purple/gradient palettes, gradient text, Inter/Geist single-font pages, side-stripe cards, card-in-card, icon-tile 3-col grids, centered-hero macrostructure, fabricated metrics, emoji icons, over-animation, buzzword copy. Runs a clarify->context->plan->run->audit->revise flow with a two-phase audit gate (pre-emit self-critique + binary slop checklist) and hands Korean copy rewriting to humanize-korean. Triggers: 'AI 티 안 나게', 'slop 제거', 'anti-slop', '디자인 감사', '랜딩/덱/대시보드/카피 디자인', 'enterprise 디자인', 'make it not look AI-generated', 'audit this design', even when this skill is not named."
---

# anti-slop-design

## Hermes Agent Compatibility

When this skill is loaded through Hermes as `anti-slop-design:anti-slop-design`, map Claude/Codex tool names to Hermes tools:

| Claude/Codex term | Hermes tool |
|---|---|
| Read | read_file |
| AskUserQuestion | clarify |
| Skill | skill_view (list available via skills_list) |

Treat `$ARGUMENTS` as the natural-language arguments supplied when the user asks Hermes to load the skill. Installed into `~/.hermes/skills/` by `npx skills`, this skill is indexed automatically — it appears in `skills_list()` and as a slash command under its **flat** name `anti-slop-design`.

An enterprise anti-slop guard for building, auditing, or improving web/SaaS landings, presentation decks (PPT), dashboards/admin UI, and marketing/UI copy — it **blocks the AI-generated look (slop) before generation** and **audits it after**.

**Core proposition:** slop = the default that shows up regardless of the brief (**default-not-choice**). Every verdict reduces to "is this a choice for *this* brief, or a choice that would show up for *any* brief?" It asks not whether the color/font/layout is "pretty" but whether it is "a choice".

## When to use

- When **newly creating** the four artifacts above (a pre-generation Phase A gate + a post-generation Phase B gate).
- When **auditing/improving** an existing artifact ("check whether this landing looks AI-generated", "catch the slop in this deck").
- When dealing with AI-tells in copy — English is detected/scored here, but **Korean rewriting is delegated to humanize-korean**.

## What it does not do (scope)

- It is not a design "generator". It provides direction, structure, and gates; the actual implementation is done by the caller (or frontend-design, ppt-master, a taste-skill, etc.).
- No executable detection engine / edit-blocking hook — it only reports and recommends.
- Deck build execution (md->SVG->pptx) is done by the existing tools (ppt-master/codex-image). But the **generation-consistency and pre-delivery verification methodology** (per-slide parallelism + BUILDKIT, render-verification pitfalls) is anti-slop's domain — see `references/slop-taxonomy.md` §3 PPT lane.
- It does **not guess brand colors/fonts from memory**. If materials exist, read them; if not, use the `references/house-style.md` defaults; if still none, leave a placeholder and ask the user.

## Flow (clarify -> context -> plan -> audit(A) -> run -> audit(B) -> revise)

### 1. Clarify
Identify the artifact type (web / ppt / dashboard / copy), audience, brand, and decision context. If ambiguous, narrow it via `AskUserQuestion` and the 'interview skill'. No automatic assumptions.

### 2. Context
- Load the relevant lane rules (the lane sections of `references/slop-taxonomy.md`) + `references/house-style.md` + the VISUAL/STRUCTURAL sections of `references/slop-taxonomy.md`.
- If copy is in scope, load `references/copy-rules.md` too.
- If brand materials exist (logo/palette/screenshots), read them to fix the brand-spec; otherwise use the house-style defaults. **Do not invent colors.**

### 3. Plan
- No **vague direction** like "clean / modern / professional". Pick one concrete direction (e.g. enterprise editorial / technical minimal / research-lab calm / operator dashboard).
- Define the information hierarchy (primary/secondary/tertiary) first.
- **For visual artifacts, propose 2-3 directions and let the user pick one** (show-don't-tell). Do not push a single option.

### 4. Audit gate — Phase A (pre-generation)
Score the plan on 6 axes and pass it before emit (details → Phase A under "Audit gate (2 phases)" below).

### 5. Run
Produce the artifact (or write the spec to hand to the caller) using the chosen direction + lane rules + house-style defaults. Every ban has an **escape hatch**: an explicit requirement in the brief always wins (if the brand is purple, purple is allowed; if the audience is children, emoji are allowed, etc.). When you use an exception, state the reason on that line.

### 6. Audit gate — Phase B (pre-delivery)
The 12-item binary checklist below (required, details → Phase B under "Audit gate (2 phases)"). When copy is included, English is detected/scored via `references/copy-rules.md`, and **Korean prose rewriting is handed off to `humanize-korean:humanize-korean` (fast mode)**, recovering only the body of `final.md`.

### 7. Revise
Fix the items that failed the gate, then finalize. The output always includes:
1. the design direction used (concrete name)
2. the information hierarchy
3. the anti-slop decisions applied (what was avoided and why)
4. the artifact (or implementation spec)
5. remaining risks / trade-offs
6. gate results — the Phase A 6-axis scores (including the lowest axis) and, of the Phase B 12 items, which failed and how they were fixed (if all were "no", state so)

## Audit gate (2 phases)

Phase A = flow step 4 (right after Plan, before Run) · Phase B = flow step 6 (after Run, before delivery).

### Phase A — pre-generation self-critique (no tools needed, highest leverage)

**self-similarity probe:** "Is this the same choice I would make processing a similar brief in my head? If so, it is not a choice for *this* brief — replace it and note what changed and why."

Then score the plan on 6 axes, 1-5 points each. **If any axis is below 3, revise once before emit:**
1. **Philosophy** — is there a "why"/point of view, or is it just a layout?
2. **Hierarchy** — is primary/secondary/tertiary readable within 2 seconds?
3. **Specificity** — does it look like this brief, or like any-page?
4. **Restraint** — does every element earn its place? (Chanel's "take one accessory off")
5. **Variety** — is it structurally different from the last artifact? (changing only the color does not count)
6. **Honesty** — are invented metrics/testimonials/logos at 0?

Loop-termination heuristic: **"2 revisions is normal; at 3, it is the brief that is wrong, not the design."** On the third, stop and re-ask the brief.

### Phase B — pre-delivery binary checklist

12 items; **all answers must be "no" to pass**. Any "yes" = fix it (delivery blocked). Each item is a detector + fix pair.

| # | tell (answer must be "no") | fix |
|---|---|---|
| 1 | purple/rainbow/mesh gradient, or gradient text? | flat committed accent, no `bg-clip:text` |
| 2 | a single overused font (Inter/Roboto/Geist/Space Grotesk) / one-font page, or an italic serif/display header (h1-h6/hero/stat — the hallmark "top AI tell")? | deliberate display+body pairing, headers in roman weight |
| 3 | side-stripe card / card-in-card / icon-tile-above-heading 3-col grid / glassmorphism-as-default·purposeless shadow? | bg·weight contrast, remove the stripe, vary the cards, shadow only when elevation has meaning |
| 4 | cream-default / `#0D1117`-neon / pure `#000`·`#fff` base? | a committed palette tinted with an anchor hue |
| 5 | full-viewport centered hero / everything centered? | centered elements <=2, introduce asymmetry |
| 6 | decorative `01/02/03` numbers / an eyebrow chip on every section? | only when it is a real sequence, encoding content |
| 7 | generic Hero->3 features->testimonials->CTA->footer skeleton? | a brief-specific macrostructure |
| 8 | invented metrics / fake testimonials / placeholder names (Acme/Jane Doe), or a hero that is a big-number+small-label+supporting-stat template (even with real numbers)? | real numbers + real narrative, labeled placeholders, or a question |
| 9 | emoji as icons / mixed icon libraries? | one real icon set |
| 10 | hand-drawn figurative SVG / redrawn browser·phone·terminal chrome? | a real screenshot or a gray placeholder |
| 11 | over-animation / `transition-all` / uniform `hover:scale` / no `prefers-reduced-motion`? | one orchestrated moment + reduced-motion |
| 12 | copy: buzzwords / "Not X, it's Y" contrast / throat-clearing / invented specifics? | direct statements, then hand Korean to humanize-korean |

**numeric floor sweep** (auto-verifiable) — the 8 detail items (contrast·body font·type-scale·line-length·line-height·color count·touch target·accent footprint) with exact numbers are in the `references/slop-taxonomy.md` §4 Numeric floor sweep table (keeping only a summary in the body, per the no-duplication policy in "reference loading guide" below).

### gate mechanics
- Form the Phase A subjective judgment **before** the Phase B checklist (so the checklist does not anchor the critique).
- **Always** leave a self-describing stamp on the artifact (`<!-- anti-slop: A-pass · contrast ok · 1-12 no -->`) — it is the only after-the-fact evidence that Phase A/B actually ran, so never omit it.
- Every ban has an escape hatch — "an explicit requirement in the brief always wins". Note exceptions inline with a reason.

## reference loading guide

| Situation | Load |
|---|---|
| all visual work | `references/slop-taxonomy.md` (VISUAL + STRUCTURAL) |
| per-lane rules | the web / ppt / dashboard sections of `references/slop-taxonomy.md` |
| copy included | `references/copy-rules.md` (+ hand Korean to humanize-korean) |
| default suggestions | `references/house-style.md` |

Do not duplicate the detailed detector lists·numbers·examples in the body; pull them from the references via progressive disclosure.

## humanize-korean handoff (copy)

- Boundary: anti-slop-design owns visual/structural + **English copy detection·scoring**. humanize-korean owns **Korean prose rewriting**.
- Call: when Korean copy rewriting is needed, call `humanize-korean:humanize-korean` (fast mode by default, strict when >=8000 chars or precision is needed). Recover only the body of the output `final.md` (exclude the HTML-comment metadata).
- register: humanize matched to the artifact's presentation context (lecture/academic/pitch) in tone and manner — for an academic/expert audience, keep established technical terms (Korean gloss once on first appearance) and do not flatten to colloquial style (`copy-rules.md` §1).
- fallback (required): `humanize-korean` is an **external dependency** not bundled in this marketplace. In an environment where it is not installed (or under Codex), graceful-degrade so the lane does not stop without the call — **rewrite manually and directly** using the Korean-copy principles in `copy-rules.md`, preferring humanize-korean when present. Do not hard-require the dependency.
- prohibited: do not replicate stop-slop-style blunt absolute bans (a blanket ban on adverbs, a blanket ban on em-dashes, a ban on 3-item lists) in Korean — follow the global guide and humanize-korean's Korean-friendly relaxation stance.
