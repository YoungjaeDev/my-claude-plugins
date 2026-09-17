# Pre-flight Review Detection (Step 5)

Triggered at the top of every iteration BEFORE the wait/polling phase. Goal: decide in one round-trip whether to wait, proceed, fall back, or abort. Removes the historical hang where Step 6 always polled CR status even when reviews had already arrived.

## Why pre-flight

Two reviewers (CR + Codex) on different channels with different timings:

- Codex usually arrives well before CR, by anything from a few minutes to tens of minutes. "Codex landed → CR done" is NOT a safe assumption.
- CR uses commit-status **or** a check-run, depending on how the app is installed on the repo; Codex uses PR reviews. They cannot be merged into one probe. `scripts/cr-commit-state.sh` normalizes CR's two surfaces onto one vocabulary.
- Mid-action re-reviews are real: one PR accumulates several distinct Codex reviews across iterations. Pre-flight has to surface the latest unprocessed review id, not just "any review existed".
- PR timeline rendering can re-order arrivals (Codex emoji flip can push CR review visually first). Pre-flight sorts by `submitted_at` / `created_at` only — never by GitHub timeline body order.

## Five-source fetch (parallel-safe)

| # | Channel | Endpoint | Purpose |
|---|---------|----------|---------|
| 1 | CR reported state | `scripts/cr-commit-state.sh` -> `commits/$SHA/statuses` (plural, `--paginate`), else `commits/$SHA/check-runs` | `state` + `description` of the latest `CodeRabbit` row on whichever surface reports |
| 2 | CR issue-comments | `repos/$O/$R/issues/$PR/comments` (`--paginate`) | `coderabbitai[bot]` bodies created OR updated after `PUSH_TIME` — catches in-place rate-limit edits |
| 3 | Codex reviews | `repos/$O/$R/pulls/$PR/reviews` (`--paginate`) | `chatgpt-codex-connector*` reviews, `COMMENTED`/`CHANGES_REQUESTED`, sorted by `submitted_at`, filtered by `codex_processed_reviews` |
| 4 | Codex emoji A | `repos/$O/$R/issues/$PR/reactions` | PR-level reactions left by `chatgpt-codex-connector*` (in_progress / clean / findings) |
| 5 | Codex emoji B | `repos/$O/$R/commits/$SHA/check-runs` | Check-run names / summaries from the connector — sometimes carries the state icon |

Channel 4/5 (emoji) are best-effort: the GitHub API exposes **no reliable surfacing path** for the marker. If both return empty, fall back to **timeout-based** logic (`push_age vs codex_timeout_seconds`, default `600` = 10 min).

> Channel C (`pulls/$PR/reviews/$rid/reactions`) was considered but returns 404 in most cases — only worth adding if a confirmed PR URL surfaces a real signal there.

## CR state read

```bash
cr_status=$(bash "$SCRIPT_DIR/cr-commit-state.sh" "$OWNER" "$REPO" "$CUR_SHA")
cr_state=$(jq -r 'if (.state // "none") == "none" then "" else .state end' <<<"$cr_status")
cr_desc=$(jq -r '.description // ""' <<<"$cr_status")
```

`cr-commit-state.sh` reads `/statuses` first (its `description` carries the rate-limit text) and falls back to `/check-runs`, mapping the check-run vocabulary onto the commit-status one:

| check-run | -> state |
|---|---|
| `completed` + `success` \| `neutral` \| `skipped` | `success` |
| `completed` + `failure` \| `timed_out` \| `cancelled` \| `action_required` \| `stale` | `failure` |
| `queued` \| `in_progress` | `pending` |
| no CodeRabbit row on either surface | `none` |

Reading only `/statuses` is what made every check-run repo report `cr_state: none` forever: pre-flight routed to `cr_wait`, `poll-cr-status.sh` never saw a terminal state, and the loop spun to `TIMEOUT` while the review had finished and posted inline comments. Fixture-covered in `tests/run-tests.sh`.

- `cr_state ∈ {success, failure, pending, "", error}` (`""` → no status row yet).
- `cr_desc` carries the free-tier-disabled and `Review limit reached` text in newer CR versions (this is the **new channel** Step 7b previously missed).
- **`Review skipped: free tier disabled` is transient, not terminal.** CodeRabbit briefly posts `success` + this description (an hourly fair-usage quota refill, observed ~5 min) before replacing it with `Review completed`. It is held non-terminal for `CR_SKIP_GRACE` seconds (default `300`) and only routed to `rate_limited` past that window — distinct from genuine `Review limit reached` / `rate limited`, which route immediately.

## CR rate-limit signal (consolidated)

The sniff script (`scripts/sniff-cr-rate-limit.sh`) checks three locations:

1. issue-comment body (`created_at > push_time` OR `updated_at > push_time`) — catches both new posts AND CR's in-place edit-to-rate-limit pattern.
2. review body (`submitted_at > push_time`).
3. commit-status `description` (no time check; latest CodeRabbit status only).

A hit whose text is `Review skipped: N files exceed the limit of M` additionally carries `permanent: true` — a skip no reset clears. It routes to `rate_limited` like any other hit, but Step 7c must not offer to wait it out, and the iteration must never converge to `clean` on it (`references/rate-limit-fallback.md`).

