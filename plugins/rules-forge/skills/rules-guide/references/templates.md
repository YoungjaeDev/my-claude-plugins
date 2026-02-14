# Templates

## Root CLAUDE.md Template

```markdown
# CLAUDE.md

## Project Context

[1-2 line business goal + tech stack summary]

## Operational Commands

```bash
# [Package manager commands]
[install command]
[run command]
[test command]
```

## Golden Rules

### Immutable

- [Non-negotiable security/architecture constraints]
- [Critical patterns that must never be violated]

### Do's

- [Clear positive actions]
- [Required patterns]

### Don'ts

- [Clear prohibitions]
- [Anti-patterns to avoid]

## Modular Rules

See @.claude/rules/[module].md for [description]
See @.claude/rules/[module].md for [description]

## [Project-Specific Sections]

[Data locations, submission tracking, deployment info, etc.]
```

## Rules File Template (General)

```markdown
---
paths: [glob pattern, optional]
---

# [Module] Rules

## Role

[What this module does, 1-2 lines]

## Dependencies

- [Key external libraries]
- [Internal module dependencies]

## Patterns

- [Common code patterns]
- [File naming conventions]
- [Directory structure expectations]

## Do's

- [Module-specific positive actions]
- [Required patterns for this area]

### Don'ts

- [Module-specific prohibitions]
- [Common mistakes to avoid]

## Testing

```bash
[Module-specific test commands]
```
```

## Rules File Template (Path-Specific)

```markdown
---
paths: src/api/**/*.ts, src/api/**/*.tsx
---

# API Development Rules

## Role

Handle all backend API routes and server-side logic.

## Patterns

- All endpoints follow REST conventions
- Use standard error response format
- Include input validation on all routes

## Do's

- Validate all incoming data
- Return consistent error structures
- Log meaningful error context

## Don'ts

- Expose internal error details to clients
- Skip authentication checks
- Use raw SQL without parameterization
```

## Restructured Root Template

When converting a large CLAUDE.md to modular structure:

```markdown
# CLAUDE.md

## Project Context

[Keep existing overview, condensed to 2-3 lines]

## Operational Commands

[Keep essential commands only]

## Golden Rules

### Immutable

[Extract from existing, keep only critical rules]

### Do's / Don'ts

[Keep top 5-7 most important rules here]

## Modular Rules

Architecture and core pipeline: @.claude/rules/architecture.md
Data processing and caching: @.claude/rules/data.md
Model and inference: @.claude/rules/inference.md
[Add more as needed based on existing sections]

## [Keep minimal project-specific sections]

[Submission tracking, data locations - things that change rarely]
```
