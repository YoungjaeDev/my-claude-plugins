#!/usr/bin/env bash
# PostToolUse hook (matcher: Bash) — soft-hint when a git commit/push touched files
# the wiki should know about. Reads tool_input JSON from stdin.
# Quiet unless we're confident the LLM should consider /wiki:ingest-finding or /dev:post-merge.
#
# Shared by Claude Code and Codex CLI (via the bundled hooks/codex-hooks.json descriptor):
#   - no arg  → plain stdout (Claude: stdout becomes additionalContext)
#   - `codex` → {"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"…"}}
#               (Codex reads context only from this envelope; plain stdout is ignored).

set -u
# Hooks must never spam the user, so stderr is discarded — but a discarded
# stderr also hides a future GNU-only construct that has no `||` fallback,
# leaving a silent no-op on macOS with nothing to diagnose. Set WIKI_HOOK_DEBUG
# (any value) to keep stderr and see what the hook is actually saying.
[ -n "${WIKI_HOOK_DEBUG:-}" ] || exec 2>/dev/null

FMT="${1:-claude}"

# Emit the hint (plain stdout for Claude, the Codex PostToolUse envelope for `codex`),
# arm the rate-limit marker, then exit. Zero-dep JSON encoding via bash parameter
# expansion, mirroring core's prompt_inject.sh. Byte-identical Claude output.
emit() {
  local msg="$1"
  if [[ "$FMT" == "codex" ]]; then
    local esc=${msg//\\/\\\\}
    esc=${esc//\"/\\\"}
    esc=${esc//$'\n'/\\n}
    printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$esc"
  else
    printf '%s\n' "$msg"
  fi
  touch "$marker"  # arm the window only after deciding to emit (never on a suppressed run)
  exit 0
}

# Read tool_input JSON from stdin
input_json=$(cat 2>/dev/null || true)
[[ -z "$input_json" ]] && exit 0

# Extract the bash command (jq if available, else grep fallback)
cmd=""
if command -v jq >/dev/null 2>&1; then
  cmd=$(printf '%s' "$input_json" | jq -r '.tool_input.command // empty' 2>/dev/null)
else
  # BSD grep has no -P/\K. awk match() finds the FIRST "command":"..." (a greedy
  # sed `.*` would select the LAST occurrence); portable across GNU/BSD awk.
  cmd=$(printf '%s' "$input_json" | LC_ALL=C.UTF-8 awk '
    match($0, /"command"[[:space:]]*:[[:space:]]*"/) {
      s = substr($0, RSTART + RLENGTH)
      if (match(s, /"/)) { print substr(s, 1, RSTART - 1); exit }
    }')
fi
[[ -z "$cmd" ]] && exit 0

# Only react to git commit / git push / gh pr merge; classify below by command string.
case "$cmd" in
  *"git commit"*|*"git push"*|*"gh pr merge"*) ;;
  *) exit 0 ;;
esac

# Need a wiki to suggest anything
# --- canonical wiki-root resolver (wiki v2) ---
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
  *"gh pr merge"*"--auto"*)
    # `gh pr merge --auto` only ENROLLS the PR for auto-merge; the merge completes
    # later, server-side, with no local command — so announcing "a PR merged" now is
    # premature. Suppress the merge hint. But if the same command also made a local
    # commit/push (e.g. `git commit ... && gh pr merge --auto`), that commit still
    # deserves the ingest-finding hint, so fall through to the commit-event path; a
    # bare `gh pr merge --auto` has no such commit and the threshold below won't fire.
    # (A repo merge queue can defer a plain `gh pr merge` too, but that is not
    # detectable from the command string; the post-merge hint is self-correcting there
    # — post-merge's own `state=MERGED` gate refuses to proceed on an unmerged PR.)
    case "$cmd" in
      *"git commit"*|*"git push"*) event="commit" ;;
      *)                           exit 0 ;;
    esac ;;
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
  emit '[wiki-ingest-hint] a `gh pr merge` just ran — a PR merged.
Consider /dev:post-merge (if the dev plugin is installed) — its mandatory wiki step scans the merged diff for ingest candidates. Without dev, run /wiki:ingest-finding manually.'
fi

# event == commit (git commit / git push): threshold on the last commit's diff.
# HEAD~1..HEAD is valid here — a local commit did move local HEAD.
# tr strips BSD wc's leading pad: (( )) skips it so the threshold below is
# correct either way, but the hint string is model-visible context and
# "touched        3 file(s)" is noise in it.
files_changed=$(git diff --name-only HEAD~1 HEAD 2>/dev/null | wc -l | tr -d '[:space:]' || echo 0)
# awk alone parses the fixed-format shortstat — a number immediately followed by
# an insertion/deletion token — with no PCRE lookahead (BSD grep lacks -P).
lines_changed=$(git diff --shortstat HEAD~1 HEAD 2>/dev/null \
                | awk '{for(i=1;i<=NF;i++) if($(i+1)~/^insertion|^deletion/) s+=$i} END{print s+0}' 2>/dev/null || echo 0)
[[ -z "$lines_changed" ]] && lines_changed=0

# Threshold: 2+ files OR 50+ lines. Below threshold, leave the marker UNTOUCHED so a
# trivial commit does not consume the window a subsequent real commit needs.
if (( files_changed < 2 )) && (( lines_changed < 50 )); then
  exit 0
fi

emit "$(printf '[wiki-ingest-hint] last commit touched %s file(s), ~%s line(s).\nConsider /wiki:ingest-finding if the commit surfaced non-obvious lore (provider quirks, debugging stories, design rationale).' "$files_changed" "$lines_changed")"
