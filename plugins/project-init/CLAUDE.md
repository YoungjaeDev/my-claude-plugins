# Project-Init Plugin

새 프로젝트의 Day-1 셋업 (`.claude/`, CLAUDE.md, AGENTS.md, README/CHANGELOG, gh repo create+push) 을 orchestrate. **Dual-surface**: 명시적 슬래시 호출 (`/project-init:new`) 과 capability-discovery 용 skill (`new`) 양쪽으로 노출, 본문은 `references/new-procedure.md` 한 곳.

## Surfaces

| Surface | Entry | Description |
|---------|-------|-------------|
| Command | `/project-init:new` | 명시적 사용자 호출 — primary surface. |
| Skill | `new` | Codex (및 Claude Code) 의 capability-discovery 용. description 이 좁게 잡혀 "bootstrap a new project in this empty dir" 류만 매치. |

두 surface 모두 본문 첫 블록에 **preflight hard guard** 를 둔다 — `.git/` / `.claude/` / source-file 이 cwd 에 하나라도 있으면 abort. description 기반 매칭에만 기대지 않고 runtime 에서 강제.

## 원칙

- **Preflight hard guard is non-negotiable**: `commands/new.md` 와 `skills/new/SKILL.md` 양쪽 Step 0 에 동일한 가드가 박혀 있다. description 만으로 잘못된 트리거를 막을 수 없다는 전제 — 모델이 description 을 잘못 해석해도 runtime 이 막는다. 가드 제거는 사용자의 명시적 (high-friction, 의도적) 결정이어야 한다.
- **Minimal seeding, explicit follow-ups**: Day-1 에 필요한 것만 시드. tech-stack 기반 rules 생성과 wiki 도메인 인터뷰는 **호출 X, 안내만**. 빈 프로젝트에 generic 콘텐츠 만들면 사용자 덮어쓰기 비용 발생.
- **Owner gate is mandatory**: 사용자가 personal + 다중 org 컨텍스트라 owner 자동 결정 금지. `AskUserQuestion` 으로 명시 선택.
- **Codex GitHub reviewer surface**: AGENTS.md `## Review guidelines` 섹션이 Codex GitHub cloud reviewer 가 자동으로 읽는 영역. **레포 생성 시점에 시드**해야 첫 PR 부터 효과.
- **Idempotent re-runs**: 같은 디렉토리에서 두 번째 호출 시 기존 파일 보존 + 단계 skip + 안내 메시지. 절대 덮어쓰지 않음. (단, hard guard 가 .git/.claude 존재만으로도 abort 시키므로 일반 경로에서는 idempotent 재실행이 발생하지 않는다 — 가드를 우회한 partial seed 회복 경로에서만 의미.)

## 파일 구성

```text
plugins/project-init/
├── .claude-plugin/plugin.json
├── commands/new.md                     # 명시적 슬래시 surface (preflight guard + 포인터)
├── skills/new/SKILL.md                 # 스킬 surface (동일 preflight guard + 포인터)
├── references/
│   ├── new-procedure.md                # 본문 (Phase 0–7) — 두 surface 가 공유
│   ├── codex-review-discovery.md       # AGENTS.md vs /review CLI
│   └── gh-repo-create-flow.md          # owner 추론 + visibility 결정
├── assets/                             # 출력물에 직접 들어가는 템플릿
│   ├── AGENTS.review-guidelines.md     # general variant (base)
│   ├── AGENTS.review-guidelines.ml.md  # ML/data variant
│   ├── AGENTS.review-guidelines.web.md # 웹/풀스택 variant
│   ├── README.minimal.md
│   └── CHANGELOG.initial.md
├── scripts/
│   ├── infer-github-context.sh         # gh api user + orgs
│   └── idempotent-seed.sh              # 충돌 가드 + .claude/ + .llmwiki/ 시드
└── CLAUDE.md                           # this file
```

## Preflight guard contract

`commands/new.md` 와 `skills/new/SKILL.md` Step 0 에 동일한 POSIX shell 블록:

```bash
if [ -d .git ] || [ -d .claude ] || [ -n "$(find . -maxdepth 2 -type f \
    \( -name '*.py' -o -name '*.ts' -o -name '*.js' -o -name '*.go' \
    -o -name '*.rs' -o -name '*.java' -o -name 'package.json' \
    -o -name 'pyproject.toml' -o -name 'Cargo.toml' -o -name 'go.mod' \) \
    2>/dev/null)" ]; then
  echo "[abort] project-init refuses to run in a non-empty directory."
  ...
  exit 1
fi
```

- **Detected sentinels**: `.git/`, `.claude/`, common source-file extensions, common manifests (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`).
- **Search depth**: 2 levels (`find -maxdepth 2`).
- **Abort message**: surfaces cwd + a redirect to `/rules-forge:write-rules` or `/llm-wiki:bootstrap-wiki` for the "scaffold an existing project" case.
- **Non-POSIX hosts**: PowerShell-default environments must invoke via `bash -c '<guard>'` (Git Bash / WSL / Cygwin). The intent of the check, not the literal shell, is what matters — equivalent PowerShell rewrites are acceptable as long as they refuse the same conditions.

수정할 때는 두 파일 양쪽을 동시에 업데이트해야 한다. 한쪽만 바꾸면 surface 간 동작이 갈린다.

## Placeholder 규약

assets/ 의 템플릿은 다음 placeholder 만 사용한다 (sed 치환):

| Placeholder | 의미 |
|-------------|------|
| `{{PROJECT_NAME}}` | 프로젝트 이름 (Phase 1 응답) |
| `{{ONE_LINER}}` | 한 줄 description |
| `{{OWNER}}` | personal account 또는 org 이름 |
| `{{LICENSE}}` | MIT / Apache-2.0 / GPL-3.0 / None |
| `{{YEAR}}` | 현재 연도 |

추가 placeholder 도입 시 `references/new-procedure.md` Phase 4/5 의 sed 라인을 함께 업데이트.

## AGENTS.md Variant 정책

3 개 파일은 동일한 골격을 공유한다:

1. `## Project context` — `{{PROJECT_NAME}}` + `{{ONE_LINER}}` (1-2 줄)
2. `## Build / Test / Lint` — 자리 표시자 TODO
3. `## Review guidelines` — **Codex 클라우드 리뷰어가 읽는 섹션**
   - `### Do not flag` (린터 영역 — 도구가 처리)
   - `### P0 — Correctness / Security`
   - `### P1 — Performance / Maintainability`
   - `### Domain-specific` (variant 별로 다름; general 은 TODO 만)

variant 차이는 `### Domain-specific` 섹션 + `### P0` / `### P1` 에 도메인별 1-2 항목 추가. **base 위에 도메인 섹션만 다르게** — 코드 중복 최소화.

## Out of Scope

- CI/CD workflow seed (`.github/workflows/`) — variant 별 다양성 너무 큼
- Pre-commit hook seed — 같은 이유
- Boilerplate auto-download (cookiecutter, copier) — `/code-scout:scout` 별도 호출
- Multi-language 인터뷰 분기 — 한/영 혼용 단일 버전 유지

## 참조

- Plugin versioning rules: `.claude/rules/plugin-versioning.md`
- Codex GitHub integration: <https://developers.openai.com/codex/integrations/github>
- 관련 follow-up: `/rules-forge:write-rules`, `/llm-wiki:bootstrap-wiki`
