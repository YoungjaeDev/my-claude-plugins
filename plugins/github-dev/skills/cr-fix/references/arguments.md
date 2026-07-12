# cr-fix Arguments

All flags are positional after `/github-dev:cr-fix`; order does not matter.

| Flag | Default | Notes |
|------|---------|-------|
| `--max-iterations <n>` | `5` | Hard cap on review-fix cycles — a CR quota budget, not just a runaway guard. Measured tier is Pro+ (10 PR-reviews/hr rolling) with Fair-Usage adaptive decay; 5 is conservative under that throttle. Rationale: `references/rate-limit-fallback.md`. |
| `--timeout <sec>` | `1800` (30 min) | Per-iteration CR-status wait cap. On timeout, exit and escalate. |
| `--interval <sec>` | `8` | Poll interval used by Step 6 / 6b / 8c fallback polls. v2 dropped the default from `60` → `8` because Step 5 pre-flight absorbs the first round-trip; tighten to 5 for faster wakeup or raise back to 30+ if your CR org rate-limits aggressively. |
| `--auto-merge` | OFF | After convergence, gate-check branch protection. With protection: `gh pr merge --auto --squash --delete-branch`. Without protection: prompt user (Merge now / Skip / Cancel). |
| `--paste <text>` | empty | Short-circuit: process pasted CR text once, then continue normal loop. Use when CR puts feedback in review summary instead of inline threads. |
| `--no-build-check` | OFF | Skip BUILD/TEST verification gate after each apply cycle. |
| `--codex-grace <sec>` | `30` | Extra wait after CR completes, used to detect an unprocessed Codex review. `0` disables grace polling (probe once, proceed). |
| `--no-codex` | OFF | Force-disable Codex auto-detect for the run. Default is auto-detect: Codex enabled iff the PR has at least one Codex review in its lifetime. |
| `--skip-minor` | OFF | Silently skip CR Minor/Trivial/Info (type ∉ {Bug, Security}) and Codex P2 items. See `references/skip-minor-rules.md`. |
| `--no-minor-stop` | OFF (soft-stop ON) | Disable the minor soft-stop. Default: from iter 2 on, a cycle that applied only low-severity fixes (no `high` reassessed, nothing deferred) ends with `final_state=minor_floor` instead of looping the low-value tail. Pass this to keep looping until the v1 `applied==0 && deferred==0` convergence. |
| `--no-generalize` | OFF (generalize ON) | Disable bounded same-file generalization. Default: a `real` + `high`-confidence + mechanically grep-able finding also patches sibling occurrences of the same pattern **in the same file** in the same commit (audit-logged as `generalized_to`). Pass this to fix only the exact flagged line. Cross-file generalization is never done regardless. See `references/autonomous-judgment.md`. |
| `--cr-source <mode>` | `auto` | Source selector. `auto` (default): PR-bot first, fall back on rate-limit. `pr-bot`: never use CLI/codex-only. `cli`: skip Step 6/6b/7, run local `coderabbit` CLI. `codex-only`: skip CR entirely, only Codex inline. |
| `--small-diff-threshold-loc <n>` | `200` | Step 5b heuristic: with `--cr-source=auto` + Codex active + diff smaller than this LoC, silent flip to `codex-only` for the run. Set `0` to disable the heuristic. |
| `--small-diff-threshold-files <n>` | `5` | Step 5b heuristic: same as above but for changed file count. Both LoC and file thresholds must hold for the flip to trigger. |

`CODEX_GRACE=0` short-circuits grace polling. `NO_CODEX=true` short-circuits all Codex paths regardless of repo state. `SKIP_MINOR=true` post-classification filter — see `references/skip-minor-rules.md`. `--cr-source` user-explicit values (pr-bot / cli / codex-only) are final — Step 7c will not silently flip away from a user choice.

## v2 behavioral notes (no flag changes)

- Step 9 is **autonomous**. No `AskUserQuestion` per finding; the LLM judges real-vs-spurious + severity + fix size and applies / defers / skips. Reasoning is logged to `STATE_FILE.auto_judge_log` and summarised in the final JSON `auto_judge_stats` field. To audit, inspect `.claude/state/archive/cr-fix-<PR>-<timestamp>.json` after the run.
- Step 5 pre-flight runs at the top of every iter. When CR + Codex have both already arrived, Step 6 / 6b polling is **skipped entirely**. Set `CODEX_PREFLIGHT_TIMEOUT` env var (seconds) to change the codex grace cap used by pre-flight (default 600).
- `--cr-source pr-bot` retains v1 strictness: pre-flight never silently flips away from a user-explicit source.
