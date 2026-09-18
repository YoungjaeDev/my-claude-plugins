---
name: convene
description: "Convene a cross-vendor council: codex (GPT), agy (Gemini) and a Claude Opus seat answer independently, hand follow-up questions to the user, rebut each other, then the chair synthesizes agreement and surviving disagreement. Use on /council:convene, '카운슬', '심의', '다른 모델 의견', 'convene a council', 'second opinion from another model', 'cross-model debate'. For a decision that needs a different model's judgment rather than more Claude sampling; not for ordinary code review."
---

# Council — cross-vendor deliberation

Put one question to three models from three different vendors, make them read and rebut each
other, and write down what they agreed on, what stayed contested, and what nobody could answer.

The point is divergence. Several Claude subagents share weights and therefore share their
systematic mistakes; a real second opinion has to come from a model somebody else trained.

## Cross-runtime interactive input

Every question below runs through a **capability-aware** interactive-input gate rather than one
hardcoded tool:

- **Claude Code**: use `AskUserQuestion`.
- **Codex**: use `request_user_input` when that tool is exposed. When it is not, ask ONE
  concise blocking question only where a wrong assumption would be costly; otherwise proceed on
  a documented safe default and state the assumption.

This plugin is Claude-only in practice (the Claude seat needs the `Agent` tool), so the Claude
row is the operative one. The other row is kept so the body never asserts that a single
interactive tool exists.

## Roles

The **chair** is the main session. It composes prompts, relays the user's answers, and
synthesizes. **The chair is not a seat and does not vote.**

| Seat | Runner | Registry key |
|---|---|---|
| codex | `codex exec` | `seats.codex` |
| agy | `agy --print` | `seats.agy` |
| claude | `Agent` tool with a `model` override | `seats.claude` |

---

## Step 0 — resolve the model registry

Seat models are pinned in `~/.claude/council-models.json`, confirmed at most once a week. The
seven-day TTL is a **constant, never a field read back from the registry** — a `ttl_days` taken
from the file it governs could never come up for confirmation again. A timestamp that is
missing, non-numeric, or in the future counts as expired, and so does a registry whose `seats`
block is missing, malformed, or empty: none of those shapes may buy freshness or let a seat run
with a model name of `null`.

- `STATE=fresh` **and** the pin still appears in the CLI's own candidate list: go to Step 1
  without asking anything. A CLI update can retire a pinned model inside the seven-day window,
  so freshness alone is not enough — the candidate-list check runs first.
- `STATE=missing`, `STATE=expired`, or a pin that has fallen off the candidate list: confirm the
  pins with the user before convening. Expiry **always** asks, even when nothing changed —
  deciding whether a newer model is actually better belongs to the user, not a silent upgrade.

