---
id: cr-rate-limit-progressive-refill
aliases: [cr-free-tier-disabled, cr-quota-budget, cr-burst-push]
last_verified: 2026-06-08
status: active
volatility: volatile
sources: 5
---

# CodeRabbit rate-limit: progressive refill, not a plan downgrade

## The misread

CodeRabbit (CR) emits `Review skipped: free tier disabled` on review-comment messages when a multi-iter loop bursts past its hourly quota. Read literally, this looks like the org's CR plan was reverted to Free — which would warrant adding a sniff cooldown that backs off for K iters.

This reading is **wrong**. The message names the wrong cause.

## The mechanism

Per CR's [Fair Usage Limits Policy](https://docs.coderabbit.ai/management/plans#fair-usage-limits-policy):

- The org's plan is unchanged. "Free tier disabled" refers to CR's **internal review tier** (the free-of-charge review path), not the customer's subscription plan.
- CR uses **progressive refill** for hourly quotas: reviews trickle back as time passes. There is no clean 60-minute reset window.
- Wait time depends on recent per-developer activity. A burst of reviews does not block the next one for a fixed hour; it shortens the trickle interval.

## Why this matters for `cr-fix`

`cr-fix` was originally written to add a per-PR cooldown that would skip `sniff-cr-rate-limit.sh` for K iters after detecting "free tier disabled". Dogfood overturned that design:

- **Do NOT add a sniff cooldown.** It would mask normal progressive-refill oscillation as a failure mode it isn't.
- **Treat `--max-iter` as a CR quota budget**, not a retry cap. Default `5` aligns with CR Pro's 5-rev/hour.
- **Add `--push-spacing <sec>`** (planned v3) to throttle burst-push patterns at source. CR Pro+ / Enterprise users can keep `0`.
- The pre-flight gate must distinguish progressive-refill rate-limiting from a hard cap — originally both surfaced as `gate=rate_limited`, losing the recoverable/non-recoverable distinction now restored at the code level (see `## The rule`).

## The rule

A transient `"Review skipped: free tier disabled"` placeholder is **non-terminal**: hold it in `gate=cr_wait` for `CR_SKIP_GRACE` seconds (default `300`, env-only — no new `--flag`, mirroring `EARLY_CHECK_WINDOW`), then fall through to `rate_limited` once the grace window expires. A genuine `Review limit reached` / `rate limited` routes to `rate_limited` immediately; `error` / `pending` / `failure` paths are untouched. The poll keeps waiting through the grace window instead of terminating on the first `state ∈ {success,failure}`, exiting only when CR flips to `Review completed` (terminal success) or grace expires — so a refill placeholder no longer collapses to the same verdict as a hard cap, and a CR-only PR no longer false-converges on the content-empty placeholder.

## Evidence across dogfood runs

Three independent instances confirm the signal is transient and recoverable, not a hard cap:

- **Burst push → skip/complete oscillation = progressive refill** (PR #33): a multi-push burst produced interleaved `Review completed` / `Review skipped: free tier disabled` commit statuses — the oscillation matches refill semantics, not a fixed-hour block.
- **CLI fallback recovery path** (PR #50): pre-flight returned `gate=rate_limited`; with `--cr-source auto`, cr-fix fell back to the authed local CodeRabbit CLI, which produced a full review and the loop converged.
- **Co-reviewer recovery path** (PR #54): early commits CR-skipped, final commit CR-completed once quota refilled, while Codex (`chatgpt-codex-connector[bot]`) carried every iteration's review through the skip window — so the loop never stalled. Caveat: during the skip window `cr_state: success` is *terminal but content-empty*, so a CR-only PR can false-"clean" unless something holds the gate (the `CR_SKIP_GRACE` rule closes that gap). The CLI fallback and the co-reviewer are two distinct recovery paths for the same signal.

> Evidence: plugins/github-dev/skills/cr-fix/references/lessons-from-dogfood.md
> Evidence: plugins/github-dev/skills/cr-fix/scripts/sniff-cr-rate-limit.sh
> See-also: [[curated-conservative]]
> See-also: [[cr-cli-false-positive-generated-files]]

## Sources

1. **plugins/github-dev/skills/cr-fix/references/lessons-from-dogfood.md** — Lesson 5 (CORRECTED): the initial misreading and the corrected reading after consulting CR docs. PR #33 dogfood evidence cited in the lesson.
2. **CodeRabbit Fair Usage Limits Policy** — `https://docs.coderabbit.ai/management/plans#fair-usage-limits-policy`. Authoritative external doc on progressive-refill semantics.
3. **PR #50 dogfood** — established the CLI-fallback recovery path: `gate=rate_limited` → `--cr-source auto` fell back to the authed CodeRabbit CLI and converged.
4. **PR #54 dogfood** — established the co-reviewer recovery path and the content-empty `cr_state: success` caveat.
5. **PR #56 (Issue #55 fix)** — code-level correction of `poll-cr-status.sh` + `pre-flight.sh`: the transient placeholder is held non-terminal for `CR_SKIP_GRACE` (default 300s, env-only) rather than collapsing to `rate_limited`.
