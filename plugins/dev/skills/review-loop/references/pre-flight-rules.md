# Pre-flight Review Detection (Step 5)

`scripts/pre-flight.sh` runs at the top of every iteration, before any wait, and decides in one round of 6 reads whether to proceed, wait for CodeRabbit, wait for Codex, fall back on a rate limit, or stop. The gate drives Steps 6, 6b and 7.

The two reviewers report on different channels at different times. Codex usually lands minutes before CodeRabbit, so a Codex review never means CodeRabbit is done, and CodeRabbit reports on a commit status or a check-run depending on how its app is installed (`scripts/cr-commit-state.sh` reads both).

One PR collects several Codex reviews across iterations, so pre-flight looks for the latest unprocessed review id, not any review. It orders by `submitted_at` / `created_at`, never by the PR timeline.

## Six-source fetch (parallel-safe)

| # | Channel | Endpoint | Purpose |
|---|---------|----------|---------|
| 1 | CR reported state | `scripts/cr-commit-state.sh` -> `commits/$SHA/statuses` (plural, `--paginate`), else `commits/$SHA/check-runs` | `state` + `description` of the latest `CodeRabbit` row on whichever surface reports |
| 2 | CR issue-comments | `repos/$O/$R/issues/$PR/comments` (`--paginate`) | `coderabbitai[bot]` bodies created OR updated after `PUSH_TIME` — catches in-place rate-limit edits |
| 3 | Codex reviews | `repos/$O/$R/pulls/$PR/reviews` (`--paginate`) | `chatgpt-codex-connector*` reviews, `COMMENTED`/`CHANGES_REQUESTED`, sorted by `submitted_at`, filtered by `codex_processed_reviews` |
| 4 | Codex emoji A | `repos/$O/$R/issues/$PR/reactions` | PR-level reactions left by `chatgpt-codex-connector*` (in_progress / clean / findings) |
| 5 | Codex emoji B | `repos/$O/$R/commits/$SHA/check-runs` | Check-runs named like Codex — wait signal only (in_progress / findings), never clean |
| 6 | Codex HEAD verdict | `scripts/codex-head-verdict.sh` -> `issues/$PR/comments` + `pulls/$PR/reviews` (`--paginate`) | Summary comment Running/Completed/Failed + SHA, and the `commit_id == HEAD` review; authoritative over channels 4/5 |

Channels 4 and 5 are best-effort hints, since the API has no reliable surface for the Codex marker. `scripts/probe-codex-state.sh` also tries review-level reactions (`pulls/$PR/reviews/$rid/reactions`, often 404) when both are `unknown` (`codex-parsing-rules.md`), and with no signal at all the timeout logic applies (`push_age` against `codex_timeout_seconds`, default `900`, `scripts/codex-turnaround.sh`).

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
| a surface that fails to fetch, or returns a page that does not parse | `error` (with that `channel`), never `none` |
| `success` whose description / title is a rate-limit marker (`Review rate limited`, `Review limit reached`, `rate limited`, refill phrasing) | `rate_limited` |

The last row applies on both surfaces: on a rate-limited push CodeRabbit posts a passing `Review rate limited` check so it never blocks a protected branch (docs.coderabbit.ai `management/rate-limits`), and no review ran. A success status is still not CodeRabbit's verdict, which is the review attached to HEAD (`scripts/cr-head-verdict.sh`).

- `cr_state ∈ {success, failure, pending, rate_limited, "", error}` (`""` → no status row yet).
- `cr_desc` carries the free-tier-disabled and `Review limit reached` text in newer CodeRabbit versions.
- **Transient skip**: `Review skipped: free tier disabled` is not terminal. CodeRabbit briefly posts `success` + this description (an hourly fair-usage quota refill, observed ~5 min) before replacing it with `Review completed`. It is held non-terminal for `CR_SKIP_GRACE` seconds (default `300`) and only routed to `rate_limited` past that window — distinct from genuine `Review limit reached` / `rate limited`, which route immediately.

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

## Codex HEAD verdict

Pre-flight runs `scripts/codex-head-verdict.sh` (contract: `references/codex-state-machine.md` "HEAD verdict") and copies `verdict` to `codex_verdict` and `wait_seconds` to `codex_wait_seconds`. When no unprocessed review id makes Codex actionable, the verdict decides `codex_state` ahead of the emoji and timeout rows below:

