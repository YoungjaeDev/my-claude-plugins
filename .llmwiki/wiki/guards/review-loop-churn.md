---
id: review-loop-churn
aliases: [cr-fix-churn, review-iteration-cap, reviewer-p1-drift]
last_verified: 2026-09-04
status: active
volatility: volatile
sources: 2
---

# Review-loop churn is not convergence

PR #213 ran nine review iterations (iter 5-13). Every round Codex produced one or two P1s, and none of them were defects in executable code.

- Class (a): an absorbed skill's old trigger phrases missing from the absorbing skill's `description` (four rounds). Fixable in one sweep by diffing every deleted skill's description against its absorber before pushing, instead of one per round.
- Class (b): findings on the lines the previous iteration added while responding to review (`post-merge --progress-only`, three rounds). Adding a new surface inside a review loop hands the reviewer fresh material. Fix existing behaviour only; defer new surfaces to an issue.
- Class (c): findings on code the PR never touched (a reference example that moved without changes). The reviewer has exhausted the diff.
- The cr-fix minor soft-stop cannot fire on this pattern because Codex labels description drift P1 and the policy treats every Codex P1 as gated regardless of location.

Stop rule that would have ended the loop at iter 8: if every finding this round sits on lines the previous round added, or outside the PR diff, record `churn`, defer the rest to an issue, and merge.

## Sources

- GitHub PR #213 review threads (2026-09-04, iter 5-13)
- GitHub issue #216 (cr-fix policy follow-up)

> Evidence: https://github.com/YoungjaeDev/my-claude-plugins/pull/213
> See-also: [[codex-plugin-surfaces]]
