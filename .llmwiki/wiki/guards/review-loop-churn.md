---
id: review-loop-churn
aliases: [cr-fix-churn, review-iteration-cap, reviewer-p1-drift]
last_verified: 2026-09-11
status: active
volatility: volatile
sources: 4
---

# Review-loop churn is not convergence

An automated review loop converges when the reviewer runs out of defects in the pull request. It looks identical from inside when the reviewer runs out of pull request and starts reporting defects in the loop's own fixes — but that second state never ends on its own, because every round manufactures the next round's material.

Three finding classes mark it: a finding on lines the loop itself added while responding to review, a finding outside the PR diff entirely, and a finding on prose or frontmatter rather than executable code. The third is the quiet one — reviewers grade by topic rather than blast radius, so a wording drift arrives at the same severity as a real defect and holds every severity-based stop gate open.

## Stopping it

- **Measure churn against the whole loop, not the previous commit.** Material accumulates. A finding on a line added three rounds ago is still the loop's own output, and a one-commit lookback reports it as fresh.
- **A judge that never defers disables every gate built on deferring.** A soft stop keyed on `deferred == 0` cannot fire while the judge rates every finding small enough to apply. Size judgment needs an objective floor — lines touched, files touched, repeated edits to one file — or the gate is decoration.
- **An iteration cap written in prose is not a cap.** It binds only where the loop actually advances; a run that drives the loop by hand sails past it.
- **When the stop fires**, record the state, file one follow-up issue for what is left, and merge. Do not add a flag, branch, or entry point inside the loop: a new surface is fresh material for the next round.

## Evidence

- Nine iterations, with no finding a defect in executable code: absorbed-skill trigger phrases missing from the absorbing description (four rounds), findings on a surface the previous round had added while responding to review (three rounds), and findings on untouched reference code.
- Six iterations after the stop rule above was implemented: the one-commit churn axis reported every finding fresh, the judge deferred none of 45 findings, and the cap was passed. Several of the later rounds' findings were defects in fixes made by earlier rounds of the same loop.

## Sources

- GitHub PR #213 review threads (2026-09-04, iter 5-13)
- GitHub issue #216 (cr-fix policy follow-up)
- GitHub PR #223 review threads (2026-09-11, iter 1-6)
- GitHub issue #225 (churn one-commit lookback, defer never firing, cap not enforced)

> Evidence: https://github.com/YoungjaeDev/my-claude-plugins/pull/223
> See-also: [[codex-plugin-surfaces]]
