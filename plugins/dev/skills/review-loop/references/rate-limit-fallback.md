# Rate-limit Fallback Decision Table

What Step 7c does when `scripts/sniff-cr-rate-limit.sh` finds a CodeRabbit rate limit: 9 source cases, 3 reset patterns, and the Step 7b and 7c blocks. A `comment`-channel hit routes here only while the commit status is non-terminal; a `success` or `failure` status wins (`pre-flight-rules.md`).

## --cr-source resolution

| `--cr-source` (user-provided) | CR rate-limited? | CLI available + authed? | Codex active? | Action |
|---|---|---|---|---|
| `auto` (default) | yes | yes | any | Silent flip → `cli`. Spawn Step 7d. |
| `auto` | yes | no | yes | Silent flip → `codex-only`. Skip Step 7/7d/8/8d. |
| `auto` | yes | no | no | Ask: wait NN min / abort / force codex-only (manual). |
| `auto` | no (status silent for other reason) | n/a | n/a | Continue with default `pr-bot` path, Step 6 keeps polling. |
| `pr-bot` | yes | any | any | No flip. Continue waiting for rate-limit reset. User chose pr-bot explicitly. Log reset minutes if extracted. |
| `cli` | n/a (Step 6/6b skipped entirely) | yes | any | Step 7d runs unconditionally. |
| `cli` | n/a | no | any | Step 2 pre-flight already aborted (`probe-cr-cli.sh` non-zero). Never reaches here. |
| `codex-only` | n/a (Step 6/7/7b/7d/8/8d skipped) | n/a | yes | Step 6b + 8b only. |
| `codex-only` | n/a | n/a | no | Step 2 pre-flight aborted (no Codex history). Never reaches here. |

## Silent flip semantics

- "Silent" means no question, only one log line: `cr-source: auto → cli (rate-limit detected, CLI authed)` or `cr-source: auto → codex-only (rate-limit, no CLI)`.
- The `codex-only` flip also logs an install suggestion from `probe-cr-cli.sh`'s `hint` (the vendor install page https://docs.coderabbit.ai/cli, then `coderabbit auth login`), once more in the Step 16 report. The run goes on, since `coderabbit auth login` needs a browser; the next run's fallback lands on `cli`.
- The flip is sticky for the rest of the run: no later iteration re-probes the reset to flip back, which would mix record sources in the Step 9a table.
- **User-explicit modes are final**: with `--cr-source pr-bot|cli|codex-only`, Step 7c never flips. A rate limit on `pr-bot` falls through to the Step 6 timeout path, whose message names `target_url` and the reset minutes.

## Permanent skips

`scripts/sniff-cr-rate-limit.sh` emits `permanent: true` for a skip that no reset window clears — currently `Review skipped: N files exceed the limit of M`. The PR is simply larger than the PR-bot will review, so waiting, re-pushing and re-running all reproduce it.

Step 7c treats a permanent hit as a source failure, not a wait:

- `auto` → flip to `cli` (or `codex-only`), exactly as for a genuine rate-limit.
- `pr-bot` → `final_state=rate_limited`. It must never fall through to `clean`: CR posted no findings because it never looked, and a run that converges on that silence merges an unreviewed PR.
- The question offers no "wait NN min" option when `permanent` is true.

## Rate-limit reset extraction

`scripts/sniff-cr-rate-limit.sh` parses these body patterns:

1. `auto-generated comment: rate limited by coderabbit\.ai` — generic, no reset hint.
2. `(?:More reviews will be available in|Next (?:included )?review available in)[^0-9]{0,12}(\d+)\s*minutes?` — extract the digits as `reset_minutes`. All three phrasings occur, and the newer ones are markdown-bold (`**Next included review available in:** **41 minutes**`), which is why the `[^0-9]{0,12}` bridge is needed.
3. `Review limit reached` — generic, no reset hint.

An extracted estimate goes into the log line (`... (reset in ~12 minutes)`) and into the question's "wait NN min" option, which defaults to 15 min without one.

