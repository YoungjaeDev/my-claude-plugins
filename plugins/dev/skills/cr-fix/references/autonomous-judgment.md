# Autonomous Judgment (Step 9c)

The main session reads the affected code, judges each finding on six axes, and decides apply / defer / skip without prompting the user.

## Per-finding procedure (Step 9c)

Items 3-8 of the SKILL.md Step 9c list, in full. Items 1-2 (path-trust gate, sanitization) run first, in the skill body.

3. **Read affected code**:
   - Line-anchored finding → Read with offset `max(1, line-20)` and limit `40`.
   - Codex file-level (no line, file ≤ 1000 LoC) → Read whole file.
   - Codex file-level (file > 1000 LoC) → skip with reason `codex-file-too-large`.

4. **Independent judgment** (LLM, structured reasoning before action):
   - `is_real`: does the claim match what the local code actually does? (`real` / `spurious` / `stylistic-only`)
   - `confidence`: `high` / `medium` / `low`, based on how unambiguous the local evidence is.
   - `severity_reassess`: reviewer-assigned severity vs. observed impact. Codex P1 with cosmetic effect → `cosmetic`. CR Minor with security implication → `high`.
   - `fix_size`: `small-safe` (1-5 line change, no API surface delta) / `large-risky` (refactor / signature change / cross-file) / `ambiguous`.
   - `over_engineering`: does the *suggestion itself* demand unrequested complexity: speculative abstraction, defensive flexibility against hypotheticals, premature generalization, or unrequested configurability? `yes` / `no`. Judge the *fix being asked for*, not the code it sits in: a complex surrounding file is not `yes`; only a suggestion that *adds* complexity is.
   - `in_prev_diff`: did the loop, not the PR, produce the material this finding sits on?
     Run the "Step 9c.4: churn scope" block in `references/run-blocks.md` verbatim.
     `churn` (inside the previous iteration's own commit, or outside the PR diff) forces `severity_reassess=cosmetic` and `churn_this_cycle=$((churn_this_cycle+1))`; `fresh` changes nothing.

   **Location rule for Codex P1.** A P1 on frontmatter text, prose or a comment — anything that is not executable code — is `severity_reassess=low`. Codex badges by topic, not blast radius, and a wording drift left at `high` keeps every soft stop below from ever firing.

   A finding asking for a new surface is `defer` regardless of `fix_size` (hard constraint above).

5. **Decision matrix** (`references/autonomous-judgment.md` for full rationale):

   | `is_real` | `severity_reassess` | `fix_size` | action |
   |---|---|---|---|
   | real | any | any *(over_engineering=yes)* | **skip** ("YAGNI: suggestion adds unrequested complexity; fails the senior-engineer test") |
   | real | any | small-safe | **apply** |
   | real | high (P1 / Critical / Major / Security) | large-risky | **defer** ("needs review: too invasive for autopilot") |
   | real | low / cosmetic (P2 / Minor / churn) | large-risky | **skip** ("low value vs. invasiveness") |
   | spurious / stylistic-only | any | any | **skip** ("did not match local code" / "stylistic preference, repo convention differs") |
   | ambiguous | any | any | **defer** ("needs human review on intent") |

   `over_engineering=yes` is evaluated first and overrides `fix_size`, including at `small-safe`.

6. **Apply / defer / skip**:
   - **apply** → **Stale-line guard**: before editing, if `$path` already appears in `$TRACK_FILE` from an earlier finding this cycle, re-Read the target region (offset `max(1, line-20)`, limit `40`) and re-locate the finding's quoted context in it: an earlier edit may have shifted the line numbers this finding was anchored to. Edit only where the expected context still matches; if the anchor content cannot be re-found in the re-Read region, **defer** the finding instead of editing a guessed location. Then Edit the file with the smallest safe fix derived from local content; `printf '%s\0' "$path" >> "$TRACK_FILE"`; `applied_this_cycle=$((applied_this_cycle+1))`; `auto_judge_apply=$((auto_judge_apply+1))`; log judgment to `STATE_FILE.auto_judge_log`.
     - **9c.6: Bounded same-file generalization**. After the flagged-line fix lands, when `GENERALIZE=true` AND `is_real=="real"` AND `confidence=="high"` AND the pattern is mechanically grep-able (a literal or regex-matchable construct, not a judgement call), grep the **same file** — or that symbol's body, when the finding is symbol-scoped — for sibling occurrences and apply the identical fix in the same commit. **Never cross-file.** Record the extra lines in `generalized_to`; the finding still counts as 1, so `applied_this_cycle` / `auto_judge_apply` are not re-incremented. Full contract: `references/autonomous-judgment.md`.
   - **defer** → `deferred_this_cycle=$((deferred_this_cycle+1))`; `auto_judge_defer=$((auto_judge_defer+1))`; log judgment.
   - **High-severity accumulator (Step 13 soft-stop signal)**: for any `apply` or `defer` whose `severity_reassess=="high"`, `high_sev_this_cycle=$((high_sev_this_cycle+1))`. This feeds the Step 13 `minor_floor` soft-stop: a cycle that applied only low-severity fixes and deferred nothing can stop early.
   - **skip** → `auto_judge_skip=$((auto_judge_skip+1))`; log judgment. Does NOT touch `applied_this_cycle` or `deferred_this_cycle`.

7. **Log entry** — append one record per decision to `STATE_FILE.auto_judge_log`: `iter`, `src` (`cr|cli|codex`), `path`, `line`, `badge_or_sev`, `judgment` (the six axes above with the values they took), `action`, `reason` (one line), and `generalized_to` (the sibling lines, only when 9c.6 fired). Full shape: `references/autonomous-judgment.md`.

8. **9c-review tier** (CR finding with no parseable header / Codex with no P1-P2 badge): surface in the Step 9a table only. No edit, no judgment — but `review_this_cycle=$((review_this_cycle+1))`. These are findings nobody examined; Step 13 refuses to call that a floor.

## Why no AskUserQuestion

A per-finding prompt is almost always rhetorical: the answer is already determined by what the local code says. Removing it eliminates the wait for user input, forces the model to articulate *why* it applied or skipped each item, and keeps the user as auditor of the log rather than gatekeeper of every line.

Three escape hatches remain, each where input is structurally required: pre-flight `gate=failure`, the auto-merge gate when branch protection is missing (Step 15), and the rate-limit fallback when no fallback channel is available (Step 7c).

## Six judgment axes

### 1. `is_real`

Does the reviewer's claim match what the local code actually does?

| Value | Trigger |
|---|---|
| `real` | Code matches the bug/improvement claim — the issue is genuine. |
| `spurious` | Reviewer pattern-matched but the local code already handles it / does it correctly. |
| `stylistic-only` | The finding is a style preference, not a correctness or performance issue. Often Codex P2 / CR Minor of refactor type. |
| `ambiguous` | Cannot determine from the read window alone — the call site, type, or intent is unclear. |

### 2. `confidence`

How unambiguous is the local evidence supporting axis #1?

`high` (code clearly matches/refutes the claim) / `medium` (likely but not certain) / `low` (would need broader context — a wider read, type info, or runtime behavior).

### 3. `severity_reassess`

Reviewer-assigned severity vs. observed impact.

| Reviewer says | Local read suggests | `severity_reassess` |
|---|---|---|
| Codex P1 / CR Critical | matches the criticality | `high` |
| Codex P1 / CR Critical | actually cosmetic | `cosmetic` |
| Codex P2 / CR Minor | actually security-adjacent | `high` |
| Codex P2 / CR Minor | matches the assigned tier | `low` |
| CR Trivial / Info | (skip tier already filtered out before Step 9c) | n/a |

**Location rule.** A Codex P1 that lands on frontmatter `description` text, prose, or a comment — anywhere that is not executable code — is `low`, not `high`. Codex assigns P1 by topic, not by blast radius, and a wording drift badged P1 otherwise keeps `high_sev_this_cycle` above zero forever and blocks every soft stop below.

The reassessment matters because reviewers regularly over-flag (Codex P1 on cosmetics) and under-flag (CR Minor on a missing `try/finally` that leaks a file handle). Trust the local evidence over the badge.

### 4. `fix_size`

| Value | Definition |
|---|---|
| `small-safe` | 1-5 line localized edit, no API surface change, no cross-file impact. |
| `large-risky` | Refactor, signature change, cross-file impact, or change that requires broader context to validate. |
| `ambiguous` | Unclear without reading more of the call graph. |

### 5. `over_engineering`

Does the *suggestion itself* demand unrequested complexity? This judges the **fix being asked for**, not the code it sits in — a finding can be entirely real and still ask for over-engineering.

| Value | Trigger |
|---|---|
| `yes` | The suggestion adds speculative abstraction, defensive flexibility against hypotheticals, premature generalization, or unrequested configurability — complexity nobody asked for. A senior engineer would call it overcomplicated. |
| `no` | The suggestion does not add unrequested complexity (it may even remove some, or be a pure correctness/clarity fix). |

The distinction that matters: a complex *surrounding file* is not `yes`. Only a suggestion that *adds* complexity to satisfy a hypothetical is. This keeps cr-fix from importing a reviewer's speculative-generality habit into the codebase under cover of a "valid" finding.

### 6. `in_prev_diff`

Did the loop produce the material this finding sits on, rather than the PR?

```bash
bash "$SKILL_DIR/scripts/churn-scope.sh" "$PREV_SHA" "origin/$BASE" "$path" "$line"
```

`churn` when the line falls inside a hunk the previous iteration's commit added or changed, or falls outside the PR diff entirely; `fresh` otherwise. From `ITER >= 2` only — the first iteration has no prior commit, and `PREV_SHA` empty disables the first test. A file-level finding with no line is always `fresh`.

**Prose skips the first test.** The previous-iteration test reads position as authorship: a line the last commit produced is a line the loop wrote. That holds for code, where a fix edits the lines it fixes. It does not hold for prose (`.md`, `.markdown`, `.mdx`, `.txt`, `.rst`, `.adoc`), where an iteration rewrites a whole paragraph and reproduces every line in it, so a genuinely new defect class in the rewritten text reads as churn. On PR #254 that stopped a live loop at iter 3 on four findings, three of them real. A prose finding is decided by the PR-diff test alone — still catching the half of churn that matters most, a reviewer that has run out of pull request and reached outside it — and the iteration cap is the backstop for a prose loop that will not converge, filing the same follow-up issue `churn` would have.

A `churn` finding has its `severity_reassess` forced to `cosmetic` and increments `churn_this_cycle`. It does not become unfixable — the matrix still applies — but it can no longer hold the loop open, which is the point: a reviewer that keeps finding material on its own review responses has run out of PR to review.

## Decision matrix

| `is_real` | `severity_reassess` | `fix_size` | action | reason field |
|---|---|---|---|---|
| `real` | any | any *(`over_engineering=yes`)* | **skip** | "YAGNI — suggestion adds unrequested complexity; fails the senior-engineer test" |
| `real` | any | `small-safe` | **apply** | "real + small/safe → fix in place" |
| `real` | `high` | `large-risky` | **defer** | "real high-severity but invasive — needs review" |
| `real` | `low` / `cosmetic` | `large-risky` | **skip** | "low value vs. invasiveness" |
| `real` | any | `ambiguous` | **defer** | "needs broader context to size" |
| `spurious` | any | any | **skip** | "did not match local code" |
| `stylistic-only` | any | any | **skip** | "stylistic preference, repo convention differs" |
| `ambiguous` | any | any | **defer** | "needs human review on intent" |

**`over_engineering=yes` is checked first and overrides `fix_size`.** A real finding whose *suggestion* is pure over-engineering is skipped even at `small-safe` — the surgical-diff / senior-engineer test (no unrequested abstraction, no configurability for a value that never changes, three lines of duplication over a premature helper) outranks "the change is tiny." A reviewer's speculative-generality suggestion is cheap to apply and expensive to live with, so diff size is the wrong gate; the right gate is whether the codebase wanted that complexity at all.

**Why cr-fix only refuses, never deletes.** This axis makes cr-fix *decline to add* over-engineering a reviewer proposes. It does **not** hunt for and remove over-engineering already in the code — that is `ponytail-review`'s job (an optional, separately-installed skill focused exclusively on what to delete). cr-fix's surface is reviewer findings; pairing the two covers both directions — refuse new complexity here, delete existing complexity there — without overloading either.

## Pre-condition gates

These run BEFORE judgment and produce a `skip` regardless of the matrix:

- **path-trust** failure (`scripts/path-trust.sh`) → skip + log untrusted-path.
- **sanitization** flag (`references/sanitization-rules.md`) → refuse-and-warn skip.
- **codex-file-too-large** (Codex file-level + file > 1000 LoC) → skip with codex-file-too-large.

## Log entry shape

Every Step 9c decision appends one record to `STATE_FILE.auto_judge_log`:

```json
{
  "iter": 2,
  "src": "codex",
  "path": "src/foo.py",
  "line": 42,
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
  "reason": "real + small/safe → fix in place"
}
```

The final JSON aggregates counts (`auto_judge_stats: {apply, defer, skip}`); the per-finding records stay in the archived state file for audit.

## Counter wiring

- `action=apply` → `applied_this_cycle++`, `auto_judge_apply++`
- `action=defer` → `deferred_this_cycle++`, `auto_judge_defer++`
- `action=skip` → `auto_judge_skip++` only (the existing `skipped_total` continues to count tier=skip filtered-before-table items per `references/skip-minor-rules.md`)
- `action ∈ {apply, defer}` AND `severity_reassess=="high"` → `high_sev_this_cycle++` (loop-local; feeds the Step 13 `minor_floor` soft-stop)
- `in_prev_diff == "churn"` → `churn_this_cycle++` (loop-local; feeds the Step 13 `churn` stop)

This keeps the `applied==0 && deferred==0 → clean` convergence test intact while exposing the autonomous-skip counter as a separate dimension.

## No new surfaces inside the loop

A review-response commit fixes **existing behaviour only**. A finding that needs a new flag, a new branch, a new entry point, or any other surface the PR does not already have is **deferred**, never applied — regardless of how small the change looks. Every new surface handed to a reviewer mid-loop is fresh material for the next round, which is how a review loop turns into churn. Deferred findings of this class are exactly what the Step 14 follow-up issue exists to carry.

## Minor soft-stop (`minor_floor`)

Default-on (disable with `--no-minor-stop`). The v1 convergence test only stopped when a cycle applied *and* deferred nothing, so a PR with an endless low-value tail (CR Minor / Codex P2 that keep being `real + small-safe → apply`) would loop to `MAX_ITER`. The soft-stop adds an early exit: from **iter 2 onward**, if a cycle applied at least one fix but reassessed **no** finding as `high` severity and deferred nothing (`high_sev_this_cycle == 0 && deferred_this_cycle == 0`), the loop ends with `final_state=minor_floor`.

It is safe because Step 12 already pushed the applied fixes before Step 13 runs. When a cycle defers anything, the finding was `high` or `ambiguous` and the user should see it, so the soft-stop deliberately does not fire.

## Churn stop (`churn`)

From `ITER >= 2`, when every finding this cycle came back `churn` on the `in_prev_diff` axis, the loop ends with `final_state=churn`. The reviewer is no longer reviewing the pull request; it is reviewing the loop's own commits and the code around them. More iterations produce more of the same. On a prose-only PR the stop fires only on the outside-the-diff half of the axis (above), so a loop that keeps finding new material in rewritten prose runs to `iteration_cap` instead.

## Merge eligibility

`clean` merges on its own. `minor_floor` and `churn` merge only once Step 14 has filed the follow-up issue carrying what was left behind — `scripts/auto-merge-gate.sh` reads `FINAL_STATE` and `FOLLOWUP_ISSUE` and reports `eligible: false` without it, so a failed `gh issue create` keeps the PR open. Every other `final_state` is ineligible.

## Bounded same-file generalization

Default-on (disable with `--no-generalize`). A reviewer flags one line, but the same defect often repeats at sibling locations the reviewer did not enumerate; fixing only the flagged line means the next cycle re-flags a sibling and the loop stretches. Step 9c.6 closes that gap **within tight bounds**.

**Scope — same file only.** After the flagged-line fix lands on the `apply` path, the generalization grep is confined to the **same file**, or to the **single symbol's body** when the finding is symbol-scoped. Cross-file expansion is a **hard exclusion** — never done, regardless of confidence. Cross-file or speculative matches stay on the existing matrix (deferred or skipped).

**Trigger — all must hold:**

- `GENERALIZE=true` (default; `--no-generalize` off),
- `is_real == "real"` and `confidence == "high"` (the judgment axes above — low/medium confidence never generalizes),
- the finding is a **mechanically grep-able** pattern: a literal or regex-matchable construct (e.g. a specific call form, a missing guard token), **not** a judgement call that needs per-site reasoning.

**Logging.** The extra edits are recorded in the `auto_judge_log` entry's `generalized_to: [<line>...]` field for audit. The finding still counts as **1** — `applied_this_cycle` / `auto_judge_apply` are **not** re-incremented per sibling line; only the line list grows.

**Surgical-diff trade-off.** This intentionally widens the diff beyond the single line the reviewer named, which is in tension with the surgical-diff rule. The bounds (same file, high-confidence, mechanically-matchable, audit-logged) are what keep it defensible: every extra line is the *identical* fix to a *mechanically identical* pattern in the *same file*, and the `generalized_to` log makes the expansion reviewable. When the pattern is not mechanically identical, or the sibling needs its own judgment, generalization does not fire — that case is a separate finding for a later cycle. Pass `--no-generalize` to keep diffs strictly line-scoped.

## When to manually re-prompt

The skill does NOT re-prompt for any finding, even ambiguous ones — defer is the escape. If the user wants to revisit a deferred item, they can:

1. Inspect `.claude/state/archive/cr-fix-<PR>-<timestamp>.json` for the reasoning.
2. Pick up the finding on the PR page (`gh pr view --comments`).
3. Manually edit, push, and re-run cr-fix; the new iter will see the change.
