---
id: cr-rate-limit-progressive-refill
aliases: [cr-free-tier-disabled, cr-quota-budget, cr-burst-push]
last_verified: 2026-06-08
status: active
volatility: volatile
sources: 3
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

## Confirming dogfood (PR #50)

A 2nd independent instance: pre-flight returned `cr_desc: "Review skipped: free tier disabled"` → `gate=rate_limited`. With `--cr-source auto`, cr-fix fell back to the local CodeRabbit CLI (v0.5.2, authed) per the rate-limit fallback table — the CLI produced a full review and the loop converged. Confirms the signal is recoverable (fallback path), not a hard failure.

## Confirming dogfood (PR #54)

A 3rd instance, showing a recovery path the prior two did not: CR's commit-status read `success / "Review skipped: free tier disabled"` on the early commits of a 5-push burst (~20 min), then flipped to `success / "Review completed"` on the final commit once quota refilled — textbook progressive refill. Crucially, **Codex (`chatgpt-codex-connector[bot]`) carried every iteration's review while CR was in the skipped window**, so the loop never stalled waiting on CR. Two operational notes from this run:

- The `cr_state: success` commit-status is *terminal but content-empty* during the skip window — `poll-cr-status.sh` returns success while no CR review content exists yet. When CR is the only reviewer this is a false "clean"; here Codex was the live reviewer, so convergence came from Codex findings + a comment/inline-completion poll, not the CR commit-status.
- Recovery does not require the CLI fallback: when a second bot reviewer (Codex) is active, it covers the CR skip window directly. The CLI fallback (PR #50) and a co-reviewer (PR #54) are two distinct recovery paths for the same signal.

> Evidence: plugins/github-dev/skills/cr-fix/references/lessons-from-dogfood.md
> Evidence: plugins/github-dev/skills/cr-fix/scripts/sniff-cr-rate-limit.sh
> See-also: [[curated-conservative]]
> See-also: [[cr-cli-false-positive-generated-files]]

## Sources

1. **plugins/github-dev/skills/cr-fix/references/lessons-from-dogfood.md** — Lesson 5 (CORRECTED). The reference file itself records both the initial misreading and the corrected reading after consulting CR docs. PR #33 dogfood evidence (CR check IDs 4393995268, 4394157080, 4394162348) cited in the lesson body.
2. **CodeRabbit Fair Usage Limits Policy** — `https://docs.coderabbit.ai/management/plans#fair-usage-limits-policy`. Authoritative external doc on progressive-refill semantics. Cited inline in Lesson 5 of the lessons-from-dogfood reference file.
3. **PR #54 dogfood (docs-forge deploy-doc + MOC)** — 5-push burst over ~20 min: early commits CR-skipped (`"Review skipped: free tier disabled"`), final commit CR-completed (`"Review completed"`); Codex co-reviewed throughout and drove convergence. Established the co-reviewer recovery path and the content-empty `cr_state: success` caveat.
