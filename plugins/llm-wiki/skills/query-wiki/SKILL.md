---
name: query-wiki
description: Use when you need domain lore (provider quirks, design rationale, debugging stories, module maps) that isn't a code invariant. Start with the project's wiki MOC before grepping the codebase. Universal — works in any repo that has `.claude/wiki/`.
---

# query-wiki

The wiki at `.claude/wiki/` is the lore layer — LLM-maintained domain knowledge that doesn't belong in rules (invariants) or code (mechanism). Use this skill when something is *known but not enforced*.

> Ships with `llm-wiki` plugin; install via marketplace. Targets whatever `.claude/wiki/` exists in the current working directory's repo. If no `.claude/wiki/` exists, suggest `/llm-wiki:bootstrap-wiki` instead.

## When to use

- "Why does provider X return null on big inputs?" → look in `wiki/<backend-domain>/<provider>.md`
- "What's the difference between configurations A and B?" → `wiki/<experiment-or-config-domain>/`
- "What does module Y do?" → `wiki/code-map/<module>.md`
- Any "why" question that the diff or grep alone can't answer

## Steps

1. **Read `.claude/wiki/index.md` first.** It's the MOC — every page listed with a 1-line hook. Skim hooks; pick page(s). If `index.md` is missing, the wiki layer is not initialized — suggest `/llm-wiki:bootstrap-wiki`.
2. **Read the matching page(s).** Each page is a single concept, ≤5KB.
3. **Follow typed cross-refs.** `> Refines: [[id]]` means deeper detail; `> Contradicts: [[id]]` means conflict to resolve before action; `> Evidence: docs/...md` means raw audit citation; `> See-also: [[id]]` is lateral.
4. **Check `last_verified:` frontmatter.** Older than ~60 days = treat as possibly stale; verify against code before acting on the lore. Soft-hint hook may already have flagged it.
5. If the wiki doesn't cover what you need, the answer is either in code (grep), in rules (invariants), or genuinely missing → trigger `/llm-wiki:ingest-finding` after you figure it out.

## Verification

- Did you start at `wiki/index.md` rather than guessing a filename? If you guessed, you may have missed related pages.
- Did you cite the wiki page (not the underlying audit md) when explaining to the user? Audits are immutable raw; wiki is the synthesized statement.

## What NOT to do

- Don't add a recommendation from memory or a rule when the wiki has a more recent page. Wiki + `last_verified:` is the authoritative summary.
- Don't `Read` the audit md directly to answer a "why" question unless wiki specifically says it's incomplete. The synthesis is the point.
- Don't quote the same lore in multiple places. If a page covers it, link to it.

## See also

> All wiki events (lint reports, ingest summaries, post-merge ingests) accumulate in `.claude/wiki/log.md` with schema header `## YYYY-MM-DD — <event-type> (<source-skill>)`.
