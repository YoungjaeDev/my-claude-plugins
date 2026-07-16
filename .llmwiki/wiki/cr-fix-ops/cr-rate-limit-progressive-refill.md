---
id: cr-rate-limit-progressive-refill
aliases: [cr-free-tier-disabled, cr-quota-budget, cr-burst-push, cr-active-rate-limit-query]
last_verified: 2026-07-16
status: active
volatility: volatile
sources: 9
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

## The adaptive Fair-Usage table (Pro+)

The progressive-refill mechanism above is now doc-confirmed with concrete numbers. Per CR's [Fair Usage Limits Policy](https://docs.coderabbit.ai/management/plans#fair-usage-limits-policy) (verified 2026-07-14), the per-hour review allowance is **not fixed** at the plan's headline rate — it adapts *down* with the developer's trailing 7-day review count. For the Pro+ tier this org runs:

| Reviews in last 7 days | Reviews / hour (Pro+) |
|---|---|
| 0-29  | 10 (headline rate) |
| 30-39 | 8 |
| 90+   | 1, one review at a time |

Intermediate 7-day bands step the hourly allowance down monotonically between these anchors (the Pro tier follows the same shape, reaching 1/hr after 60+ reviews in 7 days). This is the structural cause of the rate-limiting `cr-fix` runs experience: every incremental push consumes one review, so a heavy dogfooding week pushes the developer into the 90+/7d band where only a single review refills per hour — exactly the trickle the mechanism section describes, now with a named cause. The headline "Pro+ = 10/hr" is a ceiling, not a floor. The `.coderabbit.yaml` `auto_pause_after_reviewed_commits: 2` lever attacks this directly by cutting how many reviews a multi-push PR consumes.

**Official self-serve check.** Commenting `@coderabbitai rate limit` (or `@coderabbitai reviews remaining?`) on any PR returns the current remaining count and reset estimate — the same command `cr-fix` automates in `## The active query` below, but usable by hand to see which adaptive band you are in before a burst of pushes.

## Why this matters for `cr-fix`

`cr-fix` was originally written to add a per-PR cooldown that would skip `sniff-cr-rate-limit.sh` for K iters after detecting "free tier disabled". Dogfood overturned that design:

- **Do NOT add a sniff cooldown.** It would mask normal progressive-refill oscillation as a failure mode it isn't.
- **Treat `--max-iter` as a CR quota budget**, not a retry cap. Default `5` aligns with CR Pro's 5-rev/hour.
- **Add `--push-spacing <sec>`** (planned v3) to throttle burst-push patterns at source. CR Pro+ / Enterprise users can keep `0`.
- The pre-flight gate must distinguish progressive-refill rate-limiting from a hard cap — originally both surfaced as `gate=rate_limited`, losing the recoverable/non-recoverable distinction now restored at the code level (see `## The rule`).

## The rule

A transient `"Review skipped: free tier disabled"` placeholder is **non-terminal**: hold it in `gate=cr_wait` for `CR_SKIP_GRACE` seconds (default `300`, env-only — no new `--flag`, mirroring `EARLY_CHECK_WINDOW`), then fall through to `rate_limited` once the grace window expires. A genuine `Review limit reached` / `rate limited` routes to `rate_limited` immediately; `error` / `pending` / `failure` paths are untouched. The poll keeps waiting through the grace window instead of terminating on the first `state ∈ {success,failure}`, exiting only when CR flips to `Review completed` (terminal success) or grace expires — so a refill placeholder no longer collapses to the same verdict as a hard cap, and a CR-only PR no longer false-converges on the content-empty placeholder.

**Channel authority on the re-fetch path.** The poll's early-sniff branch re-reads the commit state after a rate-limit sniff so a *stale comment* from an earlier push cannot false-positive over a genuinely completed review. That suppression is legitimate only for the comment channel: the status **description** is SHA-scoped to the current head, so a fresh `success` whose description is itself a limit marker (`Review limit reached`, refill phrasing) is CR's quota-skip row, not a completed review, and must fall through to `rate_limited` instead of being promoted to terminal success. Rule of thumb: comment-channel hits yield to a fresh terminal state; description-channel evidence on the current SHA keeps its authority (`poll-cr-status.sh` marker guard + `pre-flight.sh` fixture "description RL on success -> gate rate_limited").

## The active query

When the passive sniff is ambiguous (a rate-limit signal with no reset estimate), cr-fix 2.8.0 posts `@coderabbitai rate limit` on the PR and parses CR's reply (`query-cr-rate-limit.sh`) for `remaining` / `reset_minutes`. Two contract rules, both dogfood-derived:

- **Anchor the reply to your own post's comment id, never to a body match.** Every run posts the identical text, so re-finding "our post" via body-match `last` is ambiguous across runs: while the new post is not yet visible in the list API, the *previous* run's post anchors the filter and its old reply is served as this query's answer — a stale `reset_minutes` drives the fallback decision. `gh pr comment` prints the new comment's URL (`…#issuecomment-<id>`); issue-comment ids are monotonic, so `reply.id > post.id` selects only replies to this query and subsumes same-second `>=` timestamp handling.
- **The result is per-run idempotent**: persisted to the state file (`rate_limit_query`) and reused across iterations, because the query is an external side effect (a comment on the PR) that must not repeat every iter.

