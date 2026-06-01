---
id: insight-moc
aliases: [insight-index, insight-toc, promoted-lore]
last_verified: 2026-06-01
---

# Insight Map of Content (MOC)

The **insight layer** is the promoted, cross-agent-visible top of the wiki. It holds the small set of findings that have earned graduation from `.llmwiki/wiki/` — recurring, generalizable, costly-to-violate, and stabilized. Both Claude Code and Codex read it (it lives under the neutral `.llmwiki/` root, never `.claude/rules/` which Codex cannot read), and the `core-config` `prompt_inject.sh` hook points every prompt here *first*, before the wiki MOC.

> **For LLMs**: consult this MOC before acting on remembered guidance. Entries are extremely condensed (rule + when-to-apply + why, a few lines). Follow `> Evidence:` / `promoted_from:` down to the wiki/raw page for the full story — never inline that detail back up here.

## Why a separate layer (not `.claude/rules/`)

Wiki findings used to graduate to `.claude/rules/`, but **Codex never reads `.claude/rules/`**, so half the toolchain missed promoted rules. Insight lives at `.llmwiki/insight/` and reaches both agents through the shared prompt-injection hook instead of Claude's `paths:`-glob auto-load. See `> See-also: [[insight-layer-via-hook]]` in the wiki design record.

## Entry frontmatter

Every insight page carries (extends the wiki schema):

```yaml
---
id: <kebab-case-slug>          # unique insight identity
aliases: [other-names]         # dedup / search keys
tier: insight                  # marks this as a promoted entry (vs a wiki page)
promoted_from: [[wiki-id]]     # the wiki page(s) this was graduated from
evidence_count: 2              # distinct sessions/PRs the pattern recurred across
last_verified: YYYY-MM-DD      # bump ONLY after re-checking vs code/source
status: active                 # active | stale (stale = kept+marked, never deleted)
volatility: stable             # stable (180d window) | volatile (30d window)
sources: 2                     # integer count of named provenance under ## Sources
---
```

There is no freeform `tags:` field — the `> Evidence:` link to the source page *is* the tag.

## Promotion criteria (graduate a wiki finding only when ALL hold)

1. **Recurs across sessions** — seen in 2+ independent sessions/PRs, not a one-off.
2. **Generalizable** — applies beyond the single file/bug that surfaced it.
3. **Costly to violate** — getting it wrong breaks a build/release/reproducibility gate or wastes a review cycle.
4. **Stabilized** — settled, not under active debate or still being designed.

Do NOT promote: one-offs, undecided/contested points, things already known before the project, or reusable *procedures* (those become a skill, not an insight).

## Consolidation discipline (non-append)

Insight is the most aggressively consolidated layer. Before adding an entry: grep `id`/`aliases`/bodies for the concept; prefer **update / supersede** over a new entry; keep each entry to its rule + apply-when + why and push longer reasoning down to `> Evidence:`. Naive accumulation here is worse than in the wiki — bloat at the top defeats the point of a promoted layer.

## Entries

<!-- No insights promoted yet. Graduate findings here via `/llm-wiki:ingest-finding`
     (its graduation step), one entry per `## <id>` heading with a 1-line hook:
     `- [title](<slug>.md) — rule + when-to-apply (promoted_from [[wiki-id]])` -->
