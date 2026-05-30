---
name: new
description: Bootstrap a brand-new project from scratch in the current directory and create its GitHub repo — interview for name/owner/visibility/license, scaffold `.claude/`, seed a minimal CLAUDE.md (LLM-Wiki entrypoint) + AGENTS.md (Codex reviewer guidelines) + README + CHANGELOG, then `gh repo create` + initial push. Use ONLY when the user explicitly wants to initialize/bootstrap a NEW project or create a new GitHub repo for the current directory (e.g. "bootstrap this new project", "set up a new repo here", "project-init"). Do NOT trigger for existing projects or casual mentions of "new" — it runs `gh repo create` and seeds files, so it always confirms the working directory and intent first.
---

# project-init: new

Bootstrap a "Day 1 ready" project in the current directory — interview → local
seed → `gh` repo create → initial commit/push.

> **High-stakes / not auto-run silently**: this seeds files into the current
> directory and creates a real GitHub repo. It must NOT proceed on a vague
> mention. Always run the Phase 0 directory + intent confirmation gate first;
> if the user has not clearly asked to bootstrap a new project HERE, stop and
> confirm. **Residual risk**: triggering in the wrong directory would seed files
> and create a repo for the wrong project — the Phase 0 gate exists to prevent this.

## 핵심 원칙

- **Minimal seeding, explicit follow-ups**: Day 1 에 진짜 필요한 것 (`.claude/` 빈 구조, CLAUDE.md stub, AGENTS.md review guidelines, README/CHANGELOG, gh 레포) 만 시드. tech-stack 기반 rules 생성 (`rules-forge:write-rules` 스킬) 와 wiki domain 인터뷰 (`llm-wiki:bootstrap-wiki` 스킬) 는 **호출하지 않고 Phase 7 안내만**. 빈 프로젝트에 generic 콘텐츠 생성하면 사용자가 덮어쓰는 비용 발생.
- **Owner gate is mandatory**: 사용자가 부업 컨텍스트 (개인 + 조직 레포) 를 가져 owner 결정은 자동화 금지 — Phase 1 인터뷰에서 반드시 묻는다.
- **Codex GitHub reviewer surface**: `AGENTS.md` 의 `## Review guidelines` 섹션이 Codex GitHub cloud reviewer 가 자동으로 읽는 영역. 레포 생성 시점에 시드해야 첫 PR 부터 효과.

## 사전 조건

- `gh` CLI 설치 + `gh auth status` OK
- `git` 설치
- `jq` 설치 (Phase 0 의 `infer-github-context.sh` 와 일부 placeholder 치환 헬퍼가 의존)
- 현재 디렉토리가 작업 대상 — `pwd` 출력을 사용자에게 보여주고 진행 확인

## Phase 0 — Preflight + intent gate

먼저 **현재 디렉토리와 의도를 반드시 확인**한다. `pwd` 를 출력하고, 이 디렉토리에서
새 프로젝트를 부트스트랩 + gh 레포 생성할 의도가 맞는지 `AskUserQuestion` 으로
확인한 뒤에만 진행한다. 사용자가 명시적으로 요청하지 않았거나 디렉토리가 의심스러우면
중단한다.

```bash
# 이 스킬의 자기 디렉토리 해석 — 번들된 scripts/ · assets/ 는 모두 여기 기준.
# Claude Code 는 ${CLAUDE_PLUGIN_ROOT} 를 주입하지만 Codex 등 다른 런타임은 주입하지
# 않으므로, 미설정이면 이 SKILL.md 가 로드된 절대 디렉토리(스킬 로드 시 표시됨)로
# SKILL_DIR 을 직접 설정한다. 절대 `${CLAUDE_PLUGIN_ROOT}` 만 의존하지 말 것.
SKILL_DIR="${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/skills/new}"
# CLAUDE_PLUGIN_ROOT 미설정(Codex 등): SKILL_DIR 를 이 스킬 디렉토리 절대경로로 지정.
[ -n "$SKILL_DIR" ] || SKILL_DIR="<이 SKILL.md 가 위치한 skills/new 디렉토리의 절대경로>"
[ -f "$SKILL_DIR/scripts/infer-github-context.sh" ] || { echo "[abort] SKILL_DIR resolution failed: $SKILL_DIR"; exit 1; }

# 인증 확인
gh auth status || { echo "[abort] gh CLI not authenticated. Run: gh auth login"; exit 1; }

# Git identity 추출
GIT_USER_NAME=$(git config --global user.name || echo "")
GIT_USER_EMAIL=$(git config --global user.email || echo "")

# 현재 디렉토리 상태 진단
CWD=$(pwd)
DIR_NAME=$(basename "$CWD")
HAS_GIT=$([ -d .git ] && echo "yes" || echo "no")
HAS_CLAUDE=$([ -d .claude ] && echo "yes" || echo "no")
HAS_CODE=$(find . -maxdepth 2 -type f \( -name "*.py" -o -name "*.ts" -o -name "*.js" -o -name "*.go" -o -name "*.rs" -o -name "*.java" \) 2>/dev/null | head -1 | wc -l)

# GitHub owner 후보 수집
bash $SKILL_DIR/scripts/infer-github-context.sh
# 출력: JSON { "personal": "<login>", "orgs": ["<org1>", "<org2>", ...] }
```

