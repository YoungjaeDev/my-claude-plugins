# Autonomous Judgment (Step 9c)

The main session reads the affected code, judges each finding on six axes, and decides apply, defer or skip without asking the user. The decision matrix has 10 rows, and only a finding that is both severe and too large or unclear to size leaves the session as a defer.

## Per-finding procedure (Step 9c)

Items 3-8 of the Step 9c list in `procedure.md`. Items 1-2 (path-trust gate, sanitization) run first.

3. **Read affected code**: a line-anchored finding reads offset `max(1, line-20)`, limit `40`. A Codex file-level finding (no line) reads the whole file up to 1000 LoC, else skips with reason `codex-file-too-large`.
4. **Independent judgment** on the six axes below before any action, with structured reasoning. `in_prev_diff` runs the "Step 9c.4: churn scope" block in `references/run-blocks.md` verbatim.
5. **Decision matrix**: decide with the table below.
6. **Apply** only behind the stale-line guard: when `$path` is already in `$TRACK_FILE` from an earlier finding this cycle, re-Read the region (offset `max(1, line-20)`, limit `40`) and re-locate the finding's quoted context. Edit only where that context still matches; when it cannot be re-found, defer instead of editing a guessed location.
   - Then Edit the smallest safe fix derived from the local content, `printf '%s\0' "$path" >> "$TRACK_FILE"`, run the bounded same-file generalization (9c.6, below), and update the counters.
   - With `VERIFICATION_GATE=on` the whole apply, siblings included, runs inside the "Step 9c.6: verify the fix" block in `references/run-blocks.md`. On `fail` the files are back at the snapshot and the counters move from apply to defer, logged as `action: "defer"`, `reason: "verification-failed"`.
7. **Log entry**: one record per decision in `STATE_FILE.auto_judge_log` (shape below).
8. **`review` tier** (a CodeRabbit finding with no parseable header, a Codex finding with no P0-P2 badge): shown in the Step 9a table only, with no edit and no judgment, but `review_this_cycle` goes up by one. Step 13 refuses to call that a floor or `clean`.

## Six judgment axes

- **`is_real`**: does the claim match what the local code does? `real` (a genuine issue), `spurious` (the code already handles it), `stylistic-only` (a preference, often a refactor-type Codex P2 or CodeRabbit Minor), or `ambiguous` (the call site, type or intent is unclear from the read window).
- **`confidence`**: `high` (the code clearly matches or refutes the claim), `medium` (likely), or `low` (needs a wider read, type information or runtime behavior).
- **`severity_reassess`**: the observed impact, not the badge. A Codex P1 or CodeRabbit Critical that is cosmetic is `cosmetic`; a Codex P2 or CodeRabbit Minor that is security-adjacent is `high`; one that matches its badge keeps it (`high` or `low`).
- **Location rule**: a Codex P1 on frontmatter `description` text, prose or a comment (anything that is not executable code) is `low`. Codex assigns P1 by topic, not blast radius, and a wording drift left at `high` keeps every soft stop from firing.
- **`fix_size`**: `small-safe` (a 1-5 line local edit, no API surface change, no cross-file impact), `large-risky` (a refactor, a signature change, cross-file impact, or broader context needed to validate), or `ambiguous` (unclear without more of the call graph).
- **`over_engineering`**: `yes` when the suggestion itself adds speculative abstraction, defensive flexibility for hypotheticals, premature generalization or unrequested configurability. Judge the fix being asked for: a complex surrounding file is not `yes`. Deleting over-engineering already in the code is not this skill's job.
- **`in_prev_diff`**: `churn` when the line falls in a hunk the previous iteration's commit added or changed, or outside the PR diff (`scripts/churn-scope.sh`); `fresh` otherwise. It applies from `ITER >= 2`, and a file-level finding with no line is `fresh`.
- **Prose skips the previous-commit test**: an iteration rewrites a whole paragraph of prose (`.md`, `.markdown`, `.mdx`, `.txt`, `.rst`, `.adoc`), so position no longer names the author. A prose finding is decided by the PR-diff test alone, and `iteration_cap` ends a prose loop that does not converge.
- A `churn` finding has `severity_reassess` forced to `cosmetic` and adds one to `churn_this_cycle`. The matrix still applies, but the finding can no longer hold the loop open.

## Decision matrix

