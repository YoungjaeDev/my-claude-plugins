---
name: interview-methodology
description: This skill should be used when conducting in-depth user interviews, "gathering requirements", "interview me", "ask me questions", "understand my needs before implementing", "spec-based development", when preparing comprehensive specifications before implementation, when relentlessly stress-testing an existing plan or decision ("grill me", "poke holes in this", "집요하게 캐물어"), or when the interview output should be a reusable prompt in Google's TCREI format ("TCREI", "structure this prompt", "make a prompt for next session", "rewrite as TCREI").
version: 0.4.0
---

# Interview Methodology

## Cross-runtime interactive input

Every question below runs through a **capability-aware** interactive-input gate, not one hardcoded tool. Read each `AskUserQuestion` mention as this gate:

- **Claude Code**: use `AskUserQuestion`.
- **Codex**: use `request_user_input` when that tool is exposed. When it is not, ask ONE concise blocking question only where a wrong assumption would be costly; otherwise proceed on a documented safe default and state the assumption.

Full policy: `AGENTS.md` → "Cross-runtime interactive input policy".

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

These govern a full interview once you've decided one is warranted. They are
explicitly relaxed by the two scoping sections that follow: **"When NOT to
Interview"** (whether to interview at all) and the lightweight close in
**"Interview Completion"** (how much to write). When those apply, they override
rules 3-5 below.

