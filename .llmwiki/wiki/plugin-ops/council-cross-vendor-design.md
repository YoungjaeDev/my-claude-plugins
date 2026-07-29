---
id: council-cross-vendor-design
aliases: [same-family-consensus-discount, cross-vendor-seats, council-model-registry]
last_verified: 2026-07-29
status: active
volatility: stable
sources: 2
---

# A council of one vendor's models is not a council

Spawning several Claude subagents buys context isolation and parallelism, not perspective — they
share weights, so they share the errors that matter. `council` exists to put a question to models
three different companies trained (`codex`/GPT, `agy`/Gemini, and a Claude seat) and make them
rebut each other before anything is synthesized.

## The chair cannot also be a voter

The chair is the main session: it composes prompts, relays the user's answers, and synthesizes. It
does **not** vote. That leaves the Claude seat sharing weights with the chair, which is the design's
one structural weakness — when that seat agrees with the chair, the chair reads "2 of 3 support my
view" from what is really one model saying the same thing twice. Two rules pay for it:

- **Same-family consensus discount** — agreement from a same-model seat is not counted as support.
  It counts only when it brings an argument the chair had not already made.
- **Adversarial role** — the seat's prompt tells it to attack the strongest argument among the
  other seats first, so agreement is not its default move.

The seat is still Opus rather than a cheaper Claude model, because round 2 is an *attack* task: a
weaker seat produces attacks the chair filters out, which makes the seat abstain in practice. The
cost of a same-family seat is paid by the two rules above, not by weakening it.

## A policy TTL must be a constant in code

Seat models are pinned in a global registry (`~/.claude/council-models.json`) confirmed at most
weekly, and expiry **always** asks rather than auto-upgrading — judging whether a newer model is
actually better is the user's call, and silent upgrades drift into unintended spend. That property
only holds if the seven-day window is a constant in the reader. A `ttl_days` field read back from
the file it governs is not a guarantee: one hand-edited value and the pins never come up again.
Same reasoning extends to the shapes a tampered or truncated registry takes — absent, non-numeric,
or future timestamps, and any missing seat pin, are all treated as expired so they route back
through confirmation instead of forward into a call with `model=null`.

Freshness is also not validity. A CLI update can retire a model inside the window, so a `fresh`
registry is still checked against the machine-readable candidate lists (`agy models`,
`$CODEX_HOME/models_cache.json`) before the run proceeds. A list that could not be *read* is not
evidence a pin is gone — that distinction has to be explicit, or a truncated cache sends the user
to pick a replacement for a model that is fine.

## Confirmed pins are data, never shell source

The values a user picks during the weekly confirmation must not be pasted into a shell block: hard
-coding defaults throws their choice away, and interpolating their answer hands `$(…)` and stray
quotes to the shell. The pins are written to a JSON file with the `Write` tool — no shell parses
it — and the writer reads that file and passes values through `jq --arg` (argv, never re-parsed),
behind a conservative charset gate. The Claude seat additionally validates against the `Agent`
tool's fixed enum (`sonnet`/`opus`/`haiku`/`fable`), because unlike the other two seats it has no
CLI to query, so a plausible-looking `claude-opus-4` would otherwise only fail at launch.

## Environment facts

- **`CLAUDE_SESSION_ID` is not exported.** Keying the per-run pointer on it alone silently
  collapses every concurrent run onto one shared pointer. `CODEX_COMPANION_SESSION_ID` *is*
  present in a Claude Code session and serves as the fallback; with neither, the run refuses to
  start a second council rather than sharing state.
- **`codex` honors `CODEX_HOME`.** Both the config and the model cache resolve through
  `${CODEX_HOME:-$HOME/.codex}`; hardcoding `$HOME/.codex` edits a directory the running CLI never
  reads. Same rule the repo's own detector applies in `plugins/project-init/scripts/project_state.sh`.
- **A wrong codex model does not hang** — it fails in seconds with an HTTP 400. `agy`, by contrast,
  blocks forever without a `< /dev/null` redirect, and `--print-timeout` does not bound it.

## Runtime scope

Claude-only (`CODEX_EXCLUDED`). Running it under Codex would seat `codex` as its own council
member, and Codex has no `Agent` tool for the Claude seat — the same circularity that excludes
`codex-image`.

## Sources

- PR #189 (`af75c84`) — the plugin, driven through 5 cr-fix iterations (39 findings, 35 applied);
  the TTL-as-constant, list-read-vs-retirement, and pins-as-data rules each came from a reviewer.
- `.claude/spec/2026-07-29-council.md` — the design record, including the deliberately deferred
  autonomous agent-team mode (teammates cannot question the user, which breaks the re-question gate).

> See-also: [[testing-shell-embedded-in-docs]]
> See-also: [[codex-image-bridge-design]]
> See-also: [[detector-cannot-look-vs-nothing-wrong]]
