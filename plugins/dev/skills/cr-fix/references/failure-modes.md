# Failure Modes

Exhaustive table of `final_state` values and their triggers. Step 16's emitted JSON always carries `final_state`.

| `final_state` | Trigger | Auto-merge eligible? | User action |
|---------------|---------|----------------------|-------------|
| `clean` | Loop exits with `applied_this_cycle == 0` and `deferred_this_cycle == 0` AND Step 8c engagement gate passed. | yes (if `--auto-merge`) | None — merge proceeds or remains manual. |
| `user_declined` | Loop exits because `applied_this_cycle == 0` but `deferred_this_cycle > 0`. User deferred everything in some iter. | no | Decide on the deferred items manually, re-run, or merge as-is via GitHub UI. |
| `minor_floor` | Minor soft-stop. `MINOR_STOP=true` (default; `--no-minor-stop` off) AND `ITER >= 2` AND this cycle applied only low-severity fixes (`high_sev_this_cycle == 0`) with nothing deferred (`deferred_this_cycle == 0`). Stops the low-value minor tail instead of looping to the `applied==0 && deferred==0` floor. | yes, once Step 14 filed the follow-up issue | Read the follow-up issue for what was left behind. Pass `--no-minor-stop` to keep looping instead. |
| `churn` | Churn stop. `ITER >= 2` AND every finding this cycle was `in_prev_diff` — on lines the previous iteration's own commit produced, or outside the PR diff entirely. The reviewer has exhausted the diff and is now reviewing the loop's own output. | yes, once Step 14 filed the follow-up issue | Read the follow-up issue. Re-running cr-fix on the same PR reproduces churn; the remaining findings belong to their own change. |
| `iteration_cap` | `ITER == MAX_ITER` and threads still actionable. | no | Step 14 still files the follow-up issue; inspect remaining threads via `target_url`, or re-run with a higher `--max-iterations`. |
| `timeout` | Step 6 CR-status poll exited 124 (TIMEOUT exceeded) without seeing `success` / `failure`. | no | Re-run with larger `--timeout`, or use `--cr-source cli\|codex-only` to bypass PR-bot. |
| `failure` | CR commit-status reported `failure`, OR Step 8 GraphQL fetch errored, OR `gh api` returned `errors` payload. | no | Inspect CR dashboard via `target_url` for the failure case; check `gh auth status` and network for the fetch case. |
| `cr_inactive` | Step 8c engagement gate: `ITER == MAX_ITER` AND `cr_engagement == 0` (CR posted nothing on this push). | no | CR is unreachable, paused, or rate-limited. Use `--cr-source cli\|codex-only` to bypass. |
| `rate_limited` | Step 7c detected a CR rate-limit or a permanent skip AND `--cr-source pr-bot` (user blocked auto-flip). | no | Wait for the CR reset window, or re-run with `--cr-source cli` / `--cr-source codex-only`. When the sniff reported `permanent: true` (`Review skipped: N files exceed the limit`) waiting never helps — the PR is too large for the PR-bot and only the CLI or Codex can review it. |
| `cli_failed` | Step 7d `coderabbit review --agent` exited non-zero OR emitted `type: "error"` event OR exited without emitting `type: "complete"`. | no | Inspect the CLI log at the path in the spawn marker's `jsonl` field (random `mktemp` suffix, no extension — glob `/tmp/cr-cli-review-${PR_NUM}-iter${ITER}-*`) for error detail. No auto-fallback to PR-bot in V1. |
| `unknown` | Trap fired before any flow path set `final_state` (rare — e.g. SIGKILL, runtime error before Step 6). | no | Inspect archived state file in `.claude/state/archive/`. |

## Codex-specific failure cases (do NOT change final_state)

| Case | Behavior |
|------|----------|
| `codex_active=active` but `codex_records=[]` for the discovered review | Step 9c.7 still persists the review id (it was surfaced); Step 9 mixing is a no-op for this iter. |
| Codex engagement probe gh api error | `codex_active=inactive` non-sticky; re-probed next iter. Warning emitted to stderr. |
| Codex grace timeout (`CODEX_GRACE` seconds elapsed without new review id) | `codex_review_id_to_process=""`, Step 8b returns `[]`, proceed normally. |