1. **Use the interactive-input gate** for all questions (Claude `AskUserQuestion`; see "Cross-runtime interactive input") - never just ask in plain text
2. **Questions must NOT be obvious** - avoid basic questions the user has already answered
3. **Don't stop a full interview early** - once committed to a full (breadth-first) interview, cover it; don't bail after 2-3 questions. (Doesn't apply when "When NOT to Interview" already capped the scope at 2-3 targeted questions.)
4. **Probe deeper on substantive answers** - each response can spawn follow-ups; in depth-first mode this is the primary loop. (Not a mandate to follow up on every trivial confirmation.)
5. **Write a spec file for substantial interviews** - large/multi-decision interviews persist a spec; small/focused ones use the lightweight close instead (see "Interview Completion").

## When NOT to Interview

Interviewing has a cost: it interrupts the user and delays the work. Skip it (or
drop to a single clarifying question through the interactive-input gate) when the
task is already well-specified or low-stakes:

- The request is already concrete and unambiguous (clear inputs, outputs, and
  acceptance criteria stated).
- It is a typo fix, a small config/copy change, a dependency bump, or adding
  tests to existing behavior.
- The scope is one obvious file/function and the change is mechanical.
- The user explicitly said "just do it" / "no questions".

When in doubt between "ask nothing" and "full interview", prefer the middle:
2-3 targeted questions that resolve the decisions that actually change the
implementation. A full multi-phase interview is for genuinely under-specified,
multi-decision work, not a reflex for every request.

## Core Principle: Non-Obvious Questions

**Never ask questions the user has already implicitly answered.** Instead, probe the gaps, assumptions, and unstated requirements.

**Verify against the codebase first: don't ask what the repo can answer.** Before adding a question, check whether the existing code, config, tests, git history, or docs already settle it (which framework, which DB, the current error-handling pattern, existing naming conventions). Asking the user to restate something discoverable from the repo wastes their time and signals you didn't look. Reserve questions for what is genuinely *non-obvious from the code*: intent, priorities, future direction, and trade-offs only the user holds.

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

## Three Interview Modes

Pick the mode that fits the uncertainty, and say which you're using:

### Breadth-first (the 5-phase flow below)
Systematically sweep every category. Best when the work is large, multi-decision,
and you need full coverage before a comprehensive spec. Batch related questions
(the Phase 2 "5-10 questions" cadence) so the user answers efficiently.

### Depth-first / Socratic (focused mode)
Target the **single biggest uncertainty** and resolve it before moving on: one
question (or one tight interactive-input gate) at a time, each chosen by "what is the
one unknown that most changes the implementation right now?". The user's answer
determines the next question. Best when one or two decisions dominate the design,
or when a broad questionnaire would feel like a wall of forms. This mode aligns
with "narrow to 2-3 interpretations and confirm": you are not firing 10 questions,
you are walking down the decision that matters.

The two modes compose: open breadth-first to map the territory, then switch to
focused mode when one answer opens a deep, consequential branch.

### Relentless / stress-test mode (adversarial)

Use when the user hands you an existing plan, design, or decision and wants it
*pressed*, not gathered: triggers like "grill me", "stress-test this", "poke
holes in this", "집요하게 캐물어". This mode **inverts the default posture**: the two
modes above optimize for *not bothering* the user, but here the user has
explicitly asked to be bothered, so **"When NOT to Interview" does not apply**:
there is no 2-3 question cap and no early exit. Press every branch of the
decision tree until you and the user reach a genuine shared understanding.

Four rules separate this from a polite interview:

1. **No escape hatches.** Do not offer to skip, defer, or "just proceed". The
   session ends when the plan is sound, not when it is merely tolerable. This
   constrains *your* offers, not the user's control: an explicit user request to
   stop, cancel, or proceed anyway always overrides and ends the mode at once:
   you simply never volunteer the shortcut yourself.
2. **Hard act-gate.** Do not act on the plan (no implementation, no spec write,
   no edits) until the user *explicitly confirms* you have reached shared
   understanding. An agent that answers its own open questions and starts working
   has broken this rule.
3. **Walk the dependency frontier.** Ask the decisions whose prerequisites are
   already settled first; a question whose answer depends on another still-open
   question belongs to a *later* round. Early answers are allowed to reshape
   later questions, which is exactly why you never batch a downstream question
   ahead of its prerequisite.
4. **Facts are yours, decisions are theirs.** Never ask the user anything the
   repo or tools can answer: when a frontier question needs a fact, dispatch a
   sub-agent or run the lookup yourself and keep pressing the rest of the
   frontier while it resolves (a pending fact-find blocks only the questions
   downstream of it). Fact-finding is **read-only**: it may read files, run
   read-only queries, and search, and it must not write files, run mutating
   commands, or send data, since that would slip work past the act-gate. Never
   autonomously settle a judgment call that is the user's to make.

### Per-question scaffold

Whichever mode, frame a substantive question so the user can answer in one glance:
state your current understanding, name the decision, and offer a recommended
default (so a low-stakes call can be a single confirmation, not an essay):

```text
현재 이해 (Current understanding): what you already know / inferred from the code
막힌 결정 (Stuck decision):        the specific fork you can't resolve yourself
추천 답안 (Recommended answer):    your default + a one-line why (mark it Recommended)
질문 (Question):                   the crisp ask, as interactive-input gate options
```

Leading with a recommended default lets the user accept low-risk decisions with a
single click and spend their attention on the calls that genuinely need them.

## Interview Flow

### Phase 1: Context Gathering (2-3 questions)
Understand the big picture before diving into details.
- What triggered this request?
- What's the current pain point?
- What does success look like?

### Phase 2: Deep Dive (5-10 questions)
Systematically cover each category above. Use the interactive-input gate with multiple-choice options when possible to make answering easier.

### Phase 3: Edge Case Exploration (3-5 questions)
Focus on "what if" scenarios. These often reveal the most important requirements.

### Phase 4: Prioritization (2-3 questions)
Help the user distinguish must-haves from nice-to-haves.

### Phase 5: Validation (1-2 questions)
Summarize understanding and confirm before finalizing.

## Interactive-Input Gate Best Practices (Claude: AskUserQuestion)

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

Scale the output to the interview's weight: don't force a full spec file onto a
two-question focused session:

- **Lightweight close (small / focused interviews):** summarize inline as
  **Decisions made** + **Open questions** and proceed. No spec file. Use this when
  the focused mode resolved one or two decisions and implementation can start
  immediately.
- **Full spec (large / multi-decision interviews):** write the comprehensive spec
  file as below. Use this when breadth-first coverage produced enough requirements
  that they need to persist for implementation and review.

When the interview warrants a full spec:
1. Summarize all requirements back to the user
2. Ask for confirmation through the interactive-input gate
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

## Reusable Prompt Output

When the interview's goal is a copy-paste-ready prompt for next-session reuse rather than a spec file, structure the output with Google's TCREI framework (Task/Context/References/Evaluate/Iterate): see `references/tcrei-template.md` for the diagnosis table, output template, and domain-specific gap patterns.

## Interviewing Anti-Patterns to Avoid

1. **Assuming you know best** - Always verify assumptions
2. **Leading questions** - Don't bias the answer
3. **Stopping too early** - Keep probing until truly complete
4. **Ignoring contradictions** - Surface and resolve conflicts
5. **Forgetting to summarize** - Always validate understanding
6. **Skipping prioritization** - Everything can't be P0
