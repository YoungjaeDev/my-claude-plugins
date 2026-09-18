# Leftover-review surface blocks (Step 1.5)

The three blocks Step 1.5 of `SKILL.md` runs, in order. The decision rules around them stay in the skill body.

## Primary signal: the cr-fix state file

Check the live path first, then the latest archive:

```bash
CRF="$MAIN_REPO/.claude/state/cr-fix-${PR_NUMBER}.json"
[ -f "$CRF" ] || CRF=$(ls -1t "$MAIN_REPO/.claude/state/archive/cr-fix-${PR_NUMBER}-"*.json 2>/dev/null | head -1)
if [ -n "${CRF:-}" ] && [ -f "$CRF" ]; then
  CRF_FINAL=$(jq -r '.final_state // "unknown"' "$CRF")
  # deferred findings, audit detail: path:line + severity + reason
  DEFERS=$(jq -c '[.auto_judge_log[]? | select(.action=="defer")
    | {path, line, sev: .badge_or_sev, reason}]' "$CRF")
  # prefer the persisted stat; fall back to counting defer entries in the log for
  # archives written before cr-fix persisted final fields (auto_judge_stats absent).
  DEFER_N=$(jq -r '.auto_judge_stats.defer // ([.auto_judge_log[]? | select(.action=="defer")] | length)' "$CRF")
else
  CRF_FINAL=""; DEFER_N=0; DEFERS='[]'
fi
```

## Secondary signal (advisory): open CR review threads on the merged PR

```bash
# --paginate emits one JSON array PER page; piping to `jq -s 'add'` slurps every
# page into a single array before counting. Using `--jq length` here would instead
# print a per-page count ("30\n5") and break the OPEN_THREADS > 0 test below.
OPEN_THREADS=$(gh api --paginate "repos/{owner}/{repo}/pulls/${PR_NUMBER}/comments" 2>/dev/null \
  | jq -s 'add // [] | [.[] | select(.in_reply_to_id == null)] | length' 2>/dev/null || echo 0)
```

## Decide the checkpoint line

```bash
case "$CRF_FINAL" in
  iteration_cap|timeout|cli_failed|rate_limited|reviewers_unavailable) CAP_TRIGGER=1 ;;
  *) CAP_TRIGGER=0 ;;
esac
if [ "$DEFER_N" -gt 0 ] || [ "$CAP_TRIGGER" = 1 ]; then
  echo "leftover-reviews: ${DEFER_N} deferred (final_state=${CRF_FINAL:-none})"
else
  echo "leftover-reviews: none"
fi
```
