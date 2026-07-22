#!/usr/bin/env bash
# Stop hook — MECHANICAL capture of ingest candidates at session end.
# Reads the Stop event JSON from stdin (session_id, transcript_path, cwd).
#
# This hook NEVER writes the wiki body. It only refreshes a per-session staging
# file under <root>/.staging/pending-<sid>.md that the next session's SessionStart
# drain hook surfaces for llm-wiki:ingest-finding curation. Capture (mechanical,
# here) and curation (an LLM turn, next session) are deliberately split: a shell
# hook cannot do dedup / conflict-resolution / supersede decisions, so it only
# FLAGS the session and POINTS at the transcript. The transcript is the source of
# truth — this snapshot is a coarse signal index, not extracted lore. Over-capture
# is safe: the ingest-finding dedup gate absorbs it; the staging file is never
# committed (gitignored) and touches no wiki page.
#
# Idempotent across the many Stop firings in one session: the per-session file is
# REGENERATED (not appended) each run, keyed by session_id, with a short rate-limit
# so rapid consecutive turns don't re-scan a large transcript. No-op when no wiki
# root resolves. mem0 is never read or written — this path is fully decoupled.
#
# Disable by setting WIKI_SESSION_CAPTURE=0, or remove the Stop entry from plugin.json.
#
# Shell portability (see plugins/llm-wiki/CLAUDE.md): LC_ALL=C.UTF-8 around grep -E,
# BSD/GNU stat + date fallbacks, cksum (POSIX) for the per-session marker.

set -u
exec 2>/dev/null  # discard stderr — hooks should never spam the user

[[ "${WIKI_SESSION_CAPTURE:-1}" == "0" ]] && exit 0

input_json=$(cat 2>/dev/null || true)
[[ -z "$input_json" ]] && exit 0

