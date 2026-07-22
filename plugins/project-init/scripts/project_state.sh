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

# --- MCP 설정 중복 --------------------------------------------------------
# 같은 서버가 두 user-scope 파일에 있으면 Claude 는 한쪽 정의를 통째로 고르고
# 나머지는 버린다 (필드 병합 없음). 두 정의가 갈라지면 한쪽 편집이 조용히 죽는다.
# 고아 등록(삭제된 플러그인의 서버)은 사용 이력이 있어야 알 수 있어 여기서 다루지 않는다.
# 손상된 JSON 에서 jq 는 non-zero 로 끝난다. `set -euo pipefail` 아래서 그 실패는
# 명령 치환을 타고 올라와 스크립트 전체를 죽인다 — 중복 하나 못 세는 대신 진단이
# 통째로 사라진다. 파싱 실패를 이 축 안에 가두고, 대신 unreadable 로 실어 보낸다:
# 조용히 "중복 없음" 이라고 답하는 것이 제일 나쁘다.
# "읽을 수 있나" 는 "유효한 JSON 인가" 보다 좁다. 빈 파일은 jq 에게 유효한 입력이고,
# `mcpServers` 가 객체가 아니면 (`[]`, `"x"`) `keys[]` 가 죽거나 인덱스를 뱉는다.
# 둘 다 "중복 없음" 으로 조용히 통과했다 — 못 본 것을 봤다고 답하는 셈이다.
mcp_readable() { jq -e 'type == "object" and ((.mcpServers // {}) | type) == "object"' "$1" >/dev/null 2>&1; }
mcp_keys() { jq -r '.mcpServers // {} | keys[]' "$1" 2>/dev/null | sort; }
MCP_USER=0; MCP_SETTINGS=0; MCP_DUPES='[]'
_bad=""
for f in "$HOME/.claude.json" "$HOME/.claude/settings.json"; do
  [ -f "$f" ] || continue
  # `${f#$HOME/}` 는 HOME 에 glob 문자가 있으면 오작동한다 — 접두사는 따옴표로 고정.
  if ! mcp_readable "$f"; then _bad="${_bad}${f#"$HOME/"}"$'\n'; fi
done
MCP_UNREADABLE=$(printf '%s' "$_bad" | jq -Rsc 'split("\n") | map(select(length>0))')
if [ -f "$HOME/.claude.json" ] && mcp_readable "$HOME/.claude.json"; then
  MCP_USER=$(mcp_keys "$HOME/.claude.json" | wc -l | tr -d ' ')
fi
if [ -f "$HOME/.claude/settings.json" ] && mcp_readable "$HOME/.claude/settings.json"; then
  MCP_SETTINGS=$(mcp_keys "$HOME/.claude/settings.json" | wc -l | tr -d ' ')
fi
if [ "$MCP_USER" -gt 0 ] && [ "$MCP_SETTINGS" -gt 0 ]; then
  MCP_DUPES=$(comm -12 <(mcp_keys "$HOME/.claude.json") <(mcp_keys "$HOME/.claude/settings.json") | jq -Rsc 'split("\n") | map(select(length>0))')
fi
# 중복 이름의 엔트리 본문 비교. 이름이 같아도 정의가 다르면 (drift) 현재 구성에서
# 지는 사본이 무효라는 뜻 — 내용 동일 중복(WARN)과 급이 다르다 (FAIL). 비교는
# jq 한 표현식 안에서 두 파일을 slurp 해 수행한다: 이름을 shell 로 개행 구분 전송하면
# 개행 포함 키가 쪼개져 오분류되므로 (그리고 jq 객체 == 는 키 순서 무관), 전 과정을
# jq 안에 가둔다. 두 파일은 이 지점에서 이미 readable 이 확인됐다 (MCP_DUPES 조건).
MCP_DRIFTED='[]'
if [ "$MCP_DUPES" != '[]' ]; then
  MCP_DRIFTED=$(jq -c --slurpfile a "$HOME/.claude.json" --slurpfile b "$HOME/.claude/settings.json" \
    '[ .[] | . as $k | select(($a[0].mcpServers[$k]) != ($b[0].mcpServers[$k])) ]' \
    <<<"$MCP_DUPES" 2>/dev/null || printf '[]')
fi

# --- .claude/rules 스코핑 무력화 -------------------------------------------
# `paths:` frontmatter 는 조건부 로드다. 그런데 CLAUDE.md 가 같은 파일을 `@import`
# 하면 launch 때 무조건 전개돼 스코핑이 죽는다 (import 는 조건을 모른다).
RULES_DEFEATED='[]'
if [ -f CLAUDE.md ] && [ -d .claude/rules ]; then
  RULES_DEFEATED=$(
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      [ "$(head -1 "$f")" = "---" ] || continue
      sed -n '1,10p' "$f" | grep -q '^paths:' || continue
      grep -q "@\.claude/rules/$(basename "$f")" CLAUDE.md && basename "$f"
    done <<EOF
$(find_or_empty .claude/rules -maxdepth 1 -type f -name '*.md')
EOF
  ) || true
  RULES_DEFEATED=$(printf '%s' "${RULES_DEFEATED:-}" | jq -Rsc 'split("\n") | map(select(length>0))')
