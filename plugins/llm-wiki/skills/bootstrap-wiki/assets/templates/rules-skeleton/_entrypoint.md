# Entrypoint — .claude/ Layout

Universal rule — always loaded. Navigates the 3-layer system.

## The 3 layers

| Layer | Path | Loaded? | Purpose |
|-------|------|---------|---------|
| **Schema** | `.claude/rules/*.md` | auto (universal or path-scoped via `paths:` frontmatter) | **Trip-wire invariants only** — things that break tests / release / reproducibility if violated |
| **Wiki (lore)** | `.claude/wiki/**/*.md` | on-demand via `/query-wiki` skill or direct read | LLM-maintained domain knowledge: provider quirks, debugging stories, design rationale, module maps |
| **Raw evidence** | external (audit reports, design docs, git history) | direct read | Append-only audit reports. Wiki cites these — never duplicates |

Karpathy LLM-Wiki analogy: rules = `__init__.py` public contract, wiki = module docstrings + design notes, skills = CLI subcommands.

## When to read which

- "How does X work?" → `wiki/index.md` first (MOC). Then page-level read.
- "Why does the test fail?" → rule file's invariant section. If absent, `wiki/<domain>/`.
- "How do I run / build / deploy?" → `.claude/skills/<workflow>/SKILL.md` via Skill tool.
- "What's in this repo?" → `rules/code-map.md` (1-depth tree). Module-level: `wiki/code-map/`.

## Wiki conventions

Every page has frontmatter:

```yaml
---
id: <kebab-case-slug>
aliases: [other-names-for-same-concept]
last_verified: YYYY-MM-DD
---
```

Cross-references are **typed**, never raw `[[wikilink]]`:

- `> Refines: [[page-id]]` — this page adds detail to another
- `> Contradicts: [[page-id]]` — points out a conflict (must be resolved before next edit)
- `> Evidence: docs/.../audit.md` — citation, not copy
- `> See-also: [[page-id]]` — related but independent

Pages live 2-depth max under `wiki/`. New top-level domain dirs need a brief in PR review.

## Maintenance ops

| Op | Skill (user-global) | When |
|----|--------------------|------|
| Find | `query-wiki` | "Where is the lore on X?" |
| Add | `ingest-finding` | New audit md / PR result / debugging finding |
| Health check | `lint-wiki` | Identity / level / relationship / staleness audit |
| Cross-repo setup | `bootstrap-wiki` | New repo without `.claude/` |
| PR → wiki chain | `post-merge-wiki` | After `github-dev:post-merge` |

All wiki edits append a one-line event to `wiki/log.md` (`## YYYY-MM-DD — <summary>` header).

## Schema rule files

Universal (always loaded):
- `_entrypoint.md` — this file
- `code-map.md` — 1-depth `src/` tree
- (add `commands.md` if the project has 3+ critical command runbooks)

Path-scoped (loaded when matching files are in context): create one rule file per major domain, with a `paths:` frontmatter glob.

For per-domain debugging lore, open `wiki/<domain>/` — not the rule file.