## Evidence across dogfood runs

Three independent instances confirm the signal is transient and recoverable, not a hard cap:

- **Burst push → skip/complete oscillation = progressive refill** (PR #33): a multi-push burst produced interleaved `Review completed` / `Review skipped: free tier disabled` commit statuses — the oscillation matches refill semantics, not a fixed-hour block.
- **CLI fallback recovery path** (PR #50): pre-flight returned `gate=rate_limited`; with `--cr-source auto`, cr-fix fell back to the authed local CodeRabbit CLI, which produced a full review and the loop converged.
- **Co-reviewer recovery path** (PR #54): early commits CR-skipped, final commit CR-completed once quota refilled, while Codex (`chatgpt-codex-connector[bot]`) carried every iteration's review through the skip window — so the loop never stalled. Caveat: during the skip window `cr_state: success` is *terminal but content-empty*, so a CR-only PR can false-"clean" unless something holds the gate (the `CR_SKIP_GRACE` rule closes that gap). The CLI fallback and the co-reviewer are two distinct recovery paths for the same signal.
- **Adaptive Fair-Usage limit, commit-status still green** (PR #104): the `Review limit reached` variant (not `free tier disabled`) arrived with commit status `CodeRabbit | success | Review completed`, 0 inline comments, and 0 reviews — the content-empty-success trap above, reached by the *hard-cap* string rather than the refill placeholder. Pre-flight routed it to `gate=rate_limited` from the comment channel, correctly. The body carried an explicit `Next review available in: 41 minutes`, which the sniffer does not extract (see the drift page).

> Evidence: plugins/github-dev/skills/cr-fix/references/lessons-from-dogfood.md
> Evidence: plugins/github-dev/skills/cr-fix/scripts/sniff-cr-rate-limit.sh
> See-also: [[curated-conservative]]
> See-also: [[cr-cli-false-positive-generated-files]]
> See-also: [[cr-cli-fallback-contract-drift]]

## Sources

1. **plugins/github-dev/skills/cr-fix/references/lessons-from-dogfood.md** — Lesson 5 (CORRECTED): the initial misreading and the corrected reading after consulting CR docs. PR #33 dogfood evidence cited in the lesson.
2. **CodeRabbit Fair Usage Limits Policy** — `https://docs.coderabbit.ai/management/plans#fair-usage-limits-policy`. Authoritative external doc on progressive-refill semantics.
3. **PR #50 dogfood** — established the CLI-fallback recovery path: `gate=rate_limited` → `--cr-source auto` fell back to the authed CodeRabbit CLI and converged.
4. **PR #54 dogfood** — established the co-reviewer recovery path and the content-empty `cr_state: success` caveat.
5. **PR #56 (Issue #55 fix)** — code-level correction of `poll-cr-status.sh` + `pre-flight.sh`: the transient placeholder is held non-terminal for `CR_SKIP_GRACE` (default 300s, env-only) rather than collapsing to `rate_limited`.
6. **PR #104 dogfood** — fourth instance: `Review limit reached` (Fair Usage adaptive limit) under a green `success / Review completed` commit status, with a machine-readable `Next review available in: 41 minutes` the sniffer drops.
7. **PR #122** (`fix(github-dev): cr-fix iter-4 — id-anchor the active rate-limit query`) — the active query lands (2.8.0) and its stale-anchor bug is reproduced RED against the body-match implementation (fixture `issue-comments-rl-stale.json`: prior-run reply id 501 served as fresh) then fixed via post-id anchoring.
8. **CodeRabbit Fair Usage adaptive rate table** — `https://docs.coderabbit.ai/management/plans#fair-usage-limits-policy` (verified 2026-07-14). The concrete Pro+ per-hour-by-7-day-review-count table (0-29 → 10/hr, 30-39 → 8/hr, 90+ → 1/hr one-at-a-time) plus the official `@coderabbitai rate limit` / `reviews remaining?` self-serve query command — the doc confirmation of the previously reverse-engineered refill lore (Issue #121). Distinct from source 2, which cites the progressive-refill *semantics* on the same page; this row cites the specific adaptive *numbers* and the user-facing query command.
9. **PR #147 + Issue #57** (`fix(github-dev): cr-fix rate-limit false positive`) — the channel-authority rule on the re-fetch path: `pre-flight.sh` overrides a comment-channel rate-limit hit with a fresh terminal success (`gate=proceed`, description authority retained) and `poll-cr-status.sh` refuses to promote a fresh success whose description is itself a limit marker. Fixture-locked in `tests/run-tests.sh` ("comment RL over terminal success -> gate proceed", "description RL on success -> gate rate_limited", "stale RL comment + status flips success -> poll emits success"). Root scenario: #56's self-referential trigger-phrase quote (Issue #57).
