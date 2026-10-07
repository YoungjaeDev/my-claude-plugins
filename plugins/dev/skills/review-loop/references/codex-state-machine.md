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

- **First iter (Step 6)**: always probe `/pulls/{pr}/reviews` filtered by `chatgpt-codex-connector` (REST reports it as `chatgpt-codex-connector[bot]`, GraphQL strips the suffix). Sets `disabled` (if `--no-codex`), `active` (count > 0), or `inactive` (count == 0).
- **Subsequent iters (Step 6)**: re-probe only if cache is `inactive`. `active` and `disabled` never flip back. This catches the common case where a PR opens just before its first Codex review arrives — without the mid-run re-probe the run would skip Codex output entirely.
- **Mid-iter constancy**: `codex_active` is cached within an iteration so Step 6b grace polling and Step 8b inline-fetch both see a fixed value. Within a single iteration the resolution is fixed.
- **Probe error handling**: if `gh api` fails, the `inactive` decision is non-sticky (treats failure as "unknown, retry next iter"). The earlier bug pattern was `gh api ... | wc -l` returning 0 on failure, silently locking `codex_active` to `inactive` — fixed by separating the gh call from the count.

## codex_processed_reviews

A JSON array of Codex review ids (numbers) that have been **surfaced to the user** in some prior iter / run on this PR. Persisted in `.claude/state/review-loop-${PR_NUM}.json`. Inherited from the prior session's archived state at Step 2.

### What "processed" means

The semantic is "this review has been surfaced to the user this iter", NOT "we wrote code for it". Step 9c.7 appends the id regardless of whether the user applied, deferred, or skipped each item under that review. Without this, the next iter / next review-loop run would re-discover the same review via Step 6b and re-prompt for items the user already decided on.

### Why filter by review id, not by commit_id

Codex review wrapper `commit_id` does NOT forward-shift on subsequent pushes. A review submitted on SHA `A` stays pinned to `A` forever, even after the user pushes SHA `B`. A `select(.commit_id == $sha)` filter has a structural blind spot: when Step 6b probes with `$CUR_SHA == B`, an already-finished Codex review on `A` is invisible and the grace poller spins until timeout.

Step 6b discovers Codex work via review `id` instead — robust to SHA progression — and uses `codex_processed_reviews` for dedupe. `pull_request_review_id` is the stable comment→review join key used in Step 8b regardless of GitHub's `commit_id` propagation rules.

### Manual override

If the user wants to re-surface an already-processed review, they can delete the relevant id from `codex_processed_reviews` in the state file by hand. The next iter will re-discover it as unprocessed.

## Re-review triggers

Codex states its own triggers as PR open, draft marked ready, and a `@codex review` comment. Repositories that enable automatic reviews also get one on every push, which is what the loop relies on: Step 12's push is the re-review trigger, and the skill never posts a trigger comment of its own.

## HEAD verdict (`scripts/codex-head-verdict.sh`)

Codex's result for the commit the PR points at now (`GLOSSARY.md` "HEAD 판정", ADR 0002). Two sources:

- **Summary comment.** Codex keeps one `<!-- codex-pull-request-review-summary -->` issue comment and edits it in place: a table row per review with `**Running**` / `**Completed**` / `**Failed**`, a `<relative-time datetime>` and a backticked short SHA. Only the newest row for HEAD (by that datetime, wherever it sits in the table; a tie takes the later row) decides, so a re-run's Completed row overrides an earlier Failed one. The newest such comment by `updated_at` from the anchored Codex login wins; a lookalike login is ignored.
- **HEAD review.** A Codex review with `commit_id == CUR_SHA`. Codex submits one only when it has findings, a few seconds before it flips the summary to Completed.

Interface: env `OWNER REPO PR_NUM CUR_SHA [PUSH_TIME] [CODEX_GRACE=30] [CODEX_PREFLIGHT_TIMEOUT=600]`, one JSON line on stdout, exit 0 (exit 1 only with `verdict=error`).

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
| row for another SHA | yes / no | `findings` / `none` (Codex has not judged HEAD) |
| unparseable or unknown status word (`summary_state=unparsed`), or no summary (`absent`) | yes / no | `findings` / `unknown`, `fallback=review_id_poll` |
| gh failed | n/a | `error`, exit 1 |

Only `clean` is a pass. `unknown` is never clean: callers fall back to review-id polling. `wait_seconds` is the single Codex wait budget, `max(CODEX_GRACE, CODEX_PREFLIGHT_TIMEOUT - push_age)`, reported even on `error`; `push_age` comes from `PUSH_TIME` via jq `fromdateiso8601` (no GNU/BSD `date` split), and an absent or unparseable `PUSH_TIME` counts as age 0. Consumers: `pre-flight.sh` (`codex_verdict`, `codex_wait_seconds`), Step 6b below, `poll-codex-grace.sh` (with `CUR_SHA`, ends on `clean` / `failed`).

## Review-id discovery and the grace cap (Step 6b)

```bash
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
    # Bash(run_in_background=true, timeout=grace_cap*1000):
    #   OWNER=... REPO=... PR_NUM=... PROCESSED=... CUR_SHA=$CUR_SHA INTERVAL=15 \
    #     bash $SKILL_DIR/scripts/poll-codex-grace.sh
    # Monitor returns one JSON line, or grace timeout (no line):
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
