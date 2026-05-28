# cr-fix Arguments

All flags are positional after `/github-dev:cr-fix`; order does not matter.

| Flag | Default | Notes |
|------|---------|-------|
| `--max-iterations <n>` | `5` | Hard cap on review-fix cycles. Prevents runaway loops. |
| `--timeout <sec>` | `1800` (30 min) | Per-iteration CR-status wait cap. On timeout, exit and escalate. |
| `--interval <sec>` | `60` | Poll interval. Don't go below 30 to respect GitHub rate limits. |
| `--auto-merge` | OFF | After convergence, gate-check branch protection. With protection: `gh pr merge --auto --squash --delete-branch`. Without protection: prompt user (Merge now / Skip / Cancel). |
| `--paste <text>` | empty | Short-circuit: process pasted CR text once, then continue normal loop. Use when CR puts feedback in review summary instead of inline threads. |
| `--no-build-check` | OFF | Skip BUILD/TEST verification gate after each apply cycle. |
| `--codex-grace <sec>` | `30` | Extra wait after CR completes, used to detect an unprocessed Codex review. `0` disables grace polling (probe once, proceed). |
| `--no-codex` | OFF | Force-disable Codex auto-detect for the run. Default is auto-detect: Codex enabled iff the PR has at least one Codex review in its lifetime. |
| `--skip-minor` | OFF | Silently skip CR Minor/Trivial/Info (type ∉ {Bug, Security}) and Codex P2 items. See `references/skip-minor-rules.md`. |
| `--cr-source <mode>` | `auto` | Source selector. `auto` (default): PR-bot first, fall back on rate-limit. `pr-bot`: never use CLI/codex-only. `cli`: skip Step 6/6b/7, run local `coderabbit` CLI. `codex-only`: skip CR entirely, only Codex inline. |
| `--small-diff-threshold-loc <n>` | `200` | Step 5b heuristic: with `--cr-source=auto` + Codex active + diff smaller than this LoC, silent flip to `codex-only` for the run. Set `0` to disable the heuristic. |
| `--small-diff-threshold-files <n>` | `5` | Step 5b heuristic: same as above but for changed file count. Both LoC and file thresholds must hold for the flip to trigger. |

`CODEX_GRACE=0` short-circuits grace polling. `NO_CODEX=true` short-circuits all Codex paths regardless of repo state. `SKIP_MINOR=true` post-classification filter — see `references/skip-minor-rules.md`. `--cr-source` user-explicit values (pr-bot / cli / codex-only) are final — Step 7c will not silently flip away from a user choice.
