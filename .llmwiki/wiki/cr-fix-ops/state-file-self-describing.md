---
id: cr-fix-state-file-self-describing
aliases: [cr-fix-emit-final-json-persist, cr-fix-archived-state, post-merge-leftover-state-read]
last_verified: 2026-06-16
status: active
volatility: stable
sources: 1
---

# cr-fix state file is not self-describing unless emit-final-json persists final fields

## The trap

cr-fix's `scripts/emit-final-json.sh` runs as the bash `EXIT` trap. The *final summary* fields a downstream reader cares about — `final_state`, `auto_judge_stats` (`{apply, defer, skip}`), applied/deferred totals — are derived from trap env vars and assembled into the **stdout JSON line**. They were never written back into the state file. The trap then `mv`s the live `.claude/state/cr-fix-<PR>.json` to `.claude/state/archive/cr-fix-<PR>-<ts>.json` **as-is**.

So the archived state file carries only what the run *initialized + appended* (Step 2 init: `start_sha`, `iter`, `cr_source`, `pre_flight_decisions`, `auto_judge_log`; per-iter appends). It does **not** carry `final_state` or `auto_judge_stats`.

## Why it bit

`post-merge` Step 1.5 (leftover-review surface) reads the cr-fix state file — and the **archived** copy is the usual hit, because the trap already moved the live file. Reading the archive:

- `jq '.final_state // "unknown"'` → `unknown` (field absent)
- `jq '.auto_judge_stats.defer // 0'` → `0` (field absent)

even when `auto_judge_log` held `action=="defer"` entries. The surface therefore printed `leftover-reviews: none` and **silently hid deferred reviews** — defeating the feature whose entire job is to make deferred/cap-stopped findings visible after a merge.

A synthetic unit test had given a false pass: the fixture was hand-built **with** `final_state`/`auto_judge_stats`, fields the real file lacks. The bug only surfaced when the cr-fix dogfood (PR #62) ran the real producer → real archive → real consumer chain (Codex P1).

## The rule

A producer that emits derived fields **only to stdout** creates a silent producer/consumer contract gap for any consumer that reads its **file**. Two-sided fix:

1. **Producer side (authoritative):** `emit-final-json.sh` writes `final_state` + `auto_judge_stats` + applied/deferred totals into the state file **before** the archive `mv`, making the archived copy self-describing. Guard the `jq` rewrite so a failure keeps the un-enriched file rather than losing it (trap context — must not throw).
2. **Consumer side (defensive):** still fall back to counting `auto_judge_log` `action=="defer"` entries when `auto_judge_stats` is absent — archives written before the producer fix have only the log.

Test the real producer → archive → consumer chain, not a hand-built fixture; a fixture that assumes the persisted shape can mask exactly this class of bug.

> See-also: [[cr-rate-limit-progressive-refill]]
> Evidence: PR #62 (merge `99e4bbf`) — `plugins/github-dev/skills/cr-fix/scripts/emit-final-json.sh`, `plugins/github-dev/skills/post-merge/SKILL.md` (Step 1.5).

## Scope note

The cr-fix `minor_floor` soft-stop and bounded same-file generalization are **active design contract**, documented in `plugins/github-dev/skills/cr-fix/references/autonomous-judgment.md` + `failure-modes.md` — not lore, and deliberately not duplicated here.

## Sources

- PR #62 dogfood (2026-06-16): Codex P1 on `post-merge/SKILL.md` Step 1.5; fix in `emit-final-json.sh` + consumer fallback. Merge `99e4bbf`.
