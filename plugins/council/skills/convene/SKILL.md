---
name: convene
description: "Convene a cross-vendor council: codex (GPT), agy (Gemini) and a Claude Opus seat answer independently, hand follow-up questions to the user, rebut each other, then the chair synthesizes agreement and surviving disagreement. Use on /council:convene, '카운슬', '심의', '다른 모델 의견', 'convene a council', 'second opinion from another model', 'cross-model debate'. For a decision that needs a different model's judgment rather than more Claude sampling; not for ordinary code review."
---

# Council — cross-vendor deliberation

Put one question to 3 models from 3 different vendors, make them read and rebut each other over 2
rounds, and write down what they agreed on, what stayed contested, and what nobody could answer.
Several Claude subagents share weights and therefore share their systematic mistakes, so a real
second opinion has to come from a model somebody else trained.

This plugin runs on Claude Code only (the Claude seat needs the `Agent` tool). Every question to the
user goes through `AskUserQuestion`.

## Roles

The chair is the main session. It composes prompts, relays the user's answers, and synthesizes. The
chair is not a seat and does not vote.

| Seat | Runner | Registry key |
|---|---|---|
| codex | `codex exec` | `seats.codex` |
| agy | `agy --print` | `seats.agy` |
| claude | `Agent` tool with a `model` override | `seats.claude` |

All runnable bash lives in `references/`: read `references/registry.md` before Step 0 and
`references/run-and-rounds.md` before Step 1, and run their blocks as written.

## Step 0 — resolve the model registry

Seat models are pinned in `~/.claude/council-models.json`, confirmed at most once a week.

- **TTL**: seven days, a constant in the reader block, never a field read back from the registry. A
  timestamp that is missing, non-numeric or in the future, or a `seats` block that is missing,
  malformed or empty, counts as expired.
- **Fresh**: `STATE=fresh` and every pin still on its CLI's own candidate list means go to Step 1
  without asking. A CLI update can retire a pin inside the window, so the candidate-list check
  always runs.
- **Confirm**: `STATE=missing`, `STATE=expired`, or a `STALE_PIN=` line means confirm the pins with
  the user before convening. Expiry always asks, even when nothing changed. A `LIST_UNREAD=` line is
  not evidence against a pin.
- **Write**: record the confirmed pins with the `Write` tool (never a heredoc or `echo`) to
  `.claude/state/council-pins.json`, then run the writer block. A value that fails its charset or
  enum check stops the write.
- **Codex config**: the registry write also inserts `check_for_update_on_startup = true` into
  `${CODEX_HOME:-$HOME/.codex}/config.toml` only when the key is absent, and never touches a user's
  own `false`. Never run `codex update` mid-council.
- **Preflight**: probe the installed `codex` with the pinned model, effort and tier before Step 1
  relies on them.

First-run defaults come from the candidate lists: the first visible codex entry at effort `xhigh`
(else its highest listed level) and its first speed tier, the first agy slug, and claude `opus`.

## Step 1 — set up the run and pre-collect context

- **Run directory**: derive a kebab-case `$SLUG` from the question and validate it before it reaches
  a path. The run is keyed by session id (or a `shared` lock when none is exposed), and the key and
  directory are claimed with atomic `mkdir`.
- **Tracked vs raw**: `$DIR` (`.council/<date>-<slug>/`) is git-tracked and holds only
  `consensus.md`. The brief, questions, round prompts and seat answers go to the gitignored `$RAW`
  (`.tmp/council/<same name>/`).
- **Re-hydrate**: shell variables do not survive between tool calls, so every later block starts
  with the re-hydration lines from `references/run-and-rounds.md`.
- **Pre-collect**: pass anything reachable by a path as a path. Collect only what a path cannot
  carry (mem0 memories, the Serena symbol graph, scout research when the question turns on external
  facts), and never paste `AGENTS.md`, `.llmwiki/` pages or source files.

Write the shared brief to `$RAW/brief.md`: the question, the resolved facts, the pre-collected
context, and the file paths worth reading.

## Step 2 — Round 1, independent opinions

Compose `$RAW/r1-prompt.md` from the brief plus these instructions to every seat:

1. Answer the question directly with reasoning.
2. Separately list open questions for the user: only things that would change the answer and that
   the repo cannot settle.

The Claude seat also gets the adversarial role from Step 4. Run the three seats so none sees
another's answer: codex reads its prompt on stdin and writes with `-o`, agy keeps `--print` last and
ends with `< /dev/null` (or it blocks forever), and the Claude seat runs through `Agent` with
`model` from `seats.claude.model`, writing `$RAW/r1-claude.md`. Verify each answer file exists and
is non-empty; a missing file is a failure, not an empty opinion.

## Step 3 — re-question gate

Merge the seats' open questions. Drop duplicates, and drop anything the chair can answer from the
repo or a read-only command: facts are the chair's job, decisions are the user's. Ask what remains
with `AskUserQuestion`, in the user's language, in one batch.

Record the questions and answers in `$RAW/questions.md`. Items the user declines to answer are
carried forward as unresolved, never guessed.

## Step 4 — Round 2, mutual rebuttal

Compose `$RAW/r2-prompt.md` with, for each seat, the other two seats' full Round 1 answers, the
user's Step 3 answers, and the instruction to state where it agrees, where it disagrees, and why.
The Claude seat's prompt adds one line: attack the strongest argument among the other seats first.
It shares weights with the chair, so agreement is its cheapest and least useful move.

Run the Step 2 commands against `r2-prompt.md`, writing `r2-codex.md`, `r2-agy.md` and
`r2-claude.md` under `$RAW`. Each round is a fresh CLI call carrying the debate in its prompt, never
`--resume-last`.

## Step 5 — synthesis and output

The chair writes `$DIR/consensus.md`, the only committed file:

- **합의**: what the seats converged on, and on what grounds.
- **갈린 이견**: positions that survived rebuttal, each with its holder and its strongest argument. Do
  not average them into a fake middle.
- **미해결**: what nobody could answer, plus questions the user left open.
- **결석**: any seat that did not participate, and why.

Apply the same-family consensus discount: count the Claude seat's agreement only when it brought an
argument the chair had not already made. Print 합의 / 갈린 이견 / 미해결 to the conversation, and
결석 whenever any seat was absent, so a two-seat result never reads as a full council. Release the
run pointer and the `shared` lock with the release block, on the success and the give-up path alike.

**Do not apply anything to the code.** Present the conclusion and stop; acting on a council result
is a separate, explicit request.

## Failure policy

Seats fail independently and the council continues without them. Every absence is named in
`consensus.md` and in the chat summary.

| Situation | Action |
|---|---|
| `codex` or `agy` missing from PATH | Mark the seat absent. Continue. |
| agy produced no file, or an empty one | Retry once with the same prompt, then mark absent. |
| agy log shows `auth timed out` / `silent auth failed` | Do not retry: the model never ran. Tell the user to run `agy` once interactively to re-authenticate. |
| codex returns HTTP 400 on the model | The pin is stale. Surface it and offer the Step 0 registry question. |
| All three seats fail | There is no council. Report and stop; do not synthesize from nothing. |

Triage an agy failure with the block in `references/failure-triage.md` and report only the
classification, never the log body. Show the raw log only if the user asks for it after seeing the
classification.
