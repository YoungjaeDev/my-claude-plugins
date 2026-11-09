---
name: interview-methodology
description: This skill should be used to confirm the open points of a small, ambiguous request before implementing it ("interview me", "ask me questions", "gathering requirements", "understand my needs before implementing"), or when the interview output should be a reusable prompt in Google's TCREI format ("TCREI", "structure this prompt", "make a prompt for next session", "rewrite as TCREI"). Ends with an inline summary, never a spec file. Large multi-decision work goes to /grill-with-docs; pressing an existing plan hard goes to Matt grilling.
---

# Interview Methodology

Confirm the open points of a small, ambiguous request before implementing it, in 5 phases and 5 question categories, and close with an inline summary in the conversation, never a file. Work that turns out large (many interlocking decisions, or a spec worth persisting for review) goes to `/grill-with-docs`; pressing an existing plan or decision hard goes to Matt `grilling`.

Ask with `AskUserQuestion` on Claude Code or `request_user_input` on Codex; when neither is available, ask one short plain-text question only where a wrong assumption is costly, otherwise proceed with the safe default and say so.

## Decide whether to interview

Skip the interview, or drop to one clarifying question, when the task is well specified or low-stakes:

- The request is concrete and unambiguous (inputs, outputs and acceptance criteria stated).
- It is a typo fix, a small config or copy change, a dependency bump, or tests for existing behavior.
- The scope is one obvious file or function and the change is mechanical.
- The user said "just do it" or "no questions".

Between asking nothing and a full interview, ask 2-3 targeted questions that resolve the decisions that change the implementation. A full multi-phase interview is for under-specified work, not a reflex.

## Bright lines

These govern a full interview once one is warranted; the 2-3 question middle path above relaxes rule 4 only.

1. **Use the question tool**: every question goes through the tool named above when one is exposed, never as plain text.
2. **Non-obvious only**: never ask what the user already answered, explicitly or implicitly.
3. **Repo first**: before adding a question, check whether code, config, tests, git history or docs already settle it (framework, database, error-handling pattern, naming). Ask only about intent, priorities, future direction and trade-offs the user holds.
4. **Finish a full interview**: once committed to a breadth-first interview, cover every category; do not stop after 2-3 questions, and probe substantive answers with follow-ups (not every trivial confirmation).
5. **Close inline, never with a file**: end with the summary below; work too large for that goes to `/grill-with-docs`.

## Interview flow

Sweep every category, batching related questions. The bad-vs-good examples and the 5-category question bank (Technical, UX, Edge Cases, Constraints, Business Context) are in `references/question-framework.md`.

1. **Context (2-3 questions)**: what triggered the request, the current pain point, what success looks like.
2. **Deep dive (5-10 questions)**: each category of the question bank, multiple-choice where possible.
3. **Edge cases (3-5 questions)**: "what if" scenarios, which often reveal the most important requirements.
4. **Prioritization (2-3 questions)**: must-haves versus nice-to-haves; not everything is P0.
5. **Validation (1-2 questions)**: summarize the understanding and confirm before finalizing.

Frame each substantive question so the user can answer in one glance, leading with a recommended default so a low-risk call is a single confirmation:

```text
현재 이해 (Current understanding): what you already know / inferred from the code
막힌 결정 (Stuck decision):        the specific fork you can't resolve yourself
추천 답안 (Recommended answer):    your default + a one-line why (mark it Recommended)
질문 (Question):                   the crisp ask, as interactive-input gate options
```

Give each question explicit options (single-select or `multiSelect`) with the implication in each option's description (examples: `references/gate-examples.md`). Avoid leading questions, surface contradictions, and verify assumptions.

## Done

Close in the conversation:

1. Summarize back under two labels, `Decisions made` and `Open questions`.
2. Confirm with the question tool when a decision was a judgment call the user has not yet seen stated plainly.
3. Proceed with the work.

If the interview shows the work is larger than a small request, stop and tell the user to run `/grill-with-docs`, which owns the spec path. When the goal is a copy-paste-ready prompt for a later session instead of an inline summary, structure it with Google's TCREI framework (Task, Context, References, Evaluate, Iterate) from `references/tcrei-template.md`, which holds the diagnosis table, the output template and the domain gap patterns.
