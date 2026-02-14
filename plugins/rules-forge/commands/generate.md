---
name: generate
description: Generate a new CLAUDE.md system for any project with modular .claude/rules/ structure
---

# Generate CLAUDE.md System

Interactive command that generates a complete CLAUDE.md system from scratch using interview-based workflow.

## Usage

```bash
/rules-forge generate [--new|--restructure]
```

### Flags

| Flag | Description |
|------|-------------|
| `--new` | Generate for new project (no existing CLAUDE.md) |
| `--restructure` | Restructure existing monolithic CLAUDE.md |
| (none) | Auto-detect mode based on CLAUDE.md existence |

## Workflow

### Mode 1: New Project (--new)

When no CLAUDE.md exists or `--new` flag is used:

1. **Interview Phase**
   - What is your project? (1-2 sentence description)
   - What is your tech stack?
   - Team size and experience level?
   - Existing tools/frameworks in use?
   - Code style preferences?

2. **Analysis Phase**
   - Scan project directory structure
   - Identify dependency boundaries (package.json, requirements.txt, etc.)
   - Identify framework boundaries (frontend/backend, API/infra)
   - Identify logical boundaries (auth, billing, ML pipeline, etc.)

3. **Proposal Phase**
   ```
   Proposed structure:

   ./CLAUDE.md (root)
     - Project overview
     - Operational commands
     - Golden rules (5-7 critical rules)
     - @import directives

   .claude/rules/
     - api.md (paths: src/api/**/*.ts)
     - components.md (paths: src/components/**/*.tsx)
     - auth.md (paths: src/auth/**/*.ts)
     - db.md (paths: prisma/**/*.prisma)

   Proceed? [y/n]
   ```

4. **Generation Phase**
   - Create root CLAUDE.md with overview, commands, critical rules, @imports
   - Create each .claude/rules/*.md file with path-specific guidelines
   - Generate based on detected patterns and user preferences

5. **Summary Phase**
   ```
   Created:
   - ./CLAUDE.md (150 lines)
   - .claude/rules/api.md (85 lines)
   - .claude/rules/components.md (120 lines)
   - .claude/rules/auth.md (95 lines)
   - .claude/rules/db.md (70 lines)

   Next steps:
   1. Review generated rules for project-specific adjustments
   2. Use claude-md-management for ongoing updates
   3. Add team-specific conventions to relevant rule files
   ```

### Mode 2: Restructure Existing (--restructure)

When CLAUDE.md exists or `--restructure` flag is used:

1. **Analysis Phase**
   - Read current CLAUDE.md
   - Identify sections >10 lines (candidates for extraction)
   - Identify domain-specific content (framework, testing, tools)
   - Classify critical vs. delegatable content

2. **Proposal Phase**
   ```
   Current: 850 lines in root CLAUDE.md

   Proposed extraction:

   Keep in root (150 lines):
     - Project overview (lines 1-15)
     - Operational commands (lines 20-45)
     - Critical safety rules (lines 50-85)
     - @import directives (new)

   Extract to .claude/rules/:
     - architecture.md (lines 100-250) → Architecture patterns
     - data.md (lines 260-380) → Data processing rules
     - inference.md (lines 390-520) → Model inference guidelines
     - testing.md (lines 530-650) → Test procedures
     - deployment.md (lines 660-820) → Deployment checklist

   Proceed? [y/n]
   ```

3. **Restructuring Phase**
   - Create .claude/rules/ directory
   - Extract sections to individual rule files
   - Update root CLAUDE.md with:
     - Condensed overview
     - Critical rules only
     - @import directives for all extracted files
   - Preserve all existing information

4. **Verification Phase**
   - Check root CLAUDE.md is <200 lines
   - Check each rule file is <500 lines
   - Verify no information was lost

5. **Summary Phase**
   ```
   Restructured:
   - Root reduced: 850 → 150 lines
   - Extracted 5 rule files (total 700 lines)

   Before: 850 lines in 1 file
   After: 150 lines (root) + 700 lines (5 files)

   All original content preserved, now modular and maintainable.
   ```

## Behind the Scenes

This command delegates to the `rules-guide` skill with appropriate context:

```typescript
// Pseudo-code
if (flag === '--new' || !claudeMdExists) {
  invoke('rules-forge:rules-guide', {
    mode: 'new',
    context: await analyzeProjectStructure()
  });
} else if (flag === '--restructure' || claudeMdExists) {
  invoke('rules-forge:rules-guide', {
    mode: 'restructure',
    currentContent: await readFile('CLAUDE.md')
  });
}
```

## Examples

### Generate for Next.js Project

```bash
/rules-forge generate --new

# Interview prompts:
# > What is your project?
# SaaS dashboard with team management
#
# > What is your tech stack?
# Next.js 14, TypeScript, Prisma, Tailwind
#
# [Analysis and generation follows...]
```

### Restructure ML Project

```bash
/rules-forge generate --restructure

# Reads existing 1200-line CLAUDE.md
# Proposes extraction to:
#   - models.md
#   - data.md
#   - inference.md
#   - training.md
#   - evaluation.md
#
# [Restructuring follows...]
```

## Best Practices

1. **New projects:** Run early to establish clean structure from the start
2. **Existing projects:** Run when CLAUDE.md exceeds 300 lines
3. **After restructuring:** Use `claude-md-management` for incremental updates
4. **Team settings:** Customize generated rules for team conventions

## Integration

Works seamlessly with:
- **claude-md-management** - For daily updates after initial generation
- **oh-my-claudecode agents** - Generated rules optimize agent behavior
- **Path-specific rules** - Auto-generates `paths:` frontmatter for targeted loading

## See Also

- `/rules-forge split` - Quick extraction without interview
- `rules-guide` skill - Underlying implementation
- `claude-md-management` - Ongoing rule maintenance
