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

## Two Modes

- **Breadth-first** (the 5-phase flow) - sweep every category; for large, multi-decision work.
- **Depth-first / Socratic (focused)** - target the single biggest uncertainty, one question at a time; for one-or-two-decision work. The two compose (map breadth-first, then dive focused).

## Interview Phases (breadth-first mode)

1. **Context Gathering** (2-3 questions) - Big picture
2. **Deep Dive** (5-10 questions) - Technical, UX, edge cases
3. **Edge Case Exploration** (3-5 questions) - "What if" scenarios
4. **Prioritization** (2-3 questions) - Must-have vs nice-to-have
5. **Validation** (1-2 questions) - Confirm understanding

## Key Principles

- Use AskUserQuestion for all questions
- Verify against the codebase first - don't ask what the repo already answers
- Ask non-obvious questions (not what user already said)
- Per-question scaffold: current understanding / stuck decision / recommended default / question
- **When NOT to interview**: skip (or drop to 2-3 targeted questions) for already-concrete requests, typos, small config/copy changes, dep bumps, test additions, or "just do it"

## Output

Scale to weight: **lightweight close** (Decisions + Open questions inline, no file) for small/focused interviews; **full spec file** for large/multi-decision interviews.

Full spec at `.claude/spec/{YYYY-MM-DD}-{feature-name}.md`:

```markdown
# Feature Specification: [Name]

## Overview
## User Stories
## Requirements (P0/P1/P2)
## Technical Constraints
## Edge Cases
## Out of Scope
```
