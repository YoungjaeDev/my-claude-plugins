# CodeRabbit and Codex coordination

How review-loop runs two automatic PR reviewers, CodeRabbit and ChatGPT-Codex, side by side: which findings it reads, how it judges them, when it waits, stops, files a follow-up issue and merges. It has 15 `final_state` values (triggers in `failure-modes.md`) and 2 interactive gates. The step-by-step rules are in `procedure.md`.

## Reviewers and sources

- **Sources**: `--cr-source auto` (default) reads the CodeRabbit PR bot and, when the bot is rate-limited, falls back silently to the local `coderabbit` CLI or to Codex-only (`rate-limit-fallback.md`).
- **CodeRabbit headers** come in two formats: the older `<category> | <severity> | <effort>`, read by emoji badge since its bold, italic or plain emphasis changes between PRs, and since 2026-10 `<severity> · <category> · <effort>` with `<img>` icons. The newer one counts as a header only when its first field, with tags stripped, is a known severity word; icon file names are never read.
- `scripts/cr-header.jq` emits both formats as the same fields. The category names the defect domain, not the impact, so the tier is decided by severity first.
- **Outside-diff findings**, which live only in a review body's "Outside diff range comments" block, are collected as the same records and judged the same way.
- **Codex** surfaces mostly P1 and P2 on GitHub; the parser reads P0 to P3.

## Tiers and judgment

- **Tiers** (`tier-classification.md` holds the table): the Security & Privacy category is gated whatever its severity. Critical and Major are gated, Minor with Heavy lift is gated, and Minor with Quick win (or no effort field) is auto-applied.
- Trivial, Info and the summary-only Nitpick are skipped. Codex P0, P1 and P2 are gated in every round, so a P2 from the second round on is judged like any other finding.
- A CodeRabbit finding whose header cannot be read, or a Codex finding with no badge, is `review`: shown, and never counted as `clean`.
- **Judgment**: every finding, whatever its tier, is judged against the local code without asking the user, as apply, defer or skip, with the reason in `auto_judge_log` (`autonomous-judgment.md`).
- Defer is only for a severe finding (Critical, Major, Security, Codex P0 or P1) whose fix is large or unclear, and it goes to the follow-up issue. Everything else is applied or skipped with its reason inside the session, including a fix that needs a new flag or entry point.

## HEAD verdict wait

No round fetches the next findings, pushes, ends or merges before every reviewer that is on has given the current HEAD a verdict (findings or clean). A progress mark, a rate-limit notice and a paused automatic review are not verdicts, and CodeRabbit drops a review in progress when a new push lands.

There are two exceptions. A cycle whose fixes all came from Minor-or-lower findings does not push them to the PR: it merges the judged HEAD and pushes them to the base ("Who reviews the fixes"). A reviewer still without a verdict past its own budget is stuck and dropped (the table below).

A stop reached right after a push (`minor_floor`, `churn`, `iteration_cap`) is held, not ended, and waits in the next iteration's Step 7e, or in Step 14 on the last iteration. A new gated finding during the wait earns one more round while the cap allows it; with no round left the run ends at `iteration_cap`.

The wait (`scripts/head-verdicts.sh`) stays inside the existing caps: `TIMEOUT` for CodeRabbit, counted from the newer of the push and the latest `@coderabbitai review` comment's server time (a nudge never restarts it), and the Codex wait budget for Codex, counted from the push. Past them it ends in the held state (else `timeout`), auto-merge stays off, and the missing verdict goes into the final JSON `head_verdict` and the report.

The wait script stops itself at its cap, since a background command has no harness timeout. It picks each next look from progress signals, the turnaround it measured and the budget left (`scripts/next-check.sh`), not a fixed interval.

| Outcome | Behavior |
|---------|----------|
| Every reviewer that is on gave findings or clean, nothing new needs a decision | The held state stands. |
| A new gated or unreadable finding on the held HEAD | One more round (Step 9a clears `HOLD_STATE`). On the last iteration there is no round: `final_state=iteration_cap`, `HEAD_VERDICT=unread`. |
| Budget spent with no verdict from anyone (every reviewer dropped, or one that cannot be read) | The held state stands (or `timeout` with none held), `HEAD_VERDICT=timeout`: the Step 15 gate finds no verdict on HEAD, so nothing merges. Step 14 reports it and files the follow-up issue only when something was deferred. |
| CodeRabbit paused automatic reviews | One `@coderabbitai review` for this HEAD (`cr-review-posted.sh` dedupes), then the wait resumes with the CodeRabbit budget counted from that request. |
| CodeRabbit silent past its budget (no review, no status, no pause) | Stuck: CodeRabbit silent for half its budget gets one `@coderabbitai review` when this HEAD has none, then waits out only the other half. Silent again, or a request already there: dropped for the run (`CR_SOURCE=codex-only`), named in `dropped_reviewers`, and Codex's verdict carries HEAD. |
| Codex without a verdict past its budget (Running, or nothing) | Dropped for the run without a nudge (`@codex review` is never posted; `NO_CODEX=true`), named in `dropped_reviewers`; CodeRabbit's verdict carries HEAD. |
| Codex Failed on HEAD | `final_state=codex_failed`, with no PR comment. |

- **Unreadable is not stuck**: a reviewer whose state cannot be read (including a nudge check that cannot read the comments, or Codex reactions where only a 👍 could decide) is never dropped.
- **Dropped reviewers**: one is off for the rest of the run, named in `dropped_reviewers` and the final report, and the merge is asked even with `--auto-merge`.
- **Codex 👍**: a Codex 👍 reaction on the PR after the push is a clean verdict only while the summary comment's `codex-review-state` marker names HEAD as reviewed, since a review of the previous commit that finishes after the push leaves one too (`codex-state-machine.md`).

