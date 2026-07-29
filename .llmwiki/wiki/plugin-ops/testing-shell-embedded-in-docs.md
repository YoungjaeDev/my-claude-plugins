---
id: testing-shell-embedded-in-docs
aliases: [test-the-artifact-not-a-copy, skill-body-shell-under-test, fence-extraction-testing]
last_verified: 2026-07-29
status: active
volatility: stable
sources: 2
---

# A skill's shell lives in its document, so the document is what the test must run

Most plugins here ship `scripts/` a test can invoke. A skill that instead carries its shell
*inside* `SKILL.md` has no executable under test: the blocks are instructions an agent will paste
into a shell later, and nothing in CI ever runs them. The obvious move — retype the logic into the
test file — produces a suite that passes forever while the real block rots, because the two copies
drift the moment either is edited.

**Extract the fence and run it.** Pull the ```bash block out of the document at test time and
execute it against a throwaway `HOME` and working directory. The bytes under test are then the
bytes the skill tells an agent to run.

## The four rules this decomposes into

- **Anchor extraction on fence *content*, never on an ordinal.** "The 3rd ```bash fence after this
  heading" breaks silently the first time a fence is inserted earlier — the index slides onto a
  neighbouring block and the suite starts certifying something it does not name. Match on a string
  the target block must contain, and fail loudly when nothing matches (an empty extraction that
  "passes" every case is worse than no test).
- **Grepping for a construct is not testing it.** A presence check confirms the *shape* of a fix,
  not its *behaviour*. Concrete cost: a `top_level_true()` helper written as
  `{ … exit ok ? 0 : 1 } END { exit 1 }` always returned 1 — in awk an `exit` inside a main rule
  jumps to `END`, and an `exit` there overwrites the status — so a correctly-configured file was
  rejected every time. The suite asserted the awk was *present* and stayed green through four
  review iterations; one executed case found it immediately.
- **Do not detect prose by pattern — parse.** A fence that lost its closing marker swallows the
  markdown that follows, and the extractor then hands that prose to `bash`. Hunting for what prose
  "looks like" is unwinnable: a `**Uppercase` regex misses Korean text, bullets, headings, and
  `#`-prefixed lines are indistinguishable from shell comments. `bash -n` on every extracted fence
  is the real parser and rejects leaked prose and ordinary syntax errors with one check.
- **Fixtures must not supply what the block is supposed to supply itself.** A test that injected
  the pin values through the environment hid the fact that the documented block never assigned
  them — following the skill literally would have written five empty strings into the registry.
  Run the block with nothing fed in, and let the assertions go empty if it is not self-contained.

## When to apply

Any skill, hook descriptor, or reference doc whose body contains shell an operator or agent is
expected to execute. Also the inverse: if a document's shell is too awkward to extract and run,
that is a signal it belongs in a bundled `scripts/` file instead.

## Why it matters here

`convene` ships no scripts by design (no `PLUGIN_ROOT` resolver needed, fewer moving parts), so
its registry arithmetic, runner contracts, and TOML editing all live in `SKILL.md`. Two of the
failures above — the mirrored TTL logic and the environment-fed pins — were found by reviewers, not
by the suite that existed to catch them.

## Sources

- PR #189 (`af75c84`) — CodeRabbit iteration 1 flagged the mirrored TTL implementation; iteration 5
  flagged the pattern-based prose check. Codex P1 (iteration 2) flagged the environment-fed pins.
- `plugins/council/skills/convene/tests/run-tests.sh` — the resulting suite (65 cases), wired into
  `.githooks/pre-commit` and both CI legs.

> See-also: [[detector-cannot-look-vs-nothing-wrong]]
> See-also: [[skill-authoring-source-grounded-then-audit]]
> See-also: [[council-cross-vendor-design]]