The confirmed pins are recorded with the **`Write` tool** (never a heredoc or `echo`) to
`.claude/state/council-pins.json` as data, then a separate block validates every value against a
conservative charset and the Claude seat's fixed model enum before writing the registry through
a temp file — a value that fails validation must stop the write, not land a registry that looks
valid. Registry writes also maintain `~/.codex/config.toml`'s `check_for_update_on_startup` key
(insert only when the key is absent; never touch a user's own `false`), and a final preflight
call re-reads the pins and probes the installed `codex` CLI before Step 1 relies on them.

Defaults on first run: codex `gpt-5.6-sol` / `xhigh` / `fast`, agy `gemini-3.6-flash-high`,
claude `opus`.

See `references/registry.md` for the TTL check, the candidate-list read, the pin write and its
charset/enum validation, the `config.toml` maintenance, and the preflight probe, each with the
runnable bash.

---

## Step 1 — set up the run and pre-collect context

`$SLUG` is a short kebab-case topic name you derive from the question, validated before it
reaches a path (it comes from free text, and a `/` or `..` segment would place the run
directory outside `.council/`). The run directory is allocated per session — keyed by
`CLAUDE_SESSION_ID`/`CODEX_COMPANION_SESSION_ID`, or a `shared` lock when neither is exposed —
so two concurrent councils never share one run pointer or one output directory; both the key
and the directory allocation are claimed atomically (`mkdir`, never a check-then-write). The
run directory itself is **git-tracked**: it is the decision record, not scratch. The run
pointer under `.claude/state/` is not, and Step 5 releases the `shared` lock on both the
success and the give-up path.

Shell variables do **not** survive between tool calls — every bash block from here on starts by
re-reading `$DIR` and the seat model variables from the registry and the run pointer; skipping
that hands empty model names and an empty output path to the first seat call.

codex and agy read files on their own, so **anything reachable by a path is passed as a path**,
never pasted. Only collect context a path cannot carry: mem0 memories (behind an MCP service,
not a file), the Serena symbol graph (`find_referencing_symbols` needs a language-server index
agy cannot build), and scout research (facts outside the repo, and the most expensive of the
three — only when the question actually turns on external facts). Do **not** paste `AGENTS.md`,
`.llmwiki/` pages, or source files; cite their paths. Write the shared brief to `$DIR/brief.md`:
the question, the resolved facts, the pre-collected context, and the file paths worth reading.

See `references/run-and-rounds.md` for the SLUG/session-id validation, the atomic lock and
directory allocation, the lock-release block, and the state re-hydration block.

---

## Step 2 — Round 1, independent opinions

Compose `$DIR/r1-prompt.md` from the brief plus these instructions to every seat:

1. Answer the question directly with reasoning.
2. Separately list **open questions for the user**: only things that would change the answer
   and that the repo cannot settle.

The Claude seat additionally gets the adversarial role described in Step 4.

Run the three seats — they must not see each other's answers in this round. codex takes its
prompt on stdin and writes its answer to a file with `-o`; never parse its stdout, which
interleaves hook lines and token counts. agy takes its prompt as a shell argument, so `--print`
must be the last flag and the call must end with `< /dev/null`, or it blocks forever waiting on
a TTY that `--print-timeout` does not bound. The Claude seat runs through the `Agent` tool with
`model` set to `seats.claude.model` from the registry (`opus` by default; the tool accepts
`sonnet`, `opus`, `haiku`, `fable`), writing its answer to `$DIR/r1-claude.md`.

Verify each file exists and is non-empty before moving on. A missing file is a failure, not an
empty opinion; see the failure policy.

See `references/run-and-rounds.md` for the exact re-hydration and seat-call bash for codex, agy,
and the Claude seat's output path.

---

## Step 3 — re-question gate

Merge the seats' open questions. Drop duplicates, and drop anything the chair can answer itself
from the repo or by running a read-only command: **facts are the chair's job, decisions are the
user's**. Ask what remains through the interactive-input gate, in the user's language, in one
batch.

Record the questions and the user's answers in `$DIR/questions.md`.

If the user declines to answer, carry those items forward as unresolved and say so in the
final document rather than guessing.

---

## Step 4 — Round 2, mutual rebuttal

Compose `$DIR/r2-prompt.md` containing, for each seat: the other two seats' full Round 1
answers, the user's answers from Step 3, and the instruction to state where it agrees, where it
disagrees, and why, with reasons, not verdicts.

The Claude seat's prompt carries an extra line: **attack the strongest argument among the other
seats first.** It shares weights with the chair, so agreement is its cheapest and least useful
move; the role exists to stop it defaulting there.

Run the same three commands as Step 2 against `r2-prompt.md`, writing `r2-codex.md`,
`r2-agy.md`, `r2-claude.md`. Each round is a fresh CLI invocation carrying the debate in its
prompt: deterministic, and no dependence on `--resume-last` picking the right session.

---

## Step 5 — synthesis and output

The chair writes `$DIR/consensus.md`:

- **합의**: what the seats converged on, and on what grounds.
- **갈린 이견**: positions that survived rebuttal, each with its holder and its strongest
  argument. Do not average them into a fake middle.
- **미해결**: what nobody could answer, plus questions the user left open.
- **결석**: any seat that did not participate, and why.

Apply the **same-family consensus discount**. The Claude seat shares weights with the chair, so
its agreement is not an independent second judgment. Count it only when it brought an argument
the chair had not already made; otherwise record the agreement without treating it as support.

Print 합의 / 갈린 이견 / 미해결 to the conversation, and **결석 whenever any seat was absent**;
leave the rest of the record in the files. Dropping the absence line is what makes a two-seat
result read as a full three-seat council.

**Do not apply anything to the code.** Present the conclusion and stop. Acting on a council
result is a separate, explicit request.

---

## Failure policy

Seats fail independently and the council continues without them. Every absence is named in
`consensus.md` and in the chat summary: a quiet absence would make a two-seat result look like
a three-seat one.

| Situation | Action |
|---|---|
| `codex` or `agy` missing from PATH | Mark the seat absent. Continue. |
| agy produced no file, or an empty one | Retry once with the same prompt, then mark absent. |
| agy log shows `auth timed out` / `silent auth failed` | Do not retry: the model never ran. Tell the user to run `agy` once interactively to re-authenticate. |
| codex returns HTTP 400 on the model | The pin is stale. Surface it and offer the Step 0 registry question. |
| All three seats fail | There is no council. Report and stop; do not synthesize from nothing. |

Triage an agy failure by matching its most recent log against three known signatures, and report
only the classification, not the log body: the log sits in an agent configuration directory and
its lines carry paths, settings, and auth diagnostics the triage decision does not need. Show
the raw log only if the user asks for it after seeing the classification.

See `references/failure-triage.md` for the classification bash.
