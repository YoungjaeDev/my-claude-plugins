---
id: wiki-moc
aliases: [moc, table-of-contents, llms-txt]
last_verified: TODO-INITIAL-DATE
---

# Wiki Map of Content (MOC)

This file is the entry point for the LLM-maintained lore layer. Every wiki page is listed below with a 1-line hook. Pages live 2-depth max under `.claude/wiki/<domain>/<page>.md`.

> **For LLMs**: when answering a "why" or "how" question that isn't a code invariant, read this file first, follow the hook to the right page, and cite the wiki page (not the underlying audit md). When you discover new lore, use `/ingest-finding` to update.

## Cross-reference grammar

Pages link to each other using **typed** references only — never raw `[[wikilink]]`:

- `> Refines: [[page-id]]` — this page adds detail to another
- `> Contradicts: [[page-id]]` — points out a conflict (must be resolved before next edit)
- `> Evidence: docs/.../audit.md` — citation to immutable raw evidence
- `> See-also: [[page-id]]` — related but independent

## Maintenance ops

| Op | Skill | When |
|----|-------|------|
| Find | `query-wiki` | "Where is the lore on X?" |
| Add | `ingest-finding` | New audit md / PR result / debugging finding |
| Health check | `lint-wiki` | Identity / level / relationship / staleness audit |

All wiki edits append one line to `log.md` (`## YYYY-MM-DD — <summary>` header).

## Domains

<!-- Add domain sections below. Each section is `## <domain>` followed by a bulleted list:
     `- [page-title](<domain>/<slug>.md) — 1-line hook` -->