| `is_real` | `severity_reassess` | `fix_size` | action | reason field |
|---|---|---|---|---|
| `real` | any | any *(`over_engineering=yes`)* | skip | "YAGNI: suggestion adds unrequested complexity; fails the senior-engineer test" |
| `real` | any | `small-safe` | apply | "real + small/safe → fix in place" |
| `real` | `high` (P0-P1 / Critical / Major / Security) | `large-risky` | defer | "real high-severity but invasive — needs review" |
| `real` | `high` | `ambiguous` | defer | "high severity, needs broader context to size" |
| `real` | `low` / `cosmetic` (P2 / Minor / churn) | `large-risky` | skip | "low value vs. invasiveness" |
| `real` | `low` / `cosmetic` | `ambiguous` | apply / skip | "narrowest reading is small-safe → applied" / "cannot size at low value → skipped" |
| `spurious` | any | any | skip | "did not match local code" |
| `stylistic-only` | any | any | skip | "stylistic preference, repo convention differs" |
| `ambiguous` | `high` | any | defer | "needs human review on intent" |
| `ambiguous` | `low` / `cosmetic` | any | apply / skip | the reading the decision took, in one line |

- `over_engineering=yes` is checked first and overrides `fix_size`, even at `small-safe`: a speculative suggestion is cheap to apply and expensive to live with.
- A fix that adds a flag, branch or entry point is judged like any other: small-safe applies, a large one follows its severity row.
- A low-severity finding is finished in the session, applied when a small safe fix exists and otherwise skipped with the reason logged. A `verification-failed` revert still defers, because the fix was wanted and did not build.

## Pre-condition gates

These run before judgment and produce a `skip` whatever the matrix says:

- **path-trust** failure (`scripts/path-trust.sh`): skip and log an untrusted path.
- **sanitization** flag (`references/sanitization-rules.md`): refuse, warn and skip.
- **codex-file-too-large** (a Codex file-level finding on a file over 1000 LoC): skip with that reason.

## Log entry and counters

Every Step 9c decision appends one record to `STATE_FILE.auto_judge_log`. `comment_id` is the thread's `databaseId` for CodeRabbit, the comment id for Codex, and `null` for an outside-diff or CLI finding; Step 9a drops a thread this run already judged by it.

`category` is the CodeRabbit/CLI header category as read (empty for Codex) and `badge_or_sev` the severity as read or the Codex badge `P0`-`P2`. `scripts/auto-merge-gate.sh` reads them and `severity_reassess` from this iteration's `apply` records to decide whether the fixes need a re-review (Step 12).

```json
{
  "iter": 2,
  "src": "codex",
  "path": "src/foo.py",
  "line": 42,
  "comment_id": 2412345678,
  "category": "",
  "badge_or_sev": "P2",
  "judgment": {
    "is_real": "real",
    "confidence": "high",
    "severity_reassess": "low",
    "fix_size": "small-safe",
    "over_engineering": "no",
    "in_prev_diff": "fresh"
  },
  "action": "apply",
  "reason": "real + small/safe → fix in place",
  "generalized_to": [57, 88]
}
```

`generalized_to` appears only when generalization fired. The final JSON carries the totals as `auto_judge_stats: {apply, defer, skip}`, and the records stay in the archived state file.

- `action=apply`: `applied_this_cycle` and `auto_judge_apply` go up by one. `action=defer`: `deferred_this_cycle` and `auto_judge_defer`.
- `action=skip`: only `auto_judge_skip`. `skipped_total` keeps counting the tier-skip items filtered before the table (`references/skip-minor-rules.md`).
- An `apply` or `defer` with `severity_reassess=="high"` adds one to `high_sev_this_cycle`, which the Step 13 `minor_floor` stop reads. `churn` adds one to `churn_this_cycle` (the `churn` stop), and the `review` tier one to `review_this_cycle` (blocks `minor_floor` and `clean`).

## Bounded same-file generalization

On by default (`--no-generalize` turns it off). After the flagged-line fix lands, a finding that is `real`, `confidence == "high"` and a mechanically grep-able pattern (a literal or regex-matchable construct, not a call that needs per-site reasoning) gets the identical fix at its sibling occurrences in the same commit.

The search stays in the same file, or in the one symbol's body when the finding is symbol-scoped. It never crosses files, whatever the confidence; cross-file or non-identical matches stay findings for the matrix or a later cycle.

The extra lines go into the record's `generalized_to`. The finding still counts once: `applied_this_cycle` and `auto_judge_apply` are not raised per sibling.
