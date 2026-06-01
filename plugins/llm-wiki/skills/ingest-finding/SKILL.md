---
name: ingest-finding
description: Use after producing a new audit md, after merging a PR with non-obvious findings, or when a debugging session uncovers lore worth saving. Pulls the finding into the wiki with reversible diff-log + multi-page cross-update. Universal — works in any repo with a `.llmwiki/wiki/` or legacy `.claude/wiki/`.
---

# ingest-finding

The wiki is only useful if it stays current. Conversations end, audit mds accumulate in `.llmwiki/raw/` (or `docs/research/audits/`, or equivalent), PRs land — without an ingest step the wiki freezes. Use this skill to bring new evidence into the wiki layer.

> Operates on the repo's wiki root, resolved in order: `.llmwiki/wiki/` (preferred) →
> `.claude/wiki/` (legacy) → `.codex/wiki/` (legacy Codex fork). Examples below use
> `.llmwiki/wiki/`; substitute the legacy path if that is what the repo has.

> Ships with `llm-wiki` plugin; install via marketplace.

## When to use

- A new audit md just landed
- A PR resolved a tricky bug — the *cause* is non-obvious from the diff
- A debugging session uncovered behavior (e.g. provider quirk, race condition) not yet in the wiki
- An invariant changed and a rule + wiki need to be re-synced

## Core patterns

### Consolidate, don't append (governing rule)

Ingest is **not** an append operation. Before writing anything, dedup and decide whether this is an update, a supersede, or (last resort) a new page. Naive accumulation — a new page or a new paragraph for every finding — is the dominant rot mode ("naive accumulation → bloat"): the wiki swells, cross-refs go stale, and the synthesis value collapses into a junk drawer. Every ingest must leave the wiki *more consolidated*, not just *longer*.

The dedup gate, run before any add:

- Grep `index.md` aliases + page bodies + `id:`/`aliases:` for the concept.
- If an existing page's scope this *refines* / *contradicts* / extends → **edit that page** (or supersede it), don't add.
- Condense to the claim; push long reasoning down to `> Evidence:` (a `.llmwiki/raw/` or external citation), never inline a wall of justification.
- Only add a new page if the finding is a genuinely new top-level concept inside an existing `wiki/<domain>/`.

### Prefer updating existing pages over adding new ones

Karpathy's original observation: **one finding usually touches 10–15 wiki pages** via cross-references, not just one. Append-only wiki growth (the "junk drawer" rot mode) appears when every new finding becomes a new page. Before adding a page:

- Grep `index.md` aliases + page bodies for the concept
- Ask "is there an existing page whose scope this *refines* or *contradicts*?" If yes, edit it
- Only add a new page if the finding introduces a new top-level concept inside an existing `wiki/<domain>/`

### Supersede over overwrite (lifecycle)

When a finding *contradicts* an existing claim that still has historical value, do NOT silently overwrite it. Preserve the lifecycle:

- Create a new page (or a new section) carrying the corrected claim, and add `> Supersedes: [[old-id]]` to it.
- Mark the old page `status: stale` in frontmatter and add `> Superseded-by: [[new-id]]` to it. Stale pages are KEPT, marked, linked, timestamped — never deleted.

For simple refinements/additions (no contradiction, or the old claim has no standalone historical value), still edit in place — that is the existing behavior.

### Reversible diff-log discipline

Silent corruption mode (LLM edits a stale page without noticing): rare but catastrophic. Mitigation — **always log the diff before applying it**:

1. Compose the wiki page change as a unified diff in your head
2. Append a `## YYYY-MM-DD — <one-line summary> (ingest-finding)` entry to the resolved root's `log.md` **first**, including the diff summary (file paths + 1-line description of each change)
3. Apply the page edit
4. If something breaks, `git revert` the commit that includes both log + page changes — both stay in sync

This is cheap and gives `git log log.md` (at the resolved root) as the single audit trail.

## Steps

