# Codex Parsing Rules

How cr-fix v2 reads Codex review state without relying on PR timeline body order. Used by Step 5 pre-flight and Step 6b grace polling.

## Background

`chatgpt-codex-connector[bot]` posts the same review surface as a human reviewer (`pulls/$PR/reviews`) plus an opaque emoji marker that flips through three states:

- "in progress" (working)
- "clean" (no findings)
- "findings" (review submitted with comments)

The emoji marker is visible on the PR page but its API surface is **not fully nailed down** — Explore agent's 4-repo sweep found channel A returning `[]` in every case, and channel B occasionally carrying check-runs with no state hint. Until a confirmed signal channel is found, treat emoji as a HINT for early routing, never as a definitive gate.

## Two-tier reading

1. **Review submission (definitive)** — `pulls/$PR/reviews` filtered by `chatgpt-codex-connector[bot]` and `state ∈ {COMMENTED, CHANGES_REQUESTED}`, dedupe-filtered by `codex_processed_reviews`. **Any non-empty result → actionable, period**. Skip emoji probing in that branch.
2. **Emoji hint (best-effort)** — Only consulted when review submission is empty. Three channels tried in order, first signal wins.

## Channel A: PR-level reactions (`issues/$PR/reactions`)

GitHub treats PRs as issues for the reactions endpoint. Codex sometimes (per user observation, unconfirmed by Explore) reacts with a thumbs-up / eyes / etc. to its own PR shell when state transitions.

```bash
gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUM/reactions" 2>/dev/null \
  | jq -s 'add // []
           | map(select(.user.login == "chatgpt-codex-connector[bot]"))
           | sort_by(.created_at) | last // {}'
```

Mapping (provisional, refine as signal-capture PRs land):

| reaction `content` | `emoji_state` |
|---|---|
| `+1` / `hooray` | `clean` |
| `eyes` | `in_progress` |
| `-1` / `confused` | `findings` |
| (empty) | `unknown` |

## Channel B: commit check-runs (`commits/$SHA/check-runs`)

Codex registers check-runs whose `name` / `output.summary` may carry the state.

```bash
gh api --paginate "repos/$OWNER/$REPO/commits/$CUR_SHA/check-runs" 2>/dev/null \
  | jq -s 'add // [] | .[].check_runs[]?
           | select((.name // "") | test("codex|chatgpt"; "i"))
           | {status, conclusion, name, summary: (.output.summary // "")}'
```

Mapping:

| `status` | `conclusion` | `summary` regex | `emoji_state` |
|---|---|---|---|
| `in_progress` / `queued` | (any) | (any) | `in_progress` |
| `completed` | `success` / `neutral` | `no issues` / `clean` (case-insensitive) | `clean` |
| `completed` | `failure` / `action_required` | (any) | `findings` |
| `completed` | (else) | (regex miss) | `unknown` |

## Channel C: review-level reactions (`pulls/$PR/reviews/$RID/reactions`)

Returns `404` in most cases observed. Try only when channels A + B both produced `unknown`. Cheap probe (1 call per Codex review id) — keep enabled to opportunistically catch unusual repo configurations.

## Fallback: timeout-based logic

When all three channels return `unknown`:

- If `push_age < codex_timeout_seconds` (default `600`) → treat as `in_progress` (Codex may still post).
- Otherwise → treat as `clean` (Codex never posted; assume nothing to add).

The 10-minute default matches the upper end of Codex publish latency observed in PR #30 / PR #31. Override via `CODEX_PREFLIGHT_TIMEOUT` env var when a repo shows consistently slower turnaround.

## False-emoji warning

Explore noted one case (4-repo sample) where channel B reported `conclusion=success` BEFORE the review submission was created. The connector occasionally posts the check-run minutes before the review payload lands. To avoid premature `proceed`:

- A `clean` emoji_state alone (no review submission AND no past `processed` review) still gates on `push_age >= 60s` minimum. Pre-flight emits `gate=codex_wait` for the first minute even on `clean` emoji.
- A `findings` emoji_state without a review submission falls through to `codex_wait` — never `proceed`. The review is mandatory for fetching the actual comments.

## Mid-action re-review (`review.id` dedupe)

CR re-review on each push is well-understood. Codex does the SAME — across iterations on PR #30 it submitted 5 distinct reviews, each with its own `id`. State file's `codex_processed_reviews` array tracks ids surfaced to the user; pre-flight + Step 6b filter against it; Step 9c.7 appends each surfaced id.

**Important nuance**: Codex review `commit_id` is pinned to the SHA where the review was *submitted*. It does NOT shift forward on subsequent pushes. A naive `select(.commit_id == $CUR_SHA)` filter blinds Step 6b to legitimate reviews submitted on a prior iter SHA that the user has not yet seen. Always join on `id` instead.

## Timestamp-only sorting (never trust PR timeline order)

PR pages render Codex emoji flips and CR review submissions interleaved with the user's commits in a renderer-specific order. The API returns `submitted_at` / `created_at` which is monotonic and authoritative.

```bash
| sort_by(.submitted_at)   # for reviews
| sort_by(.created_at)     # for statuses / comments / reactions
```

`last` picks the newest. The `reverse | .[0]` form is equivalent and equally acceptable.

## Probe script entry point

`scripts/probe-codex-state.sh` wraps channels A + B + C and emits one line:

```json
{"emoji_state":"clean|in_progress|findings|unknown","source":"reactions|check-runs|review-reactions|none"}
```

Callers (`scripts/pre-flight.sh`) consume the `emoji_state` field and ignore `source` unless debugging.

## Engagement-only probe vs state probe

The original `scripts/probe-codex-engagement.sh` (returns `active` / `inactive`) is retained — it answers "has Codex EVER reviewed this PR?", used by the small-diff codex-only heuristic (Step 5b) and the codex_active state machine (`references/codex-state-machine.md`). `probe-codex-state.sh` is the new function: "what is Codex doing RIGHT NOW on the current SHA?".
