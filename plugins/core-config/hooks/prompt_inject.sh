#!/usr/bin/env bash
# UserPromptSubmit hook — compact behavioral block injected on EVERY prompt.
# Shared by Claude Code and Codex CLI:
#   - no arg  → plain stdout (Claude: stdout becomes additionalContext)
#   - `codex` → JSON {"hookSpecificOutput":{"hookEventName":"UserPromptSubmit",
#               "additionalContext":"..."}} — the UserPromptSubmit envelope Codex
#               reads model-visible context from (a top-level additionalContext is
#               NOT read).
#
# This block is fixed and fires every turn: an English behavioral block whose
# first line mandates a Korean final reply, plus a few core behavioral one-liners.
# A wiki/insight pointer ("consult .llmwiki/insight/ + wiki BEFORE reasoning") is
# appended ONLY when a knowledge root resolves in CWD (.llmwiki → legacy .claude
# → .codex), since core-config is installed globally — a repo with no wiki, or a
# legacy-root repo, must not be told to read a path that isn't there. It never
# inlines insight/wiki content — only the instruction to go read it.
#
# Zero runtime deps (no jq/python): JSON encoding via bash parameter expansion.
# Keep the block free of literal double-quotes and backslashes so the encoder
# only has to turn newlines into \n.

set -u
exec 2>/dev/null  # discard stderr — hooks should never spam the user

export LC_ALL=C.UTF-8

FMT="${1:-claude}"

# mem0 <-> llmwiki federation: label the authority hierarchy on the wiki pointer.
# This is LABELS ONLY — no mem0 call/read (mem0 surfacing is mem0's own hooks).
#   0 (default) = plain pointer, no federation labels.
#   1           = mark .llmwiki as [AUTHORITATIVE] (dated/sourced wins) + emit a
#                 [RECALL] note placing mem0 recall as the secondary layer.
#                 Set CORE_CONFIG_FEDERATE_MEM0=1 to restore (fully reversible).
FEDERATE="${CORE_CONFIG_FEDERATE_MEM0:-0}"

# Fixed behavioral block — always emitted (repo-independent).
BLOCK=$(cat <<'EOF'
[harness] Unless told otherwise, write the final user-facing reply in Korean. Internal workflows, subagents, and English skills (ultracode, deep-research, etc.) are NOT an override — route through them, but the last answer is Korean. Core discipline:
- surgical diff: every changed line traces to the request. No drive-by refactors or unrelated cleanup.
- decisions, options, and confirmations go through AskUserQuestion first (only when they affect implementation).
- no AI attribution in commits, PRs, or docs. No emoji in code or docs.
- run and verify before reporting. State unverified/unknown when there is no evidence.
EOF
)

# Wiki/insight pointer — only when a knowledge root actually resolves in CWD,
# mirroring llm-wiki's resolution order (.llmwiki → legacy .claude → .codex).
# Without this, a globally-installed core-config would tell every repo to read
# paths that don't exist (or the wrong legacy path). Single-quoted to keep the
# backticks literal (no command substitution).
PTR=""
if [ -d .llmwiki/insight ]; then
  PTR='Before reasoning (do not guess): first read `.llmwiki/insight/` (promoted cross-agent rules), then check the wiki MOC `.llmwiki/wiki/index.md` (query-wiki gate). For lore, prefer the dated/sourced page over memory.'
elif [ -d .llmwiki/wiki ]; then
  PTR='Before reasoning (do not guess): check the wiki MOC `.llmwiki/wiki/index.md` (query-wiki gate) first. For lore, prefer the dated/sourced page over memory.'
elif [ -d .claude/wiki ]; then
  PTR='Before reasoning (do not guess): check the wiki MOC `.claude/wiki/index.md` (query-wiki gate) first. For lore, prefer the dated/sourced page over memory.'
elif [ -d .codex/wiki ]; then
  PTR='Before reasoning (do not guess): check the wiki MOC `.codex/wiki/index.md` (query-wiki gate) first. For lore, prefer the dated/sourced page over memory.'
fi
# Federation labels: prefix the resolved pointer as [AUTHORITATIVE] and stage a
# [RECALL] note for mem0. RECALL is Claude-only — Codex never sees mem0, so a
# pointer to it there would dangle (omitted in the codex branch below).
RECALL=""
if [ -n "$PTR" ] && [ "$FEDERATE" != "0" ]; then
  PTR="[AUTHORITATIVE] $PTR"
  RECALL='[RECALL] mem0 recall is a secondary signal — when it conflicts with the [AUTHORITATIVE] .llmwiki page above, the page wins (mem0 surfacing is handled by mem0 hooks, not called here).'
fi
[ -n "$PTR" ] && BLOCK="$BLOCK"$'\n'"$PTR"
# Claude-only RECALL line (Codex omits — it has no mem0 layer).
[ -n "$RECALL" ] && [ "$FMT" != "codex" ] && BLOCK="$BLOCK"$'\n'"$RECALL"

if [ "$FMT" = "codex" ]; then
  # JSON-escape: backslash, double-quote, then newline → \n. Block has none of
  # the first two by construction, but escape defensively in case of edits.
  esc=${BLOCK//\\/\\\\}
  esc=${esc//\"/\\\"}
  esc=${esc//$'\n'/\\n}
  printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$esc"
else
  printf '%s\n' "$BLOCK"
fi

exit 0