## Who reviews the fixes

At the end of each cycle `scripts/auto-merge-gate.sh` prints `next_action`; its header holds the rule. When any applied fix came from a Critical, High, Major, Security or Codex P0/P1 finding, it is `rereview_push`: push to the PR for another review.

When every fix came from a Minor-or-lower finding, it is `merge_then_main_push`: the run stops at `minor_floor`, merges the reviewed HEAD, and pushes the fixes straight to the PR's base once build/test and the pre-commit guards pass there (`scripts/base-push.sh`).

A protected base, the verification gate off, or `--no-minor-stop` re-reviews instead, and a PR that is not merged gets the fixes pushed to it.

## Stops

- **minor_floor** (default on, `--no-minor-stop` turns it off): besides `merge_then_main_push`, from iter 2 a cycle that applied only low-severity fixes (none reassessed `high`) and deferred nothing ends at `final_state=minor_floor`.
- **churn** (no opt-out): from iter 2, a cycle whose every finding sits on the previous iteration's own commit, or outside the PR diff, ends at `final_state=churn`. The previous-commit axis applies to code only, because an iteration rewrites a whole prose paragraph and position no longer names the author.
- A prose finding is judged on the PR-diff axis alone, and a prose loop that does not converge ends at `iteration_cap`.

## Verification before push

- In a repo whose build/test baseline passes, each fix is built and tested before the commit. A failing fix is reverted and deferred as `verification-failed`, and a cycle where every fix failed pushes nothing and ends at `user_declined`.
- **Fast line**: when the repo's `AGENTS.md` names one (a fenced block whose info string is `<lang> fast`, such as `` ```bash fast ``), the baseline and each fix run only that line. The full line runs once at the loop end on a HEAD about to end at `clean`, `minor_floor` or `churn`.
- Its result is the final JSON `full_verification` and goes into the report. A failure makes the run ineligible for auto-merge, so Minor fixes do not go to the base either; with no fast line, one full line does everything.

## Follow-up issue

- When `final_state` is `churn`, `minor_floor`, `iteration_cap`, `user_declined`, `clean`, `timeout`, `ci_failing` or `merged_externally`, and any cycle deferred or left unread a finding (even when a later cycle is `clean`), the run files one issue with `gh issue create --label tbd` (the gate's `file_issue`).
- With nothing left behind it files no issue, even when a HEAD verdict is missing; that goes into the final report. A re-run on the same PR appends a comment to the same issue.
- The body is built from the `defer` records and passed through a file (`failure-modes.md`), and a failed `gh issue create` keeps the PR from merging.

## Merge

- **Auto-merge** needs all three: `final_state` is `clean`, `minor_floor` or `churn`; any defer has its follow-up issue filed (or appended on a re-run); every reviewer that is on gave HEAD a verdict. A HEAD with no verdict, or only a rate-limit notice, and every other state, `codex_failed` included, is not eligible.
- Without `--auto-merge`, an eligible run does not stop silently: it asks "auto-merge 할까요?" through `AskUserQuestion` on Claude Code or `request_user_input` on Codex, and with neither available it does not merge and says so. A yes takes the same merge path.
- **CI checks**: a HEAD about to end at `clean`, `minor_floor` or `churn` with a failing CI check (CodeRabbit's and Codex's own checks excluded, pending checks waited on within `TIMEOUT`) ends at `final_state=ci_failing`, and so does a failure the Step 15 gate finds late.
- The failing names go into the final JSON `ci_failing_checks` and the report. A failing check alone files no follow-up issue, and `ci_failing` never auto-merges.

## PR comments

- review-loop posts two kinds of PR comment only: the `@coderabbitai rate limit` query when a rate-limit notice has no reset time (once per run), and at most one `@coderabbitai review` per HEAD.
- The review request is posted for a non-default base CodeRabbit does not auto-review, when CodeRabbit paused automatic reviews (`auto_pause_after_reviewed_commits`), or when its wait budget passed with no verdict. A HEAD that already has a request gets none.
- A run that posted it for a non-default base ends its report with one line suggesting that base be added to the auto-review base-branch list in `.coderabbit.yaml`. The key name is looked up in CodeRabbit's schema or docs at run time, and the file is never edited.
- It never posts `@codex review` or a progress or summary comment; the push triggers the next review.

## Runs and runtimes

- **Runner**: on Claude Code one background runner subagent runs the whole loop and the main session receives only the final JSON. It is dispatched without a name, because with agent teams on a named agent becomes a teammate, which cannot run background commands and stalls in the waits.
- A subagent has no `AskUserQuestion`, so the runner takes the safe default at each interactive gate and returns the question in the final JSON `pending_decision`, which the main session asks. Codex runs the same body inline.
- **Codex Failed**: a Codex summary comment reporting Failed on HEAD stops the run at `final_state=codex_failed` without any PR comment. A draft PR stops with a `gh pr ready` hint.
- **Same-file generalization** (default on, `--no-generalize` turns it off): a `real`, high-confidence, grep-able finding also fixes the same pattern elsewhere in the same file in the same commit, never across files, logged as `generalized_to`.
- **After the merge**: `/dev:post-merge` surfaces the deferred and cap-stopped items of the review-loop state file as one `leftover-reviews:` checkpoint line.
