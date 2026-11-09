# Codex Parsing Rules

How review-loop reads Codex review state in 3 tiers, never by PR timeline order, for Step 5 pre-flight and Step 6b. `chatgpt-codex-connector*` posts PR reviews like a human reviewer plus an emoji marker that moves through in progress, clean and findings.

The marker has no confirmed API surface: channel A usually returns `[]`, and channel B can carry check-runs with no state. Emoji is a hint for early routing, never a gate.

## Three-tier reading

1. **Review submission (definitive)** — `pulls/$PR/reviews` filtered by `chatgpt-codex-connector*` and `state ∈ {COMMENTED, CHANGES_REQUESTED}`, dedupe-filtered by `codex_processed_reviews`. **Any non-empty result → actionable, period**. Skip emoji probing in that branch.
2. **HEAD verdict** — `scripts/codex-head-verdict.sh` reads the `<!-- codex-pull-request-review-summary -->` comment and the `commit_id == HEAD` review (`references/codex-state-machine.md` "HEAD verdict"). When Codex posts that comment, it decides; an unparseable one is never clean and falls back to review-id polling.
3. **Emoji hint (best-effort)** — Only consulted when review submission is empty and Codex posts no summary comment. Three channels tried in order, first signal wins.

## Channel A: PR-level reactions (`issues/$PR/reactions`)

GitHub treats a PR as an issue for the reactions endpoint, and Codex can react to the PR (thumbs-up, eyes) as its state changes.

```bash
gh api --paginate "repos/$OWNER/$REPO/issues/$PR_NUM/reactions" 2>/dev/null \
  | jq -s 'add // []
           | map(select((.user.login // "") | test("^chatgpt-codex-connector(\\[bot\\])?$"; "i")))
           | sort_by(.created_at) | last // {}'
```

Mapping (provisional):

| reaction `content` | `emoji_state` |
|---|---|
| `+1` / `hooray` | `clean` |
| `eyes` | `in_progress` |
| `-1` / `confused` | `findings` |
| (empty) | `unknown` |

## Channel B: commit check-runs (`commits/$SHA/check-runs`)

Codex check-runs, if any, are picked by `name`. No Codex app identity (`.app.slug` / `.app.owner.login`) has been observed on check-runs to anchor on, and any GitHub App can name a check-run `codex-lint` and summarise it "clean". So this channel never yields `clean`: it can only make the loop wait.

```bash
gh api --paginate "repos/$OWNER/$REPO/commits/$CUR_SHA/check-runs" 2>/dev/null \
  | jq -s 'add // [] | .[].check_runs[]?
           | select((.name // "") | test("codex|chatgpt"; "i"))
           | {status, conclusion, name}'
```

Mapping:

| `status` | `conclusion` | `emoji_state` |
|---|---|---|
| `in_progress` / `queued` | (any) | `in_progress` |
| `completed` | `failure` / `action_required` | `findings` |
| `completed` | (else) | `unknown` |

## Channel C: review-level reactions (`pulls/$PR/reviews/$RID/reactions`)

Tried only when channels A and B both gave `unknown`, at 1 call per Codex review id; it returns `404` in most repos.

Reactions are filtered by `.user.login` with Channel A's anchored regex, since anyone who can see the PR can react to the review.

The mapping is Channel A's.

## Fallback: timeout-based logic

When all three channels return `unknown`:

- If `push_age < codex_timeout_seconds` (default `900`) → treat as `in_progress` (Codex may still post).
- Otherwise → treat as `clean` (Codex never posted; assume nothing to add).

The 15-minute default sits above the slowest Codex turnaround measured so far (726 s, `scripts/codex-turnaround.sh`). Override via `CODEX_PREFLIGHT_TIMEOUT` env var when a repo shows consistently slower turnaround.

## False-emoji warning

A reaction can report clean BEFORE the review submission is created. To avoid premature `proceed`:

- A `clean` emoji_state alone (no review submission AND no past `processed` review) still gates on `push_age >= 60s` minimum. Pre-flight emits `gate=codex_wait` for the first minute even on `clean` emoji.
- A `findings` emoji_state without a review submission falls through to `codex_wait` — never `proceed`. The review is mandatory for fetching the actual comments.

## Timestamp-only sorting (never trust PR timeline order)

PR pages render Codex emoji flips and CR review submissions interleaved with the user's commits in a renderer-specific order. The API returns `submitted_at` / `created_at` which is monotonic and authoritative.

```text
| sort_by(.submitted_at)   # for reviews
| sort_by(.created_at)     # for statuses / comments / reactions
```

`last` picks the newest. A review's `commit_id` stays pinned to the SHA it was submitted on, so join on `id` and dedupe with `codex_processed_reviews` (`codex-state-machine.md`).

## Probe scripts

`scripts/probe-codex-state.sh` wraps channels A, B and C and prints one line, whose `emoji_state` `scripts/pre-flight.sh` reads (`source` is for debugging):

```json
{"emoji_state":"clean|in_progress|findings|unknown","source":"reactions|check-runs|review-reactions|none"}
```

`scripts/probe-codex-engagement.sh` (`active` / `inactive`) answers a different question, whether Codex ever reviewed this PR, for the Step 5b heuristic and the `codex_active` cache (`codex-state-machine.md`).
