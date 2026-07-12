# Rate-limit Fallback Decision Table

Triggered by `scripts/sniff-cr-rate-limit.sh` detecting a CR rate-limit comment within ~30s of CR-status silence. SKILL.md Step 7c uses this table.

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
- The flip is **sticky for the remainder of the run** (not just this iter). A subsequent iter does NOT re-probe the rate-limit reset to flip back. Rationale: rate-limit resets are 5-60 min windows; once the user has invested 1+ iter on CLI/codex-only, paying iters to flip back mid-run causes record-source confusion in the Step 9a table.

## User-explicit modes are final

If the user passes `--cr-source pr-bot|cli|codex-only`, Step 7c **never** silently flips. Rate-limit detection on `pr-bot` falls through to the regular Step 6 timeout path (user gets the timeout error message naming `target_url` and reset minutes).

## Rate-limit reset extraction

`scripts/sniff-cr-rate-limit.sh` parses 3 body patterns:

1. `auto-generated comment: rate limited by coderabbit\.ai` — generic, no reset hint.
2. `(?:More reviews will be available in|Next review available in)[^0-9]{0,12}(\d+)\s*minutes?` — extract the digits as `reset_minutes`.
   Both phrasings occur; the newer one is markdown-bold (`**Next review available in:** **41 minutes**`), which is why the
   `[^0-9]{0,12}` bridge is needed. Matching only the older phrasing returned `reset_minutes_estimate: null` on a comment
   that plainly stated 41 minutes.
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
