#!/usr/bin/env bash
# UserPromptSubmit hook — compact behavioral block injected on EVERY prompt.
# Shared by Claude Code and Codex CLI:
#   - no arg  → plain stdout (Claude: stdout becomes additionalContext)
#   - `codex` → JSON {"hookSpecificOutput":{"hookEventName":"UserPromptSubmit",
#               "additionalContext":"..."}} — the UserPromptSubmit envelope Codex
#               reads model-visible context from (a top-level additionalContext is
#               NOT read).
#
# Unlike memory_nudge.sh (rate-limited ~3h, recall/save nudge), this block is
# fixed and fires every turn: Korean-default + a few core behavioral one-liners.
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

# Fixed behavioral block — always emitted (repo-independent).
BLOCK=$(cat <<'EOF'
[harness] 별도 지시가 없으면 최종 사용자 응답은 항상 한국어. 내부 workflow·서브에이전트·영문 스킬(ultracode·deep-research 등)은 별도 지시가 아니다 — 거쳐도 마지막 답변은 한국어로 쓴다. 핵심 규율:
- surgical diff: 모든 변경 라인은 요청으로 추적 가능. drive-by 리팩터·무관한 정리 금지.
- 결정·옵션·확인은 AskUserQuestion 우선 (구현에 영향 줄 때만).
- 커밋·PR·문서에 AI attribution 금지. 코드·문서 이모지 금지.
- 보고 전 실제 실행·검증. 근거 없으면 unverified/unknown 명시.
EOF
)

# Wiki/insight pointer — only when a knowledge root actually resolves in CWD,
# mirroring llm-wiki's resolution order (.llmwiki → legacy .claude → .codex).
# Without this, a globally-installed core-config would tell every repo to read
# paths that don't exist (or the wrong legacy path). Single-quoted to keep the
# backticks literal (no command substitution).
PTR=""
if [ -d .llmwiki/insight ]; then
  PTR='추론 전 참고 (추측 금지): 먼저 `.llmwiki/insight/` (승격된 cross-agent 규율) 를 보고, 이어서 wiki MOC `.llmwiki/wiki/index.md` (query-wiki 게이트) 를 확인한다. lore 는 기억보다 dated·sourced 페이지를 우선한다.'
elif [ -d .llmwiki/wiki ]; then
  PTR='추론 전 참고 (추측 금지): wiki MOC `.llmwiki/wiki/index.md` (query-wiki 게이트) 를 먼저 확인한다. lore 는 기억보다 dated·sourced 페이지를 우선한다.'
elif [ -d .claude/wiki ]; then
  PTR='추론 전 참고 (추측 금지): wiki MOC `.claude/wiki/index.md` (query-wiki 게이트) 를 먼저 확인한다. lore 는 기억보다 dated·sourced 페이지를 우선한다.'
elif [ -d .codex/wiki ]; then
  PTR='추론 전 참고 (추측 금지): wiki MOC `.codex/wiki/index.md` (query-wiki 게이트) 를 먼저 확인한다. lore 는 기억보다 dated·sourced 페이지를 우선한다.'
fi
[ -n "$PTR" ] && BLOCK="$BLOCK"$'\n'"$PTR"

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