fi

# --- codex CLI 자세 -------------------------------------------------------
# 값 판단은 스킬이 한다 — 여기서는 읽기만. 의도적 설정일 수 있으므로 결함이 아니다.
# Codex 는 `$CODEX_HOME` 을 존중한다 (`codex --help`: "Layer $CODEX_HOME/<name>.config.toml").
# `$HOME/.codex` 만 보면 그 환경에서 설정이 있는데도 config:false 로 보고해
# approval/sandbox 자세와 doc-budget WARN 이 통째로 사라진다.
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
# TOML allows an inline comment after a value. Cut from the first space-hash so
# `approval_policy = "never" # yolo` reads as `never`, while a `#` inside a quoted
# value (`model = "gpt#5"`) survives.
toml_val() {
  sed -n "s/^$1 *= *//p" "$CODEX_HOME_DIR/config.toml" 2>/dev/null | head -1 \
    | sed -e 's/[[:space:]]#.*$//' -e 's/[[:space:]]*$//' | tr -d '"'
}
CODEX_CONFIG=$(b test -f "$CODEX_HOME_DIR/config.toml")
CODEX_APPROVAL=""; CODEX_SANDBOX=""; CODEX_MODEL=""; CODEX_DOC_MAX=32768
if [ "$CODEX_CONFIG" = true ]; then
  CODEX_APPROVAL=$(toml_val approval_policy)
  CODEX_SANDBOX=$(toml_val sandbox_mode)
  CODEX_MODEL=$(toml_val model)
  # Only this value reaches jq through `--argjson`, which demands strict JSON.
  # A valid TOML integer may carry `_` digit separators (`65_536`), and anything
  # non-numeric that slips through aborts jq *before the script prints anything* —
  # the whole diagnostic dies, not just this axis. Accept digits only; otherwise
  # keep the documented default.
  v=$(toml_val project_doc_max_bytes | tr -d '_')
  case "$v" in
    '' | *[!0-9]*) : ;;
    *) CODEX_DOC_MAX="$v" ;;
  esac
fi
AGENTS_BYTES=0; [ -f AGENTS.md ] && AGENTS_BYTES=$(wc -c < AGENTS.md | tr -d ' ')
AGENTS_GLOBAL_BYTES=0; [ -f "$CODEX_HOME_DIR/AGENTS.md" ] && AGENTS_GLOBAL_BYTES=$(wc -c < "$CODEX_HOME_DIR/AGENTS.md" | tr -d ' ')

# --- 사용자가 이미 답한 ASK 항목 -------------------------------------------
# 결함이 아니라 결정인 축(git remote, gws-sync ...)의 답을 보관한다.
# 답이 있으면 스킬은 다시 묻지 않는다.
ANSWERS='{}'
if [ -f .claude/state/wiring.json ]; then
  ANSWERS=$(jq -c '.answers // {}' .claude/state/wiring.json 2>/dev/null || echo '{}')
fi

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
  --argjson mcp_user "$MCP_USER" --argjson mcp_settings "$MCP_SETTINGS" --argjson mcp_dupes "$MCP_DUPES" \
  --argjson mcp_drifted "$MCP_DRIFTED" --argjson mcp_unreadable "$MCP_UNREADABLE" \
  --argjson rules_defeated "$RULES_DEFEATED" \
  --argjson codex_config "$CODEX_CONFIG" --arg codex_approval "$CODEX_APPROVAL" \
  --arg codex_sandbox "$CODEX_SANDBOX" --arg codex_model "$CODEX_MODEL" \
  --argjson codex_doc_max "$CODEX_DOC_MAX" --argjson agents_bytes "$AGENTS_BYTES" \
  --argjson agents_global_bytes "$AGENTS_GLOBAL_BYTES" \
  --argjson answers "$ANSWERS" \
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
    gitignore: { claude_state: $gi_state, serena: $gi_serena, llmwiki_staging: $gi_staging, tmp: $tmp_ignored, env: $gi_env },
    mcp: { user_json: $mcp_user, settings_json: $mcp_settings, duplicates: $mcp_dupes, duplicates_drifted: $mcp_drifted, unreadable: $mcp_unreadable },
    rules_scoping: { paths_defeated_by_import: $rules_defeated },
    codex: {
      config: $codex_config,
      approval_policy: (if $codex_approval == "" then null else $codex_approval end),
      sandbox_mode: (if $codex_sandbox == "" then null else $codex_sandbox end),
      model_pinned: (if $codex_model == "" then null else $codex_model end),
      project_doc_max_bytes: $codex_doc_max,
      agents_md_bytes: $agents_bytes,
      global_agents_md_bytes: $agents_global_bytes
    },
    answers: $answers
  }'
