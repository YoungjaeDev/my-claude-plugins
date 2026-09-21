---
name: orchestrate
description: "Run the main agent as an orchestrator that delegates work to subagents: write each job card (goal, scope, absolute paths, output shape, done criteria), pick a model and effort preset per job, give agents disjoint file ownership, reject and re-query ambiguous or unverified answers, and own the final result. Use on /dev:orchestrate, '서브에이전트로 나눠서', '위임해서', '병렬로 나눠서', '오케스트레이터로', '에이전트 팀으로', 'delegate this to subagents', 'split this across agents', 'act as the orchestrator'. Chooses between Agent, fork, agent team, worktree isolation, Workflow (manual call only), or doing the work inline. Not for a one-shot parallel fan-out with no quality loop (superpowers:dispatching-parallel-agents), executing a written plan task by task (superpowers:subagent-driven-development), web research (scout:research-orchestrator), or writing a Workflow script (workflow-authoring)."
---

# orchestrate

Conduct a task through subagents without giving up ownership of the result.

## Overview

The main agent conducts; it never becomes one of the workers. Three invariants hold for the whole
run: every delegation is a job card, every returned result passes a quality gate before anything
is built on it, and the orchestrator alone verifies and answers the user. Model and effort are
chosen per job through the worker presets bundled in `plugins/dev/agents/`, because the `Agent`
tool overrides `model` per call but reads effort only from the agent definition.

Codex has no `Agent` tool. There the skill degrades to inline work that still uses the job card
as its checklist.

## When to use

Delegate when at least one of these holds:

- the task splits into two or more slices that need no result from each other
- one slice would pull so many files into the main context that coordination afterwards suffers
- the task mixes cheap mechanical work with accuracy-critical work that deserves a stronger model

Do the work inline when the change is one known file or location, or when writing the job card
would take longer than the job. A written implementation plan with numbered tasks goes to
`superpowers:subagent-driven-development` instead.

When the task itself is under-specified, load `docs:interview-methodology` and resolve the
decisions through `AskUserQuestion` before slicing.

## Quick reference

### Worker presets

| Preset | `subagent_type` | Model / effort | Pick when |
|---|---|---|---|
| standard | `dev:worker-standard` | sonnet / medium | bounded implementation, tests, docs, module summary, locate, list, grep-style lookup, mechanical rename; the default for most slices |
| deep | `dev:worker-deep` | opus / high | root cause, cross-module refactor, design or security review; a wrong answer costs a rerun |
| max | `dev:worker-max` | opus / xhigh | correctness the orchestrator cannot verify cheaply; only when the user asks for maximum accuracy |

Volume pushes a slice toward standard, accuracy toward deep or max. A slice that fails the
quality gate twice moves one preset up; that escalation is the one path to max that needs no user
request. Pass `model` on the `Agent` call only to deviate from a
preset for one job; the preset's effort still applies.

### Structure selection

| Situation | Structure |
|---|---|
| independent slices, results come back as text | `Agent` with a `dev:worker-*` type, `name` set, background, all dispatched in one message |
| the worker needs the conversation so far | `Agent` with `subagent_type: fork` |
| slices must exchange results or run long | named agents plus `SendMessage`; `ListAgents` shows who is idle |
| a slice writes files | `isolation: worktree` on the `Agent` call — one branch per writer is what makes the step 5 scope check possible at all, and step 7 merges only the branches that passed it |
| many-stage pipeline with no user judgment mid-way, or resume is needed, and the user typed `/dev:orchestrate` or "ultracode" | `Workflow`, after loading `workflow-authoring` |
| another vendor's agent (codex-rescue, agy-rescue, sidekick) looks like a better fit | ask through `AskUserQuestion` first, every time |
| one slice with a known location | inline, no delegation |

A description-triggered run uses `Agent` only; `Workflow` needs the user's own opt-in (the user's
`/dev:orchestrate` call counts as that opt-in). If a slice inside a running `Workflow` turns out to
need a user question, return to the `Agent` loop for that slice instead of stalling the script.

### Job card

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

## Procedure

1. **Slice.** Write the slice list: for each slice, its goal, whether it depends on another
   slice's result, the absolute paths it owns for writing, and the paths it only reads. Two slices
   that would write the same path are merged into one slice or ordered one after the other.
   Investigation and review slices own no write paths. Done when every path appears under at most
   one writer.
2. **Write the job cards.** One card per slice with all seven fields filled. Inputs carry what the
   conversation already settled; the worker never inherits the session, so the card is its whole
   world. A slice that needs a test seam gets that seam agreed before dispatch and carried in
   Inputs, since a worker subagent has no `AskUserQuestion` to fall back on. Done when each card can be
   read on its own and answered without a follow-up question.
3. **Pick preset and structure** from the two tables. Give every agent a `name` so a re-query can
   reach the same transcript. Done when each card names its preset and the run names its structure.
