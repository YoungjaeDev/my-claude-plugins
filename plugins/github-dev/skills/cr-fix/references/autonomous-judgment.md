# Autonomous Judgment (Step 9c)

The v2 replacement for the per-finding `AskUserQuestion` gate. The LLM main session reads the affected code, judges each finding on five axes, and decides apply / defer / skip without prompting the user.

## Why no AskUserQuestion

Sample of 10 PRs (PR #30 / #31 / 4-repo Explore + dogfood runs): **100%** of CR Minor + Codex P2 items would have been auto-skipped or auto-applied. The prompt was almost always rhetorical. Removing it:

- Eliminates the iter-stretching wait for user input (cr-fix can complete a 5-iter run in one Claude turn).
- Forces the model to articulate WHY it's applying/skipping each item — the reasoning surfaces in the final JSON instead of dying in conversation.
- Keeps the user as auditor (post-hoc review of the log), not gatekeeper.

The escape hatch: pre-flight `gate=failure` still bubbles up to the user; auto-merge gate (Step 15) still uses AskUserQuestion when branch protection is missing; rate-limit fallback (Step 7c) still asks when no fallback channel is available.

## Five judgment axes

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
| Codex P1 / CR Bug+Critical | matches the criticality | `high` |
| Codex P1 / CR Critical | actually cosmetic | `cosmetic` |
| Codex P2 / CR Minor | actually security-adjacent | `high` |
| Codex P2 / CR Minor | matches the assigned tier | `low` |
| Codex P3 / CR Nitpick | (skip tier already filtered out before Step 9c) | n/a |

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
    "over_engineering": "no"
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
- `action ∈ {apply, defer}` AND `severity_reassess=="high"` → `high_sev_this_cycle++` (loop-local; feeds the Step 13 `minor_floor` soft-stop — see below)

This keeps the v1 convergence test (`applied==0 && deferred==0 → clean`) intact while exposing the new autonomous-skip counter as a separate dimension.

## Minor soft-stop (`minor_floor`)

Default-on (disable with `--no-minor-stop`). The v1 convergence test only stopped when a cycle applied *and* deferred nothing, so a PR with an endless low-value tail (CR Minor / Codex P2 that keep being `real + small-safe → apply`) would loop to `MAX_ITER`. The soft-stop adds an early exit: from **iter 2 onward**, if a cycle applied at least one fix but reassessed **no** finding as `high` severity and deferred nothing (`high_sev_this_cycle == 0 && deferred_this_cycle == 0`), the loop ends with `final_state=minor_floor`.

It is safe because Step 12 already pushed the applied fixes before Step 13 runs. It is **not** auto-merge eligible: the latest push has not been re-reviewed by CR yet, so `minor_floor` is held to the same bar as `user_declined` (Step 15 runs only on `final_state=clean`). When a cycle defers anything, the finding was `high`/`ambiguous` and the user should see it — so the soft-stop deliberately does not fire.

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
