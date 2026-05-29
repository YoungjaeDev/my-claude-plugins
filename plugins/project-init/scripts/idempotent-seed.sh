#!/usr/bin/env bash
# idempotent-seed.sh
#
# /project-init:new 의 파일 시드 단계용 idempotent 헬퍼. 같은 디렉토리에서
# 두 번째 호출 시 기존 파일을 절대 덮어쓰지 않는다.
#
# Usage:
#   bash idempotent-seed.sh ensure-claude-dirs
#   bash idempotent-seed.sh seed-if-missing <src-template> <dst-path>
#   bash idempotent-seed.sh check-collision <dst-path>   # exit 0 = absent, 1 = collision
#   bash idempotent-seed.sh diagnose                     # 현재 디렉토리 상태 JSON 출력
#
# 출력은 사람이 읽기 위한 평문 (notice / abort), diagnose 만 JSON.

set -euo pipefail

CMD="${1:-}"
shift || true

cmd_ensure_claude_dirs() {
  # Schema layer (spec, rules) stays under .claude/. Wiki + raw evidence live under the
  # neutral .llmwiki/ root so codex-bridge's .claude/->.codex/ transform never forks them.
  local claude_subdirs=("spec" "rules")
  local llmwiki_subdirs=("raw" "wiki")
  for sub in "${claude_subdirs[@]}"; do
    mkdir -p ".claude/${sub}"
    if [ ! -f ".claude/${sub}/.gitkeep" ]; then
      : > ".claude/${sub}/.gitkeep"
      echo "[seed] created .claude/${sub}/.gitkeep"
    else
      echo "[skip] .claude/${sub}/.gitkeep already exists"
    fi
  done
  for sub in "${llmwiki_subdirs[@]}"; do
    mkdir -p ".llmwiki/${sub}"
    if [ ! -f ".llmwiki/${sub}/.gitkeep" ]; then
      : > ".llmwiki/${sub}/.gitkeep"
      echo "[seed] created .llmwiki/${sub}/.gitkeep"
    else
      echo "[skip] .llmwiki/${sub}/.gitkeep already exists"
    fi
  done
}

cmd_seed_if_missing() {
  local src="${1:-}"
  local dst="${2:-}"
  if [ -z "$src" ] || [ -z "$dst" ]; then
    echo "[idempotent-seed] usage: seed-if-missing <src> <dst>" >&2
    exit 2
  fi
  if [ ! -f "$src" ]; then
    echo "[idempotent-seed] source missing: $src" >&2
    exit 2
  fi
  if [ -e "$dst" ]; then
    echo "[skip] $dst already exists — not overwriting"
    return 0
  fi
  cp "$src" "$dst"
  echo "[seed] copied $(basename "$src") -> $dst"
}

cmd_check_collision() {
  local dst="${1:-}"
  if [ -z "$dst" ]; then
    echo "[idempotent-seed] usage: check-collision <path>" >&2
    exit 2
  fi
  if [ -e "$dst" ]; then
    echo "[collision] $dst exists"
    exit 1
  fi
  echo "[absent] $dst"
  exit 0
}

cmd_diagnose() {
  local cwd
  cwd=$(pwd)
  local has_git="false"
  [ -d .git ] && has_git="true"
  local has_claude="false"
  [ -d .claude ] && has_claude="true"
  local has_claude_md="false"
  [ -f CLAUDE.md ] && has_claude_md="true"
  local has_agents_md="false"
  [ -f AGENTS.md ] && has_agents_md="true"
  local has_readme="false"
  [ -f README.md ] && has_readme="true"
  local has_changelog="false"
  [ -f CHANGELOG.md ] && has_changelog="true"
  local commit_count="0"
  if [ "$has_git" = "true" ]; then
    commit_count=$(git rev-list --count HEAD 2>/dev/null || echo "0")
  fi
  local has_remote="false"
  if [ "$has_git" = "true" ] && git remote get-url origin >/dev/null 2>&1; then
    has_remote="true"
  fi
  # Quick code signal — first detected ext, else "none"
  local code_signal="none"
  for ext in py ts tsx js jsx go rs java rb php; do
    if find . -maxdepth 3 -type f -name "*.${ext}" 2>/dev/null | head -1 | grep -q .; then
      code_signal="${ext}"
      break
    fi
  done

  jq -nc \
    --arg cwd "$cwd" \
    --arg dir_name "$(basename "$cwd")" \
    --argjson has_git "$has_git" \
    --argjson has_claude "$has_claude" \
    --argjson has_claude_md "$has_claude_md" \
    --argjson has_agents_md "$has_agents_md" \
    --argjson has_readme "$has_readme" \
    --argjson has_changelog "$has_changelog" \
    --argjson commit_count "$commit_count" \
    --argjson has_remote "$has_remote" \
    --arg code_signal "$code_signal" \
    '{
      cwd: $cwd,
      dir_name: $dir_name,
      git: { initialized: $has_git, commits: $commit_count, remote_origin: $has_remote },
      seeded: {
        claude_dir: $has_claude,
        claude_md: $has_claude_md,
        agents_md: $has_agents_md,
        readme: $has_readme,
        changelog: $has_changelog
      },
      code_signal: $code_signal
    }'
}

case "$CMD" in
  ensure-claude-dirs) cmd_ensure_claude_dirs "$@" ;;
  seed-if-missing)    cmd_seed_if_missing "$@" ;;
  check-collision)    cmd_check_collision "$@" ;;
  diagnose)           cmd_diagnose "$@" ;;
  ""|help|-h|--help)
    cat <<EOF
idempotent-seed.sh — /project-init:new helper

Commands:
  ensure-claude-dirs                  Create .claude/{spec,rules}/.gitkeep + .llmwiki/{raw,wiki}/.gitkeep
  seed-if-missing <src> <dst>         Copy template only if dst absent
  check-collision <path>              Exit 1 if path exists, 0 if absent
  diagnose                            Output JSON snapshot of cwd state

All commands are idempotent — re-running is safe.
EOF
    ;;
  *)
    echo "[idempotent-seed] unknown command: $CMD" >&2
    exit 2
    ;;
esac
