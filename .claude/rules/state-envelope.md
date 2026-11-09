---
paths: .claude/state/*.json
---

# State-Envelope Run Records (v0)

The schema of the per-run state file a long multi-step skill writes, so a step that was skipped silently is visible afterwards and a re-run can find and archive the prior attempt. The 2 v0 adopters are `dev:post-merge` (per-step records) and `dev:new` (Phase 0.5 run record with resume and fail-loud writes).

v0 is a documented convention plus per-skill `jq`: each adopting skill inlines its own snippets, and there is no shared library or script. Keep it that way at v0.

## Location and rotation

- Live file: `.claude/state/<pipeline>-<key>.json` (for example `.claude/state/post-merge-114.json`), the same naming as `.claude/state/review-loop-<PR>.json`.
- On a re-run for the same key, archive the prior live file to `.claude/state/archive/<pipeline>-<key>-<timestamp>-$$.json` before writing a fresh one. The timestamp plus `$$` keeps a same-second or parallel run from clobbering an archived copy.
- `.claude/state/` is gitignored and machine-local. A run record is never staged, committed, or added to a skill's `RUN_TOUCHED` staging set.

## Schema

```json
{
  "schema": "state-envelope/v0",
  "run_id": "<pipeline>-<key>",
  "status": "queued | in_progress | completed",
  "conclusion": "<free string once terminal, else null>",
  "started_at": "<UTC ISO-8601>",
  "updated_at": "<UTC ISO-8601>",
  "anchor_sha": "<the commit this run is anchored to, or null>",
  "attempt": 1,
  "session_id": "<host session id, or null>",
  "steps": [
    { "step": 1, "status": "done" },
    { "step": 5, "status": "skipped", "reason": "no GitHub Project" }
  ]
}
```

- `status` moves `queued` / `in_progress` → `completed`; `conclusion` stays `null` until terminal.
- `steps[]` carries one entry per top-level step as it closes: `{step, status: done|skipped, reason?}`.
  `reason` is required on `skipped`, omitted on `done`. Sub-steps fold into their parent
  top-level step's entry.

## Per-skill jq (no shared library)

An adopting skill inlines these three moves directly in its body, with no sourced
helper file. Reference adopter: `dev:post-merge`.

Init (once the run's key + anchor sha are known):

```bash
REC=".claude/state/<pipeline>-<key>.json"
mkdir -p .claude/state/archive
if [ -f "$REC" ]; then
  mv "$REC" ".claude/state/archive/<pipeline>-<key>-$(date +%Y%m%d-%H%M%S)-$$.json" \
    || { echo "state-envelope: archive rotation failed for $REC — aborting so the next write cannot clobber the only live copy" >&2; exit 1; }
fi
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n --arg rid "<pipeline>-<key>" --arg sha "$ANCHOR_SHA" --arg now "$NOW" \
  '{schema:"state-envelope/v0", run_id:$rid, status:"in_progress", conclusion:null,
    started_at:$now, updated_at:$now, anchor_sha:($sha // null), attempt:1,
    session_id:(env.CLAUDE_SESSION_ID // null), steps:[]}' > "$REC"
```

Record one step as it closes (`reason` only on a skip):

```bash
record_step() {  # <n> <done|skipped> [reason]
  if [ "$2" = "skipped" ] && [ -z "${3:-}" ]; then
    echo "state-envelope: a skipped step needs a reason" >&2; return 1
  fi
  local tmp; tmp=$(mktemp)
  jq --argjson step "$1" --arg status "$2" --arg reason "${3:-}" \
     --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     '.updated_at = $now
      | .steps += [ {step: $step, status: $status}
                    + (if $reason == "" then {} else {reason: $reason} end) ]' \
     "$REC" > "$tmp" && mv "$tmp" "$REC"
}
```

Finalize when the last step closes:

```bash
tmp=$(mktemp)
jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '.status = "completed" | .conclusion = "success" | .updated_at = $now' \
  "$REC" > "$tmp" && mv "$tmp" "$REC"
```
