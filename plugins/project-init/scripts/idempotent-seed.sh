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

# 탐지는 project_state.sh 가 SSOT. 여기서는 기존 diagnose 출력 형태만 유지하도록
# 필요한 필드를 골라낸다 (project_state.sh 는 git 아래 hooks_* 등 상위 집합을 낸다).
cmd_diagnose() {
  local script_dir
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  bash "$script_dir/project_state.sh" | jq -c '{
    cwd,
    dir_name,
    git: { initialized: .git.initialized, commits: .git.commits, remote_origin: .git.remote_origin },
    seeded,
    code_signal
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