1. **Read the source of the finding** (audit md / PR diff / debug notes).
2. **Map to wiki pages**: search `index.md` + grep page bodies. Identify all pages the finding affects — usually 1 primary + 2-5 cross-ref updates. List them.
3. **Compose diff log entry**: draft the resolved root's `log.md` block now, listing every page you're about to touch.
4. **Apply changes page-by-page**:
   - **If editing an existing page**:
     - Update the relevant section.
     - Bump `last_verified: YYYY-MM-DD` in frontmatter.
     - Add the new evidence under `## Sources`, then set `sources:` to the new count of `## Sources` entries.
   - **If adding a new page** (only after step 2 confirms no existing page fits):
     - Place under correct `wiki/<domain>/` (2-depth max — don't make a new dir unless explicitly approved).
     - Use full v2 frontmatter (`id`, `aliases`, `last_verified`, `status: active`, inferred `volatility:`, `sources:`).
       - `status:` defaults to `active`.
       - Infer `volatility:`: arch/design/decision lore → `stable` (180d window); bug/debug/quirk/transient lore → `volatile` (30d window); default `stable`.
       - `sources:` = the count of `## Sources` entries on the page.
     - End with `## Sources` citing the raw evidence (preferred path `.llmwiki/raw/<file>`, or external `docs/...`).
     - Add a one-line entry to `index.md` under the matching domain heading.
   - **If a finding contradicts a page with historical value**: apply the supersede pattern above — new page/section gets `> Supersedes: [[old-id]]`; old page gets `status: stale` + `> Superseded-by: [[new-id]]` (kept, not deleted).
5. **Update cross-refs**: any page that previously linked to or contradicted the updated page may need a touch. Use typed grammar — `> Refines:` / `> Contradicts:` / `> Evidence:` / `> See-also:` / `> Supersedes:` / `> Superseded-by:` / `> Uses:` / `> Depends-on:` / `> Caused-by:` / `> Fixed-by:` — never raw `[[wikilink]]`.
6. **Decide whether to graduate to `.llmwiki/insight/`** (the promoted cross-agent layer — NOT `.claude/rules/`):
   - The wiki is the default home. Graduate a finding up to `.llmwiki/insight/` **only when ALL four hold**:
     1. **Recurs across sessions** — observed in 2+ independent sessions/PRs, not a one-off.
     2. **Generalizable** — applies beyond the one file/bug that surfaced it.
     3. **Costly to violate** — getting it wrong breaks a build/release/reproducibility gate or wastes a review cycle.
     4. **Stabilized** — settled, not under active debate or still being designed.
   - Do NOT graduate: one-offs, undecided/contested points, things already known going in, or reusable *procedures* (those become a skill).
   - **Why insight, not `.claude/rules/`**: Codex never reads `.claude/rules/`, so a rule promoted there is invisible to half the toolchain. Insight lives at `.llmwiki/insight/` (neutral root) and reaches both agents via the `core-config` prompt-injection hook. llm-wiki no longer promotes lore to `.claude/rules/` at all. See `.llmwiki/insight/index.md`.
   - **Insight is consolidate-first too**: dedup against existing insight entries (`id`/`aliases`/body grep) before adding; prefer update/supersede; keep each entry to rule + apply-when + why, with the long story left in the wiki page via `promoted_from:` + `> Evidence:`.
   - When graduating, write the insight entry with the insight frontmatter (`tier: insight`, `promoted_from: [[wiki-id]]`, `evidence_count: N`, plus the standard `id`/`aliases`/`last_verified`/`status`/`volatility`/`sources`), add a hook to `.llmwiki/insight/index.md`, and log it in the diff-log block like any other page touch.
   - If nothing meets the bar, insight stays out of it (lore stays in the wiki).

## LLM autonomy boundaries

| Action | LLM alone | Needs user confirm |
|---|---|---|
| Update existing page body | ✅ (after diff log) | — |
| Bump `last_verified:` after actually re-checking against code | ✅ | — |
| Add new page inside existing `wiki/<domain>/` | ✅ | — |
| Supersede a page (new page `> Supersedes:` + old page `status: stale` + `> Superseded-by:`) | ✅ (after diff log) | — |
| Graduate a finding to `.llmwiki/insight/` (all 4 promotion criteria met) | ✅ (after diff log) | — |
| Add new `wiki/<domain>/` directory | ❌ | ✅ |
| Delete or merge pages | ❌ | ✅ |
| Resolve a `> Contradicts:` link (pick a winner) | ❌ | ✅ |
| Cross-ref insertion/update | ✅ (typed grammar) | — |
| Append to the resolved root's `log.md` | ✅ (always) | — |

## Output format

After applying the ingest, report:

1. The `log.md` block you appended FIRST (the diff log), as it appears in the resolved root's `log.md`.
2. A one-line per-page edit summary (page → what changed → `last_verified` / `status` / `sources` after).

```text
## YYYY-MM-DD — <one-line summary> (ingest-finding)

- <domain>/<page>.md: <1-line description of the change>
- <domain>/<other-page>.md: <1-line description of the cross-ref touch>
- index.md: <added/updated 1-line hook>
```

### Worked example

Source: a debug session found provider X returns `null` on inputs > 8 KB.

`log.md` block appended first:

```text
## 2026-05-29 — provider-x null on oversize inputs (ingest-finding)

- backend/provider-x.md: new page, status: active, volatility: volatile, sources: 1
- index.md: added backend/provider-x.md hook
```

Page-edit summary:

- `backend/provider-x.md`: created (id `provider-x`, `last_verified: 2026-05-29`, `status: active`, `volatility: volatile`, `sources: 1`), documents the >8 KB `null` quirk, `> Evidence: .llmwiki/raw/2026-05-29-provider-x-debug.md`.
- `index.md`: added a 1-line hook under the `backend` heading.

## Verification

- New/edited page appears in `index.md` under correct domain heading
- `last_verified:` is today
- New pages have `status: active`, an inferred `volatility:`, and `sources:` equal to the `## Sources` count
- `## Sources` cites raw evidence (not copies it)
- Cross-references use typed grammar (`Refines:` / `Contradicts:` / `Evidence:` / `See-also:` / `Supersedes:` / `Superseded-by:` / `Uses:` / `Depends-on:` / `Caused-by:` / `Fixed-by:`), no raw `[[wikilink]]`
- Superseded pages are `status: stale` + carry `> Superseded-by:` (kept, not deleted)
- The resolved root's `log.md` has a new entry that lists *every* page touched in this ingest (not just the primary)

## Anti-patterns

- **Copying audit-md contents verbatim** — wiki *synthesizes*; raw belongs in `.llmwiki/raw/` (or audits dir).
- **Single-page ingest** when the finding touches multiple pages → cross-refs go stale silently.
- **New page for every finding** → append-only rot ("naive accumulation → bloat"). Run the dedup gate; update/supersede existing pages first.
- **Silently overwriting a contradicted page with historical value** — supersede instead (new page `> Supersedes:`, old page `status: stale` + `> Superseded-by:`).
- **Promoting lore to `.claude/rules/`** — Codex can't read it. Graduate cross-agent rules to `.llmwiki/insight/` (all 4 criteria), surfaced via the prompt-injection hook.
- **Graduating one-offs to insight** — insight is the most consolidated layer; promote only recurring + generalizable + costly-to-violate + stabilized findings.
- **3rd-depth directory** without approval — wiki is 2-depth (domain/page) by design.
- **Edit without log entry first** — silent corruption risk; no audit trail.

## See also

> All wiki events (lint reports, ingest summaries, post-merge ingests) accumulate in the resolved wiki root's `log.md` (e.g. `.llmwiki/wiki/log.md`) with schema header `## YYYY-MM-DD — <event-type> (<source-skill>)`.