## Push / merge failure cases

| Case | Behavior |
|------|----------|
| `git push` rejected (non-fast-forward) | Surface error, exit loop. `final_state` reflects the most recent loop state; trap still emits JSON with that value. User resolves locally. |
| `gh pr merge --auto` fails (merge conflicts, missing required reviews after enroll) | Capture stderr, print, exit non-zero — loop already completed with `final_state=clean`. `merged=false` in JSON. |
| Step 15 branch-protection probe gh api error | `protection_http: 0` — never merge on an unverified protection state; surface and leave the PR open. |
| Step 14 `gh issue create` fails | `followup_issue` stays absent, so `auto-merge-gate.sh` reports `eligible: false` and `minor_floor` / `churn` do not merge. Surface the error; the deferred findings are still in the archived `auto_judge_log`. |

## Build / verification failure (Step 11)

Does NOT change `final_state` directly. Sets `verification_blocking=true` which disables auto-merge for the run. The push still happens so CR re-review sees the new code. The user can intervene before merge.

## Follow-up issue block (Step 14)

Fires when `final_state ∈ {churn, minor_floor, iteration_cap}` and `deferred_total > 0`. Skipped-minor findings never reach `auto_judge_log`, so they cannot populate the body and do not trigger the issue. `followup_issue` is inherited from the prior state at Step 2, which is what makes the re-run idempotent.

```bash
# Idempotent: a re-run on the same PR reuses the issue instead of opening a second one;
# this run's new defers are appended to it as a comment so they are not lost in the archive.
existing=$(jq -r '.followup_issue.number // empty' "$STATE_FILE")
if [ -n "$existing" ]; then
  BODY=$(mktemp)
  {
    printf '%s\n\n' "Additional findings deferred by a later cr-fix run (\`final_state=$final_state\`):"
    printf '| Reviewer | Severity | Location | Why deferred |\n|---|---|---|---|\n'
    jq -r '.auto_judge_log[]? | select(.action == "defer")
           | "| \(.src) | \(.badge_or_sev) | \(.path):\(.line // "-") | \(.reason) |"' "$STATE_FILE"
  } > "$BODY"
  gh issue comment "$existing" --body-file "$BODY" >/dev/null || echo "cr-fix: could not append to issue #$existing" >&2
  rm -f "$BODY"
else
  # Reviewer prose reaches the body through a file, never through the command line.
  BODY=$(mktemp)
  {
    printf '%s\n\n' "cr-fix stopped at \`final_state=$final_state\` on PR #$PR_NUM. Findings below were deferred or left unapplied."
    printf '| Reviewer | Severity | Location | Why deferred |\n|---|---|---|---|\n'
    jq -r '.auto_judge_log[]? | select(.action == "defer")
           | "| \(.src) | \(.badge_or_sev) | \(.path):\(.line // "-") | \(.reason) |"' "$STATE_FILE"
  } > "$BODY"

  gh label create tbd --force >/dev/null 2>&1 || true
  issue_url=$(gh issue create \
    --title "Review follow-up: PR #$PR_NUM ($deferred_total deferred)" \
    --body-file "$BODY" --label tbd) || issue_url=""
  rm -f "$BODY"
  # gh prints the issue URL; anything else means the create did not succeed, and
  # a non-numeric tail would abort the jq --argjson below instead of reporting it.
  issue_num=$(basename "${issue_url:-}")
  case "$issue_num" in ''|*[!0-9]*) issue_num="" ;; esac

  if [ -n "$issue_num" ]; then
    tmp=$(mktemp); jq --argjson n "$issue_num" --arg u "$issue_url" \
      '.followup_issue = {number:$n, url:$u}' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
  else
    echo "cr-fix: follow-up issue creation failed — auto-merge stays blocked" >&2
  fi
fi
```
