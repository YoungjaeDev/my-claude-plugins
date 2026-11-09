# review-loop procedure

The rule for each step of `SKILL.md` after Step 1, keyed by the step numbers 2 to 16 (with 2b, 5a, 5b, 6b, 7b-7e, 8b-8d, 9a, 9c.1-9c.7). A quoted block name is a `## ` heading in `run-blocks.md`: run that block verbatim, in order. Every `scripts/` and `references/` path resolves against `SKILL_DIR` from Step 1.

Claude Code runs each poller as `Bash(run_in_background=true)` + `Monitor`, so a wait costs no tokens; a runtime without background tasks runs the same command in the foreground and reads the one JSON line it prints. Inside a wait the next look comes from what it observed (`scripts/next-check.sh`), not a fixed interval.

## Step 2: repo, PR, base and state

- Run block "Step 2: repo, PR and counters". An empty `PR_NUM` aborts the run: no open PR for the current branch, so push and open one first.
- Run block "Step 2: draft PR". A draft PR stops with a `gh pr ready <PR>` hint, since CodeRabbit skips drafts by default.
- Run block "Step 2: base branch and review request". Step 5b, Step 7d and the Step 9c churn axis all need the base it sets.
- Run block "Step 2: request_cr_review". It also defines `await_head_verdicts` (Step 7e, Step 14) and `reviewers_on` (Step 15).
- **Non-default base**: with `CR_REVIEW_REQUEST=request` and `CR_SOURCE` `auto` or `pr-bot`, call `request_cr_review` once before iter 1 (the opening push was never auto-reviewed) and after every push this run makes (Step 5a, Step 12). The function checks both conditions itself, a pause (`request_cr_review paused`) needs only the PR-bot source, and it posts only when the head has no request yet.
- An absent CodeRabbit review is never convergence: Step 8c's `cr_engagement == 0` waits or ends at `cr_inactive`, never at `clean`. The CLI and codex-only sources never post the request.
- **Source check**: `cli` needs `bash $SKILL_DIR/scripts/probe-cr-cli.sh` to exit 0, else abort and relay its `hint` (the vendor install page plus `coderabbit auth login`). `codex-only` needs `scripts/probe-codex-engagement.sh "$OWNER" "$REPO" "$PR_NUM"` to print `active`, else abort. `auto` and `pr-bot` have no check.
- Run block "Step 2: state init" (inherits `codex_processed_reviews`, `cr_processed_reviews` and `followup_issue`; schema `assets/state.schema.json`), then block "Step 2: final-JSON trap", so Step 16 runs even on an early exit.

## Step 2b: reviewer availability

A reviewer that will not review this PR says so in a PR comment seconds after the PR opens: a Codex usage-limit notice, or CodeRabbit's `skip review` marker with "Auto reviews are disabled". Run block "Step 2b: reviewer availability" once, before any iter 1 wait.

On `final_state=reviewers_unavailable`, report each non-null `codex_url` / `cr_url` from `$ru`, skip Steps 5-15, and let the EXIT trap emit the final JSON. It is not convergence and never merges.

The CodeRabbit skip counts only for the PR-bot sources (`auto`, `pr-bot`). Actions and the anchored login rule are in `scripts/reviewer-availability.sh`.

## Step 3: AGENTS.md and the verification baseline

