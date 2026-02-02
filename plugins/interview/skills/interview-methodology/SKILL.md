---
name: interview-methodology
description: This skill should be used when conducting in-depth user interviews, "gathering requirements", "interview me", "ask me questions", "understand my needs before implementing", "spec-based development", or when preparing comprehensive specifications before implementation.
version: 0.2.0
---

# Interview Methodology

A comprehensive framework for conducting thorough requirement-gathering interviews that uncover hidden needs, constraints, and edge cases.

## Trigger Examples

<example>
Context: User wants to implement a new feature without detailed spec
user: "I want to add dark mode to my app"
assistant: Loads interview-methodology skill to thoroughly understand requirements first.
<commentary>
Feature request without detailed specification - perfect trigger for deep interview before implementation.
</commentary>
</example>

<example>
Context: User explicitly requests interview-style requirements gathering
user: "Interview me about this feature before you start coding"
assistant: Loads interview-methodology skill to conduct thorough interview.
<commentary>
Explicit interview request - direct trigger.
</commentary>
</example>

## Critical Rules

1. **Use AskUserQuestion tool** for all questions - never just ask in plain text
2. **Questions must NOT be obvious** - avoid basic questions the user has already answered
3. **Continue interviewing until complete** - don't stop after 2-3 questions
4. **Probe deeper on every answer** - each response should spawn follow-up questions
5. **Write the final spec to a file** when the interview is complete

## Core Principle: Non-Obvious Questions

**Never ask questions the user has already implicitly answered.** Instead, probe the gaps, assumptions, and unstated requirements.

### Bad Questions (Obvious)
- "What feature do you want?" (they already told you)
- "Do you want it to work well?" (obviously yes)
- "Should it be fast?" (obviously yes)

### Good Questions (Non-Obvious)
- "What happens when X fails? Should it retry, fail silently, or notify?"
- "Who else might use this besides you? Do they have different needs?"
- "What's the worst thing that could happen if this feature misbehaves?"

## Question Framework by Category

### 1. Technical Implementation
- What existing systems does this need to integrate with?
- Are there performance constraints (response time, memory, etc.)?
- What's the expected scale? 10 users or 10,000?
- Are there security or compliance requirements?
- Should this work offline? On mobile?
- What happens during network failures or timeouts?

### 2. User Interface & Experience
- Who are the different user personas interacting with this?
- What's the primary device/platform? Secondary?
- Are there accessibility requirements?
- What's the user's technical proficiency level?
- What should happen on errors - technical message or friendly guidance?
- Are there existing UI patterns in the app this should follow?

### 3. Edge Cases & Error Handling
- What inputs are considered invalid? How should they be handled?
- What if the user does X when they should do Y?
- What's the behavior when data is missing or malformed?
- How should concurrent/conflicting operations be handled?
- What are the failure modes and recovery strategies?

### 4. Constraints & Tradeoffs
- What's more important: speed of delivery or completeness?
- Are there budget/resource limitations?
- What can we cut if we run out of time?
- What's the minimum viable version vs. ideal version?
- Are there dependencies on other teams or systems?

### 5. Business Context
- Why is this feature needed now?
- What problem does this solve for the business?
- How will success be measured?
- What's the cost of NOT doing this?
- Are there regulatory or legal considerations?

## Interview Flow

### Phase 1: Context Gathering (2-3 questions)
Understand the big picture before diving into details.
- What triggered this request?
- What's the current pain point?
- What does success look like?

### Phase 2: Deep Dive (5-10 questions)
Systematically cover each category above. Use AskUserQuestion with multiple-choice options when possible to make answering easier.

### Phase 3: Edge Case Exploration (3-5 questions)
Focus on "what if" scenarios. These often reveal the most important requirements.

### Phase 4: Prioritization (2-3 questions)
Help the user distinguish must-haves from nice-to-haves.

### Phase 5: Validation (1-2 questions)
Summarize understanding and confirm before finalizing.

## AskUserQuestion Best Practices

### Structure Questions with Options
```
Question: "How should the system handle authentication failures?"
Options:
1. Show error and retry (simple)
2. Lock account after 3 attempts (secure)
3. Send email notification (audit trail)
4. Custom handling...
```

### Use multiSelect for Non-Exclusive Choices
```
Question: "Which platforms need to be supported?"
multiSelect: true
Options:
1. Web browser
2. iOS app
3. Android app
4. Desktop app
```

### Provide Context in Descriptions
Each option should explain implications, not just the choice itself.

## Interview Completion

When you've gathered sufficient information:
1. Summarize all requirements back to the user
2. Ask for confirmation using AskUserQuestion
3. Write the comprehensive spec to `.claude/spec/{YYYY-MM-DD}-{feature-name}.md`
   - Date: Interview completion date (ISO format)
   - Feature name: kebab-case (e.g., `dark-mode`, `user-authentication`)
   - Create `.claude/spec/` directory if it doesn't exist
4. The spec should be detailed enough for implementation without further questions

## Spec Output Format

**File path**: `.claude/spec/{YYYY-MM-DD}-{feature-name}.md`

**Examples**:
- `.claude/spec/2026-01-20-dark-mode.md`
- `.claude/spec/2026-01-20-api-rate-limiting.md`

After interview completion, write a spec file with:

```markdown
# Feature Specification: [Feature Name]

## Overview
[1-2 sentence summary]

## User Stories
- As a [user type], I want [goal] so that [benefit]

## Requirements

### Must Have (P0)
- [ ] Requirement 1
- [ ] Requirement 2

### Should Have (P1)
- [ ] Requirement 3

### Nice to Have (P2)
- [ ] Requirement 4

## Technical Constraints
- [List technical requirements and limitations]

## UI/UX Requirements
- [List interface requirements]

## Edge Cases
| Scenario | Expected Behavior |
|----------|------------------|
| Case 1   | Behavior 1       |

## Out of Scope
- [Explicitly list what this feature does NOT include]

## Open Questions
- [Any unresolved items for future discussion]
```

## Interviewing Anti-Patterns to Avoid

1. **Assuming you know best** - Always verify assumptions
2. **Leading questions** - Don't bias the answer
3. **Stopping too early** - Keep probing until truly complete
4. **Ignoring contradictions** - Surface and resolve conflicts
5. **Forgetting to summarize** - Always validate understanding
6. **Skipping prioritization** - Everything can't be P0
