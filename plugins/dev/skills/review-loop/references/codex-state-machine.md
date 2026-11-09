# Codex State Machine

Two caches track Codex across the loop: `codex_active` (4 values, the per-iteration engagement decision) and `codex_processed_reviews` (the dedupe of Codex review ids across iterations and runs). The HEAD verdict and the Step 6 and 6b blocks follow.

## codex_active values

| Value | Meaning |
|-------|---------|
| `disabled` | `--no-codex` was passed. Step 6b / 8b / Codex-only paths all skipped for the whole run. Sticky. |
| `active` | Auto-detect found ≥1 Codex review on the PR. Step 6b polls, Step 8b fetches. Sticky once set. |
| `inactive` | Auto-detect found 0 Codex reviews. Mid-run re-probe allowed (see flip rule). |
| `unknown` | Initial value at Step 2; replaced by Step 6's first iteration probe. |

## Transition rules

- **First iter (Step 6)**: always probe `/pulls/{pr}/reviews` filtered by `chatgpt-codex-connector` (REST reports it as `chatgpt-codex-connector[bot]`, GraphQL strips the suffix). Sets `disabled` (if `--no-codex`), `active` (count > 0), or `inactive` (count == 0).
- **Subsequent iters (Step 6)**: re-probe only if cache is `inactive`. `active` and `disabled` never flip back. This catches the common case where a PR opens just before its first Codex review arrives — without the mid-run re-probe the run would skip Codex output entirely.
- **Step 6b entry**: `inactive` is probed once more after the CR poll, since Step 6 ran before it. Then the value holds for the rest of the iteration.
- **Mid-iter constancy**: `codex_active` is cached within an iteration so Step 6b grace polling and Step 8b inline-fetch both see a fixed value. Within a single iteration the resolution is fixed.
- **Probe error handling**: a failed `gh api` gives a non-sticky `inactive`, retried next iteration; the gh call is kept apart from the count so a failure never reads as 0 reviews.

## codex_processed_reviews

A JSON array of Codex review ids already surfaced on this PR, persisted in `.claude/state/review-loop-${PR_NUM}.json` and inherited from the prior run's archived state at Step 2. Step 9c.7 appends each surfaced id whatever was applied, deferred or skipped under it, so no later iteration or run judges that review again.

Discovery joins on the review `id`, never on `commit_id`: a Codex review stays pinned to the SHA it was submitted on, so a `commit_id == CUR_SHA` filter hides a finished review of an earlier push. `pull_request_review_id` is the comment-to-review join key in Step 8b.

To re-surface a processed review, delete its id from `codex_processed_reviews` in the state file by hand. Re-review needs no comment: Step 12's push triggers it on a repo with automatic Codex reviews.

## HEAD verdict (`scripts/codex-head-verdict.sh`)

Codex's result for the commit the PR points at now, from three sources:

- **Summary comment.** Codex keeps one `<!-- codex-pull-request-review-summary -->` issue comment and edits it in place: a table row per review with `**Running**` / `**Completed**` / `**Failed**`, a `<relative-time datetime>` and a backticked short SHA.
- Only the newest row for HEAD decides (by that datetime, wherever it sits; a tie takes the later row), so a re-run's Completed row overrides an earlier Failed one. The newest such comment by `updated_at` from the anchored Codex login wins, and a lookalike login is ignored.
- **HEAD review.** A Codex review with `commit_id == CUR_SHA`. Codex submits one only when it has findings, a few seconds before it flips the summary to Completed.
- **👍 reaction.** With nothing to say, Codex may leave only a `+1` reaction on the PR (`issues/{pr}/reactions`). One from the anchored Codex login created after `PUSH_TIME` is `clean` where no HEAD row and no HEAD review decide, and only while the summary's `<!-- codex-review-state:v1 {json} -->` marker has `code_review.commit_sha` equal to `CUR_SHA` and `code_review.status` `completed`.
- The marker check exists because a review of the previous commit that finishes after a new push leaves a 👍 newer than the push too. No `PUSH_TIME` or no marker gives no reaction verdict, and an unreadable reaction list is `error` only where the marker could have let a 👍 decide.

Interface: env `OWNER REPO PR_NUM CUR_SHA [PUSH_TIME] [CODEX_GRACE=30] [CODEX_PREFLIGHT_TIMEOUT=900]` (default from `scripts/codex-turnaround.sh`), one JSON line on stdout, exit 0 (exit 1 only with `verdict=error`). `reactions` says whether the PR's reactions were `read` or `unreadable`; unreadable where only a 👍 could give the verdict (no HEAD row, no HEAD review, `PUSH_TIME` known) is `verdict=error`, never "no 👍", so no wait drops Codex over a failed read.

```json
{"verdict":"findings|clean|failed|in_progress|none|unknown|error",
 "summary_state":"completed|running|failed|unparsed|absent|null",
 "summary_sha":"95ab2f6", "head_review_id":5427206208,
 "fallback":"review_id_poll|null", "wait_seconds":224}
```