- `Read` the repo-root `AGENTS.md` when it exists. Its build, lint, test and commit guidance governs Step 9c's edits, Step 10's message and Step 11's lint for the rest of the run.
- Set `VERIFY_CMD` to the repo's build + test line (the one `AGENTS.md` names, else the project's conventional entry points, else empty), then run block "Step 3: verification baseline". `VERIFICATION_GATE=on` only when that line passes on the untouched checkout.
- The gate is off as `baseline_failed` (the line already fails), `no_build_check` (`--no-build-check`) or `no_command`. Step 16 reports which, and the final report says the fixes went in unverified.
- **Fast line**: an `AGENTS.md` fenced block whose info string is a language followed by `fast` (`` ```bash fast ``) names a fast command. Set `VERIFY_FAST_CMD` to its body, else empty; `VERIFY_CMD` stays the full line.
- With a fast line, the baseline and every per-fix check run it, and Step 14 runs the full line once on the final HEAD. The full line then has no baseline, so one that is already broken fails at the loop end and blocks the merge.

## Step 4: manual paste

With a non-empty `--paste`, treat the block as one thread-equivalent: extract path, line and severity from it, run `scripts/path-trust.sh` and `sanitization-rules.md`, Edit, and append the path to `$TRACK_FILE`.

Then run Steps 10-12 and continue the normal loop from Step 5.

Use it when CodeRabbit put its feedback in a review summary instead of inline threads.

## Step 5: loop head and pre-flight

Every iteration runs this first, before any wait. Run block "Step 5: loop head and pre-flight": it opens the per-iteration loop (Steps 5a-13 run inside it, the Step 13 block closes it) and runs `scripts/pre-flight.sh` unless `CR_SOURCE` is `cli` or `codex-only`. The gate values and the JSON contract are in `pre-flight-rules.md`, the Codex channels in `codex-parsing-rules.md`.

- **Step 5a, merge conflict** (every source, first in the iteration): a PR whose `mergeable` is `CONFLICTING` follows `merge-conflicts.md`. That merge commit is the iteration's one commit, so the loop `continue`s; `UNKNOWN` proceeds.
- **Codex Failed on HEAD**: pre-flight's `codex_verdict=failed` stops the run at `final_state=codex_failed`. Tell the user no Codex review of HEAD is coming; post nothing.
- **Merged or closed outside the run**: the loop head, the Step 12 push and the Step 15 gate read `gh pr view --json state`, and a merged or closed PR ends at `final_state=merged_externally`. Nothing more goes to the PR; failure-modes.md says where held fixes and deferred findings go.

## Step 5b: small-diff codex-only (iter 1 only)

After pre-flight, on `ITER=1` with `CR_SOURCE=auto`, `SMALL_DIFF_LOC > 0`, a gate other than `proceed`, `rate_limited` or `failure`, and Codex active, a diff below both thresholds flips `CR_SOURCE=codex-only` for the run.

The block and its arithmetic are in `pre-flight-rules.md`.

The diff is the three-dot `origin/$BASE...HEAD` (the merge-base diff GitHub shows), never two-dot, which counts every commit the base gained after the fork; the churn axis uses the same rule.

## Step 6: CR wait (fallback only)

Entered when pre-flight gave `gate=cr_wait`, or with `CR_SOURCE` `auto` / `pr-bot` and no pre-flight result. Skipped for `cli`, `codex-only`, and the gates `proceed`, `codex_wait`, `rate_limited` and `failure`.

- **Codex auto-detect**: on iter 1, or a later iter whose cached `codex_active` is `inactive`, run the "Auto-detect block (Step 6)" in `codex-state-machine.md`; `--no-codex` forces `disabled`.
- Run block "Step 6: CR status poll". `poll-cr-status.sh` self-escapes on an early rate-limit body only while the commit status is non-terminal (`rate-limit-fallback.md`).
- Its JSON `state`: `success` goes to Step 6b. `failure` ends at `final_state=failure`. `rate_limited` adds one to `rate_limit_hits` and goes to Step 7c. `timeout` (exit 124) or no JSON ends at `final_state=timeout`.
- `error` also ends at `final_state=failure`: `cr-commit-state.sh` could not read the status (auth, network, a secondary rate limit, an unparseable page) for `ERROR_STREAK_MAX` (default 3) rounds in a row. Show the user the JSON's `channel` field.

## Step 6b: Codex review-id discovery

Run the "Review-id discovery and the grace cap (Step 6b)" block in `codex-state-machine.md`. It re-probes a `codex_active=inactive` left by Step 6, since a young PR's first Codex review can land during the CR poll, and skips when Codex is still not `active` or pre-flight already set `codex_review_id_to_process`.

With no unprocessed review and `CODEX_GRACE > 0`, poll `scripts/poll-codex-grace.sh` with `CAP=grace_cap` and `PUSH_TIME`: take the `codex_review_id` it prints, or go on with none on a `clean` verdict or an expired cap.

A `failed` verdict ends at `final_state=codex_failed`, as in Step 5. `grace_cap` is `max(CODEX_GRACE, CODEX_PREFLIGHT_TIMEOUT - push_age)` on every gate, from `scripts/codex-head-verdict.sh`.

## Step 7: in-progress sniff and rate limits

- Skip Step 7 when `CR_SOURCE` is `cli` or `codex-only`, or `gate == "rate_limited"`; otherwise run block "Step 7: in-progress sniffer".
- **Step 7b**, entered from Step 5 (`gate=rate_limited`) or Step 6 (`state=rate_limited`): run block "Step 7b: rate-limit sniff", then the "Active query block (Step 7b)" in `rate-limit-fallback.md`. The `@coderabbitai rate limit` query fires only when the sniff found no reset estimate, once per run (`STATE_FILE.rate_limit_query`), never on `permanent=true`.
- `permanent=true` (`Review skipped: N files exceed the limit`) is a skip no reset clears: offer no wait, and never let the iteration converge to `clean` on it, since CodeRabbit never looked.
- **Step 7c**: `auto` flips to `cli` when `probe-cr-cli.sh` exits 0, else to `codex-only` when Codex is active, and asks only when neither is left. A runner aborts there at `final_state=rate_limited` with `pending_decision.question=cr_source`.
- A user-explicit `--cr-source` is final: `pr-bot` keeps waiting through a transient limit and ends at `final_state=rate_limited` only on a permanent skip. The flip persists to `STATE_FILE.cr_source` for the rest of the run; the table and the interactive branch are in `rate-limit-fallback.md`.
- **Step 7d** (`CR_SOURCE=cli` only): run block "Step 7d: CLI review spawn". A non-zero `exit` or `incomplete=true` ends at `final_state=cli_failed`, with no fallback to the PR-bot (`cr-cli-jsonl-schema.md`). `completed_with_warnings` with nothing unreviewed is complete.

## Step 7e: HEAD verdict wait

Every iteration, before anything is fetched, judged or pushed, run block "Step 7e: HEAD verdict wait". It waits until every reviewer the run has on has given the current HEAD a verdict (findings or clean).

CodeRabbit is on for `auto` and `pr-bot`; Codex is on unless `--no-codex`, dropped, or never engaged on the PR. A progress mark, a rate-limit notice or a review pause is not a verdict.

The caps, the nudge, the drop rules and the 👍 rule are in `coordination.md` ("HEAD verdict wait"). No verdict from anyone ends the run at the stop Step 13 held, else `timeout`, with `HEAD_VERDICT=timeout`; Codex Failed ends at `codex_failed`.

## Step 8: fetch findings

- **Step 8** (PR-bot path; skip for `cli` and `codex-only`): run block "Step 8: fetch CR threads". It adds CodeRabbit's "Outside diff range comments" from review bodies (`scripts/fetch-cr-outside-diff.sh`) as thread-shaped records (`origin: "outside-diff"`, `review_id`) that go through the same Step 9.
- An outside-diff `path` comes from the body, so the Step 9c.1 path-trust gate is what makes it safe. It merges into a thread's record only as a confirmed copy (same path, line, header badges and title); reviews in `cr_processed_reviews` are skipped, and a block that cannot be read in full ends at `final_state=failure`.
- **Step 8b** (skip when `codex_active != "active"` or `codex_review_id_to_process=""`): run block "Step 8b: fetch Codex inline comments". A `gh` error ends at `final_state=failure`, never an empty review.
- **Step 8c** (PR-bot path; skip for `cli`, `codex-only`, and pre-flight `gate=proceed`): run block "Step 8c: engagement gate". It gates only a round with no records (`records_n == 0`), where a stop Step 13 held ends as held; records go on to Step 9a.
- CodeRabbit's result there is its HEAD verdict (`cr-head-verdict.sh`: `findings` / `clean` / `none`), never the success status. `cr_engagement > 0` with `cr_verdict != none` is `final_state=clean`, on to Step 13; otherwise sleep `$INTERVAL` and continue, or end at `final_state=cr_inactive` on `ITER == MAX_ITER`.
- **Step 8d** (`CR_SOURCE=cli`, after Step 7d): run block "Step 8d: CLI JSONL to records".

## Step 9a: classify

Run block "Step 9a: classify". With a stop held by Step 13 it resolves that first: no finding that needs a decision (`gated`, `defer`, `review`) on the new HEAD ends the run at the held state, and one or more earns another round.

Drop `tier=="skip"` items before rendering and count them per `skip-minor-rules.md`. Render the rest as one table (`Source · Category/Badge · Severity · Effort · Path:Line · Tier`), with the footer when `skipped_total > 0`.

Tiers are severity-first from CodeRabbit's header (`tier-classification.md`). Nothing is asked between 9a and 9c: go straight to 9c in severity order.

## Step 9c: per-finding judgment

For each non-skip finding in severity order (Codex P0, then CR/CLI Critical, High, Major, Minor, then Codex P1, P2), add one to `judged_this_cycle`, and one to `review_this_cycle` for a `review`-tier item. Steps 9c.3-9c.6 are `autonomous-judgment.md` "Per-finding procedure (Step 9c)": follow it as written.

- **9c.1, path trust** (mandatory): run block "Step 9c.1: path-trust gate".
- **9c.2, sanitize** reviewer guidance per `sanitization-rules.md`, and refuse and warn on the signals listed there.
- **9c.4, churn axis**: run block "Step 9c.4: churn scope". **9c.6, verify**: with `VERIFICATION_GATE=on`, each apply runs inside block "Step 9c.6: verify the fix".
- **9c.7, persist review ids** (always, when one was discovered): run block "Step 9c.7: persist Codex review id". It also records each CodeRabbit `review_id` of this round in `cr_processed_reviews`, so outside-diff findings are not judged twice.

## Steps 10-12: commit, lint, push

- **Step 10**: run block "Step 10: stage and commit". Besides the track file's paths, the commit takes every other file the cycle's fixes changed (a regression test, a fixture); files Step 5 recorded as dirty before the fixes stay out.
- **Step 11**: build and test already ran per fix in 9c.6, so only lint runs here, when the repo names a lint command; a failure warns and proceeds. Step 10's `noop` (every fix reverted, or none applied) skips it, and Step 12 then pushes nothing.
- **Step 12**: run block "Step 12: push". It asks `scripts/auto-merge-gate.sh` for `next_action` first; the rule is in the script header and `coordination.md` ("Who reviews the fixes"), so do not decide it here.
- `rereview_push` pushes the fixes to the PR, and CodeRabbit resolves its threads itself when the re-review sees the fix. `merge_then_main_push` keeps them on the local commit and sets `REVIEWED_SHA` to the reviewed HEAD: Step 13 stops at `minor_floor` and Step 15 merges that HEAD before the fixes go to the base.

## Step 13: convergence

Run block "Step 13: convergence ladder". `minor_floor` is on by default (`--no-minor-stop` turns it off and sends every fix back to the PR), and `churn` has no opt-out; both can merge once Step 14 files the follow-up issue for anything left behind.

A stop reached in a cycle that pushed is held (`HOLD_STATE`), not ended, because the push has no verdict yet. The next iteration's Step 7e waits for it, and on the last iteration Step 14 does.

`final_state=user_declined` does not mean the user rejected anything: it is the label for "the run deferred everything in that iteration", which downstream tooling reads.

## Step 14: cap, verdicts, CI and the follow-up issue

- A loop that exits at `ITER == MAX_ITER` with threads still actionable ends at `final_state=iteration_cap`; report the remaining thread count and `target_url`.
- Run block "Step 14: last-push HEAD verdicts and follow-up trigger". When the last iteration pushed, it waits for that HEAD's verdicts; findings there have no round left, so the run ends at `iteration_cap` with `HEAD_VERDICT=unread`.
- A run about to end at `clean`, `minor_floor` or `churn` with a fast line and `VERIFICATION_GATE=on` runs the full line once on HEAD (`scripts/verify-fix.sh full`; with held fixes that HEAD is their local commit). The result is `full_verification`, and `fail` blocks the merge and so the base push.
- The same run then reads HEAD's CI checks (`scripts/ci-checks.sh`, pending checks waited on under `TIMEOUT`). A check in gh's `fail` or `cancel` bucket ends it at `ci_failing`, the names in `ci_failing_checks`.
- `followup_needed` is the gate's `file_issue`: true only when findings were left behind (deferred in any cycle, or unread). Then file one issue with the block under "Follow-up issue block (Step 14)" in `failure-modes.md`, whose body comes from the `defer` records through a file and which reuses `STATE_FILE.followup_issue` on a re-run.
- A creation failure does not end the run, but it blocks Step 15; the findings stay in the archived `auto_judge_log`. A HEAD without every verdict and failing CI go to the final report and final JSON (`head_verdict`, `ci_failing_checks`), never into an empty issue or a PR comment.

## Step 15: merge gate and merge

Runs on every run that reaches it, with or without `--auto-merge`. Run block "Step 15: auto-merge gate": `scripts/auto-merge-gate.sh` owns eligibility (state, the follow-up issue, every reviewer's verdict on HEAD), and the block also refuses on CodeRabbit's status, a failing or unreadable CI check, or an unverified protection probe. A check that failed after Step 14 looked moves the run to `ci_failing`.

When the PR can merge without `--auto-merge`, ask "auto-merge 할까요?" (Merge / Don't merge) and set `MERGE_ANSWER=yes` on Merge, which takes the same path. `--auto-merge` on a protected base merges with `gh pr merge --auto`; an unprotected base (an immediate merge) and a run that dropped a reviewer ask even then.

Then run block "Step 15: merge". A runner leaves the question in `pending_decision` and the block merges and pushes nothing. With fixes Step 12 held (`REVIEWED_SHA`), a landed merge sends them to the base through `scripts/base-push.sh` (`base_push`); otherwise they go to the PR, unreviewed, and the report says to re-run.

## Step 16: final JSON and report

The Step 2 EXIT trap runs `scripts/emit-final-json.sh`, which always prints one JSON line (schema `assets/final-output.schema.json`, field meanings there) and archives the state file to `.claude/state/archive/`. The final report states, from that line:

- `head_verdict` when HEAD lacks a verdict, each `dropped_reviewers` entry (HEAD has no verdict from it), and `pending_decision` for the main session to ask.
- `verification_gate` other than `on` (fixes went in unverified), and a `full_verification=fail` with the line it ran (auto-merge stayed off).
- `cr_review_requested_base`: one line suggesting the user add that base to the auto-review base-branch list in `.coderabbit.yaml`, naming the key as CodeRabbit's schema (`https://coderabbit.ai/integrations/schema.v2.json`) or docs give it at run time. Never edit the file.
- The CLI install suggestion, when the Step 7c flip logged one.
