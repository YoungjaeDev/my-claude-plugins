---
id: cr-cli-fallback-contract-drift
aliases: [coderabbit-cli-0-6-schema, cr-fix-two-dot-diff, cr-cli-parser-crash]
last_verified: 2026-07-09
status: active
volatility: volatile
sources: 3
---

# cr-fix's rate-limit fallback drifted away from the tools it falls back to

`cr-fix` treats a rate-limited CodeRabbit PR-bot as recoverable: `--cr-source auto` flips to the local `coderabbit` CLI. That escape hatch is exercised only when the PR-bot is unavailable — which is exactly when nobody is watching it — so contract drift in the fallback path stays invisible until it is load-bearing.

Three drifts, all measured on one run (PR #104, CodeRabbit CLI 0.6.1, PR-bot rate-limited by Fair Usage).

## 1. The CLI finding schema changed; the parser did not

`scripts/parse-cr-cli-jsonl.sh` (and `references/cr-cli-jsonl-schema.md`) were written against CodeRabbit CLI **v0.5.x**, where a `finding` event carried `location` / `line` / `comment`.

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

## Why this class of bug hides

Every one of these lives on a path taken only when the primary path fails. The rate-limit fallback has no test that runs it against a current CLI, and the small-diff heuristic only misfires when the base moved *and* the diff is near a threshold. The signal that caught all three was running the fallback for real, once, and reading its output instead of its exit code.

> See-also: [[cr-rate-limit-progressive-refill]]
> See-also: [[cr-cli-false-positive-generated-files]]
> Evidence: plugins/github-dev/skills/cr-fix/scripts/parse-cr-cli-jsonl.sh
> Evidence: plugins/github-dev/skills/cr-fix/references/cr-cli-jsonl-schema.md

## Sources

1. **PR #104 dogfood run** — PR-bot rate-limited (Fair Usage), `--cr-source auto` flipped to CLI; `parse-cr-cli-jsonl.sh` crashed on the first `finding`; findings were recovered by hand-parsing the JSONL. All three drifts observed in the same run.
2. **CodeRabbit CLI 0.6.1 JSONL** (`/tmp/cr-cli-review-104-iter1.jsonl`) — 13 lines: `review_context`, `status` x6, `heartbeat` x2, `finding` x3, `complete`. `finding` keys: `codegenInstructions`, `fileName`, `severity`, `suggestions`, `type`.
3. **`git diff` two-dot vs three-dot semantics** — verified against `gh pr view 104 --json changedFiles,additions,deletions`, which agrees with three-dot and disagrees with two-dot once the base advanced.
