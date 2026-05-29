#!/usr/bin/env bash
# PostToolUse hook (matcher: Bash) — soft-hint when a git commit/push touched files
# the wiki should know about. Reads tool_input JSON from stdin.
# Quiet unless we're confident the LLM should consider /ingest-finding or /post-merge-wiki.

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

# Only react to git commit or git push to a non-feature branch (merge to main)
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

# Rate-limit: suppress if we've already fired in the last 10 minutes for this cwd
marker="/tmp/wiki_post_commit_hint.$(printf '%s' "$PWD" | cksum | cut -d' ' -f1)"
if [[ -f "$marker" ]]; then
  age=$(( $(date +%s) - $(stat -c %Y "$marker" 2>/dev/null || stat -f %m "$marker" 2>/dev/null || echo 0) ))
  [[ $age -lt 600 ]] && exit 0
fi
touch "$marker"

# Stat the last commit's diff
files_changed=$(git diff --name-only HEAD~1 HEAD 2>/dev/null | wc -l || echo 0)
lines_changed=$(git diff --shortstat HEAD~1 HEAD 2>/dev/null \
                | LC_ALL=C.UTF-8 grep -oP '\d+(?= insertion| deletion)' \
                | awk '{s+=$1} END{print s+0}' 2>/dev/null || echo 0)
[[ -z "$lines_changed" ]] && lines_changed=0

# Threshold: 2+ files OR 50+ lines OR a merge commit
is_merge=$(git rev-list --merges -1 HEAD~..HEAD 2>/dev/null)
if (( files_changed < 2 )) && (( lines_changed < 50 )) && [[ -z "$is_merge" ]]; then
  exit 0
fi

printf '[wiki-ingest-hint] last commit touched %s file(s), ~%s line(s)' "$files_changed" "$lines_changed"
[[ -n "$is_merge" ]] && printf ' (merge commit)'
printf '.\n'
if [[ -n "$is_merge" ]]; then
  printf 'Consider /post-merge-wiki to scan the merged diff for wiki ingest candidates.\n'
else
  printf 'Consider /ingest-finding if the commit surfaced non-obvious lore (provider quirks, debugging stories, design rationale).\n'
fi

exit 0
