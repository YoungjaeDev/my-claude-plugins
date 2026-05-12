# rules-forge → write-rules Consolidation

**Date:** 2026-05-12
**Status:** Approved (brainstorm)
**Plugin:** `plugins/rules-forge/`
**Version bump:** 1.0.0 → 2.0.0 (breaking)

## Goal

Collapse the existing `rules-forge` plugin (1 skill `rules-guide` + 2 commands `generate`, `split`) into a single skill `write-rules` that internally branches across four operating modes. Align the plugin with current Claude Code 2026 documentation: `.claude/rules/*.md` auto-load semantics, 200-line CLAUDE.md target, `paths:` glob scoping, and the merge of custom commands into skills.

## Why

1. Users only need to learn one entry point. The two commands already delegate to the same skill; the surface is artificial.
2. Custom commands have been formally merged into skills in current Claude Code — a `SKILL.md` creates the slash command automatically, removing the need for a separate `commands/` file.
3. The current skill recommends `@import` directives, but the official docs say imported files are still fully loaded at startup, so `@import` provides no token savings versus `.claude/rules/*.md` auto-load. The skill output should reflect this.
4. Reference templates from external projects (golden-rabbit-antigravity-v1 ecommerce/saas) provide a richer category vocabulary (architecture, framework, tech-stack, service-spec) than the current default — adapting them into `assets/examples/` lifts output quality without expanding the skill's surface area.

## Scope

### In scope

- Single skill `write-rules` with internal mode detection
- `assets/` directory holding references (official docs), templates (output skeletons), and examples (adapted external rules)
- Hard removal of `skills/rules-guide/` and `commands/` directory
- Plugin v2.0.0 bump + marketplace.json sync
- Plugin doc (`plugins/rules-forge/CLAUDE.md`) update
- Root `CLAUDE.md` description sync if needed

### Out of scope

- AGENTS.md mirror generation (skill will *detect* AGENTS.md presence and hint, but not generate)
- PRD-style service-spec template generation by default (one example is included as inspiration only)
- `.gitignore` automation for `CLAUDE.local.md`
- Subagent skills, hooks, MCP integration
- claude-md-management plugin coordination changes
- Auto-memory directory management (Claude owns `~/.claude/projects/<proj>/memory/`)

## Architecture

### Final file layout

```
plugins/rules-forge/
├── .claude-plugin/plugin.json              v2.0.0
├── CLAUDE.md                                rewritten for single-skill surface
└── skills/
    └── write-rules/
        ├── SKILL.md                         single entrypoint, ≤500 lines
        └── assets/
            ├── references/
            │   └── claude-code-memory.md    Claude Code memory page (excerpt)
            ├── templates/
            │   ├── root-claude-md.md        root CLAUDE.md skeleton
            │   ├── rule-file.md             single .claude/rules/*.md skeleton
            │   └── rule-categories.md       category catalog with paths: hints
            └── examples/
                ├── nextjs-clean-arch.md     adapted from ecommerce/architecture.md
                ├── nextjs-framework.md      adapted from ecommerce/nextjs-framework.md
                ├── tech-stack-supabase.md   adapted from ecommerce/tech-stack.md
                └── saas-service-spec.md     adapted from saas/service.md
```

### Deletions

```
plugins/rules-forge/skills/rules-guide/      entire tree
plugins/rules-forge/commands/                entire directory (generate.md, split.md)
```

### Invocation paths

- Explicit slash: `/rules-forge:write-rules`
- Auto-trigger via skill description on phrases like:
  - "rules 작성", "write rules"
  - "generate claude.md", "create claude.md system"
  - "restructure claude.md", "split claude.md", "modularize instructions"
  - "organize project rules", "rules 분리"

Default invocation policy: both user and Claude can invoke. No `disable-model-invocation`.

## Components

### SKILL.md structure

```
---
name: write-rules
description: <multilingual trigger surface, prioritizing key use cases first>
allowed-tools: Read Write Edit Glob Grep Bash
---

# Write Rules

## Role
<one paragraph: AI Context Architect for CLAUDE.md systems>

## Modes
<table summarizing NEW / TIGHTEN / SPLIT / REORGANIZE with detection rules>

## Detection logic
<numbered steps: scan project state, propose mode, confirm via AskUserQuestion>

## Mode execution
### NEW
### TIGHTEN
### SPLIT
### REORGANIZE
<each subsection: 5–10 numbered steps, refers to assets/templates/*>

## Output conventions
<Do / Don't list: 200-line cap, no @import for rules/*, paths: scoping, Do/Don't structure>

## Post-generation hints
<auto-memory, CLAUDE.local.md, AGENTS.md coexistence — informational only>

## Assets reference
<table: when to Read each assets/ file>
```

