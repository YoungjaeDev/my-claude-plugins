# review-loop Arguments

The 15 flags `scripts/parse-args.sh` reads, in any order after `/dev:review-loop`. A user-explicit `--cr-source` (`pr-bot`, `cli`, `codex-only`) is final: neither pre-flight nor Step 7c flips away from it.

| Flag | Default | Notes |
|------|---------|-------|
| `--max-iterations <n>` | `5` | Hard cap on review-fix cycles, and a CodeRabbit review-quota budget (`rate-limit-fallback.md`). The soft stops (`minor_floor`, `churn`) usually end a run before it. |
| `--timeout <sec>` | `1800` (30 min) | CodeRabbit wait cap per iteration. On timeout, exit and escalate. |
| `--interval <sec>` | `30` | Base poll interval of every wait (the Step 7e / Step 14 HEAD verdict wait, the Step 6 / 6b / 8c fallback polls). `scripts/next-check.sh` adapts around it: a third of it while a reviewer is at work, nothing before 68 s after the push, twice it past 726 s, never past a budget. A tighter interval spends the shared 5,000/hr GitHub API quota without a sooner verdict. |
| `--auto-merge` | OFF | After convergence, check branch protection. With protection: `gh pr merge --auto --squash --delete-branch`. Without protection the merge is immediate, so the user still confirms it. Without the flag a merge-eligible run asks "auto-merge 할까요?" (no interaction tool: no merge, reported), and a yes takes the same path (Step 15). |
| `--paste <text>` | empty | Process pasted CodeRabbit text once, then continue the normal loop (Step 4). For feedback CodeRabbit put in a review summary instead of inline threads. |
| `--no-build-check` | OFF | Skip the build/test gate (baseline, per-fix checks and the loop-end full line); the final JSON reports `verification_gate=no_build_check`. |
| `--codex-grace <sec>` | `30` | Floor of the Codex wait: every gate waits `max(CODEX_GRACE, CODEX_PREFLIGHT_TIMEOUT - push_age)` for an unprocessed Codex review or a HEAD verdict. `0` removes only the floor; a push younger than `CODEX_PREFLIGHT_TIMEOUT` still waits out the rest of that window. |
| `--no-codex` | OFF | Disable Codex for the run. By default Codex is on when the PR has at least one Codex review. |
| `--skip-minor` | OFF | Silently skip CodeRabbit Minor/Trivial/Info (category not `🔒 Security & Privacy`) and Codex P2 items (`skip-minor-rules.md`). |
| `--no-minor-stop` | OFF (soft stop ON) | Disable the `minor_floor` stop: every fix goes back to the PR for re-review, and the loop runs to `applied==0 && deferred==0`. The `churn` stop has no opt-out (`coordination.md`). |
| `--no-generalize` | OFF (generalize ON) | Fix only the flagged line, with no same-file generalization (`autonomous-judgment.md`). Cross-file generalization never happens either way. |
| `--cr-source <mode>` | `auto` | `auto`: PR bot first, fall back on a rate limit. `pr-bot`: never the CLI or codex-only. `cli`: skip Steps 6/6b/7 and run the local `coderabbit` CLI. `codex-only`: skip CodeRabbit, Codex inline only. |
| `--small-diff-threshold-loc <n>` | `200` | Step 5b: with `--cr-source auto`, Codex active and a diff under this many lines, flip to `codex-only` for the run. `0` disables the heuristic. |
| `--small-diff-threshold-files <n>` | `5` | Step 5b: the same for the changed file count. Both thresholds must hold for the flip. |
| `--runner` | OFF | Set by the main session when the user asks for a background run and it hands the run to a subagent (SKILL.md "Runner"); not for users. Both interactive gates then take their safe default and return the question in the final JSON's `pending_decision`. |

`CODEX_PREFLIGHT_TIMEOUT` (env, seconds, default 900, `CODEX_BUDGET_DEFAULT` in `scripts/codex-turnaround.sh`) sets the Codex wait budget that pre-flight and Step 6b share through `scripts/codex-head-verdict.sh`. `CR_SKIP_GRACE` is the other env-only knob (`pre-flight-rules.md`).