만약 `HAS_CLAUDE=yes` 또는 `.git/` 안에 commit 가 이미 있는 경우 — **idempotency guard** 발동:
- `AskUserQuestion` 으로 "이미 셋업된 디렉토리. 계속 시도하면 기존 파일은 보존되지만 일부 단계가 skip 됨. 계속?" 확인.

## Phase 1 — Project Identity Interview

**Single batched `AskUserQuestion` — 4 questions** (description 은 자유 텍스트라 Other 로 받음).

Question 1: **Project name**
- header: "Name"
- options: `<DIR_NAME>` (default) / "Custom (Other)"

Question 2: **Owner**
- header: "Owner"
- options: 동적 생성 — Phase 0 의 personal account + 모든 orgs. 각 옵션 description 에 "Personal" / "Organization" 표시.

Question 3: **Visibility**
- header: "Visibility"
- options: "Private (Recommended)" / "Public"
- (org owner 면 "Internal" 추가)

Question 4: **License**
- header: "License"
- options: "MIT (Recommended)" / "Apache-2.0" / "GPL-3.0" / "None"

> Description (one-liner) 은 별도 평문 질문 X — Phase 1 응답 받은 직후 평문으로 한 줄 짧게 묻거나, AskUserQuestion 의 Other 입력으로 받는다. 평문 description 입력이 더 자연스러우므로 별도 짧은 질문 1 회 허용.

## Phase 2 — `.claude/` Scaffold (structure only)

```bash
bash $SKILL_DIR/scripts/idempotent-seed.sh ensure-claude-dirs
# 생성: .claude/{spec,rules}/.gitkeep + .llmwiki/{raw,wiki}/.gitkeep
```

`bootstrap-wiki` / `write-rules` 스킬은 호출하지 않는다 — 빈 프로젝트에는 적을 lore 도, tech-stack signal 도 없다.

## Phase 3 — CLAUDE.md Minimal Stub

기존 `CLAUDE.md` 가 있으면 skip with notice. 없으면 다음 형태로 작성:

