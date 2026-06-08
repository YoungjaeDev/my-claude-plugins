# Pre-flight Review Detection (Step 5)

Triggered at the top of every iteration BEFORE the wait/polling phase. Goal: decide in one round-trip whether to wait, proceed, fall back, or abort. Removes the historical hang where Step 6 always polled CR status even when reviews had already arrived.

## Why pre-flight

Two reviewers (CR + Codex) on different channels with different timings:

- Codex arrives **3-24 minutes earlier** than CR in the observed 7-PR / 4-repo sample. "Codex landed → CR done" is NOT a safe assumption.
- CR uses commit-status; Codex uses PR reviews. They cannot be merged into one probe.
- Mid-action re-reviews are real (PR #30: 5 distinct Codex reviews across iterations). Pre-flight has to surface the latest unprocessed review id, not just "any review existed".
- PR timeline rendering can re-order arrivals (Codex emoji flip can push CR review visually first). Pre-flight sorts by `submitted_at` / `created_at` only — never by GitHub timeline body order.

## Five-source fetch (parallel-safe)

| # | Channel | Endpoint | Purpose |
|---|---------|----------|---------|
| 1 | CR commit-status | `repos/$O/$R/commits/$SHA/statuses` (plural, `--paginate`) | `state` + `description` of latest `CodeRabbit` context |
| 2 | CR issue-comments | `repos/$O/$R/issues/$PR/comments` (`--paginate`) | `coderabbitai[bot]` bodies created OR updated after `PUSH_TIME` — catches in-place rate-limit edits |
| 3 | Codex reviews | `repos/$O/$R/pulls/$PR/reviews` (`--paginate`) | `chatgpt-codex-connector[bot]` reviews, `COMMENTED`/`CHANGES_REQUESTED`, sorted by `submitted_at`, filtered by `codex_processed_reviews` |
| 4 | Codex emoji A | `repos/$O/$R/issues/$PR/reactions` | PR-level reactions left by `chatgpt-codex-connector[bot]` (in_progress / clean / findings) |
| 5 | Codex emoji B | `repos/$O/$R/commits/$SHA/check-runs` | Check-run names / summaries from the connector — sometimes carries the state icon |

Channel 4/5 (emoji) are best-effort. The Explore agent's 4-repo probe found **no reliable surfacing path** in the GitHub API as of plan date. If both return empty, fall back to **timeout-based** logic (`push_age vs codex_timeout_seconds`, default `600` = 10 min).

> Channel C (`pulls/$PR/reviews/$rid/reactions`) was considered but returns 404 in most cases — only worth adding if a confirmed PR URL surfaces a real signal there.

## CR state read

```bash
cr_status=$(gh api --paginate "repos/$OWNER/$REPO/commits/$CUR_SHA/statuses" \
  | jq -s 'add // [] | [.[] | select(.context | test("CodeRabbit"; "i"))] | sort_by(.created_at) | reverse | .[0] // {}')
cr_state=$(jq -r '.state // ""' <<<"$cr_status")
cr_desc=$(jq -r '.description // ""'  <<<"$cr_status")
```

- `cr_state ∈ {success, failure, pending, "", error}` (`""` → no status row yet).
- `cr_desc` carries the free-tier-disabled and `Review limit reached` text in newer CR versions (this is the **new channel** Step 7b previously missed).

## CR rate-limit signal (consolidated)

The sniff script (`scripts/sniff-cr-rate-limit.sh`) checks three locations:

1. issue-comment body (`created_at > push_time` OR `updated_at > push_time`) — catches both new posts AND CR's in-place edit-to-rate-limit pattern (PR #30).
2. review body (`submitted_at > push_time`).
3. commit-status `description` (no time check; latest CodeRabbit status only).

Hit on ANY of the three → rate-limited.

## Codex review id read

```bash
PROCESSED=$(jq -c '.codex_processed_reviews // []' "$STATE_FILE")
codex_latest_id=$(gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUM/reviews" \
  | jq -s --argjson p "$PROCESSED" 'add // []
      | [ .[]
          | select(.user.login == "chatgpt-codex-connector[bot]")
          | select(.state == "COMMENTED" or .state == "CHANGES_REQUESTED")
          | select(.id as $i | $p | index($i) | not) ]
      | sort_by(.submitted_at) | last | .id // ""')
```

If `codex_latest_id != ""` → Codex is actionable for this iter regardless of emoji state.

## Codex emoji read (best-effort, multi-channel)

See `references/codex-parsing-rules.md` for full channel logic. The pre-flight aggregates whatever signal the helper script `scripts/probe-codex-state.sh` emits:

```text
emoji_state ∈ {findings, clean, in_progress, unknown}
```

`unknown` means none of the channels surfaced a state — the pre-flight then falls back to timeout-based logic.

## Decision matrix

| `cr_state` | `cr_desc` keyword | CR comment rate-limit hit | `codex_latest_id` | `emoji_state` | `push_age` vs timeout | gate |
|---|---|---|---|---|---|---|
| `success` | none | no | non-empty | any | n/a | `proceed` |
| `success` | none | no | empty | `clean` | n/a | `proceed` (CR only) |
| `success` | none | no | empty | `findings` | n/a | `codex_wait` (review still publishing) |
| `success` | none | no | empty | `in_progress` | < timeout | `codex_wait` |
| `success` | none | no | empty | `unknown` | < timeout | `codex_wait` |
| `success` | none | no | empty | any | ≥ timeout | `proceed` (Codex assumed clean) |
| `success` | `Review skipped: free tier disabled` | n/a | n/a | n/a | `push_age` < `CR_SKIP_GRACE` | `cr_wait` (transient — poll the real review out) |
| `success` | `Review skipped: free tier disabled` | n/a | n/a | n/a | `push_age` ≥ `CR_SKIP_GRACE` | `rate_limited` (genuine skip) |
| `success` | `Review limit reached` / `rate limited` | n/a | n/a | n/a | n/a | `rate_limited` |
| `success` | none | yes | n/a | n/a | n/a | `rate_limited` |
| `pending` / `in_progress` / `""` | n/a | n/a | n/a | n/a | n/a | `cr_wait` |
| `failure` | n/a | n/a | n/a | n/a | n/a | `failure` |
| `error` | n/a | n/a | n/a | n/a | n/a | `cr_wait` (treat as transient, retry-by-polling) |

`codex_timeout_seconds` defaults to `600`. Override per-run via env var `CODEX_PREFLIGHT_TIMEOUT` if a CI pattern shows Codex routinely lands later.

`CR_SKIP_GRACE` defaults to `300` (seconds). CodeRabbit briefly publishes a `success` commit-status with `description = "Review skipped: free tier disabled"` before replacing it with `"Review completed"` once the real review lands on a paid private repo (observed ~5 min gap; "free tier disabled" is the [fair-usage hourly-quota refill](https://docs.coderabbit.ai/management/plans#fair-usage-limits-policy) wording, NOT a plan downgrade). Treating that transient row as terminal makes the skill fetch threads before any finding exists and report false convergence, so within `CR_SKIP_GRACE` the gate stays `cr_wait`; only a row still skipped past the grace routes to `rate_limited`. Both `pre-flight.sh` and `poll-cr-status.sh` honor `CR_SKIP_GRACE`.

## Output JSON contract

`scripts/pre-flight.sh` emits one terminal JSON line on stdout:

```json
{
  "cr_state": "success|failure|pending|error|none",
  "cr_actionable": true,
  "cr_desc": "Review skipped: ...",
  "codex_state": "actionable|clean|arriving|unknown",
  "codex_actionable": true,
  "codex_latest_id": 123456789,
  "codex_emoji_state": "findings|clean|in_progress|unknown",
  "gate": "proceed|cr_wait|codex_wait|rate_limited|failure",
  "codex_timeout_active": true,
  "push_age_seconds": 42,
  "rate_limit_source": "comment|description|none"
}
```

## State persistence

After pre-flight runs, the SKILL.md writes `pre_flight_decision: {cr_state, codex_state, gate, codex_timeout_active, rate_limit_source}` into `$STATE_FILE`. Next iter can use this for diagnostics or to skip re-probing when a gate decision is sticky (e.g. `rate_limited`).

## Behavior when pre-flight itself fails

Any `gh api` returning a non-2xx propagates as `error` for that channel only — pre-flight emits `gate: cr_wait` and lets the legacy Step 6 polling cover the gap. The skill never aborts on pre-flight failure; it degrades to v1 behavior.

## Polling-interval coupling

When `gate == cr_wait` or `gate == codex_wait`, Step 6 / 6b take over with `INTERVAL` controlling poll frequency. The plan moves the default from `60s` to `8s` (within the 5-10s pseudo-interrupt window) because pre-flight already absorbs the cold-start latency that justified the original 60s value.
