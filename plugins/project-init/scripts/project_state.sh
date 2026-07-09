#!/usr/bin/env bash
# project_state.sh
#
# 프로젝트의 에이전트 하네스 설정 상태를 탐지해 JSON 한 덩어리로 출력한다.
# 순수 read-only — 어떤 파일도 만들거나 고치지 않는다.
#
# `/project-init:wiring` 의 탐지 SSOT. `idempotent-seed.sh diagnose` 도 이걸 감싼다.
#
# Usage:
#   bash project_state.sh            # 전체 상태 JSON
#
# Env:
#   WIRING_TMP_STALE_DAYS   .tmp/ stale 판정 기준 (기본 14)
#
# 의존성: jq (infer-github-context.sh / idempotent-seed.sh 와 동일한 기존 의존성)

set -euo pipefail

STALE_DAYS="${WIRING_TMP_STALE_DAYS:-14}"
# 비정수면 `find -mtime +$STALE_DAYS` 와 `jq --argjson` 이 둘 다 깨진다.
# jq 의 usage dump 대신 원인을 말하고 죽는다.
case "$STALE_DAYS" in
  '' | *[!0-9]*)
    echo "[project_state] WIRING_TMP_STALE_DAYS must be a non-negative integer (got: $STALE_DAYS)" >&2
    exit 2
    ;;
esac

b() { if "$@" >/dev/null 2>&1; then echo true; else echo false; fi; }

# `find` 는 "없음" 을 exit 1 로 표현한다. pipefail 아래서 그대로 파이프에 물리면
# 정상적인 빈 결과가 스크립트를 죽인다 — 모든 find 는 이 두 헬퍼를 거친다.
find_or_empty() { find "$@" 2>/dev/null || true; }

count_files() { find_or_empty "$@" | wc -l | tr -d ' '; }

# 디렉토리가 없으면 0. -maxdepth 1 로 최상위만.
count_md() {
  [ -d "$1" ] || { echo 0; return; }
  count_files "$1" -maxdepth 1 -type f -name '*.md'
}

# YAML frontmatter (첫 줄이 ---) 가 없는 .md 개수
count_no_frontmatter() {
  local dir="$1" n=0 f
  [ -d "$dir" ] || { echo 0; return; }
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ "$(head -1 "$f" 2>/dev/null)" != "---" ]; then n=$((n + 1)); fi
  done <<EOF
$(find_or_empty "$dir" -maxdepth 1 -type f -name '*.md')
EOF
  echo "$n"
}

ignored() {
  # git repo 가 아니면 판정 불가 -> false
  [ "$GIT_INIT" = true ] || { echo false; return; }
  if git check-ignore -q "$1" 2>/dev/null; then echo true; else echo false; fi
}

CWD="$(pwd)"
DIR_NAME="$(basename "$CWD")"

# --- git -----------------------------------------------------------------
# `test -d .git` 은 worktree 와 submodule 에서 false 다 — 거기선 .git 이 gitdir
# 포인터 *파일*이다. 그러면 ignored() 가 전부 false 를 뱉어 .gitignore 축이
# 통째로 거짓 FAIL 이 된다 (github-dev 는 worktree 를 쓴다).
GIT_INIT=false
if [ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]; then GIT_INIT=true; fi
COMMITS=0
REMOTE=false
if [ "$GIT_INIT" = true ]; then
  COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo 0)
  REMOTE=$(b git remote get-url origin)
fi
# repo 밖에서 core.hooksPath 를 읽으면 남의 global 값을 이 프로젝트 것인 양 보고한다.
# 단 scope 는 좁히지 않는다 — 실제로 적용되는 값은 local > global > system 의 해석 결과다.
HOOKS_PATH=""
if [ "$GIT_INIT" = true ]; then
  HOOKS_PATH=$(git config core.hooksPath 2>/dev/null || true)
fi
HOOKS_DIR=$(b test -d .githooks)

# --- seeded files (idempotent-seed.sh diagnose 호환 필드) -----------------
S_CLAUDE_DIR=$(b test -d .claude)
S_CLAUDE_MD=$(b test -f CLAUDE.md)
S_AGENTS_MD=$(b test -f AGENTS.md)
S_README=$(b test -f README.md)
S_CHANGELOG=$(b test -f CHANGELOG.md)

# `find | head -1 | grep -q .` 는 head 의 조기 종료가 find 를 SIGPIPE(141) 로 죽여
# pipefail 아래서 "찾았는데 못 찾았다" 로 뒤집힌다. -print -quit 로 파이프를 제거.
CODE_SIGNAL=none
for ext in py ts tsx js jsx go rs java rb php; do
  if [ -n "$(find_or_empty . -maxdepth 3 -type f -name "*.${ext}" -print -quit)" ]; then
    CODE_SIGNAL="$ext"
    break
  fi
done

