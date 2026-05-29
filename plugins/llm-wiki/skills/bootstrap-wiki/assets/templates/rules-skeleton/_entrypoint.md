# Entrypoint — Layout

Universal rule — always loaded. Navigates the 3-layer system.

## The 3 layers

| Layer | Path | Loaded? | Purpose |
|-------|------|---------|---------|
| **Schema** | `.claude/rules/*.md` | auto (universal or path-scoped via `paths:` frontmatter) | **Trip-wire invariants only** — things that break tests / release / reproducibility if violated |
| **Wiki (lore)** | `.llmwiki/wiki/**/*.md` | on-demand via `/query-wiki` skill or direct read | LLM-maintained domain knowledge: provider quirks, debugging stories, design rationale, module maps |
| **Raw evidence** | `.llmwiki/raw/**` (may also cite external audit reports, design docs, git history) | direct read | Append-only immutable evidence. Wiki cites these — never duplicates |

The wiki + raw layers live under the neutral `.llmwiki/` root (not under `.claude/`), so `codex-bridge`'s `.claude/`→`.codex/` body transform can never fork them per-agent. The schema layer stays at `.claude/rules/` — the only verified session-start auto-load path.

Karpathy LLM-Wiki analogy: rules = `__init__.py` public contract, wiki = module docstrings + design notes, skills = CLI subcommands.

## Resolution order

Skills and hooks resolve the wiki root in order: `.llmwiki/wiki/` (preferred) → `.claude/wiki/` (legacy) → `.codex/wiki/` (legacy Codex fork). New repos get `.llmwiki/`; old repos keep working until migrated (`/migrate-wiki`). Examples below use `.llmwiki/wiki/`; substitute the legacy path if that is what the repo has.

## Memory overlay

The system maps the 4-tier memory model onto existing artifacts — no new directories are created:

| Memory tier | Maps to (existing artifact) | Lifetime |
|-------------|-----------------------------|----------|
| Working | the current session (ephemeral) | this conversation |
| Episodic | `.llmwiki/wiki/log.md` (chronological event log) | append-only |
| Semantic | `.llmwiki/wiki/<domain>/*.md` (consolidated lore) | long-lived |
| Procedural | `.claude/skills/*/SKILL.md` (workflows) | long-lived |

## When to read which

- "How does X work?" → `wiki/index.md` first (MOC). Then page-level read.
- "Why does the test fail?" → rule file's invariant section. If absent, `wiki/<domain>/`.
- "How do I run / build / deploy?" → `.claude/skills/<workflow>/SKILL.md` via Skill tool.
- "What's in this repo?" → `rules/code-map.md` (1-depth tree). Module-level: `wiki/code-map/`.

## Wiki conventions

Every page (not `index.md`, not `log.md`) has frontmatter:

```yaml
---
id: <kebab-case-slug>          # unique page identity
aliases: [other-names]         # dedup / search keys
last_verified: YYYY-MM-DD      # bump ONLY after re-checking vs code/source
status: active                 # active | stale (stale = kept+marked, never deleted)
volatility: stable             # stable | volatile; default stable
sources: 2                     # integer count of named provenance under ## Sources
---
```

- `status` default `active`. A superseded page becomes `status: stale` + gains `> Superseded-by:`. Stale pages are KEPT, marked, linked, timestamped — never deleted.
- `volatility` default `stable`. `stable` (arch/design decisions) → 180-day staleness window; `volatile` (bug/transient/quirk) → 30-day window. Absent ⇒ treated as `stable`.
- `sources` = number of distinct provenance entries under the page's `## Sources` section. This replaces numeric confidence floats. "How sure" = source count + `last_verified` recency + presence of `> Contradicts:`.

Cross-references are **typed**, never raw `[[wikilink]]`:

- `> Refines: [[page-id]]` — this page adds detail to another
- `> Contradicts: [[page-id]]` — points out a conflict (must be resolved before next edit)
- `> Evidence: .llmwiki/raw/<file>` — citation, not copy (may also point at external `docs/...`)
- `> See-also: [[page-id]]` — related but independent
- `> Supersedes: [[page-id]]` — on the NEW page, points at the claim it replaces
- `> Superseded-by: [[page-id]]` — on the OLD page (paired with `status: stale`)
- `> Uses: [[page-id]]`
- `> Depends-on: [[page-id]]`
- `> Caused-by: [[page-id]]`
- `> Fixed-by: [[page-id]]`

Pages live 2-depth max under `wiki/`. New top-level domain dirs need a brief in PR review.

## Maintenance ops

| Op | Skill (user-global) | When |
|----|--------------------|------|
| Find | `query-wiki` | "Where is the lore on X?" |
| Add | `ingest-finding` | New audit md / PR result / debugging finding |
| Health check | `lint-wiki` | Identity / level / relationship / staleness audit |
| Cross-repo setup | `bootstrap-wiki` | New repo without `.claude/` |
| Migrate to v2 | `migrate-wiki` | Consolidate legacy `.claude/wiki/` + `.codex/wiki/` into `.llmwiki/` |
| PR → wiki chain | `post-merge-wiki` | After `github-dev:post-merge` |

All wiki edits append a one-line event to `wiki/log.md` (`## YYYY-MM-DD — <summary>` header).

## Schema rule files

Universal (always loaded):
- `_entrypoint.md` — this file
- `code-map.md` — 1-depth `src/` tree
- (add `commands.md` if the project has 3+ critical command runbooks)

Path-scoped (loaded when matching files are in context): create one rule file per major domain, with a `paths:` frontmatter glob.

For per-domain debugging lore, open `wiki/<domain>/` — not the rule file.
