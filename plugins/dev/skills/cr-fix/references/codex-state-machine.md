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

A JSON array of Codex review ids (numbers) that have been **surfaced to the user** in some prior iter / run on this PR. Persisted in `.claude/state/cr-fix-${PR_NUM}.json`. Inherited from the prior session's archived state at Step 2.

### What "processed" means

The semantic is "this review has been surfaced to the user this iter", NOT "we wrote code for it". Step 9c.7 appends the id regardless of whether the user applied, deferred, or skipped each item under that review. Without this, the next iter / next cr-fix run would re-discover the same review via Step 6b and re-prompt for items the user already decided on.

### Why filter by review id, not by commit_id

Codex review wrapper `commit_id` does NOT forward-shift on subsequent pushes. A review submitted on SHA `A` stays pinned to `A` forever, even after the user pushes SHA `B`. A `select(.commit_id == $sha)` filter has a structural blind spot: when Step 6b probes with `$CUR_SHA == B`, an already-finished Codex review on `A` is invisible and the grace poller spins until timeout.

Step 6b discovers Codex work via review `id` instead — robust to SHA progression — and uses `codex_processed_reviews` for dedupe. `pull_request_review_id` is the stable comment→review join key used in Step 8b regardless of GitHub's `commit_id` propagation rules.

### Manual override

If the user wants to re-surface an already-processed review, they can delete the relevant id from `codex_processed_reviews` in the state file by hand. The next iter will re-discover it as unprocessed.

## Re-review triggers

Codex states its own triggers as PR open, draft marked ready, and a `@codex review` comment. Repositories that enable automatic reviews also get one on every push, which is what the loop relies on: Step 12's push is the re-review trigger, and the skill never posts a trigger comment of its own.

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
    # Cap the poll at the larger of CODEX_GRACE and the pre-flight remainder:
    # gate=codex_wait promised Codex is not assumed clean before
    # push_age >= CODEX_PREFLIGHT_TIMEOUT, and the knob alone lets Step 8c mark
    # `clean` mid-review. $pf exists only on the auto|pr-bot path, so read it
    # under gate=codex_wait alone — a bare `<<<"$pf"` aborts bypass under
    # `set -u`, and `${pf:-{}}` mis-expands to `<value>}` when it IS set.
    if [ "$gate" = "codex_wait" ]; then
      pf_timeout=${CODEX_PREFLIGHT_TIMEOUT:-600}
      push_age=$(jq -r '.push_age_seconds // 0' <<<"$pf")
      pf_remaining=$(( pf_timeout - push_age ))
      [ "$pf_remaining" -lt 0 ] && pf_remaining=0
      [ "$pf_remaining" -gt "$CODEX_GRACE" ] && grace_cap="$pf_remaining" || grace_cap="$CODEX_GRACE"
    else
      grace_cap="$CODEX_GRACE"
    fi
    # Bash(run_in_background=true, timeout=grace_cap*1000):
    #   OWNER=... REPO=... PR_NUM=... PROCESSED=... INTERVAL=15 \
    #     bash $SKILL_DIR/scripts/poll-codex-grace.sh
    # Monitor returns one JSON line: {codex_review_id:N, pr:N} or grace timeout (no line).
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
