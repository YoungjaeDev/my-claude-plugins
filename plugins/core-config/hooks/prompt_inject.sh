#!/usr/bin/env bash
# UserPromptSubmit hook — compact behavioral block injected on EVERY prompt.
# Shared by Claude Code and Codex CLI:
#   - no arg  → plain stdout (Claude: stdout becomes additionalContext)
#   - `codex` → JSON {"additionalContext": "..."} (Codex UserPromptSubmit format)
#
# Unlike memory_nudge.sh (rate-limited ~3h, recall/save nudge), this block is
# fixed and fires every turn: Korean-default + a few core behavioral one-liners +
# a pointer to consult .llmwiki/insight/ + wiki BEFORE reasoning. It does NOT
# inline insight/wiki content — only the instruction to go read it.
#
# Zero runtime deps (no jq/python): JSON encoding via bash parameter expansion.
# Keep the block free of literal double-quotes and backslashes so the encoder
# only has to turn newlines into \n.

set -u
exec 2>/dev/null  # discard stderr — hooks should never spam the user

export LC_ALL=C.UTF-8

FMT="${1:-claude}"

BLOCK=$(cat <<'EOF'
[harness] 별도 지시가 없으면 한국어로 응답한다. 핵심 규율:
- surgical diff: 모든 변경 라인은 요청으로 추적 가능해야 하고, drive-by 리팩터/무관한 정리는 하지 않는다.
- 결정·옵션 선택·확인은 AskUserQuestion 우선 (평문 질문 지양). 구현에 영향을 주는 경우에만 묻는다.
- 커밋/PR/이슈/문서에 AI attribution 금지. 코드/문서에 이모지 금지.
- 했다/통과 보고 전에 실제 실행·검증한다. 근거가 없으면 unverified/unknown 으로 명시한다.
추론 전 참고 (추측 금지): 먼저 `.llmwiki/insight/` (승격된 cross-agent 규율) 를 보고, 이어서 wiki MOC `.llmwiki/wiki/index.md` (query-wiki 게이트) 를 확인한다. lore 는 기억보다 dated·sourced 페이지를 우선한다.
EOF
)

if [ "$FMT" = "codex" ]; then
  # JSON-escape: backslash, double-quote, then newline → \n. Block has none of
  # the first two by construction, but escape defensively in case of edits.
  esc=${BLOCK//\\/\\\\}
  esc=${esc//\"/\\\"}
  esc=${esc//$'\n'/\\n}
  printf '{"additionalContext":"%s"}\n' "$esc"
else
  printf '%s\n' "$BLOCK"
fi

exit 0
