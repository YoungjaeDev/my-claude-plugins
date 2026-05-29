#!/usr/bin/env bash
# SessionStart hook — soft-hint when this repo's wiki hasn't been linted recently.
# Reads SessionStart JSON from stdin (non-blocking). Emits additionalContext (model-visible).
# Soft-hint only — NEVER writes the wiki. Rate-limited to once per 4h per cwd via /tmp marker.

set -u
exec 2>/dev/null  # discard stderr — hooks should never spam the user

# Read stdin JSON (don't block); optionally cd into cwd if present
input_json=$(cat 2>/dev/null || true)
if [[ -n "$input_json" ]] && command -v jq >/dev/null 2>&1; then
  cwd=$(printf '%s' "$input_json" | jq -r '.cwd // empty' 2>/dev/null)
  [[ -n "$cwd" && -d "$cwd" ]] && cd "$cwd"
fi

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

log_file="$wiki_root/log.md"
[[ -f "$log_file" ]] || exit 0

# Rate-limit: only run once per 4h per cwd (avoid /clear spam)
marker="/tmp/wiki_session_start_lint_hint.$(printf '%s' "$PWD" | md5sum | cut -d' ' -f1)"
if [[ -f "$marker" ]]; then
  age=$(( $(date +%s) - $(stat -c %Y "$marker" 2>/dev/null || echo 0) ))
  [[ $age -lt 14400 ]] && exit 0
fi
touch "$marker"

# Find newest lint-wiki date in the log
newest=$(LC_ALL=C.UTF-8 grep -oP '^##\s+\K\d{4}-\d{2}-\d{2}(?=.*\(lint-wiki\))' "$log_file" 2>/dev/null | sort -r | head -1)

msg=""
if [[ -z "$newest" ]]; then
  msg="[wiki-lint-hint] no lint-wiki baseline in $log_file; consider /lint-wiki to establish wiki health."
else
  n_ts=$(date -d "$newest" +%s 2>/dev/null) || exit 0
  age_days=$(( ($(date +%s) - n_ts) / 86400 ))
  if (( age_days > 3 )); then
    msg="[wiki-lint-hint] last /lint-wiki was $age_days days ago ($newest); consider /lint-wiki to catch drift."
  fi
fi

[[ -z "$msg" ]] && exit 0

# Emit as SessionStart additionalContext (model-visible)
esc=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g')
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$esc"

exit 0
