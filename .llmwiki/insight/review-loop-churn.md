---
id: review-loop-churn
aliases: [cr-fix-churn, review-iteration-cap, reviewer-p1-drift]
tier: insight
promoted_from: [[review-loop-churn]]
evidence_count: 2
last_verified: 2026-09-11
status: active
volatility: volatile
sources: 2
---

# A review round that finds defects in the loop's own fixes is churn, not convergence

Stop the loop, file one follow-up issue for what is left, and merge. Measure churn against every round so far, not the previous commit, and never add a flag, branch, or entry point while responding to review.

**When to apply**: any automated review loop that pushes a fix and waits for the reviewer to run again — `dev:cr-fix`, or the same cycle driven by hand.

**Why**: the loop cannot converge on material it produces itself, and the usual stop gates fail open. A cap written in prose binds nothing, a soft stop keyed on `deferred == 0` never fires while the judge rates everything applicable, and a one-commit lookback calls three-rounds-old output fresh.

The full story — the three finding classes, both occurrences, and why the first stop rule was insufficient — stays in the wiki page named by `promoted_from:`.

## Sources

- GitHub PR #213 review threads (iter 5-13) and issue #216
- GitHub PR #223 review threads (iter 1-6) and issue #225

> Evidence: https://github.com/YoungjaeDev/my-claude-plugins/pull/223
> See-also: [[codex-plugin-surfaces]]