### Mode detection logic

```
state = {
  hasClaudeMd:      exists("./CLAUDE.md") or exists("./.claude/CLAUDE.md")
  claudeMdLines:    wc -l on the file if present
  hasRulesDir:      exists("./.claude/rules/") and contains *.md
  rulesFileCount:   count of .claude/rules/*.md
  hasAgentsMd:      exists("./AGENTS.md")
}

mode =
  NEW         if not state.hasClaudeMd
  TIGHTEN     if state.hasClaudeMd and state.claudeMdLines <= 200 and not state.hasRulesDir
  SPLIT       if state.hasClaudeMd and state.claudeMdLines > 200 and not state.hasRulesDir
  REORGANIZE  if state.hasClaudeMd and state.hasRulesDir
```

Detection is presented to the user via AskUserQuestion as a single recommended choice plus three override options (other modes). User can accept, override, or cancel.

### Mode execution summaries

- **NEW** — Interview (project name, 1-line overview, tech stack, primary domains), pick relevant template + example files, generate `./CLAUDE.md` + initial `.claude/rules/*.md` files (one per detected domain), insert ToC list (not `@import`) in root.
- **TIGHTEN** — Read current CLAUDE.md, restructure into Do/Don't sections where applicable, propose `paths:` candidates for sections that map to specific directories, patch root file. No new rules/ files unless user opts in.
- **SPLIT** — Parse current CLAUDE.md sections, classify by topic (architecture, testing, deployment, etc.), extract sections ≥ threshold (default 10 lines) to `.claude/rules/<topic>.md` with auto-generated `paths:` frontmatter where boundary is clear. Reduce root to overview + Quick Reference + ToC.
- **REORGANIZE** — Cross-check existing root + rules/ for: duplication, missing `paths:`, sections too long (>500 lines), missing Do/Don't structure. Present diff summary, patch with confirmation per file.

### Templates

#### `assets/templates/root-claude-md.md`

Root CLAUDE.md skeleton (≤200 lines target). Sections:
- Project name and 1–2 sentence overview
- Critical rules (5–7 always-visible safety rules)
- Quick reference table
- Rules section: ToC of `.claude/rules/*.md` files with one-line each (text links, **not** `@import` directives)

#### `assets/templates/rule-file.md`

Single rule file skeleton:
```markdown
---
paths:
  - "<glob 1>"
  - "<glob 2>"
---

# <Topic>

## Role
<one-sentence responsibility>

## Do
- <rule>

## Don't
- <anti-rule>

## Examples
<optional code blocks>

## Source of Truth
- <link to spec / canonical file>
```

When the rule is universal (no clear path boundary), the frontmatter block is omitted entirely (always-load default).

#### `assets/templates/rule-categories.md`

Catalog of 5 starter categories, each with:
- One-line definition
- Suggested `paths:` glob
- Cross-link to a relevant `assets/examples/*.md`
- Default Do/Don't seeds

Starter categories: `architecture`, `framework`, `tech-stack`, `testing`, `service-spec`.

### Examples (adapted from golden-rabbit-antigravity-v1)

Each example file carries a top-of-file HTML comment with attribution:

```markdown
<!--
Adapted from: codefactory-co/golden-rabbit-antigravity-v1
Original path: 10/ecommerce/.agent/rules/architecture.md
Adaptation: frontmatter trigger: always_on → paths: glob | content compressed to ≤150 lines | restructured into Do/Don't sections
License: see source repository
-->
```

Adapted files:
1. `nextjs-clean-arch.md` — Clean Architecture layering, dependency rule, Composition Root pattern. `paths:` set to `src/core/**/*.ts`.
2. `nextjs-framework.md` — Server Components first, Server Actions, performance optimization. `paths:` set to `src/app/**/*.{ts,tsx}`.
3. `tech-stack-supabase.md` — Supabase SSR, RLS, type generation, Tailwind utility-first, TypeScript strict. No `paths:` (always-load, tech-stack rules apply repo-wide).
4. `saas-service-spec.md` — PRD-style hybrid: service overview, target users, pricing tiers, UX flow, inferred data models. No `paths:`. Included as inspiration for product-context-heavy projects.

