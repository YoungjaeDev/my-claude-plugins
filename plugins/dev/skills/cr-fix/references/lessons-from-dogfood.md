# Lessons from cr-fix v2 Dogfood (PR #33)

8-iter self-review run captured the limits of v2's autonomous judgment + convergence model. Each lesson below is grounded in an observed pattern from the run, with both the failure mode and a concrete next-step recommendation.

Skip-this-file context: these are **prospective improvements** for cr-fix v3 / follow-up PRs, not active design constraints. SKILL.md / pre-flight.sh keep the v2 contract intact.

## Run summary (PR #33 dogfood)

| iter | apply | defer | new findings (Codex P-level / CR) |
|------|------:|------:|---|
| 1 | 4 | 0 | P2×2 + self-found×2 |
| 2 | 5 | 1 | P1 + P2 + CR Major×2 + Minor |
| 3 | 2 | 0 | P2×2 (logic gap + doc-code mismatch) |
| 4 | 2 | 1 | P2×2 + repeat |
| 5 | 1 | 1 | P2 + repeat |
| 6 | 1 | 0 | P2 |
| 7 | 2 | 1 | P2 + CR Minor + repeat |
| 8 | 1 | 1 | P2 + repeat |
| **total** | **18** | **5** | |

Apply curve: `4 → 5 → 2 → 2 → 1 → 1 → 2 → 1` — monotone-decreasing-ish but never reaches zero in 8 iters. Convergence never naturally triggered.

## Lesson 1 — Plateau detection (CRITICAL)

**Pattern**: v1/v2 only converge on `applied=0 AND deferred=0`. When every fix introduces ≤ 2 new sharp edges, the loop runs indefinitely.

**Failure mode**: Run cost = O(iter × wait + iter × process). On PR #33 a single iter took 4-8 min wait + 5-10 min processing. The 8-iter run consumed ~100 minutes for diminishing-return polish.

**Recommendation**: Add `--plateau-iter <N>` flag (default 3). Stop when:
- N consecutive iters had `applied_this_cycle ≤ 1`, AND
- the same `(path, line, src)` defer repeats in ≥ 2 of those iters.

Surface in final JSON: `"plateau_break": true`.

## Lesson 2 — Defer-repeat dedupe (HIGH)

**Pattern**: `sniff-cr-rate-limit.sh:33` deferred at iter 2 was re-judged from scratch at iters 4, 5, 7, 8 — 4 redundant LLM judgments, all reaching the same `defer (contract change)` conclusion.

**Failure mode**: v2's state file tracks `codex_processed_reviews` (review-id dedupe) but NOT finding-level dedupe. Every iter re-enters the matrix for the same defer.

**Recommendation**: State file gains `deferred_findings: [{path, line, src, iter, reason}]`. Step 9c front-loads a check:

```
key = "{src}:{path}:{line}"
if key in deferred_findings AND iters_since(key) <= 3:
  auto_judge_skip++
  log "repeat-defer (iter N)"
  continue
```

## Lesson 3 — Soft vs hard MAX_ITER (MEDIUM)

**Pattern**: User instructed "ralph 끝까지" — v2 honored it past MAX_ITER=5 cap, but there was no documented escape valve.

**Failure mode**: Two distinct user intents conflated under one flag — "stop after N iters no matter what" vs "stop when plateau detected within N iters".

**Recommendation**: Split into:
- `--max-iter <N>` — hard stop, default 5 (a conservative CR quota budget — see Lesson 5 and `references/rate-limit-fallback.md`).
- `--plateau-iter <N>` — soft stop, default 3 iters of plateau (Lesson 1 condition).

Hard cap always wins. If neither triggers, run continues.

## Lesson 4 — Active polishing zone (MEDIUM)

**Pattern**: 5 of 8 iters produced Codex findings on `pre-flight.sh` or `SKILL.md` — the same files we kept editing. Each fix surface attracted the next finding.

**Failure mode**: Self-feeding loop is structurally unavoidable in dogfooding scenarios, but v2 doesn't tag it.

**Recommendation**: Track per-iter `(path → finding-count)`. When the same path produces a finding in 3 consecutive iters, mark it as **active polishing zone**:
- Subsequent findings on that path auto-defer (`reason: "active-polishing-zone"`).
- Surface in iter summary: `iter 6: applied=1, active-polishing-zone=plugins/dev/skills/cr-fix/SKILL.md`.

## Lesson 5 — CR rate-limit understanding (CORRECTED)

**Initial pattern observation**: `cr_state: success` + `cr_desc: "Review completed"` toggled with `cr_desc: "Review skipped: free tier disabled"` across the 8 iters (5 reviewed / 3 skipped).

**Initial misreading**: We considered adding a cooldown that skips sniff for K iters after a rate-limit hit. After consulting [CR docs](https://docs.coderabbit.ai/management/plans), this is **wrong**:

- "Free tier disabled" is misleading — it does NOT mean the org reverted to Free. It means **trial/Pro hourly quota temporarily exhausted under progressive refill** ([Fair Usage Limits Policy](https://docs.coderabbit.ai/management/plans#fair-usage-limits-policy)).
- CR uses **progressive refill** (reviews trickle back, not a 60-minute reset).
- Wait time depends on recent activity per developer.

**Failure mode**: cr-fix's multi-iter loop is structurally a **burst-push pattern** (8 push in ~10 min on PR #33). The measured tier is Pro+ (10 PR-reviews/hr on a rolling window) with Fair-Usage adaptive decay that throttles heavy 7-day usage toward ~1/hr, so the ceiling that actually bites is the decayed rate, not the nominal 10/hr; the iter cap of 5 sits conservatively under it.

**Recommendation**:
- Treat `--max-iter` as a **quota budget**, not a retry cap. Default 5 is conservative under Pro+ (10/hr rolling) with Fair-Usage adaptive decay — full rationale in `references/rate-limit-fallback.md`.
- Add `--push-spacing <sec>` (default `0`) to enforce minimum interval between consecutive pushes, throttling burst patterns. CR Pro+/Enterprise users can keep `0`.
- pre-flight description should distinguish "rate-limited (progressive refill in progress)" from "rate-limited (hard cap)" — currently both produce identical `gate=rate_limited`.

## Lesson 6 — Mid-run summary (LOW)

**Pattern**: defer-repeat (5×) was invisible to the user until final JSON.

**Failure mode**: A user watching the run can't tell whether the LLM is making good autonomous decisions until everything is over.

**Recommendation**: Emit a 1-line summary at the end of each iter:

```
iter 5: applied=1, deferred=1 (sniff:33 5th repeat — contract-change), processed 1 Codex review
```

Goes to stderr (won't disturb the final JSON contract on stdout). Already trivially possible via `STATE_FILE.auto_judge_log` post-processing — just needs a per-iter flush.

## Out of scope for this PR

These six lessons are not addressed in this PR. They are documented here as the next milestone for cr-fix. Follow-up PR title suggestion:

> `feat(github-dev): cr-fix v2.1 — plateau detection + repeat-defer dedupe + push-spacing`

## How to read this file

If you are running a multi-iter cr-fix and notice:
- Same finding deferred for 3+ iters → Lesson 2 applies; consider manual thread resolve.
- 5+ iters without `applied=0` → Lesson 1 applies; consider Ctrl-C + manual review.
- CR oscillation in `cr_desc` → Lesson 5; that's normal CR progressive refill, not a bug.

For the active design contract (what v2 currently does), see `SKILL.md` and `references/autonomous-judgment.md`.
