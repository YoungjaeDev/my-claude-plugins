---
id: wiki-moc
aliases: [moc, table-of-contents, llms-txt]
last_verified: 2026-05-31
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
| Find | `query-wiki` | "Where is the lore on X?" |
| Add | `ingest-finding` | New audit md / PR result / debugging finding |
| Health check | `lint-wiki` | Identity / level / relationship / staleness audit |

All wiki edits append one line to `log.md` (`## YYYY-MM-DD — <summary>` header).

## Domains

<!-- Add domain sections below. Each section is `## <domain>` followed by a bulleted list:
     `- [page-title](<domain>/<slug>.md) — 1-line hook` -->

## llm-wiki-design

The v2 design record: which rohitg00-v2 ideas were harvested vs rejected, and why.

- [Curated-conservative v2 upgrade](llm-wiki-design/curated-conservative.md) — hub: harvest the git-auditable kernel of each v2 idea, reject the heavyweight machinery (steal the ideas, not the plan).
- [Neutral `.llmwiki/` root](llm-wiki-design/neutral-llmwiki-root.md) — wiki/raw move out of `.claude/` so codex-bridge's `.claude/`->`.codex/` body transform can never fork the wiki per-agent.
- [Volatility over decay](llm-wiki-design/volatility-over-decay.md) — a `volatility:` class with a fixed window replaces Ebbinghaus decay math; old is not stale.
- [Provenance over confidence](llm-wiki-design/provenance-over-confidence.md) — `sources: N` + a named `## Sources` list replaces fabricated float confidence.
- [Post-merge wiki trigger](llm-wiki-design/post-merge-trigger.md) — post-merge-wiki fires from two complementary triggers: github-dev:post-merge Step 5.8 (workflow + GitHub-UI merges) and the wiki_post_commit_hint hook (local CLI merges only).

## plugin-ops

Operational lore for the plugin system itself — cache, loading, version resolution. Complements the schema-layer version contract in `.claude/rules/plugin-versioning.md`.

- [Plugin cache version-pinning](plugin-ops/cache-version-pinning.md) — the cache holds multiple versions per plugin; a session pins the startup-resolved version, so a newer already-cached version is not served until restart (or via a `local` settings.json source).
- [Shared-source Codex manifests](plugin-ops/shared-source-codex-manifests.md) — Claude and Codex 0.135 read the same `plugins/<name>/skills/` tree via a thin manifest generator (`scripts/sync-codex-manifests.mjs`); the retired `codex-bridge` body-transform mirror was wrong because its 275 audit hits were authorial intent, not stale references.
