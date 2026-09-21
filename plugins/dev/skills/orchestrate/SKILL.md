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
| parallel writers own disjoint paths but each needs its own clean checkout (build, test, or generated files) | `isolation: worktree` on the `Agent` call, with the baseline in step 4 and the cleanup gate in step 7 |
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
   for the result they consume. Slices that write go out with `isolation: worktree`, or one at a
   time: two writers in one checkout cannot be told apart at the gate, and gating one against the
   other's writes reverts work that was never out of scope. Before the first dispatch, record `git
   status --porcelain -z --untracked-files=all` as the scope baseline for step 5. `-z` keeps a path
   with a space or a non-ASCII byte parseable, and `--untracked-files=all` lists a new directory
   file by file — the default collapses it to one `?? dir/` entry, which hides that a card owns some
   files inside it and none of the others, and turns a delete into a recursive one. Gitignored paths
   stay out of the baseline on purpose: they are build output and tool state, not deliverables, so
   pulling them in would make every `__pycache__` a violation and put files like
   `.claude/state/*.json` on the delete path. Record `git rev-parse HEAD` alongside it: a worker that
   commits its work leaves `git status` clean on both sides of the run, so the status baseline on its
   own sees nothing at all. Record the content of every path that baseline already
   lists as well — `git diff` *and* `git diff --cached` for a tracked one, since a staged change is
   invisible to a bare `git diff`, and `git hash-object` for an untracked one, which `git diff` does
   not cover at all. That content is the user's own work, and what it was at dispatch time is the
   only way to tell a later worker edit inside those files apart from what was there first. When any
   card uses `isolation: worktree`, record `git worktree list` before the first dispatch as the
   baseline for step 7, and take the same recordings inside each worktree. While agents run, the
   orchestrator prepares the verification of step 6 instead of doing a worker's job in parallel.
   Done when every card has been sent, the scope baseline is recorded, and, where worktrees are in
   play, the worktree baseline is recorded.
5. **Quality gate.** Read each result against its card. Reject when any of these holds: the answer
   is ambiguous or hedged where the card asked for a decision, a claim carries no evidence
   (`file:line` for file content, command plus output for a run result, the path for a path), the
   result contradicts what the repository shows, the done criteria are not met, or an owned path
   list was exceeded. Two of these are decided by git, not by the worker's report. **Path
   violation:** re-run the step 4 command after the result arrives and compare it with the baseline,
   then add what the worker committed: `git diff -z --name-only <baseline HEAD>..HEAD` in the
   checkout it worked in, which for a worktree slice is that worktree's own branch. `-z` again, and
   for the same reason: with default `core.quotePath` this prints a quoted, octal-escaped string for
   a non-ASCII or newline path, which matches neither the card's absolute paths nor the `-z` status
   baseline, so a legitimate owned file reads as a violation and the restore that follows misses.
   Resolve each repo-relative path against the repo root before comparing it with the card.
   Committing is not a way out of the gate. A path is a violation when it falls outside the owned
   Paths of the card whose result is being gated — another card owning it is no defence, because
   step 1 gave every path one writer, and a worker writing into a sibling's path is the race that
   rule exists to prevent. It counts when the path is new against the baseline, and equally when the
   baseline already listed it but its content moved from the step 4 snapshot: an already-dirty or
   already-untracked file is not a free pass to write into. Gate one result at a time and roll the
   baseline forward to the post-gate state after each accepted one, so the next comparison sees only
   the next worker's writes — which is why step 4 isolates or serialises every writing slice.
   **Content violation:** a diff inside an owned path that the card's Goal does not explain — an
   unrequested feature, a refactor nobody asked for, a bulk reformat. On rejection, re-query in this
   order and stop at the first pass:
   1. `SendMessage` to the same agent, naming the failed criterion, at most twice.
   2. Re-dispatch the card once on the next preset up, with the rejected answer attached as an input.
      A rejected `dev:worker-max` result has no next preset and goes straight to 3.
   3. `AskUserQuestion` with the rejected answers summarised; another vendor's agent is one of the
      options offered there, never a silent fallback.
   Done when every slice has an accepted result or an open question in front of the user.

   **Scope violations.** Revert a path violation path by path. A tracked file the baseline showed as
   clean goes back with `git restore --source=<baseline HEAD> --staged --worktree -- <path>` — the
   HEAD step 4 recorded, never the current one, which holds the violation itself when the worker
   committed it and would restore it verbatim. `--staged` resets the index too: a bare
   `git checkout -- <path>` copies the index into the worktree, so a worker that ran `git add` leaves
   its change staged and it rides into the user's next commit. A violation that reached a commit has
   to leave that branch's history as well — amend or rebase the path out before step 7 merges the
   branch, since a working-tree restore alone leaves the out-of-scope blob in the commits being
   merged. A file the
   baseline did not list at all is deleted, after `git restore --staged -- <path>` drops it from the
   index: removing the file alone leaves the `A` entry a worker's `git add` created, which shows up
   as `AD` and still rides into the next commit. Re-run the step 4 command afterwards to confirm
   each reverted path sits where the baseline had it. Never restore in bulk — no `git checkout .`,
   no `git stash`. A path the baseline already showed as dirty is never reverted: the user's own
   uncommitted work is mixed into that file, so surface it instead, with the step 4 diff beside the
   current one, and let the user decide. Keep whatever the worker produced inside its scope and
   carry on with the gate on that part, and write `scope violation: <path>` in the agent's ledger
   row. Reach for `AskUserQuestion` when the reverted work looks worth keeping, or when a
   dirty-baseline file needs that decision. A content violation is not a revert: send it through the
   re-query ladder above.

6. **Integrate and verify.** Combine the accepted results and verify them directly: run the tests,
   lint, or build the repository defines, and `Read` the decisive `file:line` evidence. Worker
   self-reports do not count as verification. When a slice needs an evaluation, a quantitative check
   becomes the smallest script that fails when the property breaks, and a qualitative check goes to a
   deep-preset review slice with its own card. Done when the verification commands have run in this
   session and their output is in hand.
7. **Clean up and report.** A worktree's commits pass the step 5 path check before anything is
   merged; a slice that committed out-of-scope files hands them to the merge otherwise. When any
   agent ran with `isolation: worktree`, compare
   `git worktree list` with the baseline taken before dispatch, merge what is kept, then
   `git worktree remove <path>` and delete the `worktree-<name>` branch until the list matches the
   baseline. Report to the user with the outcome first, then a ledger:

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
| a worker edited a file no card owned | step 4 recorded no `git status` baseline, so the gate had nothing but the worker's self-report to go on |
| effort never changed between jobs | `model` was passed on the `Agent` call without a `dev:worker-*` type; effort lives in the preset definition |

## Verification

The run is done when the slice list shows one writer per path, every dispatched agent has a ledger
row with an accepted verdict or an open user question, every path that changed since the step 4
scope baseline either has an owning card, was reverted, or was surfaced to the user as a
dirty-baseline file the orchestrator must not revert, the verification commands ran in this
session, `git worktree list` matches its pre-dispatch baseline, and the user's report leads with
the outcome and marks anything unverified as such.