Hit on ANY of the three → rate-limited — **except** a `comment`-channel-only hit while the commit-status already reports a terminal `success`/`failure`. The commit-status/check-run is authoritative, so a lingering rate-limit comment (stale from an earlier push, or CR's in-place edit that outlived the real review) does not override it. The `description` and `both` channels are commit-status-derived and keep override authority.

## Codex review id read

```bash
PROCESSED=$(jq -c '.codex_processed_reviews // []' "$STATE_FILE")
codex_latest_id=$(gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUM/reviews" \
  | jq -s --argjson p "$PROCESSED" 'add // []
      | [ .[]
          | select((.user.login // "") | test("^chatgpt-codex-connector(\\[bot\\])?$"; "i"))
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
| `success` | `Review skipped: free tier disabled` | n/a | n/a | n/a | `cr_skip_age < CR_SKIP_GRACE` | `cr_wait` (transient, hold for the real `Review completed`) |
| `success` | `Review skipped: free tier disabled` | n/a | n/a | n/a | `cr_skip_age ≥ CR_SKIP_GRACE` | `rate_limited` (genuine disable) |
| `success` | `Review limit reached` / `rate limited` | n/a | n/a | n/a | n/a | `rate_limited` |
| `success` | none | yes (`comment` channel) | n/a | n/a | n/a | `proceed` — comment sniff is not authoritative over a terminal commit-status; the `description`/`both` channels still route to `rate_limited` |
| `pending` / `in_progress` / `""` | n/a | n/a | n/a | n/a | n/a | `cr_wait` |
| `failure` | n/a | n/a | n/a | n/a | n/a | `failure` |
| `error` | n/a | n/a | n/a | n/a | n/a | `cr_wait` (treat as transient, retry-by-polling) |

`codex_timeout_seconds` defaults to `600`. Override per-run via env var `CODEX_PREFLIGHT_TIMEOUT` if a CI pattern shows Codex routinely lands later.

`CR_SKIP_GRACE` defaults to `300` (seconds). It bounds how long a transient `success` + `Review skipped: free tier disabled` row is held as `cr_wait` before being treated as a genuine disable (`rate_limited`). The grace clock (`cr_skip_age`) is anchored to the CR status row's own `created_at` — i.e. how long *that placeholder* has existed — so a bot that queues the row late (more than the grace after the push) still gets the full window to flip to `Review completed`; it falls back to `push_age` only when the status carries no parseable timestamp. The background `poll-cr-status.sh` anchors the same window to the first moment it *sees* the skip row — both measure placeholder age, not push age. Env-only, no `--flag` — mirrors `EARLY_CHECK_WINDOW`.

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
  "rate_limit_source": "comment|description|both|none"
}
```

## State persistence

After pre-flight runs, the SKILL.md writes `pre_flight_decision: {cr_state, codex_state, gate, codex_timeout_active, rate_limit_source}` into `$STATE_FILE`. Next iter can use this for diagnostics or to skip re-probing when a gate decision is sticky (e.g. `rate_limited`).

## Behavior when pre-flight itself fails

Any `gh api` returning a non-2xx propagates as `error` for that channel only — pre-flight emits `gate: cr_wait` and lets the legacy Step 6 polling cover the gap. The skill never aborts on pre-flight failure; it degrades to v1 behavior.

## Polling-interval coupling

When `gate == cr_wait` or `gate == codex_wait`, Step 6 / 6b take over with `INTERVAL` controlling poll frequency. The default is `8s`, inside the 5-10s pseudo-interrupt window: pre-flight already absorbs the cold-start latency that a longer interval would otherwise hide.

## Small-diff codex-only heuristic (Step 5b)

Runs once, on `ITER=1`, after the pre-flight gate so a rate-limited PR does not spend a cycle on
engagement probing. When the PR is small enough that a full CR review is not worth a quota slot and
Codex is already engaged, the run flips to `codex-only` for its remaining iterations.

```bash
# `gate=proceed` means CR already finished on this HEAD and may be holding inline findings.
# Flipping to codex-only there makes Step 8 skip the CR fetch and lose them.
if [ "$ITER" = "1" ] && [ "$CR_SOURCE" = "auto" ] && [ "$SMALL_DIFF_LOC" -gt 0 ] && [ "$gate" != "proceed" ] && [ "$gate" != "rate_limited" ] && [ "$gate" != "failure" ]; then
  codex_active=$(bash $SKILL_DIR/scripts/probe-codex-engagement.sh "$OWNER" "$REPO" "$PR_NUM")
  [ "$NO_CODEX" = "true" ] && codex_active=disabled
  # A checkout without origin/$BASE or a merge-base cannot measure the diff; an empty
  # measurement must not read as "small", or a large PR loses its CodeRabbit review.
  if [ "$codex_active" = "active" ] && git merge-base "origin/$BASE" HEAD >/dev/null 2>&1; then
    loc=$(git diff --shortstat "origin/$BASE...HEAD" 2>/dev/null | awk '{s=0; for(i=1;i<=NF;i++) if($i~/^[0-9]+$/ && ($(i+1)~/insertion/||$(i+1)~/deletion/)) s+=$i; print s+0}')
    files=$(git diff --name-only "origin/$BASE...HEAD" 2>/dev/null | wc -l)
    if [ "${loc:-0}" -lt "$SMALL_DIFF_LOC" ] && [ "${files:-0}" -lt "$SMALL_DIFF_FILES" ]; then
      echo "cr-source: auto → codex-only (small diff: ${loc} LoC / ${files} files, Codex active)"
      CR_SOURCE=codex-only
    fi
  fi
fi
```

Both thresholds must hold; `--small-diff-threshold-loc 0` disables the heuristic entirely. The
`origin/$BASE...HEAD` three-dot range is the merge-base diff GitHub itself shows — a two-dot range
would count every commit the base picked up after the fork.
