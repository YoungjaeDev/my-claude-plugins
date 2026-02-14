# Rules Forge Plugin

**Generate and restructure CLAUDE.md systems with modular .claude/rules/ delegation**

## Overview

Rules Forge helps you create and maintain clean, modular CLAUDE.md instruction systems by:

1. **Generating** new CLAUDE.md systems from scratch with interview-based workflows
2. **Restructuring** existing monolithic CLAUDE.md files into modular `.claude/rules/` delegation
3. **Migrating** from legacy patterns to modern best practices

This plugin integrates seamlessly with the official `claude-md-management` plugin for ongoing maintenance and updates.

## Features

### Skills

| Skill | Trigger | Purpose |
|-------|---------|---------|
| `rules-guide` | `/rules-forge:rules-guide` | Interactive CLAUDE.md generation and restructuring |

**Auto-triggers:**
- "generate claude.md"
- "restructure claude.md"
- "split claude.md"
- "modularize instructions"

### Commands

| Command | Purpose |
|---------|---------|
| `/rules-forge generate` | Generate new CLAUDE.md system (interview workflow) |
| `/rules-forge split` | Extract rules from existing CLAUDE.md to .claude/rules/ |

## Usage Examples

### Generate New CLAUDE.md

```
/rules-forge generate
```

Interactive interview asks about:
- Project type and domain
- Team size and experience level
- Required instruction categories
- Existing tools/frameworks
- Code style preferences

### Restructure Existing CLAUDE.md

```
/rules-forge split
```

Automatically:
1. Analyzes current CLAUDE.md
2. Extracts modular sections to `.claude/rules/`
3. Updates root with `@import` references
4. Preserves critical root content (quick reference, emergency protocols)

### Combined Workflow

```
"restructure my claude.md into modular rules"
```

Auto-triggers `rules-guide` skill with restructure mode.

## Integration with claude-md-management

**Rules Forge** focuses on **initial creation and major restructuring**:
- Generating new CLAUDE.md systems
- Migrating monolithic → modular
- One-time extraction of rules

**claude-md-management** handles **ongoing maintenance**:
- Adding/updating individual rules
- Managing imports
- Incremental updates

### Recommended Workflow

1. **Initial Setup**: Use Rules Forge to generate or restructure
2. **Daily Updates**: Use claude-md-management for incremental changes
3. **Major Refactors**: Return to Rules Forge for restructuring

## File Structure

```
.claude/
├── CLAUDE.md           # Root (quick reference + @import statements)
└── rules/
    ├── core/           # Core guidelines
    ├── workflows/      # Process workflows
    ├── architecture/   # Design patterns
    ├── testing/        # Test standards
    └── tools/          # Tool-specific rules
```

## Best Practices

### What Goes in Root CLAUDE.md

- **Project identity** (1-2 sentences)
- **Emergency protocols** (critical safety rules)
- **Quick reference table** (common tasks)
- **@import directives** for all rule categories

### What Goes in .claude/rules/

- Detailed guidelines (>10 lines)
- Domain-specific rules
- Framework conventions
- Testing procedures
- Tool configurations
- Code style guides

### Content Classification

| Content Type | Location | Reason |
|--------------|----------|--------|
| Project overview | Root | Immediate context |
| Critical safety rules | Root | Always visible |
| Navigation/ToC | Root | Quick access |
| Detailed guidelines | Rules | Modular, focused |
| Framework docs | Rules | Domain-specific |
| Code patterns | Rules | Reusable across projects |
| Test procedures | Rules | Isolated concern |

## Examples

See `skills/rules-guide/references/examples.md` for:
- Minimal startup CLAUDE.md
- Full-featured enterprise system
- Incremental migration paths
- Before/after restructuring comparisons

## Version History

- **1.0.0** (2026-02-14) - Initial release
  - Interactive CLAUDE.md generation
  - Monolithic → modular restructuring
  - Template library with examples