### References

#### `assets/references/claude-code-memory.md`

Verbatim excerpt of the Claude Code memory documentation page (CLAUDE.md, auto-memory, `.claude/rules/`, AGENTS.md coexistence, troubleshooting). Korean version preserved. Loaded by the skill on demand when the user asks "why this structure" or when mode execution needs to reference official guidance.

## Data Flow

```
User invokes /rules-forge:write-rules (or natural-language trigger)
  ↓
SKILL.md loads
  ↓
[A] State scan via Bash (existence + line counts)
  ↓
[B] Mode proposal (heuristic) + AskUserQuestion
  ↓
[C] On accept, mode-specific execution:
      • Read relevant assets/templates/*.md
      • Read relevant assets/examples/*.md (if mode is NEW)
      • Optionally Read assets/references/claude-code-memory.md
      • Apply transforms based on user interview / project state
  ↓
[D] Write/Edit files (CLAUDE.md, .claude/rules/*.md)
  ↓
[E] Summary report: file list with line counts, next-step hints
      (auto-memory hint, CLAUDE.local.md hint, AGENTS.md coexistence hint)
```

## Error Handling

- **Mode detection ambiguous** — present heuristic recommendation + override list; never auto-execute without confirmation
- **CLAUDE.md exceeds 25000 tokens** — fall back to chunked Read with `offset` / `limit`, classify sections incrementally
- **`.claude/rules/` already has files in REORGANIZE mode** — propose per-file diff, never overwrite without explicit confirmation
- **AGENTS.md exists** — surface as informational hint after generation; do not modify
- **Detection finds neither `./CLAUDE.md` nor `./.claude/CLAUDE.md`** — proceed with NEW mode
- **User declines AskUserQuestion** — exit cleanly, no file changes

## Testing

Manual verification matrix (no automated test harness for this plugin):

| Scenario | Expected mode | Expected output |
|---|---|---|
| Empty repo, no CLAUDE.md | NEW | Root CLAUDE.md + initial rules/ files matching interview |
| 80-line CLAUDE.md, no rules/ | TIGHTEN | Patched root, no new rules/ files |
| 600-line CLAUDE.md, no rules/ | SPLIT | Reduced root + 4–6 rules/ files |
| Root + rules/ both present | REORGANIZE | Diff summary + per-file patches on confirmation |
| AGENTS.md exists in any scenario | hint in summary | No write to AGENTS.md |

Verification steps:
1. Manual run in a scratch dir for each row
2. Inspect generated files match templates
3. Confirm root CLAUDE.md ≤200 lines target
4. Confirm `paths:` frontmatter present on path-scoped rules
5. Confirm no `@import` directives in generated root

## Migration

### Plugin versioning (per `.claude/rules/plugin-versioning.md`)

- `plugins/rules-forge/.claude-plugin/plugin.json`: `version` 1.0.0 → 2.0.0
- `.claude-plugin/marketplace.json`: rules-forge entry version 1.0.0 → 2.0.0
- `.claude-plugin/marketplace.json`: `metadata.version` bumped for marketplace release
- Plugin count unchanged (20)

### Doc sync

- `plugins/rules-forge/CLAUDE.md` — rewrite for single-skill surface
- Root `CLAUDE.md` rules-forge row description — minor update if needed
- Root `README.md` rules-forge section — update Skills/Commands listing

### codex-bridge implications

- `skills/write-rules/SKILL.md` is auto-discovered by codex-bridge sync engine
- `assets/` directory under SKILL.md is copied recursively (verify in implementation plan)
- Frontmatter preserved verbatim; `bridge_source: rules-forge/write-rules` injected
- Old `skills/rules-guide/` becomes orphaned bridge-managed file → pruned on next sync

### User-facing migration note

Marketplace release notes should call out:
- `/rules-forge:generate` and `/rules-forge:split` are gone — use `/rules-forge:write-rules` (or natural language: "restructure my CLAUDE.md")
- `~/.claude/plugins/cache/my-claude-plugins/` should be cleared before next `update` (per existing cache workaround in rules)

## Open Items (deferred to plan phase)

1. Final skill description string — needs phrasing pass for trigger coverage in both KR/EN
2. Exact line budgets per template file (root template's "critical rules" section size)
3. Whether SPLIT mode threshold default (10 lines) should be configurable via skill arguments
4. Whether to include a fifth example (Python / ML project) — current scope is Next.js-heavy