| `codex_verdict` | `codex_state` |
|---|---|
| `clean`, or `findings` whose review is already processed | `clean` |
| `failed` | `unknown` (not a pass; the Step 5 block stops at `final_state=codex_failed` on `codex_verdict=failed`) |
| `in_progress`, `none`, `error`, or `unknown` with `summary_state=unparsed` | `arriving`, whatever `push_age` is |
| `unknown` with `summary_state=absent` (no summary comment) | the emoji / timeout / engagement rows below |

So a summary that says Codex is still Running on HEAD, or has not reached HEAD, holds `codex_wait` past `CODEX_PREFLIGHT_TIMEOUT`; Step 6b bounds the wait by `codex_wait_seconds`, which every gate reports with the same formula.

## Codex emoji read (best-effort, multi-channel)

Consulted only when Codex posts no summary comment. See `references/codex-parsing-rules.md` for full channel logic. The pre-flight aggregates whatever signal the helper script `scripts/probe-codex-state.sh` emits:

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
| `rate_limited` (success + `Review rate limited` / `Review limit reached` / `rate limited`) | n/a | n/a | n/a | n/a | n/a | `rate_limited` |
| `success` | none | yes (`comment` channel) | n/a | n/a | n/a | `proceed` — comment sniff is not authoritative over a terminal commit-status; the `description`/`both` channels still route to `rate_limited` |
| `pending` / `in_progress` / `""` | n/a | n/a | n/a | n/a | n/a | `cr_wait` |
| `failure` | n/a | n/a | n/a | n/a | n/a | `failure` |
| `error` | n/a | n/a | n/a | n/a | n/a | `cr_wait` (treat as transient, retry-by-polling) |

The emoji and timeout rows apply only when the Codex HEAD verdict is `unknown` with no summary comment (see "Codex HEAD verdict" above). `codex_timeout_seconds` defaults to `900` (`CODEX_BUDGET_DEFAULT`, `scripts/codex-turnaround.sh`). Override per-run via env var `CODEX_PREFLIGHT_TIMEOUT` if a CI pattern shows Codex routinely lands later.

`CR_SKIP_GRACE` (default `300` seconds, env only, no flag) bounds how long a transient `success` + `Review skipped: free tier disabled` row is held as `cr_wait` before it reads as a genuine disable (`rate_limited`).

Its clock (`cr_skip_age`) counts from the status row's own `created_at`, so a row queued late still gets the whole window, and falls back to `push_age` only when the row has no parseable timestamp. `poll-cr-status.sh` uses the same anchor, falling back to the first moment it sees the row, so a foreground re-run with the remaining cap does not restart the grace.

## Output JSON contract

`scripts/pre-flight.sh` emits one terminal JSON line on stdout:

```json
{
  "cr_state": "success|failure|pending|rate_limited|error|none",
  "cr_actionable": true,
  "cr_desc": "Review skipped: ...",
  "codex_state": "actionable|clean|arriving|unknown",
  "codex_actionable": true,
  "codex_latest_id": 123456789,
  "codex_emoji_state": "findings|clean|in_progress|unknown",
  "gate": "proceed|cr_wait|codex_wait|rate_limited|failure",
  "codex_timeout_active": true,
  "push_age_seconds": 42,
  "rate_limit_source": "comment|description|both|none",
  "codex_verdict": "findings|clean|failed|in_progress|none|unknown|error|disabled",
  "codex_wait_seconds": 224
}
```

## State, failure and polling

- **State**: after pre-flight, `pre_flight_decision: {cr_state, codex_state, gate, codex_timeout_active, rate_limit_source}` goes into `$STATE_FILE`, for diagnostics and for a sticky gate such as `rate_limited`.
- **Failure**: a `gh api` call that fails or returns a page that does not parse is `error` for that channel only. Pre-flight then emits `gate: cr_wait`, Step 6 polling covers the gap, and the run never aborts on it.
- **Polling**: on `cr_wait` or `codex_wait`, Steps 6 and 6b poll with `INTERVAL` as the base interval (default 30, `scripts/parse-args.sh`), and `scripts/next-check.sh` adapts each look around it.

## Small-diff codex-only heuristic (Step 5b)

Runs once, on `ITER=1`, after the pre-flight gate, so a rate-limited PR spends no cycle on engagement probing. A PR too small to be worth a CodeRabbit quota slot, with Codex already engaged, flips to `codex-only` for the rest of the run.

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

Both thresholds must hold, and `--small-diff-threshold-loc 0` disables the heuristic. The three-dot `origin/$BASE...HEAD` range is the merge-base diff GitHub shows; a two-dot range would count every commit the base gained after the fork.
