---
name: ingest-finding
description: Use after producing a new audit md, after merging a PR with non-obvious findings, or when a debugging session uncovers lore worth saving. Pulls the finding into `.claude/wiki/` with reversible diff-log + multi-page cross-update. Universal — works in any repo with `.claude/wiki/`.
---

# ingest-finding

The wiki is only useful if it stays current. Conversations end, audit mds accumulate in `docs/research/audits/` (or equivalent), PRs land — without an ingest step the wiki freezes. Use this skill to bring new evidence into the wiki layer.

> Ships with `llm-wiki` plugin; install via marketplace. Operates on the current repo's `.claude/wiki/`.

## When to use

- A new audit md just landed
- A PR resolved a tricky bug — the *cause* is non-obvious from the diff
- A debugging session uncovered behavior (e.g. provider quirk, race condition) not yet in the wiki
- An invariant changed and a rule + wiki need to be re-synced

## Core patterns

### Prefer updating existing pages over adding new ones

Karpathy's original observation: **one finding usually touches 10–15 wiki pages** via cross-references, not just one. Append-only wiki growth (the "junk drawer" rot mode) appears when every new finding becomes a new page. Before adding a page:

- Grep `wiki/index.md` aliases + page bodies for the concept
- Ask "is there an existing page whose scope this *refines* or *contradicts*?" If yes, edit it
- Only add a new page if the finding introduces a new top-level concept inside an existing `wiki/<domain>/`

### Reversible diff-log discipline

Silent corruption mode (LLM edits a stale page without noticing): rare but catastrophic. Mitigation — **always log the diff before applying it**:

1. Compose the wiki page change as a unified diff in your head
2. Append a `## YYYY-MM-DD — <one-line summary> (ingest-finding)` entry to `wiki/log.md` **first**, including the diff summary (file paths + 1-line description of each change)
3. Apply the page edit
4. If something breaks, `git revert` the commit that includes both log + page changes — both stay in sync

This is cheap and gives `git log wiki/log.md` as the single audit trail.

## Steps

1. **Read the source of the finding** (audit md / PR diff / debug notes).
2. **Map to wiki pages**: search `wiki/index.md` + grep page bodies. Identify all pages the finding affects — usually 1 primary + 2-5 cross-ref updates. List them.
3. **Compose diff log entry**: draft the `wiki/log.md` block now, listing every page you're about to touch.
4. **Apply changes page-by-page**:
   - **If editing an existing page**:
     - Update the relevant section.
     - Bump `last_verified: YYYY-MM-DD` in frontmatter.
     - Add the new evidence under `## Sources`.
   - **If adding a new page** (only after step 2 confirms no existing page fits):
     - Place under correct `wiki/<domain>/` (2-depth max — don't make a new dir unless explicitly approved).
     - Use full frontmatter (`id`, `aliases`, `last_verified`).
     - End with `## Sources` citing the raw evidence.
     - Add a one-line entry to `wiki/index.md` under the matching domain heading.
5. **Update cross-refs**: any page that previously linked to or contradicted the updated page may need a touch. Use typed grammar (`> Refines:` / `> Contradicts:` / `> Evidence:` / `> See-also:`), never raw `[[wikilink]]`.
6. **Decide if `rules/` needs an update**:
   - If the finding turns a previously-soft pattern into a hard test-pin → also update the matching `rules/*.md` invariant section.
   - Otherwise rules/ stays out of it (lore goes to wiki, not rules).

## LLM autonomy boundaries

| Action | LLM alone | Needs user confirm |
|---|---|---|
| Update existing page body | ✅ (after diff log) | — |
| Bump `last_verified:` after actually re-checking against code | ✅ | — |
| Add new page inside existing `wiki/<domain>/` | ✅ | — |
| Add new `wiki/<domain>/` directory | ❌ | ✅ |
| Delete or merge pages | ❌ | ✅ |
| Resolve a `> Contradicts:` link (pick a winner) | ❌ | ✅ |
| Change a `rules/` invariant | ❌ (alert only) | ✅ |
| Cross-ref insertion/update | ✅ (typed grammar) | — |
| Append to `wiki/log.md` | ✅ (always) | — |

## Verification

- New/edited page appears in `wiki/index.md` under correct domain heading
- `last_verified:` is today
- `## Sources` cites raw evidence (not copies it)
- Cross-references use typed grammar (`Refines:` / `Contradicts:` / `Evidence:` / `See-also:`), no raw `[[wikilink]]`
- `wiki/log.md` has a new entry that lists *every* page touched in this ingest (not just the primary)

## Anti-patterns

- **Copying audit-md contents verbatim** — wiki *synthesizes*; raw belongs in audits dir.
- **Single-page ingest** when the finding touches multiple pages → cross-refs go stale silently.
- **New page for every finding** → append-only rot. Update existing pages first.
- **3rd-depth directory** without approval — wiki is 2-depth (domain/page) by design.
- **Edit without log entry first** — silent corruption risk; no audit trail.

## See also

> All wiki events (lint reports, ingest summaries, post-merge ingests) accumulate in `.claude/wiki/log.md` with schema header `## YYYY-MM-DD — <event-type> (<source-skill>)`.
