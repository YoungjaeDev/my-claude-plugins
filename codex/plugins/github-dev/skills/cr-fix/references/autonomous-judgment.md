# Autonomous Judgment (Step 9c)

The v2 replacement for the per-finding `AskUserQuestion` gate. The LLM main session reads the affected code, judges each finding on four axes, and decides apply / defer / skip without prompting the user.

## Why no AskUserQuestion

Sample of 10 PRs (PR #30 / #31 / 4-repo Explore + dogfood runs): **100%** of CR Minor + Codex P2 items would have been auto-skipped or auto-applied. The prompt was almost always rhetorical. Removing it:

- Eliminates the iter-stretching wait for user input (cr-fix can complete a 5-iter run in one Claude turn).
- Forces the model to articulate WHY it's applying/skipping each item — the reasoning surfaces in the final JSON instead of dying in conversation.
- Keeps the user as auditor (post-hoc review of the log), not gatekeeper.

The escape hatch: pre-flight `gate=failure` still bubbles up to the user; auto-merge gate (Step 15) still uses AskUserQuestion when branch protection is missing; rate-limit fallback (Step 7c) still asks when no fallback channel is available.

## Four judgment axes

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

## Decision matrix

| `is_real` | `severity_reassess` | `fix_size` | action | reason field |
|---|---|---|---|---|
| `real` | any | `small-safe` | **apply** | "real + small/safe → fix in place" |
| `real` | `high` | `large-risky` | **defer** | "real high-severity but invasive — needs review" |
| `real` | `low` / `cosmetic` | `large-risky` | **skip** | "low value vs. invasiveness" |
| `real` | any | `ambiguous` | **defer** | "needs broader context to size" |
| `spurious` | any | any | **skip** | "did not match local code" |
| `stylistic-only` | any | any | **skip** | "stylistic preference, repo convention differs" |
| `ambiguous` | any | any | **defer** | "needs human review on intent" |

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
    "fix_size": "small-safe"
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

This keeps the v1 convergence test (`applied==0 && deferred==0 → clean`) intact while exposing the new autonomous-skip counter as a separate dimension.

## When to manually re-prompt

The skill does NOT re-prompt for any finding, even ambiguous ones — defer is the escape. If the user wants to revisit a deferred item, they can:

1. Inspect `.codex/state/archive/cr-fix-<PR>-<timestamp>.json` for the reasoning.
2. Pick up the finding on the PR page (`gh pr view --comments`).
3. Manually edit, push, and re-run cr-fix; the new iter will see the change.
