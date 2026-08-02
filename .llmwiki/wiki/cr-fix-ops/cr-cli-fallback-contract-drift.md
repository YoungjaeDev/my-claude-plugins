---
id: cr-cli-fallback-contract-drift
aliases: [coderabbit-cli-0-6-schema, cr-fix-two-dot-diff, cr-cli-parser-crash, suggestions-are-strings-not-objects, cr-check-run-surface]
last_verified: 2026-08-02
status: active
volatility: volatile
sources: 6
---

# cr-fix's rate-limit fallback drifted away from the tools it falls back to

`cr-fix` treats a rate-limited CodeRabbit PR-bot as recoverable: `--cr-source auto` flips to the local `coderabbit` CLI. That escape hatch is exercised only when the PR-bot is unavailable — which is exactly when nobody is watching it — so contract drift in the fallback path stays invisible until it is load-bearing.

Three drifts, all measured on one run (PR #104, CodeRabbit CLI 0.6.1, PR-bot rate-limited by Fair Usage).

## 1. The CLI finding schema changed; the parser did not

`scripts/parse-cr-cli-jsonl.sh` (and `references/cr-cli-jsonl-schema.md`) were written against CodeRabbit CLI **v0.5.x**, where a `finding` event carried `location` / `line` / `comment`.

**Correction (0.6.5, measured).** The parser already read `fileName`, `severity` and `codegenInstructions`; those bindings were never the crash. The fatal line is `.suggestions[0].line`: `suggestions` is an array of raw patch **strings**, not objects, and indexing a string with `.line` aborts jq with `Cannot index string with string "line"`. The slurp path and the per-line fallback shared that expression, so the fallback died with it. A PR whose findings all carry `suggestions: []` survives by accident, which is why the crash looks intermittent.

A second, quieter drift outlives the crash fix: **`comment` is absent entirely** in 0.6.x. The key union of a `finding` is exactly `type`, `fileName`, `severity`, `suggestions`, `codegenInstructions`. So `body` comes back empty, `type_emoji` (parsed out of `comment`'s `_Type_ | _Severity_` header) is always `null`, and `line` is always `null` unless it is parsed out of the prose inside `codegenInstructions` (`around lines 11 - 23`, `at line 4`). With `type_emoji` null, `classify-item.sh` falls through to its severity-only branch and a `minor` CLI finding lands in the `review` tier — surfaced, never applied. The CLI path therefore fixes strictly less than the PR-bot path even after the parser runs.

CLI **0.6.1** emits a different shape:

```json
{"type":"finding","fileName":"...","severity":"major",
 "suggestions":["<patch text>"],"codegenInstructions":"..."}
```

`location` is `null`; there is no `line` and no `comment`. `suggestions` is sometimes `[]`, sometimes an array of raw patch strings. The parser dies on the first finding with `jq: Cannot index string with string "line"`, so **the whole CLI fallback is non-functional unattended**. The spawn wrapper still reports `exit: 0, emitted_complete: true` — the CLI itself succeeded — which means the failure surfaces one step later, in the parser, not in the health check.

Severity is the field that survived: `minor` / `major` map cleanly onto the existing tier table.

## 2. `git diff A..B` compares endpoints, not merge-base

Step 5b's small-diff heuristic (flip to `codex-only` when the change is tiny) sizes the PR with:

```bash
git diff --shortstat "origin/$BASE..HEAD"
```

In `git diff`, two-dot is **not** merge-base — it is `git diff origin/$BASE HEAD`, a plain endpoint comparison. Once the base branch advances past the fork point, every commit that landed on base but not on the branch shows up *reversed* in the count.

Measured on PR #104 after `main` gained two commits:

| form | files | LoC |
|---|---|---|
| two-dot `origin/main..HEAD` (current code) | 21 | 627 |
| three-dot `origin/main...HEAD` (merge-base) | 10 | 420 |
| GitHub's own PR diff | 10 | 420 |

Three-dot matches GitHub exactly. The bug is silent unless the PR sits near the `--small-diff-threshold-loc` / `-files` boundary, where it flips the codex-only decision the wrong way. (`git log A..B` *is* merge-base-ish and reads fine; the trap is that `git diff` gives the same syntax a different meaning.)

## 3. The reset estimate is present but unparsed

`scripts/sniff-cr-rate-limit.sh` returns `{"hits":1,"reset_minutes_estimate":null,"channel":"comment"}` while the comment body it just matched says, verbatim:

> **Next review available in:** **41 minutes**

Step 7c's `AskUserQuestion` fallback then offers the hard-coded "Wait ~15 min" default. The number is in the payload; the extractor does not look for that phrasing.

## 4. The wrapper's completion signal can be read before it exists

Step 7d decides the CLI path's health from `cr-cli-spawn.sh`'s marker line: `exit != 0` **or**
`emitted_complete=false` means `cli_failed`, break the loop. That reads the marker as if its absence
were a verdict. It is also just a race.

Measured on PR #197: the background-task notification reported the spawn "completed (exit code 0)"
while its output file was **0 bytes** and the JSONL sat at 5 lines ending on
`{"type":"status","phase":"analyzing","status":"summarizing"}`. The `coderabbit` child had outlived
the wrapper process the notification was tracking and was still emitting heartbeats. Minutes later
the same output file held `{"exit":0,"emitted_complete":true}` and the JSONL had grown to 22 lines
including `complete` — the run had been healthy the whole time.

Read at the moment the notification arrives, `emitted_complete=false` is a false negative, and the
documented response to it is to stop a converging loop. The distinguishing evidence is not the
marker but the JSONL: a run that truly died stops mid-phase and stays there, while a live one keeps
appending `heartbeat` lines. Check the transcript for a terminal `complete` before declaring
`cli_failed`, and re-read the marker rather than trusting the first read.

This is not a drift in cr-fix's code — the wrapper's contract is correct — but it lands on the same
fallback path as the three above, and it fails the same way: the health signal is checked, it
answers, and the answer is wrong in the direction of "give up".

## Why this class of bug hides

Every one of these lives on a path taken only when the primary path fails. The rate-limit fallback has no test that runs it against a current CLI, and the small-diff heuristic only misfires when the base moved *and* the diff is near a threshold. The signal that caught all three was running the fallback for real, once, and reading its output instead of its exit code.

## Resolution — cr-fix 2.7.1

All of the above is fixed as of cr-fix 2.7.1 (merged `75f7c9d`); this page stays as the drift record and the lesson above stands.

- Parser rewritten against the measured 0.6.5 five-key schema: `suggestions` handled as patch **strings**, `comment` treated as absent, `line` recovered from `codegenInstructions` prose where present.
- Step 5b sizes the diff with three-dot (merge-base), matching GitHub's own PR diff.
- `sniff-cr-rate-limit.sh` extracts the "Next review available in: N minutes" refill phrasing — and counts it in the hit gate itself (the initial 2.7.1 cut had it only in the minutes regex, so that phrasing alone still yielded hits=0; caught in merge review).
- New capability the drift analysis exposed: CodeRabbit reports on **two surfaces** (commit-status OR check-run, install-dependent). `cr-commit-state.sh` now reads both — statuses preferred; among check-runs a queued run (null `started_at`) sorts **newest**, or a stale completed success masks the queued re-review (also caught in merge review).
- Root cause addressed, not just the instances: a 21-test offline suite with recorded 0.5.x/0.6.5/check-run fixtures now runs the fallback path in CI and pre-commit — the "no test runs it against a current CLI" gap is closed.

> See-also: [[cr-rate-limit-progressive-refill]]
> See-also: [[cr-cli-false-positive-generated-files]]
> Evidence: plugins/github-dev/skills/cr-fix/scripts/parse-cr-cli-jsonl.sh
> Evidence: plugins/github-dev/skills/cr-fix/references/cr-cli-jsonl-schema.md
> Refined-by: [[jq-capture-yields-empty]]
> See-also: [[codex-review-threads-never-resolve]]

## Sources

1. **PR #104 dogfood run** — PR-bot rate-limited (Fair Usage), `--cr-source auto` flipped to CLI; `parse-cr-cli-jsonl.sh` crashed on the first `finding`; findings were recovered by hand-parsing the JSONL. All three drifts observed in the same run.
2. **CodeRabbit CLI 0.6.1 JSONL** (`/tmp/cr-cli-review-104-iter1.jsonl`) — 13 lines: `review_context`, `status` x6, `heartbeat` x2, `finding` x3, `complete`. `finding` keys: `codegenInstructions`, `fileName`, `severity`, `suggestions`, `type`.
3. **`git diff` two-dot vs three-dot semantics** — verified against `gh pr view 104 --json changedFiles,additions,deletions`, which agrees with three-dot and disagrees with two-dot once the base advanced.
4. **CodeRabbit CLI 0.6.5 run on PR #107** (`/tmp/cr-cli-review-107-iter3.jsonl`, 12 lines, 3 findings) — `bash parse-cr-cli-jsonl.sh` exits 5 with `jq: error (at <stdin>:3): Cannot index string with string "line"`; the two findings carrying `suggestions: []` project fine, the third carries a patch string. `finding` key union confirmed as five keys, `comment` present in zero of three. `cr-cli-spawn.sh` still reports `{"exit":0,"emitted_complete":true}` — the CLI succeeded; only the parser died.
5. **PR #109 (merged `75f7c9d`, cr-fix 2.7.1)** — the resolution: parser/diff/sniffer fixes, dual-surface `cr-commit-state.sh`, 21-test offline suite (incl. the two merge-review blocker fixes: refill phrasing in the hit gate, queued-run sort).
6. **PR #197 dogfood run (CodeRabbit CLI 0.7.0)** — PR-bot rate-limited (`Review rate limited`, ~47 min refill), `--cr-source auto` flipped to CLI and the CLI path worked. Section 4's race measured directly: task notification "completed (exit 0)" against a 0-byte marker file and a 5-line JSONL still on `analyzing/summarizing`; the same files later held `emitted_complete: true` and a terminal `complete` at 22 lines.
