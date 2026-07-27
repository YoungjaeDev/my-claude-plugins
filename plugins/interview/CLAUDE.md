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

## Three Modes

- **Breadth-first** (the 5-phase flow) - sweep every category; for large, multi-decision work.
- **Depth-first / Socratic (focused)** - target the single biggest uncertainty, one question at a time; for one-or-two-decision work. The two compose (map breadth-first, then dive focused).
- **Relentless / stress-test (adversarial)** - for "grill me" / "poke holes in this": press an existing plan, inverting the default "don't bother the user" posture. "When NOT to Interview" does not apply; adds a hard act-gate (no action until the user confirms shared understanding), dependency-frontier ordering, and non-blocking fact-dispatch.

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

## Hermes Agent

Install the skill (`npx skills`, wrapped by the repo's installer):

```bash
node scripts/install-skills.mjs                                                    # interactive picker
npx skills add YoungjaeDev/my-claude-plugins -a hermes-agent -s interview-methodology -g
```

It lands in `~/.hermes/skills/interview-methodology/`, which Hermes indexes automatically — it shows up in `skills_list()` and as a slash command under its **flat** name `interview-methodology`, not `interview:interview-methodology`.

The skill body carries a Hermes compatibility table mapping Claude/Codex tool terms (e.g. `AskUserQuestion`, `Read`, `Write`) to Hermes tools (`clarify`, `read_file`, `write_file`).
