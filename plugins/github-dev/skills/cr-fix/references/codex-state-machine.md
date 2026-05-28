# Codex State Machine

Two related state caches live alongside the iteration loop: `codex_active` (per-iteration engagement decision) and `codex_processed_reviews` (cross-iteration / cross-run dedupe of Codex review ids).

## codex_active values

| Value | Meaning |
|-------|---------|
| `disabled` | `--no-codex` was passed. Step 6b / 8b / Codex-only paths all skipped for the whole run. Sticky. |
| `active` | Auto-detect found ≥1 Codex review on the PR. Step 6b polls, Step 8b fetches. Sticky once set. |
| `inactive` | Auto-detect found 0 Codex reviews. Mid-run re-probe allowed (see flip rule). |
| `unknown` | Initial value at Step 2; replaced by Step 6's first iteration probe. |

## Transition rules

- **First iter (Step 6)**: always probe `/pulls/{pr}/reviews` filtered by `chatgpt-codex-connector[bot]`. Sets `disabled` (if `--no-codex`), `active` (count > 0), or `inactive` (count == 0).
- **Subsequent iters (Step 6)**: re-probe only if cache is `inactive`. `active` and `disabled` never flip back. This catches the common case where a PR opens just before its first Codex review arrives — without the mid-run re-probe the run would skip Codex output entirely.
- **Mid-iter constancy**: `codex_active` is cached within an iteration so Step 6b grace polling and Step 8b inline-fetch both see a fixed value. Within a single iteration the resolution is fixed.
- **Probe error handling**: if `gh api` fails, the `inactive` decision is non-sticky (treats failure as "unknown, retry next iter"). The earlier bug pattern was `gh api ... | wc -l` returning 0 on failure, silently locking `codex_active` to `inactive` — fixed by separating the gh call from the count.

## codex_processed_reviews

A JSON array of Codex review ids (numbers) that have been **surfaced to the user** in some prior iter / run on this PR. Persisted in `.claude/state/cr-fix-${PR_NUM}.json`. Inherited from the prior session's archived state at Step 2.

### What "processed" means

The semantic is "this review has been surfaced to the user this iter", NOT "we wrote code for it". Step 9c.7 appends the id regardless of whether the user applied, deferred, or skipped each item under that review. Without this, the next iter / next cr-fix run would re-discover the same review via Step 6b and re-prompt for items the user already decided on.

### Why filter by review id, not by commit_id

Codex review wrapper `commit_id` does NOT forward-shift on subsequent pushes. A review submitted on SHA `A` stays pinned to `A` forever, even after the user pushes SHA `B`. A `select(.commit_id == $sha)` filter has a structural blind spot: when Step 6b probes with `$CUR_SHA == B`, an already-finished Codex review on `A` is invisible and the grace poller spins until timeout.

Step 6b discovers Codex work via review `id` instead — robust to SHA progression — and uses `codex_processed_reviews` for dedupe. `pull_request_review_id` is the stable comment→review join key used in Step 8b regardless of GitHub's `commit_id` propagation rules.

### Manual override

If the user wants to re-surface an already-processed review, they can delete the relevant id from `codex_processed_reviews` in the state file by hand. The next iter will re-discover it as unprocessed.

## Cancel semantics

If the user picks Cancel in Step 9b's AskUserQuestion (which exits the loop before Step 9c-gated runs), Step 9c.7 is unreached and the review id stays unprocessed. The user gets to retry from scratch on the next run. That is intentional: Cancel is the escape hatch for "I want to re-think this review from the top".
