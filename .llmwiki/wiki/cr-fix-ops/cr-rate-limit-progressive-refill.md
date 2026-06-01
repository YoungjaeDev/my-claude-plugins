---
id: cr-rate-limit-progressive-refill
aliases: [cr-free-tier-disabled, cr-quota-budget, cr-burst-push]
last_verified: 2026-05-30
status: active
volatility: volatile
sources: 2
---

# CodeRabbit rate-limit: progressive refill, not a plan downgrade

## The misread

CodeRabbit (CR) emits `Review skipped: free tier disabled` on review-comment messages when a multi-iter loop bursts past its hourly quota. Read literally, this looks like the org's CR plan was reverted to Free — which would warrant adding a sniff cooldown that backs off for K iters.

This reading is **wrong**. The message names the wrong cause.

## The mechanism

Per CR's [Fair Usage Limits Policy](https://docs.coderabbit.ai/management/plans#fair-usage-limits-policy):

- The org's plan is unchanged. "Free tier disabled" refers to CR's **internal review tier** (the free-of-charge review path), not the customer's subscription plan.
- CR uses **progressive refill** for hourly quotas: reviews trickle back as time passes. There is no clean 60-minute reset window.
- Wait time depends on recent per-developer activity. A burst of 5 reviews in 10 minutes does not block the 6th for a fixed hour; it shortens the trickle interval.

## Why this matters for `cr-fix`

`cr-fix` was originally written to add a per-PR cooldown that would skip `sniff-cr-rate-limit.sh` for K iters after detecting "free tier disabled". The lesson learned during PR #33 dogfood (8 push in ~10 min, 5 CR-reviewed / 3 skipped) overturned that design:

- **Do NOT add a sniff cooldown.** It would mask normal progressive-refill oscillation as a failure mode it isn't.
- **Treat `--max-iter` as a CR quota budget**, not a retry cap. Default `5` happens to align with CR Pro's 5-rev/hour — possibly a Karpathy-style intentional design coincidence in cr-fix v1.
- **Add `--push-spacing <sec>`** (planned v3) to throttle burst-push patterns at source. CR Pro+ / Enterprise users can keep `0`.
- The pre-flight gate should distinguish "rate-limited (progressive refill in progress)" from "rate-limited (hard cap)" — currently both surface as `gate=rate_limited` and lose the recoverable/non-recoverable distinction.

## Trial dogfood data (PR #33)

- 8 push within ~10 minutes
- 5 successful CR reviews (`cr_state: success`, `cr_desc: "Review completed"`)
- 3 skipped reviews (`cr_state: success`, `cr_desc: "Review skipped: free tier disabled"`)
- Skip:complete oscillation matches progressive-refill semantics — not a hard cap.

> Evidence: plugins/github-dev/skills/cr-fix/references/lessons-from-dogfood.md
> Evidence: plugins/github-dev/skills/cr-fix/scripts/sniff-cr-rate-limit.sh
> See-also: [[curated-conservative]]

## Sources

1. **plugins/github-dev/skills/cr-fix/references/lessons-from-dogfood.md** — Lesson 5 (CORRECTED). The reference file itself records both the initial misreading and the corrected reading after consulting CR docs. PR #33 dogfood evidence (CR check IDs 4393995268, 4394157080, 4394162348) cited in the lesson body.
2. **CodeRabbit Fair Usage Limits Policy** — `https://docs.coderabbit.ai/management/plans#fair-usage-limits-policy`. Authoritative external doc on progressive-refill semantics. Cited inline in Lesson 5 of the lessons-from-dogfood reference file.