## Active query block (Step 7b)

The three patterns are passive. When the sniff confirmed a rate limit but found no reset (`reset` empty), `scripts/query-cr-rate-limit.sh` asks CodeRabbit instead of guessing 15 min: it posts one `@coderabbitai rate limit` comment, polls issue comments for the reply (default 6 rounds of 20 s), and parses `remaining` and `reset_minutes` from it.

The post is an external write that cannot be repeated safely, so it runs once per run: persist the outcome to `STATE_FILE.rate_limit_query` and reuse it on later iterations. The `--max-iterations` default of 5 is a CodeRabbit review-quota budget as well as a runaway guard: one review per iteration has to fit the plan's hourly limit after fair-usage decay.[^quota]

```bash
prior_aq=$(jq -c '.rate_limit_query // empty' "$STATE_FILE")
if [ "$permanent" = "true" ]; then
  : # no reset to query for
elif [ -n "$prior_aq" ]; then
  reset=$(jq -r '.reset_minutes // empty' <<<"$prior_aq")
elif [ -n "$rl" ] && [ -z "$reset" ]; then
  # Bash(run_in_background=true, timeout=180000):
  #   bash $SKILL_DIR/scripts/query-cr-rate-limit.sh "$OWNER" "$REPO" "$PR_NUM"
  # Monitor returns one JSON line: {remaining, reset_minutes, replied, body_excerpt}
  #   aq=<that line>
  #   [ "$(jq -r '.replied' <<<"$aq")" = true ] && reset=$(jq -r '.reset_minutes // empty' <<<"$aq")
  #   tmp=$(mktemp); jq --argjson q "$aq" '.rate_limit_query = $q' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
fi
```

## Fallback decision block (Step 7c)

The table above in executable form:

```text
if CR_SOURCE != "auto" → respect user choice:
  - "pr-bot"     → permanent=true: final_state="rate_limited", break; otherwise keep waiting (Step 6 timeout path), no flip
  - "cli"/"codex-only" → unreachable
elif probe-cr-cli.sh exits 0:
  CR_SOURCE=cli; log "cr-source: auto → cli (rate-limit via ${channel}, CLI authed${reset:+, reset in ~${reset} min})"
elif codex_active == "active":
  CR_SOURCE=codex-only; log "cr-source: auto → codex-only (rate-limit via ${channel}, no CLI)"
  # The flip landed here only because no CLI is installed; surface the
  # platform-aware install command so the NEXT run can fall back to cli instead.
  cli_hint=$(bash $SKILL_DIR/scripts/probe-cr-cli.sh 2>/dev/null | jq -r '.hint // empty') || cli_hint=""
  [ -n "$cli_hint" ] && log "suggest: install the CodeRabbit CLI to keep CR coverage under rate limits. $cli_hint"
else:
  # Interactive gate (SKILL.md hard constraints): [Abort] / [Install CLI (${cli_hint})
  # then retry] / [Force codex-only], plus [Wait ${reset:-15} min] unless
  # permanent=true. With no interaction tool on the runtime, abort — flipping a
  # source the user did not choose is not a safe default. A runner (--runner) aborts
  # too, at final_state=rate_limited with
  # pending_decision={question:"cr_source", reset_minutes:${reset:-null}, permanent:$permanent},
  # and the main session asks this question, then dispatches a new runner (SKILL.md "Runner").
```

When `cli_hint` is non-empty, the Step 16 summary carries one "install the CodeRabbit CLI" line.

`jq '.cr_source = $src' "$STATE_FILE"` persists the flip. Flip is sticky for remaining iters of this run.

[^quota]: Pro+ allows 10 PR reviews an hour on a rolling window, and sustained heavy use (about 90+ reviews in 7 days) decays it toward 1 an hour ([Fair Usage Limits Policy](https://docs.coderabbit.ai/management/plans#fair-usage-limits-policy)). Raise `--max-iterations` only on an account fresh on that window.
