# Failure Modes

Exhaustive table of `final_state` values and their triggers. Step 16's emitted JSON always carries `final_state`.

| `final_state` | Trigger | Auto-merge eligible? | User action |
|---------------|---------|----------------------|-------------|
| `clean` | Loop exits with `applied_this_cycle == 0` and `deferred_this_cycle == 0` AND Step 8c engagement gate passed. | yes (if `--auto-merge`) | None — merge proceeds or remains manual. |
| `user_declined` | Loop exits because `applied_this_cycle == 0` but `deferred_this_cycle > 0`. User deferred everything in some iter. | no | Decide on the deferred items manually, re-run, or merge as-is via GitHub UI. |
| `minor_floor` | Minor soft-stop (B). `MINOR_STOP=true` (default; `--no-minor-stop` off) AND `ITER >= 2` AND this cycle applied only low-severity fixes (`high_sev_this_cycle == 0`) with nothing deferred (`deferred_this_cycle == 0`). Stops the low-value minor tail early instead of looping to the v1 `applied==0 && deferred==0` floor. | no | The applied minor fixes were already pushed but the latest push is not yet CR-re-reviewed — treated like `user_declined`. Inspect via `gh pr view --comments`, merge via GitHub UI, or re-run cr-fix to re-confirm clean. Pass `--no-minor-stop` to keep looping. |
| `iteration_cap` | `ITER == MAX_ITER` and threads still actionable. | no | Inspect remaining threads via `target_url`; re-run with higher `--max-iterations`. |
| `timeout` | Step 6 CR-status poll exited 124 (TIMEOUT exceeded) without seeing `success` / `failure`. | no | Re-run with larger `--timeout`, or use `--cr-source cli\|codex-only` to bypass PR-bot. |
| `failure` | CR commit-status reported `failure`, OR Step 8 GraphQL fetch errored, OR `gh api` returned `errors` payload. | no | Inspect CR dashboard via `target_url` for the failure case; check `gh auth status` and network for the fetch case. |
| `cr_inactive` | Step 8c engagement gate: `ITER == MAX_ITER` AND `cr_engagement == 0` (CR posted nothing on this push). | no | CR is unreachable, paused, or rate-limited. Use `--cr-source cli\|codex-only` to bypass. |
| `rate_limited` | Step 7c detected CR rate-limit comment AND `--cr-source pr-bot` (user blocked auto-flip). | no | Wait for CR reset window (typically 5-60 min) or re-run with `--cr-source cli` / `--cr-source codex-only`. |
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
| Step 15 branch-protection probe gh api error | Treat as 404 (no protection) and fall through to AskUserQuestion path (Merge now / Skip / Cancel). |

## Build / verification failure (Step 11)

Does NOT change `final_state` directly. Sets `verification_blocking=true` which disables auto-merge for the run. The push still happens so CR re-review sees the new code. The user can intervene before merge.
