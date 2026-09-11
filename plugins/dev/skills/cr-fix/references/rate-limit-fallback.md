# Rate-limit Fallback Decision Table

Triggered by `scripts/sniff-cr-rate-limit.sh` detecting a CR rate-limit comment within ~30s of CR-status silence. A `comment`-channel hit routes here **only while the commit-status is non-terminal** — if the status has already flipped to `success`/`failure`, that authoritative state wins and this table is not entered (see `pre-flight-rules.md`). SKILL.md Step 7c uses this table.

## --cr-source resolution

| `--cr-source` (user-provided) | CR rate-limited? | CLI available + authed? | Codex active? | Action |
|---|---|---|---|---|
| `auto` (default) | yes | yes | any | **Silent flip → `cli`**. Spawn Step 7d. |
| `auto` | yes | no | yes | **Silent flip → `codex-only`**. Skip Step 7/7d/8/8d. |
| `auto` | yes | no | no | **AskUserQuestion**: wait NN min / abort / force codex-only (manual). |
| `auto` | no (status silent for other reason) | n/a | n/a | Continue with default `pr-bot` path, Step 6 keeps polling. |
| `pr-bot` | yes | any | any | **No flip.** Continue waiting for rate-limit reset. User chose pr-bot explicitly. Log reset minutes if extracted. |
| `cli` | n/a (Step 6/6b skipped entirely) | yes | any | Step 7d runs unconditionally. |
| `cli` | n/a | no | any | Step 2 pre-flight already aborted (`probe-cr-cli.sh` non-zero). Never reaches here. |
| `codex-only` | n/a (Step 6/7/7b/7d/8/8d skipped) | n/a | yes | Step 6b + 8b only. |
| `codex-only` | n/a | n/a | no | Step 2 pre-flight aborted (no Codex history). Never reaches here. |

## Silent flip semantics

- "Silent" = no `AskUserQuestion`, just log a single line: `cr-source: auto → cli (rate-limit detected, CLI authed)` or `cr-source: auto → codex-only (rate-limit, no CLI)`.
- The `codex-only` flip additionally logs an install suggestion when the CLI is absent, using `probe-cr-cli.sh`'s platform-aware `hint` field (Windows: `irm https://cli.coderabbit.ai/install.ps1 | iex` in PowerShell, native, no admin; macOS: `brew install coderabbit`; Linux: `curl -fsSL https://cli.coderabbit.ai/install.sh | sh`; all followed by `coderabbit auth login`). The suggestion also appears once in the Step 16 final report. The run itself is not interrupted — installing mid-run cannot complete `coderabbit auth login` (browser auth), so the payoff is the NEXT run's rate-limit fallback landing on `cli` instead of `codex-only`.
- The flip is **sticky for the remainder of the run** (not just this iter). A subsequent iter does NOT re-probe the rate-limit reset to flip back. Rationale: rate-limit resets are 5-60 min windows; once the user has invested 1+ iter on CLI/codex-only, paying iters to flip back mid-run causes record-source confusion in the Step 9a table.

## User-explicit modes are final

If the user passes `--cr-source pr-bot|cli|codex-only`, Step 7c **never** silently flips. Rate-limit detection on `pr-bot` falls through to the regular Step 6 timeout path (user gets the timeout error message naming `target_url` and reset minutes).

## Permanent skips

`scripts/sniff-cr-rate-limit.sh` emits `permanent: true` for a skip that no reset window clears — currently `Review skipped: N files exceed the limit of M`. The PR is simply larger than the PR-bot will review, so waiting, re-pushing and re-running all reproduce it.

Step 7c treats a permanent hit as a **source failure**, not a wait:

- `auto` → flip to `cli` (or `codex-only`), exactly as for a genuine rate-limit.
- `pr-bot` → `final_state=rate_limited`. It must never fall through to `clean`: CR posted no findings because it never looked, and a run that converges on that silence merges an unreviewed PR.
- The AskUserQuestion offers **no "wait NN min" option** when `permanent` is true.

## Rate-limit reset extraction

`scripts/sniff-cr-rate-limit.sh` parses these body patterns:

1. `auto-generated comment: rate limited by coderabbit\.ai` — generic, no reset hint.
2. `(?:More reviews will be available in|Next (?:included )?review available in)[^0-9]{0,12}(\d+)\s*minutes?` — extract the digits as `reset_minutes`. All three phrasings occur, and the newer ones are markdown-bold (`**Next included review available in:** **41 minutes**`), which is why the `[^0-9]{0,12}` bridge is needed.
3. `Review limit reached` — generic, no reset hint.

If a reset estimate was extracted, the SKILL.md log line includes it: `... (reset in ~12 minutes)`. The AskUserQuestion "wait NN min" option uses the extracted estimate; if absent, default to 15 min.

## Active query channel (`scripts/query-cr-rate-limit.sh`)

The three patterns above are **passive** — they read whatever CodeRabbit already
posted. When the passive sniff confirms a rate-limit but extracts no reset (a
generic `Review limit reached` with no minutes), SKILL.md Step 7b escalates to an
**active** query rather than defaulting to 15 min: it posts one
`@coderabbitai rate limit` comment and polls issue comments for CodeRabbit's
reply (bounded, default 6 rounds x 20s), then parses `remaining` review count and
`reset_minutes` out of the reply body. It is a companion to — not a replacement
for — the passive sniff, and only fires on the ambiguous case, so the extra
comment is not posted on every rate-limit hit. The parser is exercised in
`tests/run-tests.sh` via the `parse` seam (reply body on stdin, no network).

## `--max-iterations` budget rationale (measured tier)

The default `--max-iterations 5` is a **quota budget**, not just a runaway guard.
Earlier notes tied it to "CR Pro = 5 reviews/hour"; the measured tier is actually
**Pro+ at 10 PR-reviews/hour on a rolling window**, layered with a **Fair-Usage
adaptive decay** — sustained heavy use (roughly 90+ reviews over 7 days) throttles
the effective rate down toward ~1/hour ([Fair Usage Limits Policy](https://docs.coderabbit.ai/management/plans#fair-usage-limits-policy)).
Because cr-fix pushes a burst (one review consumed per iter), the ceiling that
bites is the adaptive-decayed rate, not the nominal 10/hr. Default 5 stays
**conservative under adaptive throttle**: it fits inside the decayed budget for a
developer who is not already near the 7-day cap, while still leaving headroom
below the nominal 10/hr. Raise `--max-iterations` only when the account is known
to be fresh on the rolling window; lower it when recent activity is heavy.

## Active query block (Step 7b)

When the sniff confirmed a rate-limit but extracted no reset estimate (`reset` empty), ask CodeRabbit rather than guess 15 min: the query posts one `@coderabbitai rate limit` comment and polls for the reply. **Once per run** — the post is a non-idempotent external write, so persist the outcome to `STATE_FILE.rate_limit_query` and reuse it on later iterations.

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
  - "pr-bot"     → final_state="rate_limited", break (no flip)
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
  # source the user did not choose is not a safe default.
```

When `cli_hint` is non-empty, the Step 16 summary carries one "install the CodeRabbit CLI" line.

`jq '.cr_source = $src' "$STATE_FILE"` persists the flip. Flip is sticky for remaining iters of this run.

