# Interview Plugin

Structured requirements gathering before implementation.

## Skill

| Skill | Description |
|-------|-------------|
| `interview-methodology` | In-depth user interview framework |

## Purpose

Conduct thorough interviews to uncover hidden needs, constraints, and edge cases before writing code.

## Triggers

- "interview me"
- "ask me questions"
- "understand my needs before implementing"
- "spec-based development"
- Feature requests without detailed specs

## Interview Phases

1. **Context Gathering** (2-3 questions) - Big picture
2. **Deep Dive** (5-10 questions) - Technical, UX, edge cases
3. **Edge Case Exploration** (3-5 questions) - "What if" scenarios
4. **Prioritization** (2-3 questions) - Must-have vs nice-to-have
5. **Validation** (1-2 questions) - Confirm understanding

## Key Principles

- Use AskUserQuestion for all questions
- Ask non-obvious questions (not what user already said)
- Continue until complete (don't stop after 2-3 questions)
- Probe deeper on every answer

## Output

Spec file at `.claude/spec/{YYYY-MM-DD}-{feature-name}.md`:

```markdown
# Feature Specification: [Name]

## Overview
## User Stories
## Requirements (P0/P1/P2)
## Technical Constraints
## Edge Cases
## Out of Scope
```
