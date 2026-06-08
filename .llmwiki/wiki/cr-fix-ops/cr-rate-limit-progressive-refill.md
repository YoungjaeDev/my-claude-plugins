---
id: cr-rate-limit-progressive-refill
aliases: [cr-free-tier-disabled, cr-quota-budget, cr-burst-push]
last_verified: 2026-06-08
status: active
volatility: volatile
sources: 4
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
- The pre-flight gate should distinguish "rate-limited (progressive refill in progress)" from "rate-limited (hard cap)" — originally both surfaced as `gate=rate_limited` and lost the recoverable/non-recoverable distinction. **Resolved at the code level in PR #56** for the transient `"Review skipped: free tier disabled"` case (see `## Code-level fix (PR #56)` below): the placeholder now holds in `cr_wait` for a grace window instead of collapsing to `rate_limited`.

## Trial dogfood data (PR #33)

- 8 push within ~10 minutes
- 5 successful CR reviews (`cr_state: success`, `cr_desc: "Review completed"`)
- 3 skipped reviews (`cr_state: success`, `cr_desc: "Review skipped: free tier disabled"`)
- Skip:complete oscillation matches progressive-refill semantics — not a hard cap.

## Confirming dogfood (PR #50)

A 2nd independent instance: pre-flight returned `cr_desc: "Review skipped: free tier disabled"` → `gate=rate_limited`. With `--cr-source auto`, cr-fix fell back to the local CodeRabbit CLI (v0.5.2, authed) per the rate-limit fallback table — the CLI produced a full review and the loop converged. Confirms the signal is recoverable (fallback path), not a hard failure.

## Confirming dogfood (PR #54)

A 3rd instance, showing a recovery path the prior two did not: CR's commit-status read `success / "Review skipped: free tier disabled"` on the early commits of a 5-push burst (~20 min), then flipped to `success / "Review completed"` on the final commit once quota refilled — textbook progressive refill. Crucially, **Codex (`chatgpt-codex-connector[bot]`) carried every iteration's review while CR was in the skipped window**, so the loop never stalled waiting on CR. Two operational notes from this run:

- The `cr_state: success` commit-status is *terminal but content-empty* during the skip window — `poll-cr-status.sh` returns success while no CR review content exists yet. When CR is the only reviewer this is a false "clean"; here Codex was the live reviewer, so convergence came from Codex findings + a comment/inline-completion poll, not the CR commit-status. **PR #56 closes this gap directly** (`## Code-level fix (PR #56)`): the poll no longer returns premature success on the placeholder — it holds until CR flips to `Review completed` or the grace window expires, so a CR-only PR no longer false-converges.
- Recovery does not require the CLI fallback: when a second bot reviewer (Codex) is active, it covers the CR skip window directly. The CLI fallback (PR #50) and a co-reviewer (PR #54) are two distinct recovery paths for the same signal.

## Code-level fix (PR #56)

The three prior dogfood instances established that `"Review skipped: free tier disabled"` is transient and recoverable. PR #56 stops the pre-flight/poll path from treating it as terminal in the first place — the structural fix the prior runs only worked around (via Codex co-review or the CLI fallback).

The placeholder is now **non-terminal for `CR_SKIP_GRACE` seconds** (default `300`, env-only — no new `--flag`, mirroring `EARLY_CHECK_WINDOW`):

- `pre-flight.sh`: within grace → `gate=cr_wait` (the rate-limit sniff is guarded so it cannot re-flag the placeholder as a genuine limit); past grace → `gate=rate_limited` (`rate_limit_source=description`). Grace is anchored to the status `created_at` / `push_age` — a one-shot probe has no prior observation to anchor against, so it uses push age.
- `poll-cr-status.sh`: records the first-seen-skip timestamp and keeps polling instead of terminating on the first `state ∈ {success,failure}`; it exits only when the row flips to `"Review completed"` (terminal success) or the grace window expires (emit `rate_limited`). Default poll wait shortened 60s → 8s for responsiveness.
- **Unchanged paths**: genuine `Review limit reached` / `rate limited` route to `rate_limited` immediately; `error` / `pending` / `failure` paths are untouched.

This is the code-level realization of the recoverable/non-recoverable distinction the `## Why this matters for cr-fix` note above asked for: a transient refill placeholder no longer collapses into the same `rate_limited` verdict as a hard cap.

**Open follow-up (not yet lore):** the comment-channel rate-limit sniffer can false-positive on self-referential PR content (issue #57, open) — distinct from the commit-status path fixed here. Tracked, not asserted.

> Evidence: plugins/github-dev/skills/cr-fix/references/lessons-from-dogfood.md
> Evidence: plugins/github-dev/skills/cr-fix/scripts/sniff-cr-rate-limit.sh
> See-also: [[curated-conservative]]
> See-also: [[cr-cli-false-positive-generated-files]]

## Sources

1. **plugins/github-dev/skills/cr-fix/references/lessons-from-dogfood.md** — Lesson 5 (CORRECTED). The reference file itself records both the initial misreading and the corrected reading after consulting CR docs. PR #33 dogfood evidence (CR check IDs 4393995268, 4394157080, 4394162348) cited in the lesson body.
2. **CodeRabbit Fair Usage Limits Policy** — `https://docs.coderabbit.ai/management/plans#fair-usage-limits-policy`. Authoritative external doc on progressive-refill semantics. Cited inline in Lesson 5 of the lessons-from-dogfood reference file.
3. **PR #54 dogfood (docs-forge deploy-doc + MOC)** — 5-push burst over ~20 min: early commits CR-skipped (`"Review skipped: free tier disabled"`), final commit CR-completed (`"Review completed"`); Codex co-reviewed throughout and drove convergence. Established the co-reviewer recovery path and the content-empty `cr_state: success` caveat.
4. **PR #56 (Issue #55 fix)** — code-level correction of `poll-cr-status.sh` + `pre-flight.sh`: the transient placeholder is held non-terminal for `CR_SKIP_GRACE` (default 300s, env-only) rather than collapsing to `rate_limited`. Verification in the PR body: `bash -n` on both scripts, description-regex simulation, and stubbed-`gh` end-to-end gate transitions (`push_age=10`→`cr_wait`, `push_age=400`→`rate_limited`, `Review completed`→`proceed`, `Review limit reached`→immediate `rate_limited`). Evidence: `plugins/github-dev/skills/cr-fix/scripts/{poll-cr-status,pre-flight}.sh` + `references/pre-flight-rules.md`.
