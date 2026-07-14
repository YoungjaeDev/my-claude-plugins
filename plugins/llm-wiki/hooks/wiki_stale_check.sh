#!/usr/bin/env bash
# UserPromptSubmit hook — soft-hint when this repo's wiki has stale pages.
# Quiet by default. Rate-limited to once per hour per workspace via /tmp marker.
#
# Shared by Claude Code and Codex CLI (via the bundled hooks/codex-hooks.json descriptor):
#   - no arg  → plain stdout (Claude: stdout becomes additionalContext)
#   - `codex` → {"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"…"}}
#               (Codex reads context only from this envelope; plain stdout is ignored).

set -u
exec 2>/dev/null  # discard stderr — hooks should never spam the user

FMT="${1:-claude}"

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

# Rate-limit: only run once per hour per cwd
marker="/tmp/wiki_stale_check.$(printf '%s' "$PWD" | cksum | cut -d' ' -f1)"
if [[ -f "$marker" ]]; then
  age=$(( $(date +%s) - $(stat -c %Y "$marker" 2>/dev/null || stat -f %m "$marker" 2>/dev/null || echo 0) ))
  [[ $age -lt 3600 ]] && exit 0
fi
touch "$marker"

today_ts=$(date +%s)
stale=()

# The promoted insight layer (.llmwiki/insight/) is a sibling of .llmwiki/wiki and
# carries the same last_verified/volatility frontmatter, but resolve_wiki_root only
# returns the wiki root — scan insight too so its staleness isn't a blind spot.
scan_dirs=("$wiki_root")
[[ "$wiki_root" == ".llmwiki/wiki" && -d ".llmwiki/insight" ]] && scan_dirs+=(".llmwiki/insight")

while IFS= read -r f; do
  d=$(LC_ALL=C.UTF-8 grep -oP '^last_verified:\s*\K\d{4}-\d{2}-\d{2}' "$f" 2>/dev/null | head -1)
  [[ -z "$d" ]] && continue
  d_ts=$(date -d "$d" +%s 2>/dev/null || date -j -f '%Y-%m-%d' "$d" +%s 2>/dev/null) || continue
  # Per-page volatility window: volatile -> 30d, stable/absent -> 180d
  vol=$(LC_ALL=C.UTF-8 grep -oP '^volatility:\s*\K\S+' "$f" 2>/dev/null | head -1)
  if [[ "$vol" == "volatile" ]]; then window=30; else window=180; fi
  age_days=$(( (today_ts - d_ts) / 86400 ))
  if (( age_days > window )); then
    stale+=("$f ($age_days days > ${window}d ${vol:-stable})")
  fi
done < <(find "${scan_dirs[@]}" -maxdepth 3 -type f -name '*.md' \
         -not -name 'index.md' -not -name 'log.md' 2>/dev/null)

n=${#stale[@]}
(( n == 0 )) && exit 0

# Build the hint (cap the listing at the first 5 stale pages).
out=$(
  printf '[wiki-stale-hint] %d wiki/insight page(s) exceed their volatility window (stable 180d / volatile 30d):\n' "$n"
  for s in "${stale[@]:0:5}"; do printf '  - %s\n' "$s"; done
  (( n > 5 )) && printf '  - ... and %d more\n' "$((n - 5))"
  printf 'Run /lint-wiki for a full report, or /query-wiki + bump last_verified after re-checking each page.'
)

# Emit plain (Claude: stdout -> additionalContext) or the Codex UserPromptSubmit
# envelope (Codex ignores plain stdout). Zero-dep JSON encoding via parameter expansion.
if [[ "$FMT" == "codex" ]]; then
  esc=${out//\\/\\\\}
  esc=${esc//\"/\\\"}
  esc=${esc//$'\n'/\\n}
  printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$esc"
else
  printf '%s\n' "$out"
fi

exit 0
