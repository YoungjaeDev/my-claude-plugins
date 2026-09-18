# Run Record (Step 1 + Step 10)

Every post-merge run opens a per-run record so each step's outcome is machine-visible: a step that
skipped **silently** is otherwise invisible. Convention + schema: `.claude/rules/state-envelope.md`
(concept mirror in `AGENTS.md`).

There is no shared library — the `jq` below is the whole mechanism. The file lives under gitignored
`.claude/state/`, so it is machine-local and is **never** staged (never added to Step 10's
`RUN_TOUCHED`).

## Open the record (Step 1)

Run once `PR_NUMBER` and `MERGE_SHA` are fixed.

```bash
# Fail closed on an empty PR_NUMBER: an unset variable would silently write
# .claude/state/post-merge-.json and label the run record `post-merge-`.
: "${PR_NUMBER:?Step 1: set PR_NUMBER to the merged PR number before opening the record}"
# The main repo's state dir, also from inside a worktree (SKILL.md Guidelines, Worktree mode).
MAIN_REPO=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
REC="$MAIN_REPO/.claude/state/post-merge-${PR_NUMBER}.json"
mkdir -p "$MAIN_REPO/.claude/state/archive"
# Archive a prior same-PR record before overwriting (mirrors cr-fix Step 2).
# Fail closed: a failed archive must abort init, else the jq below clobbers the only live copy.
if [ -f "$REC" ]; then
  mv "$REC" "$MAIN_REPO/.claude/state/archive/post-merge-${PR_NUMBER}-$(date +%Y%m%d-%H%M%S)-$$.json" \
    || { echo "post-merge: archiving the prior run record failed — aborting to avoid clobbering it" >&2; exit 1; }
fi
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n --arg rid "post-merge-${PR_NUMBER}" --arg sha "$MERGE_SHA" --arg now "$NOW" \
  '{schema:"state-envelope/v0", run_id:$rid, status:"in_progress", conclusion:null,
    started_at:$now, updated_at:$now, anchor_sha:($sha // null), attempt:1,
    session_id:(env.CLAUDE_SESSION_ID // null), steps:[]}' > "$REC"

# record_step <n> <done|skipped> [reason] — append one entry, bump updated_at.
record_step() {
  if [ "$2" = "skipped" ] && [ -z "${3:-}" ]; then
    echo "post-merge: a skipped step needs a reason" >&2; return 1
  fi
  local tmp; tmp=$(mktemp)
  jq --argjson step "$1" --arg status "$2" --arg reason "${3:-}" \
     --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     '.updated_at = $now
      | .steps += [ {step: $step, status: $status}
                    + (if $reason == "" then {} else {reason: $reason} end) ]' \
     "$REC" > "$tmp" && mv "$tmp" "$REC"
}
record_step 1 done
```

## Recording contract

Append each top-level step's outcome as it closes. **Shell state does not persist across separate
tool calls**: `REC` is the deterministic path `$MAIN_REPO/.claude/state/post-merge-<PR>.json`, so in the
bash block that closes a later step, re-derive `MAIN_REPO`, re-set `REC` and re-declare `record_step`
(copy them from above) before calling it.

Sub-steps fold into their parent entry: 1.5 into 1, 4.5 and 4.6 into 4, 6.5 into 6.

| Step | `done` | `skipped "<reason>"` |
|---|---|---|
| 1 | always | — |
| 2 | always | — |
| 3 | always | — |
| 4 | always (folds 4.5, 4.6) | — |
| 5 | Project status set | `no GitHub Project` / `issue not in the project` |
| 5.5 | milestone table regenerated | `no milestone` |
| 5.7 | `spec.json` entry moved | `no spec.json entry` |
| 6 | always (folds 6.5) | — |
| 7 | Serena memory updated | `Serena unavailable` / `Codex — Serena unavailable` |
| 8 | always — mandatory, records `done` even on the `no-lore` path | — |
| 9 | whenever the About check fired, README edit or not | `no README changes` only when the About check also could not run (no `gh` auth, no remote) |
| 9.5 | CHANGELOG entry added | `no CHANGELOG` / `not changelog-worthy` |

Step 11 only prints the worktree cleanup command after the record is finalized; it is not recorded.

A skip reason must name **which** condition fired; collapsing two conditions into one reason loses
why the step skipped.

## Finalize (Step 10)

Records the closing step and marks the envelope terminal. Step 10 is a fresh shell, so re-set
`PR_NUMBER` first; `record_step` is not used here — the append and the finalize are inlined.

```bash
# Step 10 runs in a fresh shell — neither PR_NUMBER nor record_step from Step 1 persist.
# Re-set PR_NUMBER (the merged PR number) so REC points at the real record, not
# .claude/state/post-merge-.json; the :? guard fails loud if it is empty.
MAIN_REPO=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
REC="$MAIN_REPO/.claude/state/post-merge-${PR_NUMBER:?Step 10: re-set PR_NUMBER to the merged PR number before finalizing}.json"
tmp=$(mktemp)
jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '.steps += [{step: 10, status: "done"}]
   | .status = "completed" | .conclusion = "success" | .updated_at = $now' \
  "$REC" > "$tmp" && mv "$tmp" "$REC"
```
