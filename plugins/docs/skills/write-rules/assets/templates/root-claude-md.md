<!--
Template: Root CLAUDE.md skeleton (target ≤200 lines).

Use: write-rules skill Read s this when generating a NEW project's
root CLAUDE.md or when TIGHTEN / SPLIT mode rebuilds it.

Placeholders use {{...}} syntax — skill substitutes during mode
execution. Comments (this block and {{...}} hints) are stripped from
final output.

Design notes:
- No @import directives. `.claude/rules/*.md` auto-load handles it.
- "Rules" section is a plain ToC for human navigation, not a
  functional load directive.
- "Critical Rules" stays inline because it must be visible without
  reading sub-files (safety, never-do items).
- Quick Reference table caps build/test commands at ~8 rows.
- If AGENTS.md exists in the project, write-rules adds a leading
  `@AGENTS.md` import line BEFORE the # heading (handled by skill,
  not present in this template).
-->

# {{PROJECT_NAME}}

{{1-2 sentence overview — what the project is, primary domain}}

## Critical Rules

{{5-7 always-visible items. Examples:}}
- {{Never commit secrets / .env files}}
- {{Run `<test command>` before pushing}}
- {{Production deploys require a tagged release}}
- {{API breaking changes need RFC in docs/}}

## Quick Reference

| Task | Command |
|---|---|
| {{Install dependencies}} | `{{<install cmd>}}` |
| {{Run dev server}} | `{{<dev cmd>}}` |
| {{Run tests}} | `{{<test cmd>}}` |
| {{Lint / typecheck}} | `{{<lint cmd>}}` |
| {{Build production}} | `{{<build cmd>}}` |

## Code Structure

{{Brief paragraph (≤10 lines): what lives where. Examples:}}
- `src/api/` — {{API handlers and routing}}
- `src/components/` — {{Shared React components}}
- `src/lib/` — {{Pure utilities, no I/O}}
- `tests/` — {{Test suites mirroring src layout}}

For detailed conventions per area, see Rules section below.

## Rules

Modular rules live under `.claude/rules/` and load automatically when
working with matching files. This list is for human navigation only —
no `@import` needed since `.claude/rules/*.md` is auto-discovered.

{{ToC entries, one line each. Examples — replace with actual files generated:}}
- `architecture.md` — {{Layering and dependency direction}}
- `framework.md` — {{Next.js / React conventions}}
- `tech-stack.md` — {{Tooling rules (Supabase, Tailwind, TS)}}
- `testing.md` — {{Test patterns and coverage targets}}

## Development Workflow

{{3-5 bullets covering common dev cycle. Examples:}}
- Branch from `main`, name `feat/<topic>` or `fix/<topic>`
- {{PR description must reference an issue or RFC}}
- {{Squash merge to main, no merge commits}}

## Notes for Claude Code

- Path-scoped rules under `.claude/rules/` apply when editing files
  that match their `paths:` glob.
- {{Project-specific guidance for AI assistance.}}

<!--
End of root CLAUDE.md skeleton.

Final size after substitution: aim for ≤200 lines. If the project's
nature pushes Code Structure beyond ~15 lines, extract it to
.claude/rules/code-structure.md (no paths: frontmatter — always load).
-->
