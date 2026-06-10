---
name: query-wiki
description: Use as the verification gate BEFORE acting on remembered global/project guidance, provider quirks, design rationale, debugging stories, or module maps that aren't code invariants — check the wiki MOC first so you rely on the dated, sourced page instead of stale memory. Universal — works in any repo with a `.llmwiki/wiki/` or legacy `.claude/wiki/`.
---

# query-wiki

The wiki is the lore layer — LLM-maintained domain knowledge that doesn't belong in rules (invariants) or code (mechanism). Use this skill when something is *known but not enforced*, and as the gate you call to verify lore before relying on memory: before you act on something you "remember" from global or project guidance, confirm the wiki agrees and the page is current.

> Operates on the repo's wiki root, resolved in order: `.llmwiki/wiki/` (preferred) →
> `.claude/wiki/` (legacy) → `.codex/wiki/` (legacy Codex fork). Examples below use
> `.llmwiki/wiki/`; substitute the legacy path if that is what the repo has.

> Ships with `llm-wiki` plugin; install via marketplace. If no wiki root resolves, suggest `/llm-wiki:bootstrap-wiki` instead.

## When to use

- "Why does provider X return null on big inputs?" → look in `wiki/<backend-domain>/<provider>.md`
- "What's the difference between configurations A and B?" → `wiki/<experiment-or-config-domain>/`
- "What does module Y do?" → `wiki/code-map/<module>.md`
- Any "why" question that the diff or grep alone can't answer

## Steps

1. **Check `.llmwiki/insight/index.md` first (if present), then the wiki `index.md`.** Insight is the promoted, most-consolidated layer — the `core-config` prompt-injection hook already points both agents here first. If an insight entry covers your question, it is the authoritative condensed rule; follow its `promoted_from: [[wiki-id]]` down to the wiki page only when you need the full story. Then read the wiki MOC (`index.md` at the resolved root) — every page listed with a 1-line hook; skim hooks, pick page(s). If neither `index.md` exists, the layer is not initialized — suggest `/llm-wiki:bootstrap-wiki`.
2. **Read the matching page(s).** Each page is a single concept, ≤5KB.
3. **Follow typed cross-refs (authoritative grammar).** The typed token set — `> Refines:` / `> Contradicts:` / `> Evidence:` / `> See-also:` / `> Supersedes:` / `> Superseded-by:` / `> Uses:` / `> Depends-on:` / `> Caused-by:` / `> Fixed-by:` — is the only authoritative link form; never raw `[[wikilink]]`. Two gate action: `> Contradicts: [[id]]` is a conflict to resolve before acting; `> Superseded-by: [[id]]` redirects you to the active replacement. Per-token meanings: `references/wiki-conventions.md` § Cross-reference grammar.
4. **Check `status:` and `last_verified:` frontmatter.** If `status: stale`, the page is superseded — follow its `> Superseded-by: [[id]]` to the active replacement and read that instead. Then check `last_verified:`: older than the page's volatility window (stable 180d / volatile 30d) = treat as possibly stale; verify against code before acting on the lore. `volatile` (bug/transient) lore needs re-checking sooner; `stable` (design/rationale) lore stays trustworthy longer. Soft-hint hook may already have flagged it.
5. If neither insight nor wiki covers what you need, the answer is either in code (grep), in `.claude/rules/` (mechanical tool invariants — not wiki lore), or genuinely missing → trigger `/llm-wiki:ingest-finding` after you figure it out (it decides wiki vs insight graduation).

## Verification

- Did you start at `wiki/index.md` rather than guessing a filename? If you guessed, you may have missed related pages.
- Did you cite the wiki page (not the underlying audit md) when explaining to the user? Audits are immutable raw; wiki is the synthesized statement.

## What NOT to do

- Don't act on remembered global/project guidance without first checking whether the wiki has a more recent page. Wiki + `last_verified:` is the authoritative summary; memory is the thing being verified.
- Don't `Read` the audit md directly to answer a "why" question unless wiki specifically says it's incomplete. The synthesis is the point.
- Don't quote the same lore in multiple places. If a page covers it, link to it.

## See also

> All wiki events (lint reports, ingest summaries, post-merge ingests) accumulate in the resolved wiki root's `log.md` (e.g. `.llmwiki/wiki/log.md`) with schema header `## YYYY-MM-DD — <event-type> (<source-skill>)`.

## References

- Canonical frontmatter schema, cross-reference grammar (per-token meanings), resolution order, log.md discipline: `references/wiki-conventions.md`.
