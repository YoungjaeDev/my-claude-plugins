---
id: insight-moc
aliases: [insight-index, insight-toc, promoted-lore]
last_verified: TODO-INITIAL-DATE
---

# Insight Map of Content (MOC)

The **insight layer** is the promoted, cross-agent-visible top of the knowledge system. It holds the small set of findings that earned graduation from `.llmwiki/wiki/`. Both Claude Code and Codex read it (it lives under the neutral `.llmwiki/` root), and the `core` `prompt_inject.sh` hook points every prompt here *first*, before the wiki MOC.

> **For LLMs**: consult this MOC before acting on remembered guidance. Entries are extremely condensed (rule + when-to-apply + why). Follow `promoted_from:` / `> Evidence:` down to the wiki/raw page for the full story — never inline that detail back up here.

## The layers

| Layer | Path | Loaded? | Purpose |
|-------|------|---------|---------|
| **Insight (promoted)** | `.llmwiki/insight/**` | via the `prompt_inject.sh` hook (Claude + Codex), every prompt | cross-agent promoted rules: recurring, generalizable, costly-to-violate, stabilized |
| **Wiki (lore)** | `.llmwiki/wiki/**` | on-demand direct read (start at `index.md`) | LLM-maintained domain knowledge: provider quirks, debugging stories, design rationale, module maps |
| **Raw evidence** | `.llmwiki/raw/**` (+ external docs) | direct read | append-only immutable evidence — wiki cites, never copies |

All three live under the neutral `.llmwiki/` root so no per-agent transform can fork them — one copy, both agents. `.claude/rules/` is **not** part of this system: it is reserved for mechanical tool-operation rules (Codex can't read it), so wiki lore is never promoted there. Cross-agent rules graduate to `.llmwiki/insight/` and reach both runtimes through the prompt-injection hook.

## Memory overlay

The 4-tier memory model maps onto existing artifacts — no extra directories:

| Memory tier | Maps to (existing artifact) | Lifetime |
|-------------|-----------------------------|----------|
| Working | the current session (ephemeral) | this conversation |
| Episodic | `.llmwiki/wiki/log.md` (chronological event log) | append-only |
| Semantic | `.llmwiki/wiki/<domain>/*.md` (consolidated lore) | long-lived |
| Procedural | `.claude/skills/*/SKILL.md` (workflows) | long-lived |

The structure/code map lives as a wiki page under `.llmwiki/wiki/code-map/` (not a `.claude/rules/` file).

## Entry frontmatter

Every insight page carries (extends the wiki schema):

```yaml
---
id: <kebab-case-slug>          # unique insight identity
aliases: [other-names]         # dedup / search keys
tier: insight                  # marks a promoted entry (vs a wiki page)
promoted_from: [[wiki-id]]     # the wiki page(s) this was graduated from
evidence_count: 2              # distinct sessions/PRs the pattern recurred across
last_verified: YYYY-MM-DD      # bump ONLY after re-checking vs code/source
status: active                 # active | stale (stale = kept+marked, never deleted)
volatility: stable             # stable (180d window) | volatile (30d window); default stable
sources: 2                     # integer count of named provenance under ## Sources
---
```

No freeform `tags:` field — the `> Evidence:` link to the source page *is* the tag.

## Promotion criteria (graduate only when ALL hold)

1. **Recurs across sessions** — 2+ independent sessions/PRs, not a one-off.
2. **Generalizable** — applies beyond the one file/bug that surfaced it.
3. **Costly to violate** — breaks a build/release/reproducibility gate or wastes a review cycle.
4. **Stabilized** — settled, not under active debate or still being designed.

Do NOT promote: one-offs, undecided/contested points, prior-knowledge, or reusable *procedures* (those become a skill).

## Cross-reference grammar (typed only — never raw `[[wikilink]]`)

- `> Refines: [[page-id]]` · `> Contradicts: [[page-id]]` · `> See-also: [[page-id]]`
- `> Evidence: .llmwiki/raw/<file>` (or external `docs/...`)
- `> Supersedes: [[page-id]]` / `> Superseded-by: [[page-id]]` (lifecycle)
- `> Uses:` / `> Depends-on:` / `> Caused-by:` / `> Fixed-by:`

## Maintenance ops

| Op | Skill | When |
|----|-------|------|
| Find | read `index.md` | "Where is the promoted/lore rule on X?" — check insight first, then wiki |
| Add / graduate | `ingest-finding` | new finding; its graduation step decides wiki vs insight |
| Health check | `lint-wiki` | identity / level / relationship / staleness + insight promotion integrity |

## Entries

<!-- No insights promoted yet. Graduate findings here via `/wiki:ingest-finding`,
     one entry per line: `- [title](<slug>.md) — rule + when-to-apply (promoted_from [[wiki-id]])` -->