| Newest summary row on HEAD | HEAD review | `verdict` |
|---|---|---|
| Running | any | `in_progress` |
| Failed | any | `failed` |
| Completed | yes | `findings` |
| Completed | no | `clean` |
| row for another SHA | yes / no | `findings` / `none` (Codex has not judged HEAD), `clean` with a 👍 after the push and the state marker on HEAD |
| unparseable or unknown status word (`summary_state=unparsed`), or no summary (`absent`) | yes / no | `findings` / `unknown`, `fallback=review_id_poll`; `clean` with a 👍 after the push and the state marker on HEAD (never with no summary) |
| gh failed | n/a | `error`, exit 1 |

Only `clean` is a pass. `unknown` is never clean: callers fall back to review-id polling. `wait_seconds` is the single Codex wait budget, `max(CODEX_GRACE, CODEX_PREFLIGHT_TIMEOUT - push_age)`, reported even on `error`; `push_age` comes from `PUSH_TIME` via jq `fromdateiso8601` (no GNU/BSD `date` split), and an absent or unparseable `PUSH_TIME` counts as age 0. Consumers: `pre-flight.sh` (`codex_verdict`, `codex_wait_seconds`), Step 6b below, `poll-codex-grace.sh` (with `CUR_SHA` and `PUSH_TIME`, ends on `clean` / `failed`).

## Review-id discovery and the grace cap (Step 6b)

```bash
# Step 6 probed before the CR poll; a PR that opened minutes ago can have its first
# Codex review by now (PR #334: inactive at 292 s, active after the poll). Probe again.
if [ "$codex_active" = "inactive" ]; then
  [ "$(bash "$SKILL_DIR/scripts/probe-codex-engagement.sh" "$OWNER" "$REPO" "$PR_NUM")" = active ] && codex_active=active
fi
if [ "$codex_active" = "active" ] && [ -z "$codex_review_id_to_process" ]; then
  PROCESSED=$(jq -c '.codex_processed_reviews // []' "$STATE_FILE")
  # jq -sr, not -s: without -r an empty result prints the two-char string '""',
  # which is non-empty -> candidate looks found -> grace polling is skipped and
  # the iter silently loses every Codex finding (fetch by review id '""' -> []).
  candidate=$(gh api --paginate "repos/$OWNER/$REPO/pulls/$PR_NUM/reviews" \
    | jq -sr --argjson p "$PROCESSED" 'add // []
        | [ .[] | select((.user.login // "") | test("^chatgpt-codex-connector(\\[bot\\])?$"; "i"))
                | select(.state=="COMMENTED" or .state=="CHANGES_REQUESTED")
                | select(.id as $i | $p | index($i) | not) ]
        | sort_by(.submitted_at) | last | .id // ""')
  if [ -n "$candidate" ] && [ "$candidate" != "null" ]; then
    codex_review_id_to_process="$candidate"
  elif [ "$CODEX_GRACE" -gt 0 ] && [ "$gate" = "codex_wait" -o "$gate" = "cr_wait" -o "$gate" = "bypass" ]; then
    # One Codex wait budget on every gate: max(CODEX_GRACE, CODEX_PREFLIGHT_TIMEOUT
    # - push_age), computed by codex-head-verdict.sh (pre-flight reports the same
    # number as codex_wait_seconds). CODEX_GRACE alone on cr_wait / bypass let
    # Step 8c mark `clean` while Codex was still reviewing HEAD. Never read $pf
    # here: the bypass path has none, and a bare `<<<"$pf"` aborts under set -u.
    hv=$(OWNER="$OWNER" REPO="$REPO" PR_NUM="$PR_NUM" CUR_SHA="$CUR_SHA" PUSH_TIME="$PUSH_TIME" \
         CODEX_GRACE="$CODEX_GRACE" bash "$SKILL_DIR/scripts/codex-head-verdict.sh" 2>/dev/null) \
      || echo "warn: Codex HEAD verdict unavailable (gh error); the wait budget still applies" >&2
    grace_cap=$(jq -r ".wait_seconds // empty" <<<"$hv"); [ -n "$grace_cap" ] || grace_cap="$CODEX_GRACE"
    # Bash(run_in_background=true) + Monitor; the poll stops itself at CAP:
    #   OWNER=... REPO=... PR_NUM=... PROCESSED=... CUR_SHA=$CUR_SHA PUSH_TIME=$PUSH_TIME INTERVAL=15 CAP=$grace_cap \
    #     bash $SKILL_DIR/scripts/poll-codex-grace.sh
    # One JSON line, or grace expiry (exit 124, no line):
    #   {codex_review_id:N, pr:N}                         -> codex_review_id_to_process=N
    #   {codex_review_id:null, pr:N, verdict:clean}  -> no review is coming; proceed with none
    #     (codex_review_id_to_process stays "").
    #   {codex_review_id:null, pr:N, verdict:failed} -> final_state=codex_failed, break
    #     (not a pass; no PR comment, no `@codex` request).
  fi
fi
```

## Auto-detect block (Step 6)

```bash
if [ "$ITER" = "1" ] && [ "$codex_active" = "unknown" ]; then
  codex_active=$(bash $SKILL_DIR/scripts/probe-codex-engagement.sh "$OWNER" "$REPO" "$PR_NUM")
  [ "$NO_CODEX" = "true" ] && codex_active=disabled
elif [ "$codex_active" = "inactive" ]; then
  new=$(bash $SKILL_DIR/scripts/probe-codex-engagement.sh "$OWNER" "$REPO" "$PR_NUM")
  [ "$new" = "active" ] && codex_active=active
fi
```
