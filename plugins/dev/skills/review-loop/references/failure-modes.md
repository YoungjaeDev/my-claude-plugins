# Failure Modes

The 15 `final_state` values with their triggers, merge eligibility and user action, then the failure cases that leave `final_state` alone. Step 16's JSON always carries `final_state`.

| `final_state` | Trigger | Auto-merge eligible? | User action |
|---------------|---------|----------------------|-------------|
| `clean` | Loop exits with `applied_this_cycle == 0`, `deferred_this_cycle == 0`, `review_this_cycle == 0` (no finding left unread), AND Step 8c engagement gate passed, AND Step 7e saw every reviewer's verdict on HEAD. | yes (`--auto-merge`, or a yes to Step 15's question), once Step 14 filed the follow-up issue when an earlier cycle deferred something | None — merge proceeds or remains manual. |
| `user_declined` | Loop exits because `applied_this_cycle == 0` but `deferred_this_cycle > 0` or `review_this_cycle > 0`. The run deferred everything in some iter, including a cycle whose every fix failed verification (`verification-failed`), or left findings it could not read. | no | Read the Step 14 follow-up issue, decide on the deferred and unread (`review`-tier) items manually, re-run, or merge as-is via GitHub UI. |
| `minor_floor` | Minor soft stop, `MINOR_STOP=true` (default; `--no-minor-stop` off). Either Step 12 held this cycle's fixes because all came from Minor-or-lower findings (`next_action=merge_then_main_push`, any iteration; Step 15 merges the reviewed HEAD, then pushes them to the base, or to the PR when unmerged), or from `ITER >= 2` the cycle pushed only low-severity fixes with nothing deferred or unread (`high_sev_this_cycle == 0`, `deferred_this_cycle == 0`, `review_this_cycle == 0`). | yes, once Step 14 filed the follow-up issue when something was left behind | Read the follow-up issue, if any, and the final JSON's `base_push`. Pass `--no-minor-stop` to keep looping instead. |
| `churn` | Churn stop. `ITER >= 2` AND every finding this cycle was `in_prev_diff` — on lines the previous iteration's own commit produced, or outside the PR diff entirely. The reviewer has exhausted the diff and is now reviewing the loop's own output. | yes, once Step 14 filed the follow-up issue when something was left behind | Read the follow-up issue. Re-running review-loop on the same PR reproduces churn; the remaining findings belong to their own change. |
| `iteration_cap` | `ITER == MAX_ITER` and threads still actionable, or the last iteration's push drew findings on the new HEAD that no round is left to judge (Step 14, `HEAD_VERDICT=unread`). | no | Step 14 files the follow-up issue when something was deferred; the final JSON's `head_verdict` says when HEAD drew unread findings. Inspect remaining threads via `target_url`, or re-run with a higher `--max-iterations`. |
| `timeout` | Step 6 CR-status poll exited 124 (TIMEOUT exceeded) without seeing `success` / `failure`, or Step 7e: a reviewer that is on gave HEAD no verdict within the wait budget and no stop was held (`HEAD_VERDICT=timeout`). | no | Re-run with larger `--timeout`, or use `--cr-source cli\|codex-only` to bypass PR-bot. |
| `failure` | CR commit-status reported `failure`, OR Step 8 GraphQL fetch errored, OR Step 8b Codex comment fetch errored, OR `gh api` returned `errors` payload, OR Step 10's commit failed (a hook refused it; the fixes stay staged, nothing is pushed). | no | Inspect CR dashboard via `target_url` for the failure case; check `gh auth status` and network for the fetch case; for a refused commit, read the hook output and commit by hand. |
| `cr_inactive` | Step 8c engagement gate: `ITER == MAX_ITER` AND `cr_engagement == 0` (CR posted nothing on this push). | no | CR is unreachable, paused, or rate-limited. Use `--cr-source cli\|codex-only` to bypass. |
| `rate_limited` | Step 7c detected a CR rate-limit or a permanent skip AND `--cr-source pr-bot` (user blocked auto-flip). | no | Wait for the CR reset window, or re-run with `--cr-source cli` / `--cr-source codex-only`. When the sniff reported `permanent: true` (`Review skipped: N files exceed the limit`) waiting never helps — the PR is too large for the PR-bot and only the CLI or Codex can review it. |
| `cli_failed` | Step 7d `coderabbit review --agent` exited non-zero OR emitted `type: "error"` event OR exited without emitting `type: "complete"` OR its `complete` event reports `outcome: "failed"` or `unreviewedFileCount > 0` (a partial review, even with findings emitted; spawn marker `incomplete: true`). | no | Inspect the CLI log at the path in the spawn marker's `jsonl` field (random `mktemp` suffix, no extension — glob `/tmp/cr-cli-review-${PR_NUM}-iter${ITER}-*`) for error detail. There is no fallback to the PR bot. |
| `reviewers_unavailable` | Step 2b found a "will not review" comment for every reviewer this run uses (Codex usage limit, CodeRabbit "Auto reviews are disabled"), or dropped CodeRabbit and Codex was not engaged. Stops before any wait. | no | Read the comment URLs in the report. Re-run with `--cr-source cli` for a local CodeRabbit review, or ask for one with `@coderabbitai review`, or wait for the Codex quota. |
| `codex_failed` | Codex's summary comment reports Failed for HEAD (`codex_verdict=failed` from pre-flight, or `verdict: failed` from the Step 6b grace poll). No Codex review of HEAD is coming. The loop stops without writing to the PR: no `@codex review`, no comment of any kind. | no | Read the Codex summary comment on the PR. Push a new commit for Codex to review, or ask Codex for a review yourself, then re-run. |
| `ci_failing` | The run would end at `clean`, `minor_floor` or `churn`, but a CI check on HEAD failed (Step 14, `scripts/ci-checks.sh`: checks sorted by gh's `bucket` field, CodeRabbit and Codex checks left out, pending checks waited on under `TIMEOUT`, a failed lookup keeps the state), or the Step 15 gate's one look found one failing that Step 14 had not. The failing names go to `ci_failing_checks` in the final JSON and the final report. A failing check alone files no follow-up issue; deferred findings still do. | no | Fix the checks named in `ci_failing_checks`, push, and re-run. |
| `merged_externally` | Someone else merged or closed the PR while the loop ran, seen at the top of an iteration, right before Step 12's push, or by the Step 15 gate. Nothing is pushed to the PR. Fixes held for the base still reach an unprotected base through `scripts/base-push.sh` after a merge; every other unpushed fix stays on the local commit the run names, and deferred findings still get the follow-up issue. | no | Push the named local commit to the base yourself or open a new PR for it, and read the follow-up issue, if any. |
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
| `git push` rejected (non-fast-forward) | Surface error, set `final_state=failure`, exit loop (Step 12). No review request is posted for the unpushed head, and `failure` never auto-merges. User resolves locally. |
| `gh pr merge --auto` fails (merge conflicts, missing required reviews after enroll) | Capture stderr, print, exit non-zero — loop already completed with `final_state=clean`. `merged=false` in JSON. |
| Step 15 branch-protection probe gh api error | `protection_http: 0` — never merge on an unverified protection state; surface and leave the PR open. |
| Step 14 `gh issue create` fails | `followup_issue` stays absent, so `auto-merge-gate.sh` reports `eligible: false` and `minor_floor` / `churn` do not merge. Surface the error; the deferred findings are still in the archived `auto_judge_log`. |
| Fixes held for the base (`merge_then_main_push`), PR not merged (ineligible, declined, no interaction tool, or `gh pr merge` failed) | Step 15 pushes them to the PR instead and says the new HEAD is unreviewed; re-run review-loop to judge it. |
| Fixes held for the base, `scripts/base-push.sh` refuses (no build/test command, fixes do not apply on the merged base, build/test or a pre-commit guard fails, push rejected) | Nothing reaches the base. The PR is already merged; the fixes stay on the local commit Step 15 names, for a new PR. `base_push` stays `null`. |

## Build / verification failure (Steps 3, 9c.6, 14)

These leave `final_state` alone. A fix that fails build/test is reverted and deferred with reason `verification-failed`, so only passing fixes are committed, and a cycle whose every fix failed pushes nothing and ends at `user_declined`, which files the follow-up issue.

A baseline that already fails at Step 3 turns the gate off (`verification_gate=baseline_failed`). With a fast line, a failed loop-end full line keeps `final_state`, sets `full_verification=fail`, and makes `auto-merge-gate.sh` refuse the merge (`ineligible_reason` names it), so held fixes go to the PR, not the base.

`verification_blocking=true` comes from a merge-conflict resolution that breaks the checks (`references/merge-conflicts.md`), and it disables auto-merge for the run.

The HEAD verdict wait outcomes (held stops, stuck and dropped reviewers) are in `references/coordination.md` ("HEAD verdict wait").

## Follow-up issue block (Step 14)

A state that files one, with findings left behind, sets `followup_needed=true` (`scripts/auto-merge-gate.sh`'s `file_issue`). Left behind means deferred in any cycle, even when a later cycle is clean, or `review`-tier findings nobody could read; skipped-minor findings never reach `auto_judge_log` and do not count.

Nothing left behind files nothing, so no issue says "0 deferred": a HEAD without every verdict and failing CI checks go to the final report. A filed body says why HEAD is unverified and names the failing CI checks on `ci_failing`, and `followup_issue`, inherited at Step 2, makes a re-run append instead of opening a second issue.

More defers in this run than `SUB_ISSUE_THRESHOLD` (5, `scripts/file-sub-issues.sh`) add one sub-issue per finding under that issue, keyed so a re-run files none twice. A failed sub-issues call puts the rest into the issue body as a task list (`followup_issue.split=task_list`); an unreadable issue body edits nothing (`split=failed`).

Fires when the Step 14 block sets `followup_needed=true`:

```bash
# Idempotent: a re-run on the same PR reuses the issue instead of opening a second one;
# this run's new defers are appended to it as a comment so they are not lost in the archive.
existing=$(jq -r '.followup_issue.number // empty' "$STATE_FILE")
# Why the last HEAD is unverified, for the new issue and an appended comment alike.
head_note() {
  case "$HEAD_VERDICT" in
    timeout) printf '%s\n\n' "HEAD \`$(git rev-parse HEAD)\` got no verdict from every reviewer within the wait budget; auto-merge stays off." ;;
    unread)  printf '%s\n\n' "HEAD \`$(git rev-parse HEAD)\` drew reviewer findings after the last round; read them on the PR." ;;
  esac
}
# The CI checks that kept a converged HEAD from ending clean (Step 14, ci_failing).
ci_note() {
  [ "$final_state" = ci_failing ] || return 0
  printf '%s\n\n' "CI checks failing on HEAD \`$(git rev-parse HEAD)\`: $(jq -r 'join(", ")' <<<"${ci_failing_checks:-[]}")"
}
if [ -n "$existing" ]; then
  BODY=$(mktemp)
  {
    printf '%s\n\n' "Additional findings deferred by a later review-loop run (\`final_state=$final_state\`):"
    head_note
    ci_note
    [ "$review_total" -gt 0 ] && printf '%s\n\n' "$review_total finding(s) had no readable severity badge (\`review\` tier) and were not judged; read them on the PR."
    printf '| Reviewer | Severity | Location | Why deferred |\n|---|---|---|---|\n'
    jq -r '.auto_judge_log[]? | select(.action == "defer")
           | "| \(.src) | \(.badge_or_sev) | \(.path):\(.line // "-") | \(.reason) |"' "$STATE_FILE"
  } > "$BODY"
  # The flag is set on failure and cleared on success: it is inherited with the issue
  # object, so a transient failure must not block every later run's merge.
  if gh issue comment "$existing" --body-file "$BODY" >/dev/null; then
    tmp=$(mktemp); jq '.followup_issue.append_failed = false' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
  else
    tmp=$(mktemp); jq '.followup_issue.append_failed = true' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
    echo "review-loop: could not append to issue #$existing — auto-merge stays blocked" >&2
  fi
  rm -f "$BODY"
else
  # Reviewer prose reaches the body through a file, never through the command line.
  BODY=$(mktemp)
  {
    printf '%s\n\n' "review-loop stopped at \`final_state=$final_state\` on PR #$PR_NUM. Findings below were deferred or left unapplied."
    head_note
    ci_note
    [ "$review_total" -gt 0 ] && printf '%s\n\n' "$review_total finding(s) had no readable severity badge (\`review\` tier) and were not judged; read them on the PR."
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
    echo "review-loop: follow-up issue creation failed — auto-merge stays blocked" >&2
  fi
fi
# More defers than file-sub-issues.sh's threshold: one sub-issue each under the issue,
# or a task list in its body when the sub-issues API fails. The issue's table stays
# the record either way, so a failed split is reported, not a merge blocker.
parent=$(jq -r '.followup_issue.number // empty' "$STATE_FILE")
if [ -n "$parent" ]; then
  split=$(STATE_FILE="$STATE_FILE" bash "$SKILL_DIR/scripts/file-sub-issues.sh" "$OWNER" "$REPO" "$parent" "$PR_NUM")
  jq -e '.split and .sub_issues' <<<"$split" >/dev/null 2>&1 || split='{"split":"failed","sub_issues":[]}'
  if [ "$(jq -r '.split' <<<"$split")" != none ]; then
    tmp=$(mktemp); jq --argjson s "$split" '.followup_issue.split = $s.split
      | .followup_issue.sub_issues = ((.followup_issue.sub_issues // []) + $s.sub_issues | unique)' \
      "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
  fi
fi
```