4. **Dispatch.** Independent slices go out in one message, in the background. Dependent slices wait
   for the result they consume. Every slice that writes goes out with `isolation: worktree`. A fresh
   worktree carries none of the main checkout's uncommitted, untracked or ignored files, so a worker
   cannot reach the user's work at all, and its branch is a per-worker record of what it changed —
   which is the whole basis of the step 5 check. The card tells the worker to commit its work on
   that branch before returning; work left uncommitted in a worktree is invisible to the check and
   never merges. A slice that must write in the main checkout runs alone, with no other writer in
   flight, and its results are surfaced rather than merged. Record `git rev-parse HEAD` as the base
   the workers branched from, and `git worktree list` as the baseline for step 7. While agents run,
   the orchestrator prepares the verification of step 6 instead of doing a worker's job in parallel.
   Done when every card has been sent and both baselines are recorded.
5. **Quality gate.** Read each result against its card. Reject when any of these holds: the answer
   is ambiguous or hedged where the card asked for a decision, a claim carries no evidence
   (`file:line` for file content, command plus output for a run result, the path for a path), the
   result contradicts what the repository shows, the done criteria are not met, or the card's owned
   Paths were exceeded. That last one is decided by git, not by the worker's report. **Path
   violation:** list what the worker's branch changed with `git diff -z --name-only <recorded
   HEAD>...<worker branch>` — three dots, so commits the base picked up meanwhile stay out of the
   list — and resolve each repo-relative path against the repo root. `-z` is load-bearing: under
   default `core.quotePath` a non-ASCII or newline path comes back quoted and octal-escaped,
   matching neither the card's absolute paths nor anything on disk, so a legitimate owned file reads
   as a violation. A path outside *this* card's owned Paths is a violation; another card owning it
   is no defence, because step 1 gave every path one writer. **Content violation:** a diff inside an
   owned path that the card's Goal does not explain — an unrequested feature, a refactor nobody
   asked for, a bulk reformat. On rejection, re-query in this order and stop at the first pass:
   1. `SendMessage` to the same agent, naming the failed criterion, at most twice.
   2. Re-dispatch the card once on the next preset up, with the rejected answer attached as an input.
      A rejected `dev:worker-max` result has no next preset and goes straight to 3.
   3. `AskUserQuestion` with the rejected answers summarised; another vendor's agent is one of the
      options offered there, never a silent fallback.
   Done when every slice has an accepted result or an open question in front of the user.

   **Scope violations.** The orchestrator does not revert anything. A branch that fails the check is
   simply not merged, so its writes never reach the user's checkout; send the card back down the
   re-query ladder naming the paths it left, and write `scope violation: <path>` in the agent's
   ledger row. Use `AskUserQuestion` before dropping a branch whose out-of-scope work looks worth
   keeping. A content violation goes the same way — the ladder, never a revert. The one slice that
   can touch the user's checkout is a main-checkout writer, and there the orchestrator reports
   rather than repairs: compare `git status --porcelain -z --untracked-files=all` with the reading
   taken before that slice went out, show the user what moved outside the card, and let them decide.
   Never `git checkout .` or `git stash` — the user's own uncommitted work is in that checkout too.

6. **Integrate and verify.** Combine the accepted results and verify them directly: run the tests,
   lint, or build the repository defines, and `Read` the decisive `file:line` evidence. Worker
   self-reports do not count as verification. When a slice needs an evaluation, a quantitative check
   becomes the smallest script that fails when the property breaks, and a qualitative check goes to a
   deep-preset review slice with its own card. Done when the verification commands have run in this
   session and their output is in hand.
7. **Clean up and report.** Merge only the branches that passed step 5; a branch that did not is
   dropped, not cleaned up by hand. Then compare `git worktree list` with the baseline taken before
   dispatch and run `git worktree remove <path>` plus a delete of the `worktree-<name>` branch until
   the list matches. Report to the user with the outcome first, then a ledger:

   | Agent | Preset | Retries | Verdict | Evidence |
   |---|---|---|---|---|

   Done when the report names what was verified, what remains `unverified`, and the ledger has one
   row per dispatched agent.

## Pitfalls

| Symptom | Cause |
|---|---|
| two agents edited the same file | step 1 skipped the per-path writer check; merge the slices or serialise them |
| a worker asked a clarifying question and stalled | the card's Inputs omitted a decision the conversation had already made |
| an accepted answer turned out wrong at step 6 | the gate accepted a claim without `file:line`; evidence is a gate criterion, not a report format |
| the orchestrator ran out of context mid-run | it read the worker's files itself during step 4 instead of waiting for the card's output shape |
| a worktree survived the session | `isolation: worktree` keeps a changed worktree until a periodic sweep; the baseline comparison in step 7 was skipped |
| `Workflow` refused or surprised the user | the run was description-triggered; `Workflow` needs the user's own `/dev:orchestrate` call or "ultracode" |
| a worker edited a file no card owned | the writing slice went out without `isolation: worktree`, so its writes landed in the shared checkout where no branch attributes them and the gate had only the worker's self-report |
| a worker's branch diff came back empty | the card never told it to commit; uncommitted work in a worktree is invisible to the step 5 check and never merges |
| effort never changed between jobs | `model` was passed on the `Agent` call without a `dev:worker-*` type; effort lives in the preset definition |

## Verification

The run is done when the slice list shows one writer per path, every writing slice ran in its own
worktree or alone in the main checkout, every dispatched agent has a ledger row with an accepted
verdict or an open user question, every merged branch passed the step 5 path check, the verification
commands ran in this session, `git worktree list` matches its pre-dispatch baseline, and the user's
report leads with the outcome and marks anything unverified as such.
