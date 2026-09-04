# council

A cross-vendor deliberation plugin. One skill, `convene`, puts the same question to three
models built by three different companies, has them read and rebut each other, and writes the
agreement, the surviving disagreement, and the unanswered questions to a tracked file.

## Why this exists

Spawning several Claude subagents does not add perspective. They share weights, so they share
their systematic errors. Real divergence needs a model trained by someone else on something
else. `core` already injects a one-line `[council]` reminder that another model is on
PATH, but nothing executes the delegation. Until this plugin, every handoff was hand-assembled.

## Shape

| Piece | Where |
|---|---|
| Entry point | `/council:convene` |
| Seat roster + pinned models | `~/.claude/council-models.json` (global, 7-day TTL) |
| Per-run output | `.council/<YYYY-MM-DD>-<slug>/` in the current repo, git-tracked |
| Design record | `.claude/spec/2026-07-29-council.md` |

Three seats, plus a chair that is not a seat:

| Seat | Runner | Pinned by default |
|---|---|---|
| codex | `codex exec` | `gpt-5.6-sol`, effort `xhigh`, service tier `fast` |
| agy | `agy --print` | `gemini-3.6-flash-high` |
| claude | `Agent` tool with a `model` override | `opus` |
| chair | the main session | whatever the user is running |

## Design decisions worth not re-litigating

- **The chair is not a seat.** It composes prompts, relays the user's answers, and synthesizes.
  It does not vote.
- **The Claude seat is Opus, and that costs something.** It shares weights with the chair, so
  its agreement is not an independent second judgment. Two rules pay that back: a
  *same-family consensus discount* (agreement alone is not evidence; only a new argument
  counts) and an explicit adversarial role in the seat's prompt. Opus is still chosen because
  round 2 is an attack task, and a weaker seat produces attacks the chair simply filters out.
- **TTL expiry always asks.** Both CLIs expose machine-readable model lists, so the skill
  *could* auto-upgrade. It does not. Judging whether a new model is actually better is the
  user's call, and silent upgrades drift into unintended spend.
- **Only unfetchable context is pre-collected.** codex and agy read files themselves, so file
  paths are passed as paths. What gets packed into the prompt is what a path cannot carry:
  mem0 memories, Serena symbol graphs, scout research.
- **Claude-only.** Running this under Codex would summon codex as its own seat, and Codex has
  no `Agent` tool for the Claude seat. Same reasoning that excludes `codex-image`.
- **Autonomous agent-team debate was deliberately deferred.** It works technically, but
  teammates cannot question the user, which breaks the re-question gate. The full finding is
  in the spec's "보류된 갈래" section.

## Runner contracts that bite

- **codex** takes its prompt on stdin via `codex exec ... -` and returns the final message with
  `-o <file>`. Do not parse stdout: hook lines and token counts are mixed into it.
- **agy** takes its prompt as a shell argument, so `--print` must be the last flag and the
  command must end with `< /dev/null`. Without that redirect it blocks forever waiting on a TTY
  and `--print-timeout` does not bound it. Its answer is also read from a file rather than
  stdout, because agy has a history of dropping stdout when it is not a terminal.
- A wrong codex model name is not a hang. It fails in seconds with an HTTP 400.

## Portability

No bundled scripts, so no `PLUGIN_ROOT` resolver is needed. The inline shell sticks to
`date +%s`, `date -u +%Y-%m-%d`, `jq`, and `mktemp -d`, all of which behave the same on GNU and
BSD. `scripts/check-shell-portability.mjs` enforces this.
