# Rules Forge Plugin

**Generate and restructure CLAUDE.md systems with modular `.claude/rules/` delegation**

## Overview

Rules Forge helps create and maintain clean, modular CLAUDE.md
instruction systems. A single skill (`write-rules`) auto-detects
project state and branches into one of four modes:

- **NEW** — Generate a fresh CLAUDE.md system + initial `.claude/rules/*.md`
- **TIGHTEN** — Patch an existing small CLAUDE.md into Do/Don't shape
- **SPLIT** — Extract sections from a monolithic CLAUDE.md into modular rules
- **REORGANIZE** — Audit existing root + rules/ structure for drift

Aligned with Claude Code 2026 official docs: `.claude/rules/*.md`
auto-load with `paths:` glob scoping, 200-line root target, no
redundant `@import` directives.

## Skills

| Skill | Trigger | Purpose |
|-------|---------|---------|
| `write-rules` | `/rules-forge:write-rules` or natural language | Generate or restructure CLAUDE.md + `.claude/rules/` with auto mode detection |

**Auto-triggers** (natural language phrases the skill responds to):
- "rules 작성", "write rules"
- "generate claude.md", "create claude.md system"
- "restructure claude.md", "split claude.md", "modularize instructions"
- "organize project rules", "rules 분리"

## Assets

The skill ships with three asset categories under
`skills/write-rules/assets/`:

| Directory | Contents | When loaded |
|-----------|----------|-------------|
| `references/` | Verbatim KR excerpt of Claude Code's official memory docs (CLAUDE.md placement, `.claude/rules/`, auto-memory, AGENTS.md, troubleshooting) | On demand when user asks "why this structure" or skill needs to cite docs |
| `templates/` | Output skeletons — root CLAUDE.md, single rule file (Variants A/B), category catalog | Per mode execution |
| `examples/` | Four adapted reference rules from `codefactory-co/golden-rabbit-antigravity-v1` (Next.js Clean Architecture, Next.js Framework, Tech Stack: Supabase, SaaS Service Spec) | Per mode execution when tech stack matches |

Assets are loaded with the `Read` tool only when the skill needs them
— they don't enter context at session start.

## Output File Structure

The skill generates this canonical layout:

```
your-project/
├── CLAUDE.md                   # Root (≤200 lines target)
└── .claude/
    └── rules/
        ├── architecture.md     # path-scoped or always-load
        ├── framework.md        # path-scoped
        ├── tech-stack.md       # usually always-load
        └── ...                 # one per detected category
```

Optional companions the skill detects and hints about (but does not
generate):

- `AGENTS.md` — if present, skill suggests `@AGENTS.md` import line
- `CLAUDE.local.md` — skill hints about `.gitignore` pattern

## Output Conventions

### Root CLAUDE.md

- Project overview (1–2 sentences)
- Critical Rules (5–7 always-visible safety items)
- Quick Reference table (build / test / dev commands)
- Code Structure (brief, ≤10 lines)
- Rules section (plain text ToC pointing to `.claude/rules/*.md`)
- **No `@import` directives** — `.claude/rules/*.md` auto-loads

### Each `.claude/rules/*.md`

Follows the proven Role / Do / Don't / Examples / Source of Truth
shape (the same pattern this repo uses in
`.claude/rules/codex-bridge-sync.md`).

Variant A (path-scoped):
```yaml
---
paths:
  - "src/api/**/*.ts"
---
```

Variant B (always-load): no frontmatter at all.

## Integration with `claude-md-management`

Rules Forge handles **initial creation and major restructuring**.
The official `claude-md-management` plugin handles **ongoing
maintenance** — incremental rule additions, edits, and refactors.

Recommended workflow:

1. Initial setup → `write-rules` (mode = NEW)
2. Daily updates → `claude-md-management`
3. Major refactors → `write-rules` (mode = REORGANIZE or SPLIT)

## Version History

- **2.1.0** (2026-05-13) — Asset routing fixes (non-breaking)
  - Mode execution sections now cite `Read assets/*` inline at the
    first step (was: bottom-of-file `Assets Reference` table only).
    REORGANIZE / TIGHTEN / SPLIT no longer skip the bundled examples
    when a tech-stack signal is present.
  - Detection Logic adds `contentSignals` field (grep tags:
    `clean-arch`, `nextjs-framework`, `supabase`, `service-spec`)
    that drives which `assets/examples/*.md` the mode Reads. Signals
    do not affect mode selection.
  - Verify steps in every mode replaced prose checks with concrete
    bash commands (`wc -l`, `find`, `grep -c '^@\.claude/rules'`).
  - Added a Worked Example section showing REORGANIZE + Clean Arch
    signal flow end-to-end.
- **2.0.0** (2026-05-12) — BREAKING
  - Consolidated `rules-guide` skill + `generate` / `split` commands
    into a single `write-rules` skill with internal mode detection
  - Aligned output with Claude Code 2026 docs (200-line root cap,
    `paths:` glob scoping, no auto `@import` for `.claude/rules/`)
  - Added `assets/` directory with references / templates / examples
  - Removed `commands/` directory (commands merged into skills per
    docs change)
  - Migration: `/rules-forge:generate` and `/rules-forge:split` removed.
    Use `/rules-forge:write-rules` (or natural-language triggers).
- **1.0.0** (2026-02-14) — Initial release
