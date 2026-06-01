---
id: cr-rate-limit-budget
aliases: [cr-progressive-refill-rule, cr-max-iter-budget]
tier: insight
promoted_from: [[cr-rate-limit-progressive-refill]]
evidence_count: 2
last_verified: 2026-06-01
status: active
volatility: stable
sources: 2
---

# CodeRabbit "free tier disabled" = quota refill, not a plan downgrade

When CR emits `Review skipped: free tier disabled` mid-loop, read it as **progressive-refill hourly-quota exhaustion**, not a subscription downgrade. Do NOT add a sniff cooldown that backs off for K iters — it masks normal refill oscillation as a failure. Treat `--max-iter` as a CR quota budget (Pro ≈ 5 rev/hour), and throttle bursts with push spacing instead.

**When to apply**: running `cr-fix` (or any CR multi-iter loop) that bursts several pushes within an hour and starts seeing skipped reviews.

**Why**: a cooldown would suppress recoverable refill behavior and waste iterations; the misread inverts a recoverable state into a hard-cap failure.

The dogfood data, the Fair-Usage-Policy citation, and the planned-v3 `--push-spacing` design stay in the `promoted_from:` wiki page (still `volatility: volatile`); only the stabilized rule is promoted here.

## Sources

- `.llmwiki/wiki/cr-fix-ops/cr-rate-limit-progressive-refill.md` — the promoted source page (mechanism, PR #33 dogfood data, policy citation).
- `plugins/github-dev/skills/cr-fix/references/lessons-from-dogfood.md` — Lesson 5 (the corrected reading after consulting CR docs).

> Evidence: .llmwiki/wiki/cr-fix-ops/cr-rate-limit-progressive-refill.md
> See-also: [[cr-rate-limit-progressive-refill]]
