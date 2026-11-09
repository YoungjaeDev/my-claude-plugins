# council

A cross-vendor deliberation plugin with 1 skill, `convene`. It puts the same question to 3 models
built by 3 different companies, has them read and rebut each other, and writes the agreement, the
surviving disagreement and the unanswered questions to a tracked file. Several Claude subagents
share weights and so share their systematic errors; real divergence needs a model trained by someone
else.

## Shape

| Piece | Where |
|---|---|
| Entry point | `/council:convene` |
| Procedure and bash | `skills/convene/SKILL.md`; runnable blocks in `skills/convene/references/` |
| Seat roster + pinned models | `~/.claude/council-models.json` (global, 7-day TTL) |
| Per-run output | `.council/<YYYY-MM-DD>-<slug>/consensus.md` in the current repo, git-tracked; brief, questions, prompts and seat answers in `.tmp/council/<same name>/`, gitignored |
| Tests | `skills/convene/tests/run-tests.sh` extracts the reference blocks and runs them against a throwaway HOME |

## Decisions

- **Chair**: the main session composes prompts, relays the user's answers and synthesizes. It is not
  a seat and does not vote.
- **Claude seat**: Opus, because round 2 is an attack task. It shares weights with the chair, so the
  skill applies a same-family consensus discount and gives the seat an adversarial role.
- **TTL expiry always asks**: both CLIs expose model lists, but judging whether a new model is
  better is the user's call, so nothing auto-upgrades.
- **Pre-collect**: codex and agy read files themselves, so paths are passed as paths. Only mem0
  memories, Serena symbol graphs and scout research are packed into the prompt.
- **Claude-only**: under Codex, codex would be its own seat and the Claude seat has no `Agent` tool.
- **No agent-team debate**: teammates cannot question the user, which breaks the re-question gate.

## Portability

No bundled scripts, so no `PLUGIN_ROOT` resolver is needed. The inline shell sticks to `date +%s`,
`date -u +%Y-%m-%d`, `jq` and `mktemp`, which behave the same on GNU and BSD.
`scripts/check-shell-portability.mjs` in this repository enforces it.