# --- guidance (CLAUDE.md / AGENTS.md / .claude/rules) ---------------------
RULES_COUNT=$(count_md .claude/rules)
# 크로스런타임 공백: Claude 전용 rules 가 있는데 Codex/Hermes 가 읽는 AGENTS.md 가 없음.
# Codex/Hermes 는 `@import` 를 확장하지 않으므로 AGENTS.md 부재 = 지침 소실.
CROSS_RUNTIME_GAP=false
if [ "$RULES_COUNT" -gt 0 ] && [ "$S_AGENTS_MD" = false ]; then CROSS_RUNTIME_GAP=true; fi

# --- llm-wiki ------------------------------------------------------------
# 루트 판정은 hooks/skills 와 동일한 규칙: index.md 또는 log.md 가 있어야 카운트.
wiki_root_at() { [ -f "$1/index.md" ] || [ -f "$1/log.md" ]; }
WIKI_STATE=absent
if wiki_root_at .llmwiki/wiki; then
  WIKI_STATE=current
elif wiki_root_at .claude/wiki || wiki_root_at .codex/wiki; then
  WIKI_STATE=legacy
fi
WIKI_INSIGHT=$(b test -f .llmwiki/insight/index.md)
# post-2.4.0 신호: raw/ 가 source-type 버킷 구조
WIKI_RAW_BUCKETS=false
if [ -d .llmwiki/raw/external ] && [ -d .llmwiki/raw/research ] \
  && [ -d .llmwiki/raw/transcripts ] && [ -d .llmwiki/raw/audits ]; then
  WIKI_RAW_BUCKETS=true
fi
STAGING_PENDING=$(count_files .llmwiki/.staging -maxdepth 1 -name 'pending-*.md')

# --- serena --------------------------------------------------------------
SERENA_MEMS=$(count_files .serena/memories -maxdepth 1 -type f -name '*.md')
SERENA_STATE=not-registered
if [ -f .serena/project.yml ]; then
  if [ "$SERENA_MEMS" -gt 0 ]; then SERENA_STATE=onboarded; else SERENA_STATE=registered; fi
fi
SERENA_NAME=""
SERENA_DRIFT=false
if [ -f .serena/project.yml ]; then
  SERENA_NAME=$(sed -n 's/^project_name:[[:space:]]*//p' .serena/project.yml | head -1 | tr -d '"'"'" | tr -d '\r')
  if [ -n "$SERENA_NAME" ] && [ "$SERENA_NAME" != "$DIR_NAME" ]; then SERENA_DRIFT=true; fi
fi

# --- memory surfaces -----------------------------------------------------
# 네이티브 auto-memory 는 cwd 를 '/'->'-' 치환한 slug 로 ~/.claude/projects/ 아래 산다.
SLUG=$(printf '%s' "$CWD" | sed 's#/#-#g')
NATIVE_MEM=$(b test -f "$HOME/.claude/projects/$SLUG/memory/MEMORY.md")
MEM0_SETTINGS=$(b test -f "$HOME/.mem0/settings.json")
MEM0_MAPPED=false
if [ -f "$HOME/.mem0/project_map.json" ]; then
  MEM0_MAPPED=$(b grep -qF "\"$CWD\"" "$HOME/.mem0/project_map.json")
fi

# 파일 존재는 기능 활성화의 프록시일 뿐이다. MEMORY.md 는 auto-memory 를 끈 뒤에도
# 남으므로, 두 writer 가 정말 동시에 살아있는지는 설정을 직접 읽어야 안다.
# 설정 cascade: user < project < local. 미설정이면 기본 ON.
SETTINGS_CASCADE=("$HOME/.claude/settings.json" ".claude/settings.json" ".claude/settings.local.json")
NATIVE_ENABLED=true
for f in "${SETTINGS_CASCADE[@]}"; do
  [ -f "$f" ] || continue
  v=$(jq -r 'if has("autoMemoryEnabled") then (.autoMemoryEnabled|tostring) else empty end' "$f" 2>/dev/null || true)
  if [ -n "$v" ]; then NATIVE_ENABLED="$v"; fi
done

# 연합 라벨: 런타임 env 가 우선, 없으면 settings 의 env 블록. 기본 off (=0).
FED_RAW="${CORE_CONFIG_FEDERATE_MEM0:-}"
if [ -z "$FED_RAW" ]; then
  for f in "${SETTINGS_CASCADE[@]}"; do
    [ -f "$f" ] || continue
    v=$(jq -r '.env.CORE_CONFIG_FEDERATE_MEM0 // empty' "$f" 2>/dev/null || true)
    if [ -n "$v" ]; then FED_RAW="$v"; fi
  done
fi
FEDERATE=false
if [ "$FED_RAW" = "1" ]; then FEDERATE=true; fi

# --- spec ----------------------------------------------------------------
SPEC_CLAUDE=$(count_md .claude/spec)
SPEC_SUPERPOWERS=$(count_md docs/superpowers/specs)
SPEC_STATE=$(b test -f .claude/state/spec.json)
SPEC_NO_FM=$(( $(count_no_frontmatter .claude/spec) + $(count_no_frontmatter docs/superpowers/specs) ))

