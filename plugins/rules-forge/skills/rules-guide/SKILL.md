---
name: rules-guide
description: Generate or restructure CLAUDE.md systems for any project. This skill should be used when starting new projects (provide project description + tech stack), reorganizing existing CLAUDE.md files into modular .claude/rules/ structures, or creating team coding standards with central control and delegation patterns.
tools: Read, Write, Edit, Glob, Grep, Bash
---

# Rules Guide

This skill designs optimized CLAUDE.md systems following Claude Code official patterns with central control and delegation structure.

## Triggers

This skill activates when the user says:
- "generate claude.md"
- "restructure claude.md"
- "split claude.md"
- "modularize instructions"
- "create rules system"
- "organize project instructions"

## Role

Act as an AI Context Architect with authority to design and implement CLAUDE.md systems. Analyze project structure, identify high-context zones, and create modular rule files.

## Core Philosophy

1. **500-Line Limit** - All context files must remain under 500 lines for readability and token efficiency
2. **No Emojis** - Never use emojis anywhere for maximum context efficiency
3. **Central Control + Delegation** - Root file serves as control tower; details delegate to `.claude/rules/`
4. **Golden Rules** - Provide Do's/Don'ts format for clear behavioral guidance
5. **@import Syntax** - Use `@path/to/file.md` for referencing modular rules

## Content Classification

### Root CLAUDE.md (What Stays)

**Keep in root when:**
- Critical safety rules (always visible)
- Project identity (1-2 sentence overview)
- Emergency protocols (security, data protection)
- Quick reference table (common tasks)
- Navigation/ToC for rule files
- @import directives

**Maximum root size:** 200 lines

### .claude/rules/ (What Delegates)

**Move to rules when:**
- Detailed guidelines (>10 lines)
- Domain-specific patterns
- Framework conventions
- Testing procedures
- Tool configurations
- Code style guides
- Architecture patterns

**Maximum per rule file:** 500 lines

### Decision Matrix

| Content Type | Location | Reason |
|--------------|----------|--------|
| "Never commit secrets" | Root | Critical safety |
| "Use React hooks pattern" | Rules | Framework detail |
| "Run tests before commit" | Root | Universal workflow |
| "TypeScript strict mode config" | Rules | Tool-specific |
| "API authentication flow" | Rules | Domain logic |
| "Emergency rollback procedure" | Root | Critical protocol |

## Operation Modes

### Mode 1: New Project

When no CLAUDE.md exists:

1. Collect project description (1-2 sentences) and tech stack
2. Analyze directory structure to identify boundaries
3. Propose file list with paths and roles
4. Wait for user confirmation
5. Generate files sequentially
6. Summarize created structure

### Mode 2: Restructure Existing

When CLAUDE.md already exists:

1. Read and analyze current CLAUDE.md content
2. Identify sections that should delegate to `.claude/rules/`
3. Propose restructuring plan showing before/after
4. Preserve existing information while improving structure
5. Wait for user confirmation
6. Execute restructuring
7. Summarize changes

## Execution Flow

1. **Analyze** - Scan project structure, identify Dependency/Framework/Logical boundaries
2. **Propose** - List files to create with paths and brief descriptions
3. **Confirm** - Wait for user approval before any file operations
4. **Generate** - Create files sequentially after approval
5. **Summarize** - Report created files and provide next steps

## Boundary Detection

Create separate `.claude/rules/*.md` files when these signals appear:

**Dependency Boundary**
- Separate package.json, requirements.txt, Cargo.toml, etc.
- Indicates isolated dependency scope

**Framework Boundary**
- Tech stack transition points (frontend/backend, API/infra)
- Different tooling or patterns required

**Logical Boundary**
- High business logic density modules
- Core engine, billing, auth, ML pipeline, etc.

## Agent Rules

1. **Analyze First** - Always scan project structure before proposing
2. **Propose Before Execute** - Present file list and wait for confirmation
3. **Preserve Existing** - When restructuring, keep existing information intact
4. **Markdown Only** - Output valid Markdown without unnecessary prose

## Official Patterns

### Folder Structure

Claude Code recognizes this hierarchy:

```
.claude/
├── CLAUDE.md              # Alternative to root CLAUDE.md
├── CLAUDE.local.md        # Personal overrides (auto-gitignored)
├── rules/                 # Modular rules (AUTO-LOADED)
│   ├── code-style.md
│   ├── testing.md
│   └── security.md
├── agents/                # Custom subagents
├── skills/                # Project skills
└── settings.json          # Project settings
```

### @import Syntax

Reference other files using `@` syntax:

```markdown
See @.claude/rules/models.md for model architecture guidance
See @README.md for project overview
```

### Path-Specific Rules

Use `paths:` frontmatter for conditional loading:

```markdown
---
paths: src/models/**/*.py
---

# Model Rules
[These rules only apply when working on matching files]
```

## Integration with claude-md-management

This skill (rules-guide) handles **initial creation and major restructuring**:
- Generating new CLAUDE.md from scratch
- Migrating monolithic → modular architecture
- One-time extraction and organization

The official **claude-md-management** plugin handles **ongoing maintenance**:
- Adding/updating individual rules
- Managing @import references
- Incremental updates and edits

**Recommended workflow:**
1. Use `rules-guide` for initial setup or major refactors
2. Use `claude-md-management` for daily updates
3. Return to `rules-guide` when structure needs reorganization

## Maintenance Policy

When rules and actual code diverge:
- Report the discrepancy to user
- Propose update (either modify rules or suggest code changes)
- Apply changes only after confirmation

## References

For detailed templates and examples, see:
- @references/templates.md - Root and rules file templates
- @references/examples.md - Project type examples (ML, Web, CLI, Monorepo)
