#!/usr/bin/env bash
# PostToolUse hook (matcher: Bash) — soft-hint when a git commit/push touched files
# the wiki should know about. Reads tool_input JSON from stdin.
# Quiet unless we're confident the LLM should consider /llm-wiki:ingest-finding or /github-dev:post-merge.

set -u
exec 2>/dev/null

# Read tool_input JSON from stdin
input_json=$(cat 2>/dev/null || true)
[[ -z "$input_json" ]] && exit 0

# Extract the bash command (jq if available, else grep fallback)
cmd=""
if command -v jq >/dev/null 2>&1; then
  cmd=$(printf '%s' "$input_json" | jq -r '.tool_input.command // empty' 2>/dev/null)
else
  cmd=$(printf '%s' "$input_json" | LC_ALL=C.UTF-8 grep -oP '"command"\s*:\s*"\K[^"]+' | head -1)
fi
[[ -z "$cmd" ]] && exit 0

# Only react to git commit / git push / gh pr merge; classify below by command string.
case "$cmd" in
  *"git commit"*|*"git push"*|*"gh pr merge"*) ;;
  *) exit 0 ;;
esac

# Need a wiki to suggest anything
# --- canonical wiki-root resolver (llm-wiki v2) ---
# Resolution order: .llmwiki/wiki (preferred) -> .claude/wiki (legacy) -> .codex/wiki (legacy fork)
# A candidate counts only if it carries an init signal (index.md or log.md), so an empty
# seeded .gitkeep-only dir never masks a populated legacy wiki.
resolve_wiki_root() {
  local cand
  for cand in ".llmwiki/wiki" ".claude/wiki" ".codex/wiki"; do
    if [[ -f "$cand/index.md" || -f "$cand/log.md" ]]; then printf '%s\n' "$cand"; return 0; fi
  done
  return 1
}
wiki_root="$(resolve_wiki_root)" || exit 0

# Classify the event by the COMMAND STRING, not local git state. `gh pr merge` is a
# remote operation — it never changes local HEAD (a --squash merge leaves no local
# 2-parent commit), so deriving "is this a merge?" from `git rev-list` on HEAD was
# unreliable (~always false). Compound commands (`git commit && gh pr merge`) count
# as a merge: the merge is the high-value event.
case "$cmd" in
  *"gh pr merge"*) event="merge" ;;
  *)               event="commit" ;;
esac

# Rate-limit per (cwd, event): a preceding commit must not consume the merge budget,
# and vice versa — each event class gets an independent 10-minute window.
cksum_pwd=$(printf '%s' "$PWD" | cksum | cut -d' ' -f1)
marker="/tmp/wiki_post_commit_hint.${cksum_pwd}.${event}"
if [[ -f "$marker" ]]; then
  age=$(( $(date +%s) - $(stat -c %Y "$marker" 2>/dev/null || stat -f %m "$marker" 2>/dev/null || echo 0) ))
  [[ $age -lt 600 ]] && exit 0
fi

if [[ "$event" == "merge" ]]; then
  # A PR merged. There is no local diff to threshold (remote op), so fire the
  # post-merge hint directly, rate-limited by the merge marker alone.
  printf '[wiki-ingest-hint] a `gh pr merge` just ran — a PR merged.\n'
  printf 'Consider /github-dev:post-merge (if the github-dev plugin is installed) — its mandatory wiki step scans the merged diff for ingest candidates. Without github-dev, run /llm-wiki:ingest-finding manually.\n'
  touch "$marker"  # arm the window only after deciding to print (never on a suppressed run)
  exit 0
fi

# event == commit (git commit / git push): threshold on the last commit's diff.
# HEAD~1..HEAD is valid here — a local commit did move local HEAD.
files_changed=$(git diff --name-only HEAD~1 HEAD 2>/dev/null | wc -l || echo 0)
lines_changed=$(git diff --shortstat HEAD~1 HEAD 2>/dev/null \
                | LC_ALL=C.UTF-8 grep -oP '\d+(?= insertion| deletion)' \
                | awk '{s+=$1} END{print s+0}' 2>/dev/null || echo 0)
[[ -z "$lines_changed" ]] && lines_changed=0

# Threshold: 2+ files OR 50+ lines. Below threshold, leave the marker UNTOUCHED so a
# trivial commit does not consume the window a subsequent real commit needs.
if (( files_changed < 2 )) && (( lines_changed < 50 )); then
  exit 0
fi

printf '[wiki-ingest-hint] last commit touched %s file(s), ~%s line(s).\n' "$files_changed" "$lines_changed"
printf 'Consider /llm-wiki:ingest-finding if the commit surfaced non-obvious lore (provider quirks, debugging stories, design rationale).\n'
touch "$marker"  # arm the window only after threshold passed + output emitted (fixes touch-before-check)
exit 0