# --- extract Stop fields (jq preferred, grep fallback) ---
extract() { # $1=key
  local key="$1" v=""
  if command -v jq >/dev/null 2>&1; then
    v=$(printf '%s' "$input_json" | jq -r --arg k "$key" '.[$k] // empty' 2>/dev/null)
  fi
  # BSD grep has no -P/\K. awk match() finds the FIRST "$key":"..." (a greedy sed
  # `.*` would select the LAST). $key is a fixed literal from the caller (cwd/…),
  # passed via -v so it is not a regex; portable across GNU/BSD awk.
  [[ -z "$v" ]] && v=$(printf '%s' "$input_json" | LC_ALL=C.UTF-8 awk -v k="$key" '
    match($0, "\"" k "\"[[:space:]]*:[[:space:]]*\"") {
      s = substr($0, RSTART + RLENGTH)
      if (match(s, /"/)) { print substr(s, 1, RSTART - 1); exit }
    }')
  printf '%s' "$v"
}
cwd=$(extract cwd)
# SubagentStop carries BOTH transcript_path (the PARENT session's transcript) and
# agent_transcript_path (this subagent's OWN transcript, written and present at fire
# time — verified empirically). Prefer the agent transcript so a subagent capture
# records the delegated work the parent Stop never sees; scanning transcript_path
# would just duplicate the main Stop capture. The main Stop event has no
# agent_transcript_path, so it falls through to transcript_path as before. When a
# subagent has no persisted transcript (agent_transcript_path names a missing file),
# the -f guard below no-ops rather than falling back to the redundant parent.
transcript=$(extract transcript_path)
agent_transcript=$(extract agent_transcript_path)
[[ -n "$agent_transcript" ]] && transcript="$agent_transcript"
session_id=$(extract session_id)
# Present only on SubagentStop — used below to key this subagent's capture separately
# from the parent session's (they share session_id). Empty on the main Stop event.
agent_id=$(extract agent_id)
# cd into the event cwd when given; exit gracefully if the cd itself fails (race /
# permission) so we never scan from the wrong directory. Empty cwd is intentional —
# fall through to PWD (the harness launches the hook there).
[[ -n "$cwd" && -d "$cwd" ]] && { cd "$cwd" || exit 0; }

# --- canonical wiki-root resolver (llm-wiki v2) ---
# Resolution order: .llmwiki/wiki (preferred) -> .claude/wiki (legacy) -> .codex/wiki (legacy fork)
# A candidate counts only if it carries an init signal (index.md or log.md).
resolve_wiki_root() {
  local cand
  for cand in ".llmwiki/wiki" ".claude/wiki" ".codex/wiki"; do
    if [[ -f "$cand/index.md" || -f "$cand/log.md" ]]; then printf '%s\n' "$cand"; return 0; fi
  done
  return 1
}
wiki_root="$(resolve_wiki_root)" || exit 0

# Need a readable transcript to scan; without it we cannot point the curator at anything.
[[ -n "$transcript" && -f "$transcript" ]] || exit 0

# Sanitize session id for use in a filename / marker.
[[ -n "$session_id" ]] || session_id="unknown"
sid=$(printf '%s' "$session_id" | LC_ALL=C.UTF-8 tr -c 'A-Za-z0-9._-' '_')

# When fired as SubagentStop, key the marker + staging file by session_id AND agent_id
# so a subagent capture cannot collide with the parent Stop capture (they may share
# session_id). Main Stop has no agent_id -> unkeyed, preserving pending-<sid>.md.
if [[ -n "$agent_id" ]]; then
  aid=$(printf '%s' "$agent_id" | LC_ALL=C.UTF-8 tr -c 'A-Za-z0-9._-' '_')
  marker="/tmp/wiki_session_capture.${sid}.${aid}"
  pending_basename="pending-${sid}-${aid}.md"
else
  marker="/tmp/wiki_session_capture.${sid}"
  pending_basename="pending-${sid}.md"
fi

# Rate-limit: at most once per 90s per session/agent (Stop fires every assistant turn).
if [[ -f "$marker" ]]; then
  age=$(( $(date +%s) - $(stat -c %Y "$marker" 2>/dev/null || stat -f %m "$marker" 2>/dev/null || echo 0) ))
  [[ $age -lt 90 ]] && exit 0
fi
touch "$marker"

# --- mechanical signal detection over the transcript (heuristic, intentionally coarse) ---
# Bound the scan: read at most the last 4 MB of the transcript (tail -c seeks, so the
# read is O(cap) not O(filesize)) and grep that, so a pathological multi-MB session
# stays well under the 5s hook timeout. Piping tail straight into each grep means there
# is NO failure path that falls back to an unbounded full-file scan — a failed tail just
# yields an empty stream (zero counts, degrading safely), never the whole file. The
# recent, ingest-relevant turns are at the tail; the full transcript path is still
# recorded in the staging file, so the curator always reads the complete source — this
# cap only bounds the coarse fire/no-fire heuristic.
scan_cap=$((4 * 1024 * 1024))
scan() { tail -c "$scan_cap" "$transcript" 2>/dev/null; }

# grep -c prints a count to stdout (and exits 1 on zero matches, swallowed by $()).
# Kept as 3 separate greps (not one alternation) so per-category counts survive for
# the staging signal breakdown below.
merge_hits=$(scan | LC_ALL=C.UTF-8 grep -cE 'gh pr merge|git merge|Merged pull request|"merged":[[:space:]]*true' 2>/dev/null)
debug_hits=$(scan | LC_ALL=C.UTF-8 grep -ciE 'root cause|근본 원인|원인은|the bug was|fixed by|race condition|provider quirk|deadlock|off-by-one' 2>/dev/null)
decision_hits=$(scan | LC_ALL=C.UTF-8 grep -ciE 'decided to|trade-?off|왜냐하면|the reason is|rationale|we chose|design decision' 2>/dev/null)
merge_hits=${merge_hits:-0}; debug_hits=${debug_hits:-0}; decision_hits=${decision_hits:-0}

pr_refs=$(scan | LC_ALL=C.UTF-8 grep -oE 'PR #[0-9]+|pull/[0-9]+' 2>/dev/null \
          | LC_ALL=C.UTF-8 grep -oE '[0-9]+' | sort -un | head -10 | tr '\n' ' ')

# Fire only when the session plausibly produced lore: a real merge, OR several
# debugging/decision signals. Below threshold -> no staging file (avoid churn).
weak_score=$(( debug_hits + decision_hits ))
if (( merge_hits == 0 )) && (( weak_score < 3 )); then
  exit 0
fi

# --- write the per-session staging file (regenerate; never touch the wiki body) ---
staging_dir="$(dirname "$wiki_root")/.staging"
mkdir -p "$staging_dir" || exit 0
today=$(date +%Y-%m-%d)
recent_commits=$(git log --oneline -5 2>/dev/null || true)
pending_file="$staging_dir/${pending_basename}"

{
  printf -- '---\n'
  printf 'session: %s\n' "$session_id"
  [[ -n "$agent_id" ]] && printf 'agent_id: %s\n' "$agent_id"
  printf 'captured: %s\n' "$today"
  printf 'transcript: %s\n' "$transcript"
  printf 'cwd: %s\n' "$PWD"
  printf 'signals: merge=%s debug=%s decision=%s\n' "$merge_hits" "$debug_hits" "$decision_hits"
  printf 'pr_refs: %s\n' "${pr_refs:-none}"
  printf -- '---\n\n'
  printf '# Pending wiki-ingest candidate — session %s\n\n' "$sid"
  printf 'This session showed ingest-candidate signals at session end. It was captured\n'
  printf 'MECHANICALLY by the Stop hook — the wiki body was NOT touched. The transcript\n'
  printf '(above) is the source of truth; the counts below are a coarse index, not lore.\n\n'
  printf '## Detected signals\n'
  printf -- '- merge events: %s\n' "$merge_hits"
  printf -- '- debugging-conclusion lines: %s\n' "$debug_hits"
  printf -- '- decision/rationale lines: %s\n' "$decision_hits"
  printf -- '- PR refs: %s\n\n' "${pr_refs:-none}"
  printf '## Recent commits (current branch)\n'
  if [[ -n "$recent_commits" ]]; then printf '%s\n\n' "$recent_commits"; else printf '(none)\n\n'; fi
  printf '## How to curate (next session, via llm-wiki:ingest-finding)\n'
  printf -- '1. Read the transcript above (or recall this session).\n'
  printf -- '2. For each non-obvious lore item (provider quirk, debugging cause, design\n'
  printf -- '   rationale, decision + why) run the ingest-finding dedup gate — decide\n'
  printf -- '   update / supersede / new-page / skip per the diff-log-first rule.\n'
  printf -- '3. After ingesting (or deciding nothing is worth it), DELETE this file.\n'
} > "$pending_file" 2>/dev/null

exit 0
