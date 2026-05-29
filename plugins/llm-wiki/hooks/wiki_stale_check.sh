#!/usr/bin/env bash
# UserPromptSubmit hook — soft-hint when this repo's wiki has stale pages.
# Quiet by default. Anything printed to stdout becomes additionalContext for the LLM.
# Rate-limited to once per hour per workspace via /tmp marker.

set -u
exec 2>/dev/null  # discard stderr — hooks should never spam the user

# --- canonical wiki-root resolver (llm-wiki v2) ---
# Resolution order: .llmwiki/wiki (preferred) -> .claude/wiki (legacy) -> .codex/wiki (legacy fork)
resolve_wiki_root() {
  local cand
  for cand in ".llmwiki/wiki" ".claude/wiki" ".codex/wiki"; do
    if [[ -d "$cand" ]]; then printf '%s\n' "$cand"; return 0; fi
  done
  return 1
}
wiki_root="$(resolve_wiki_root)" || exit 0

# Rate-limit: only run once per hour per cwd
marker="/tmp/wiki_stale_check.$(printf '%s' "$PWD" | md5sum | cut -d' ' -f1)"
if [[ -f "$marker" ]]; then
  age=$(( $(date +%s) - $(stat -c %Y "$marker" 2>/dev/null || echo 0) ))
  [[ $age -lt 3600 ]] && exit 0
fi
touch "$marker"

today_ts=$(date +%s)
stale=()

while IFS= read -r f; do
  d=$(LC_ALL=C.UTF-8 grep -oP '^last_verified:\s*\K\d{4}-\d{2}-\d{2}' "$f" 2>/dev/null | head -1)
  [[ -z "$d" ]] && continue
  d_ts=$(date -d "$d" +%s 2>/dev/null) || continue
  # Per-page volatility window: volatile -> 30d, stable/absent -> 180d
  vol=$(LC_ALL=C.UTF-8 grep -oP '^volatility:\s*\K\S+' "$f" 2>/dev/null | head -1)
  if [[ "$vol" == "volatile" ]]; then window=30; else window=180; fi
  age_days=$(( (today_ts - d_ts) / 86400 ))
  if (( age_days > window )); then
    stale+=("$f ($age_days days > ${window}d ${vol:-stable})")
  fi
done < <(find "$wiki_root" -maxdepth 3 -type f -name '*.md' \
         -not -name 'index.md' -not -name 'log.md' 2>/dev/null)

n=${#stale[@]}
(( n == 0 )) && exit 0

# Cap output — show first 5
printf '[wiki-stale-hint] %d wiki page(s) exceed their volatility window (stable 180d / volatile 30d):\n' "$n"
for s in "${stale[@]:0:5}"; do printf '  - %s\n' "$s"; done
(( n > 5 )) && printf '  - ... and %d more\n' "$((n - 5))"
printf 'Run /lint-wiki for a full report, or /query-wiki + bump last_verified after re-checking each page.\n'

exit 0