```markdown
# <project_name>

<one-line description>

## LLM Wiki (`.llmwiki/wiki/`)

이 프로젝트는 Karpathy LLM-Wiki 3-layer 시스템 위에 동작한다. 도메인 lore (provider quirks, design rationale, debugging stories) 는 wiki 가 보관한다.

- **진입점**: `.llmwiki/wiki/index.md` (Map of Content). 페이지 직접 grep 금지.
- **사용 순서**:
  1. lore 가 필요할 때 → `llm-wiki:query-wiki` 스킬 먼저
  2. 새 발견 → `llm-wiki:ingest-finding` 스킬
  3. PR merge 후 → `github-dev:post-merge` 스킬이 자동으로 `llm-wiki:post-merge-wiki` 체이닝
- **현재 상태**: wiki 비어있음. 적극 채워라. 첫 도메인 lore 가 쌓이기 시작하면 `llm-wiki:bootstrap-wiki` 스킬로 도메인 구조 인터뷰를 받는다.

## Setup Status

이 파일은 project-init 의 `new` 스킬이 만든 minimal stub 이다. 코드가 어느 정도 쌓이면 다음을 호출해라:

- `rules-forge:write-rules` 스킬 — tech-stack 기반 CLAUDE.md + `.claude/rules/*.md` 재생성
- `llm-wiki:bootstrap-wiki` 스킬 — 첫 wiki 도메인 인터뷰 + 템플릿 시드

> 사용자의 global `~/.claude/CLAUDE.md` 가 항상 우선한다. 이 파일은 프로젝트 한정 규칙만 보관한다.
```

placeholder (`<project_name>`, `<one-line description>`) 는 Phase 1 응답으로 치환.

## Phase 4 — AGENTS.md Seed (★ 이 플러그인의 차별점)

**Variant 선택**: Phase 1 description 키워드로 추천하되 사용자 확인.

| Keyword in description | Recommended variant |
|------------------------|---------------------|
| "deep learning", "ML", "model", "training", "dataset", "vision", "NLP" | `ml` |
| "web", "fullstack", "frontend", "backend", "API", "REST", "GraphQL" | `web` |
| 그 외 / 명확하지 않음 | `general` (base) |

`AskUserQuestion`:
- header: "Variant"
- options: "<recommended> (Recommended)" / 나머지 2 개

> 응답을 `VARIANT` 변수에 할당 (예: `general` / `ml` / `web`). 사용자가 비워두거나 응답 누락 시 default `VARIANT=general`.

```bash
# Portable in-place sed — GNU sed 는 `sed -i 'cmd' file`, BSD/macOS sed 는
# `sed -i '' 'cmd' file` 시그니처. `sed --version` 으로 분기한다.
if sed --version >/dev/null 2>&1; then
  sed_inplace() { sed -i "$@"; }
else
  sed_inplace() { sed -i '' "$@"; }
fi

# POSIX 소문자화 — ${VAR,,} 는 Bash 4+ 전용이라 macOS 기본 /bin/bash (3.2) 에서
# bad substitution 으로 깨진다. tr 로 대체 (Phase 6 visibility 정규화에서도 재사용).
to_lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# AskUserQuestion 라벨 ("ml (Recommended)" / "web" / "general") 을
# 파일명 토큰 (general|ml|web) 으로 정규화. 알 수 없는 값은 abort.
variant_lower=$(to_lower "$VARIANT")
case "$variant_lower" in
  *ml*)         VARIANT_FLAG="ml" ;;
  *web*)        VARIANT_FLAG="web" ;;
  *general*|"") VARIANT_FLAG="general" ;;
  *) echo "[abort] Unknown variant: $VARIANT"; exit 1 ;;
esac

SRC="$SKILL_DIR/assets/AGENTS.review-guidelines.${VARIANT_FLAG}.md"
# Variant 가 general 이면 base 파일
[ "$VARIANT_FLAG" = "general" ] && SRC="$SKILL_DIR/assets/AGENTS.review-guidelines.md"

# sed replacement 컨텍스트에서 위험한 문자 (\, &, |) escape — 사용자 입력에
# "Frontend & Backend" 같은 `&` 가 있으면 sed 가 매치 전체를 다시 삽입한다.
esc_sed() { printf '%s' "$1" | sed 's/[\\&|]/\\&/g'; }
PROJECT_NAME_ESC=$(esc_sed "$PROJECT_NAME")
ONE_LINER_ESC=$(esc_sed "$ONE_LINER")
OWNER_ESC=$(esc_sed "$OWNER")
LICENSE_ESC=$(esc_sed "$LICENSE")

if [ ! -f AGENTS.md ]; then
  cp "$SRC" AGENTS.md
  # placeholder 치환 (escape 된 값 사용)
  sed_inplace "s|{{PROJECT_NAME}}|${PROJECT_NAME_ESC}|g" AGENTS.md
  sed_inplace "s|{{ONE_LINER}}|${ONE_LINER_ESC}|g" AGENTS.md
  sed_inplace "s|{{OWNER}}|${OWNER_ESC}|g" AGENTS.md
else
  echo "[skip] AGENTS.md already exists — preserving existing content"
fi
```

AGENTS.md 의 `## Review guidelines` 섹션은 Codex GitHub cloud reviewer 가 자동으로 읽는다 ([OpenAI Codex GitHub integration](https://developers.openai.com/codex/integrations/github)) — 사용자에게 한 줄 안내. 배경은 `references/codex-review-discovery.md` 참조.

## Phase 5 — README + CHANGELOG

```bash
# 새로 시드한 파일만 추적 — 기존 파일에 의도적으로 둔 {{PROJECT_NAME}} 류
# placeholder 가 변조되지 않도록 cp 한 파일에만 치환을 적용한다.
SEEDED_FILES=()
if [ ! -f README.md ]; then
  cp "$SKILL_DIR/assets/README.minimal.md" README.md
  SEEDED_FILES+=("README.md")
fi
if [ ! -f CHANGELOG.md ]; then
  cp "$SKILL_DIR/assets/CHANGELOG.initial.md" CHANGELOG.md
  SEEDED_FILES+=("CHANGELOG.md")
fi

# Phase 4 에서 정의한 sed_inplace / *_ESC 재사용 — escape + 플랫폼 portable
for f in "${SEEDED_FILES[@]}"; do
  sed_inplace "s|{{PROJECT_NAME}}|${PROJECT_NAME_ESC}|g" "$f"
  sed_inplace "s|{{ONE_LINER}}|${ONE_LINER_ESC}|g" "$f"
  sed_inplace "s|{{OWNER}}|${OWNER_ESC}|g" "$f"
  sed_inplace "s|{{LICENSE}}|${LICENSE_ESC}|g" "$f"
done
```

게이트: README.md 첫 30줄 미리보기 후 수정 기회. 한 번 더 호출하지 않고 inline `Edit` 로 즉시 수정.

## Phase 6 — GitHub Repo Creation

배경 의사결정 컨텍스트는 `references/gh-repo-create-flow.md` 참조.

```bash
# Git init if needed
[ -d .git ] || git init -b main

# Stage all seeded files (이미 존재한 파일은 git add 가 no-op)
git add .claude/ .llmwiki/ CLAUDE.md AGENTS.md README.md CHANGELOG.md

# Idempotent re-run 경로: Phase 4/5 가 모두 skip 했고 staged diff 가 없으면
# `git commit` 이 `nothing to commit` 으로 실패해 이후 gh repo create 까지
# abort 된다. staged 변경 존재 여부로 분기한다.
if ! git diff --cached --quiet; then
  git commit -m "chore: bootstrap project skeleton via project-init"
else
  echo "[skip] no new changes to commit — idempotent re-run path"
fi
```

`AskUserQuestion`: dry-run 미리보기 후 confirm (gh repo create 는 비가역 — 반드시 미리보기 + 확인 후 실행).

```bash
# AskUserQuestion 라벨 ("Private (Recommended)", "Public", "Internal") 을
# gh CLI 토큰 (private|public|internal) 으로 정규화.
# Phase 4 의 to_lower 헬퍼 재사용 (POSIX tr — Bash 3.2 호환).
vis_lower=$(to_lower "$VISIBILITY")
case "$vis_lower" in
  *private*)  VIS_FLAG="private" ;;
  *public*)   VIS_FLAG="public" ;;
  *internal*) VIS_FLAG="internal" ;;
  *) echo "[abort] Unknown visibility: $VISIBILITY"; exit 1 ;;
esac

# Idempotent re-run 가드: origin remote 가 이미 있으면 `gh repo create
# --remote=origin` 이 중복 등록을 시도하다 실패한다. 기존 remote 가 가리키는
# URL 을 노출하고 사용자에게 manual push 명령을 안내한다.
if git remote get-url origin >/dev/null 2>&1; then
  EXISTING=$(git remote get-url origin)
  echo "[skip] origin remote already exists ($EXISTING) — skipping gh repo create."
  echo "       manual sync: git push -u origin $(git branch --show-current)"
else
  # Repo create + push (dry-run preview first, then real run)
  PREVIEW="gh repo create ${OWNER}/${PROJECT_NAME} --${VIS_FLAG} --description \"${ONE_LINER}\" --source=. --remote=origin --push"
  echo "$PREVIEW"

  # User confirms via AskUserQuestion (Recommended: "Run")
  gh repo create "${OWNER}/${PROJECT_NAME}" --"${VIS_FLAG}" --description "${ONE_LINER}" --source=. --remote=origin --push
fi
```

License 가 None 이 아니면 — gh repo create 후 `gh api` 로 LICENSE 파일 생성하거나 사용자에게 "later" 안내. 단순화를 위해 V1 에서는 안내만.

## Phase 7 — Summary + Next Actions

```text
✓ Project '<name>' bootstrapped at <cwd>

Files seeded:
  .claude/spec/.gitkeep
  .claude/rules/.gitkeep
  .llmwiki/raw/.gitkeep
  .llmwiki/wiki/.gitkeep
  CLAUDE.md       (minimal stub — LLM Wiki entrypoint)
  AGENTS.md       (variant: <variant> — includes Codex Review guidelines)
  README.md       (6-section minimal)
  CHANGELOG.md    ([Unreleased] only)

GitHub repo: https://github.com/<owner>/<name>

Next actions (invoke the skill when ready):
  1. 코드가 쌓이면        → rules-forge:write-rules 스킬
     (tech-stack 기반 CLAUDE.md + .claude/rules/*.md 재생성)

  2. 첫 도메인 lore 쌓이면 → llm-wiki:bootstrap-wiki 스킬
     (도메인 인터뷰 + .llmwiki/wiki/<domain>/ 구조 시드)

  3. 첫 PR merge 후        → github-dev:post-merge 스킬
     (자동으로 llm-wiki:post-merge-wiki 체이닝)
```

## 실패 처리

| 단계 | 실패 시 동작 |
|------|--------------|
| Phase 0 — gh auth | abort + 안내 (`gh auth login`) |
| Phase 0 — 디렉토리/의도 미확인 | 즉시 stop, 아무것도 시드/생성하지 않음 |
| Phase 0 — idempotency guard 사용자 abort | 즉시 stop, partial seed 보존 |
| Phase 6 — `gh repo create` | local 변경/커밋은 그대로, push 만 실패. 사용자에게 manual retry 명령 안내 |
| Phase 6 — repo 이름 충돌 | gh CLI error 메시지 그대로 노출 + Phase 1 재시도 권유 |

## Out of Scope

- CI/CD workflow seed (`.github/workflows/`)
- pre-commit hook seed
- 외부 boilerplate auto-download (cookiecutter 등 — 필요하면 `code-scout:research-orchestrator` 스킬 별도 호출)
- 다국어 인터뷰 분기 — 한/영 혼용 단일 버전 유지