# --- gws-sync ------------------------------------------------------------
GWS_CLI=$(b command -v gws)
GWS_CONFIG=$(b test -f .gws-sync.json)

# --- .tmp ----------------------------------------------------------------
TMP_DIR=$(b test -d .tmp)
TMP_IGNORED=$(ignored .tmp/)
TMP_STALE=0
if [ "$TMP_DIR" = true ]; then
  TMP_STALE=$(count_files .tmp -type f -mtime "+${STALE_DAYS}")
fi

# --- .gitignore coverage -------------------------------------------------
GI_STATE=$(ignored .claude/state/)
GI_SERENA=$(ignored .serena/)
GI_STAGING=$(ignored .llmwiki/.staging/)
GI_ENV=$(ignored .env)

jq -nc \
  --arg cwd "$CWD" --arg dir_name "$DIR_NAME" \
  --argjson git_init "$GIT_INIT" --argjson commits "$COMMITS" --argjson remote "$REMOTE" \
  --arg hooks_path "$HOOKS_PATH" --argjson hooks_dir "$HOOKS_DIR" \
  --argjson s_claude_dir "$S_CLAUDE_DIR" --argjson s_claude_md "$S_CLAUDE_MD" \
  --argjson s_agents_md "$S_AGENTS_MD" --argjson s_readme "$S_README" --argjson s_changelog "$S_CHANGELOG" \
  --arg code_signal "$CODE_SIGNAL" \
  --argjson rules_count "$RULES_COUNT" --argjson cross_gap "$CROSS_RUNTIME_GAP" \
  --arg wiki_state "$WIKI_STATE" --argjson wiki_insight "$WIKI_INSIGHT" \
  --argjson wiki_buckets "$WIKI_RAW_BUCKETS" --argjson staging "$STAGING_PENDING" \
  --arg serena_state "$SERENA_STATE" --argjson serena_mems "$SERENA_MEMS" \
  --arg serena_name "$SERENA_NAME" --argjson serena_drift "$SERENA_DRIFT" \
  --argjson native_mem "$NATIVE_MEM" --argjson native_enabled "$NATIVE_ENABLED" \
  --argjson mem0_settings "$MEM0_SETTINGS" --argjson mem0_mapped "$MEM0_MAPPED" \
  --argjson federate "$FEDERATE" \
  --argjson spec_claude "$SPEC_CLAUDE" --argjson spec_sp "$SPEC_SUPERPOWERS" \
  --argjson spec_state "$SPEC_STATE" --argjson spec_no_fm "$SPEC_NO_FM" \
  --argjson gws_cli "$GWS_CLI" --argjson gws_config "$GWS_CONFIG" \
  --argjson tmp_dir "$TMP_DIR" --argjson tmp_ignored "$TMP_IGNORED" \
  --argjson tmp_stale "$TMP_STALE" --argjson stale_days "$STALE_DAYS" \
  --argjson gi_state "$GI_STATE" --argjson gi_serena "$GI_SERENA" --argjson gi_staging "$GI_STAGING" \
  --argjson gi_env "$GI_ENV" \
  '{
    cwd: $cwd,
    dir_name: $dir_name,
    git: {
      initialized: $git_init, commits: $commits, remote_origin: $remote,
      hooks_path: (if $hooks_path == "" then null else $hooks_path end),
      hooks_dir_present: $hooks_dir
    },
    seeded: {
      claude_dir: $s_claude_dir, claude_md: $s_claude_md, agents_md: $s_agents_md,
      readme: $s_readme, changelog: $s_changelog
    },
    code_signal: $code_signal,
    guidance: { rules_count: $rules_count, cross_runtime_gap: $cross_gap },
    llmwiki: {
      state: $wiki_state, insight_layer: $wiki_insight,
      raw_source_buckets: $wiki_buckets, staging_pending: $staging
    },
    serena: {
      state: $serena_state, memories: $serena_mems,
      project_name: (if $serena_name == "" then null else $serena_name end),
      name_drift: $serena_drift
    },
    memory: {
      native_memory_md: $native_mem,
      native_auto_memory_enabled: $native_enabled,
      mem0_settings: $mem0_settings,
      mem0_project_mapped: $mem0_mapped,
      federate_labels: $federate
    },
    spec: {
      claude_spec: $spec_claude, superpowers_spec: $spec_sp,
      state_json: $spec_state, missing_frontmatter: $spec_no_fm
    },
    gws_sync: { cli: $gws_cli, config: $gws_config },
    tmp: { dir: $tmp_dir, gitignored: $tmp_ignored, stale_files: $tmp_stale, stale_days: $stale_days },
    gitignore: { claude_state: $gi_state, serena: $gi_serena, llmwiki_staging: $gi_staging, tmp: $tmp_ignored, env: $gi_env }
  }'
