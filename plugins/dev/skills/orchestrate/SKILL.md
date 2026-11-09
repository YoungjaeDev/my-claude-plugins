---
name: orchestrate
description: "Run the main agent as an orchestrator that delegates work to subagents: write each job card (goal, scope, absolute paths, output shape, done criteria), pick a model and effort preset per job, give agents disjoint file ownership, reject and re-query ambiguous or unverified answers, and own the final result. Use on /dev:orchestrate, '서브에이전트로 나눠서', '위임해서', '병렬로 나눠서', '오케스트레이터로', '에이전트 팀으로', 'delegate this to subagents', 'split this across agents', 'act as the orchestrator'. Chooses between Agent, fork, agent team, worktree isolation, Workflow (manual call only), or doing the work inline. Not for a one-shot parallel fan-out with no quality loop (superpowers:dispatching-parallel-agents), executing a written plan task by task (superpowers:subagent-driven-development), web research (scout:research-orchestrator), or writing a Workflow script (workflow-authoring)."
---

# orchestrate

Conduct a task through subagents without giving up ownership of the result, in 7 steps. The main agent conducts and never becomes a worker: every delegation is a job card, every result passes a quality gate before anything builds on it, and the orchestrator alone verifies and answers the user.

Read `references/procedure.md` before step 1. It holds each step's detail, the worktree and path rules, and a pitfalls table.

## When to use

Delegate when at least one of these holds:

- the task splits into two or more slices that need no result from each other
- one slice would pull so many files into the main context that coordination afterwards suffers
- the task mixes cheap mechanical work with accuracy-critical work that deserves a stronger model

Work inline when the change is one known file or location, or when writing the job card would take longer than the job. A written plan with numbered tasks goes to `superpowers:subagent-driven-development`. An under-specified task first goes through `docs:interview-methodology`, with the decisions asked through `AskUserQuestion`.

## Worker presets

Model and effort are chosen per job through this plugin's `agents/worker-*.md` presets, because the `Agent` tool overrides `model` per call but reads effort only from the agent definition (<https://code.claude.com/docs/en/sub-agents#supported-frontmatter-fields>).

| Preset | `subagent_type` | Model / effort | Pick when |
|---|---|---|---|
| standard | `dev:worker-standard` | sonnet / medium | bounded implementation, tests, docs, module summary, locate, list, grep-style lookup, mechanical rename; the default for most slices |
| deep | `dev:worker-deep` | opus / high | root cause, cross-module refactor, design or security review; a wrong answer costs a rerun |
| max | `dev:worker-max` | opus / xhigh | correctness the orchestrator cannot verify cheaply; only when the user asks for maximum accuracy |

Volume pushes a slice toward standard, accuracy toward deep or max. A slice that fails the gate twice moves one preset up, the one path to max that needs no user request. Pass `model` on the `Agent` call only to deviate for one job; the preset's effort still applies.

## Structure selection

| Situation | Structure |
|---|---|
| independent slices, results come back as text | `Agent` with a `dev:worker-*` type, `name` set, background, all dispatched in one message |
| the worker needs the conversation so far | `Agent` with `subagent_type: fork` |
| slices must exchange results or run long | named agents plus `SendMessage`; `ListAgents` shows who is idle |
| a slice writes files | `isolation: worktree` on the `Agent` call: one branch per writer makes the step 5 scope check possible, and step 7 merges only the branches that passed it |
| many-stage pipeline with no user judgment mid-way, or resume is needed, and the user typed `/dev:orchestrate` or "ultracode" | `Workflow`, after loading `workflow-authoring` |
| another vendor's agent (codex-rescue, agy-rescue, sidekick) looks like a better fit | ask through `AskUserQuestion` first, every time |
| one slice with a known location | inline, no delegation |

A description-triggered run uses `Agent` only; `Workflow` needs the user's own `/dev:orchestrate` call or "ultracode". A slice inside a running `Workflow` that needs a user question returns to the `Agent` loop.

## Job card

Every `Agent` prompt and every re-query carries all seven fields.

```text
Goal:          one sentence, the question to answer or the change to make
Scope:         in / out, with an explicit "do not touch" list
Paths:         absolute paths owned (may write) and consulted (read only)
Inputs:        facts already established and decisions already made, so the worker does not re-derive them
Output shape:  findings as file:line, a diff summary, a JSON shape, or "edit in place and list changed files"
Done criteria: observable: a command that passes, N items listed, a question answered with evidence
Preset:        which dev:worker-* and the one-clause reason
```

## Steps

1. **Slice**: goal, dependency, owned and consulted paths per slice. Every path has at most one writer.
2. **Job cards**: one per slice, all seven fields, readable without a follow-up question.
3. **Preset and structure** from the tables above; every agent gets a `name`.
4. **Dispatch**: the user commits uncommitted changes on card paths first (commit, not stash). Every writing slice runs in its own worktree with Paths rewritten under that worktree root, and each base plus the `git worktree list` baseline are recorded.
5. **Quality gate**: reject hedged, unevidenced, contradicted or incomplete answers, and any branch that leaves its card's owned Paths. Git decides scope: `git rev-list --merges <base>..<worker branch>` must be empty, and `git log --no-renames -z --name-only --pretty=format: <base>..<worker branch>` lists the touched paths. Re-query up the ladder: same agent at most twice (never for a path violation), the next preset once, then the user.
6. **Integrate and verify** in one integration worktree with every accepted branch merged; worker self-reports do not count.
7. **Clean up and report**: merge the verified result, drop failed branches, return `git worktree list` to its baseline, and report the outcome first with one ledger row per agent.

## Bright lines

- Never write in the user's checkout from a worker, and never revert a scope violation: an unmerged branch is the whole remedy.
- Never merge a branch that failed step 5 or step 6, and never repair one by hand.
- Never run `Workflow` without the user's own opt-in, and never fall back to another vendor's agent without asking.
- The gate covers writes that go through git only; a write through a symlink removed before the commit is out of its reach, and the report must not claim otherwise.

## Codex

- Check whether the session exposes subagent spawning (the subagents page under <https://developers.openai.com/codex/llms.txt>).
- `dev:worker-*` presets and `isolation: worktree` do not exist there, so the run uses Codex subagents with a hand-made `git worktree add` per writing slice.
- With no delegation tool, work inline with the job card as the checklist. Take the same worktree and step 5 check by hand when a slice is large enough to be worth proving; otherwise the card's Paths bound the edits and the report names every path written.

## Done

- The slice list shows one writer per path, and every writing slice ran in its own worktree.
- Every dispatched agent has a ledger row with an accepted verdict or an open user question, and every merged branch passed the step 5 path check.
- The verification ran against the integrated tree in this session, `git worktree list` matches its baseline, and the report leads with the outcome and marks anything unverified as such.
- On a Codex inline run that took no worktree, the card's Paths bound every edit, the report names every path written, and the orchestrator verifies those paths directly.
