#!/usr/bin/env bash
# SessionStart hook — DRAIN pending wiki-ingest captures from prior sessions.
# Reads SessionStart JSON from stdin (non-blocking). Emits additionalContext.
#
# If <root>/.staging/ holds pending-*.md files (written by the Stop capture hook at
# the end of EARLIER sessions), this hook injects a STRONG directive telling THIS
# session to process them through the llm-wiki:ingest-finding dedup gate, then
# delete the consumed files. This is the curation half of the auto-capture path:
# capture is mechanical (Stop hook), curation is an LLM turn (surfaced here). The
# hook itself NEVER writes or curates the wiki — it only surfaces the work. A
# session never drains its OWN capture (Stop writes at the end; this fires at the
# start of the NEXT session), preserving the capture/curation separation.
#
# No-op when no wiki root resolves or no pending files exist. Rate-limited per cwd
# so rapid /clear / resume doesn't re-inject. mem0 is never touched.
#
# Disable by setting WIKI_SESSION_DRAIN=0, or remove the entry from plugin.json.
#
# Shell portability (see plugins/llm-wiki/CLAUDE.md): BSD/GNU stat fallback, cksum
# (POSIX) for the per-cwd marker, JSON encoding via parameter expansion (no jq dep
# for the emit path).

set -u
exec 2>/dev/null  # discard stderr — hooks should never spam the user

[[ "${WIKI_SESSION_DRAIN:-1}" == "0" ]] && exit 0

input_json=$(cat 2>/dev/null || true)
if [[ -n "$input_json" ]] && command -v jq >/dev/null 2>&1; then
  cwd=$(printf '%s' "$input_json" | jq -r '.cwd // empty' 2>/dev/null)
  # exit gracefully if the cd itself fails (race / permission); empty cwd falls
  # through to PWD intentionally.
  [[ -n "$cwd" && -d "$cwd" ]] && { cd "$cwd" || exit 0; }
fi

# --- canonical wiki-root resolver (llm-wiki v2) ---
resolve_wiki_root() {
  local cand
  for cand in ".llmwiki/wiki" ".claude/wiki" ".codex/wiki"; do
    if [[ -f "$cand/index.md" || -f "$cand/log.md" ]]; then printf '%s\n' "$cand"; return 0; fi
  done
  return 1
}
wiki_root="$(resolve_wiki_root)" || exit 0

staging_dir="$(dirname "$wiki_root")/.staging"
[[ -d "$staging_dir" ]] || exit 0

# Collect pending capture files (this hook only acts on the Stop hook's pending-*.md).
shopt -s nullglob
pending=( "$staging_dir"/pending-*.md )
shopt -u nullglob
(( ${#pending[@]} > 0 )) || exit 0

# Rate-limit: re-inject at most once per 900s per cwd (avoid /clear / resume spam).
# The pending files themselves are the real gate — once curated + deleted, this hook
# falls silent regardless of the marker.
marker="/tmp/wiki_session_drain.$(printf '%s' "$PWD" | cksum | cut -d' ' -f1)"
if [[ -f "$marker" ]]; then
  age=$(( $(date +%s) - $(stat -c %Y "$marker" 2>/dev/null || stat -f %m "$marker" 2>/dev/null || echo 0) ))
  [[ $age -lt 900 ]] && exit 0
fi
touch "$marker"

n=${#pending[@]}
list=""
for f in "${pending[@]}"; do list+=$'\n'"- $f"; done

msg="[wiki-drain] ${n} pending wiki-ingest candidate(s) were captured at the end of prior session(s) and await curation:${list}"
msg+=$'\n'"BEFORE other work this session, process each through the llm-wiki:ingest-finding dedup gate: read the file (it points at the source transcript + detected signals), decide ingest / update / supersede / skip per the diff-log-first rule, then DELETE the consumed file. The Stop hook only captured mechanically — nothing has entered the wiki yet, so this is the step that actually curates it."

# JSON-escape: backslash, double-quote, then newline -> \n.
esc=${msg//\\/\\\\}
esc=${esc//\"/\\\"}
esc=${esc//$'\n'/\\n}
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$esc"

exit 0
