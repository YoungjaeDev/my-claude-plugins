---
paths: .claude/state/*.json
---

# State-Envelope Run Records (v0)

Convention for the per-run state files a long multi-step skill writes to make its own
progress machine-inspectable. v0 is a **documented convention plus per-skill `jq`** —
there is deliberately **no shared library or script**. Each adopting skill inlines its
own `jq` snippets; this file is only the schema they agree on.

## Role

Give multi-step pipeline skills a uniform run-record shape so a step that skipped
**silently** is visible after the fact, and so a re-run can find and archive the prior
attempt. Introduced narrow: the v0 adopters are `github-dev:post-merge` (per-step
records) and `project-init:new` (Phase 0.5 run record with resume + fail-loud writes).
Retrofitting other skills' state files onto this envelope is deliberately deferred to
a later change.

## Location & rotation

- Live file: `.claude/state/<pipeline>-<key>.json` — e.g. `.claude/state/post-merge-114.json`,
  mirroring the existing `.claude/state/cr-fix-<PR>.json` naming.
- On a re-run for the same key, archive the prior live file to
  `.claude/state/archive/<pipeline>-<key>-<timestamp>-$$.json` before writing a fresh
  one (mirrors `cr-fix` Step 2 — the timestamp + `$$` suffix keeps a same-second or
  parallel run from clobbering an archived copy).
- `.claude/state/` is **gitignored and machine-local**. A run record is never staged,
  committed, or added to a skill's `RUN_TOUCHED` staging set.

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

## Orthogonality to spec-state

A state-envelope run record is **not** `.claude/state/spec.json`. `spec.json` (owned by
`spec-state:state-tracker`) is the cross-run aggregate of spec → issue → PR pipeline work.
A run record is a **single skill run's own step log**. They are separate files with
separate owners: a state-envelope record never reads or writes `spec.json`, and the
spec aggregate never carries per-run step logs.

## Per-skill jq (no shared library)

An adopting skill inlines these three moves directly in its body — there is no sourced
helper file. Reference adopter: `github-dev:post-merge`.

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

## Don'ts

- Never promote this into a shared library/script at v0 — a narrow per-skill convention is the point.
- Never commit a run record — `.claude/state/` is gitignored; keep it out of any commit staging set.
- Never overload `spec.json` with per-run step logs — that file is a different concern (see above).
