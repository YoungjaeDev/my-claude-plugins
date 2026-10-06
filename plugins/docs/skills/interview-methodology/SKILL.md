---
name: interview-methodology
description: This skill should be used to confirm the open points of a small, ambiguous request before implementing it ("interview me", "ask me questions", "gathering requirements", "understand my needs before implementing"), or when the interview output should be a reusable prompt in Google's TCREI format ("TCREI", "structure this prompt", "make a prompt for next session", "rewrite as TCREI"). Ends with an inline summary, never a spec file. Large multi-decision work goes to /grill-with-docs; pressing an existing plan hard goes to Matt grilling.
version: 0.4.0
---

# Interview Methodology

## Cross-runtime interactive input

Every question below runs through a **capability-aware** interactive-input gate, not one hardcoded tool. Read each `AskUserQuestion` mention as this gate:

- **Claude Code**: use `AskUserQuestion`.
- **Codex**: use `request_user_input` when that tool is exposed. When it is not, ask ONE concise blocking question only where a wrong assumption would be costly; otherwise proceed on a documented safe default and state the assumption.

Full policy: `AGENTS.md` → "Cross-runtime interactive input policy".

A framework for confirming the open points of a request before implementing it, uncovering hidden needs, constraints, and edge cases. The result is an inline summary in the conversation, never a file. When the work turns out large (many interlocking decisions, or a spec worth persisting for review), stop and tell the user to run `/grill-with-docs` instead. To press an existing plan or decision hard, hand off to Matt `grilling`.

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
explicitly relaxed by **"When NOT to Interview"** (whether to interview at all).
When it applies, it overrides rules 3-4 below.

1. **Use the interactive-input gate** for all questions (Claude `AskUserQuestion`; see "Cross-runtime interactive input") - never just ask in plain text
2. **Questions must NOT be obvious** - avoid basic questions the user has already answered
3. **Don't stop a full interview early** - once committed to a full (breadth-first) interview, cover it; don't bail after 2-3 questions. (Doesn't apply when "When NOT to Interview" already capped the scope at 2-3 targeted questions.)
4. **Probe deeper on substantive answers** - each response can spawn follow-ups; in depth-first mode this is the primary loop. (Not a mandate to follow up on every trivial confirmation.)
5. **Close inline, never with a file** - end with the summary in "Interview Completion"; work too large for that goes to `/grill-with-docs`.

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
implementation. A full multi-phase interview is for genuinely under-specified
work, not a reflex for every request.

## Core Principle: Non-Obvious Questions

**Never ask questions the user has already implicitly answered.** Instead, probe the gaps, assumptions, and unstated requirements.

**Verify against the codebase first: don't ask what the repo can answer.** Before adding a question, check whether the existing code, config, tests, git history, or docs already settle it (which framework, which DB, the current error-handling pattern, existing naming conventions). Asking the user to restate something discoverable from the repo wastes their time and signals you didn't look. Reserve questions for what is genuinely *non-obvious from the code*: intent, priorities, future direction, and trade-offs only the user holds.

Bad-vs-good question examples and the 5-category question bank
(Technical / UX / Edge Cases / Constraints / Business Context) used in
Phase 2 below: `references/question-framework.md`.

## Two Interview Modes

Pick the mode that fits the uncertainty, and say which you're using:

### Breadth-first (the 5-phase flow below)
Systematically sweep every category. Best when the work is large, multi-decision,
and you need full coverage before implementation. Batch related questions
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

Structure each question with explicit options (single-select or
`multiSelect`) and put the implications in each option's description,
not just the choice: worked examples in `references/gate-examples.md`.

## Interview Completion

Close in the conversation, not in a file:

1. Summarize back as **Decisions made** + **Open questions**.
2. Confirm through the interactive-input gate when a decision was a judgment
   call the user has not yet seen stated plainly.
3. Proceed with the work.

If the interview shows the work is larger than a small request (many
interlocking decisions, or requirements that need to persist for
implementation and review), stop and tell the user to run `/grill-with-docs`,
which owns the spec path.

## Reusable Prompt Output

When the interview's goal is a copy-paste-ready prompt for next-session reuse rather than an inline summary, structure the output with Google's TCREI framework (Task/Context/References/Evaluate/Iterate): see `references/tcrei-template.md` for the diagnosis table, output template, and domain-specific gap patterns.

## Interviewing Anti-Patterns to Avoid

1. **Assuming you know best** - Always verify assumptions
2. **Leading questions** - Don't bias the answer
3. **Stopping too early** - Keep probing until truly complete
4. **Ignoring contradictions** - Surface and resolve conflicts
5. **Forgetting to summarize** - Always validate understanding
6. **Skipping prioritization** - Everything can't be P0
