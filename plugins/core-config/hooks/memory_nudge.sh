#!/usr/bin/env bash
# UserPromptSubmit hook — soft memory-discipline reminder.
# Quiet by default. Anything printed to stdout becomes additionalContext for the LLM.
# Rate-limited to once per ~3h per workspace via /tmp marker.
#
# This does NOT re-inject CLAUDE.md (that was the removed `inject-guidelines`
# anti-pattern — ~/.claude/CLAUDE.md is native-loaded once per session). It only
# nudges the LLM to USE the memory Claude Code already auto-loads.

set -u
exec 2>/dev/null  # discard stderr — hooks should never spam the user

export LC_ALL=C.UTF-8

# Rate-limit: only emit once per window per cwd (window tunable)
WINDOW=10800  # ~3h
marker="/tmp/memory_nudge.$(printf '%s' "$PWD" | cksum | cut -d' ' -f1)"
if [[ -f "$marker" ]]; then
  age=$(( $(date +%s) - $(stat -c %Y "$marker" 2>/dev/null || stat -f %m "$marker" 2>/dev/null || echo 0) ))
  [[ $age -lt $WINDOW ]] && exit 0
fi
touch "$marker"

cat <<'EOF'
[memory-hint] Project + user memory is loaded (MEMORY.md index + ~/.claude/CLAUDE.md "# Memory").
- Recall relevant memories before deciding — they hold prior decisions and user preferences.
- Save durable user facts / workflow feedback / project constraints to memory as you learn them (one fact per file + a MEMORY.md pointer).
- Correct or delete memories that prove wrong; don't save what the repo or git already records.
EOF

exit 0
