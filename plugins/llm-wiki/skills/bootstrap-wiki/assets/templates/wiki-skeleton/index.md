---
id: wiki-moc
aliases: [moc, table-of-contents, llms-txt]
last_verified: TODO-INITIAL-DATE
---

# Wiki Map of Content (MOC)

This file is the entry point for the LLM-maintained lore layer. Every wiki page is listed below with a 1-line hook. Pages live 2-depth max under `.llmwiki/wiki/<domain>/<page>.md`.

> **For LLMs**: when answering a "why" or "how" question that isn't a code invariant, read this file first, follow the hook to the right page, and cite the wiki page (not the underlying audit md). When you discover new lore, use `/ingest-finding` to update.

## Page frontmatter (mini-legend)

Every wiki page (not this MOC, not `log.md`) carries:

```yaml
---
id: <kebab-case-slug>          # unique page identity
aliases: [other-names]         # dedup / search keys
last_verified: YYYY-MM-DD      # bump ONLY after re-checking vs code/source
status: active                 # active | stale (stale = kept+marked, never deleted)
volatility: stable             # stable (180d window) | volatile (30d window); default stable
sources: 2                     # integer count of named provenance under ## Sources
---
```

"How sure" = source count + `last_verified` recency + presence of `> Contradicts:`. No numeric confidence floats.

## Cross-reference grammar

Pages link to each other using **typed** references only — never raw `[[wikilink]]`:

- `> Refines: [[page-id]]` — this page adds detail to another
- `> Contradicts: [[page-id]]` — points out a conflict (must be resolved before next edit)
- `> Evidence: .llmwiki/raw/<file>` — citation to immutable raw evidence (may also point at external `docs/...`)
- `> See-also: [[page-id]]` — related but independent
- `> Supersedes: [[page-id]]` — on the NEW page, points at the claim it replaces
- `> Superseded-by: [[page-id]]` — on the OLD page (paired with `status: stale`)
- `> Uses: [[page-id]]`
- `> Depends-on: [[page-id]]`
- `> Caused-by: [[page-id]]`
- `> Fixed-by: [[page-id]]`

## Maintenance ops

| Op | Skill | When |
|----|-------|------|
| Find | read `index.md` | "Where is the lore on X?" |
| Add | `ingest-finding` | New audit md / PR result / debugging finding |
| Health check | `lint-wiki` | Identity / level / relationship / staleness audit |

All wiki edits append one line to `log.md` (`## YYYY-MM-DD — <summary>` header).

## Domains

<!-- Add domain sections below. Each section is `## <domain>` followed by a bulleted list:
     `- [page-title](<domain>/<slug>.md) — 1-line hook` -->
