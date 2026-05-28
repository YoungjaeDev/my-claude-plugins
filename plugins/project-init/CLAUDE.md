# Project-Init Plugin

새 프로젝트의 Day-1 셋업 (`.claude/`, CLAUDE.md, AGENTS.md, README/CHANGELOG, gh repo create+push) 을 단일 `/project-init:new` 명령으로 orchestrate.

## Command

| Command | Description |
|---------|-------------|
| `/project-init:new` | 인터뷰 → 로컬 시드 → gh repo 생성 → 초기 커밋/푸시. 명시적 호출 only (자동 트리거 없음). |

## 원칙

- **Minimal seeding, explicit follow-ups**: Day-1 에 필요한 것만 시드. tech-stack 기반 rules 생성과 wiki 도메인 인터뷰는 **호출 X, 안내만**. 빈 프로젝트에 generic 콘텐츠 만들면 사용자 덮어쓰기 비용 발생.
- **Owner gate is mandatory**: 사용자가 personal + 다중 org 컨텍스트라 owner 자동 결정 금지. `AskUserQuestion` 으로 명시 선택.
- **Codex GitHub reviewer surface**: AGENTS.md `## Review guidelines` 섹션이 Codex GitHub cloud reviewer 가 자동으로 읽는 영역. **레포 생성 시점에 시드**해야 첫 PR 부터 효과.
- **Idempotent re-runs**: 같은 디렉토리에서 두 번째 호출 시 기존 파일 보존 + 단계 skip + 안내 메시지. 절대 덮어쓰지 않음.

## 파일 구성

```
plugins/project-init/
├── .claude-plugin/plugin.json
├── commands/new.md                     # 단일 orchestration command
├── assets/                             # 출력물에 직접 들어가는 템플릿
│   ├── AGENTS.review-guidelines.md     # general variant (base)
│   ├── AGENTS.review-guidelines.ml.md  # ML/data variant
│   ├── AGENTS.review-guidelines.web.md # 웹/풀스택 variant
│   ├── README.minimal.md
│   └── CHANGELOG.initial.md
├── references/                         # 의사결정 context
│   ├── codex-review-discovery.md       # AGENTS.md vs /review CLI
│   └── gh-repo-create-flow.md          # owner 추론 + visibility 결정
├── scripts/
│   ├── infer-github-context.sh         # gh api user + orgs
│   └── idempotent-seed.sh              # 충돌 가드 + .claude/ 시드
└── CLAUDE.md                           # this file
```

## Placeholder 규약

assets/ 의 템플릿은 다음 placeholder 만 사용한다 (sed 치환):

| Placeholder | 의미 |
|-------------|------|
| `{{PROJECT_NAME}}` | 프로젝트 이름 (Phase 1 응답) |
| `{{ONE_LINER}}` | 한 줄 description |
| `{{OWNER}}` | personal account 또는 org 이름 |
| `{{LICENSE}}` | MIT / Apache-2.0 / GPL-3.0 / None |
| `{{YEAR}}` | 현재 연도 |

추가 placeholder 도입 시 `commands/new.md` Phase 4/5 의 sed 라인을 함께 업데이트.

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
- Codex GitHub integration: https://developers.openai.com/codex/integrations/github
- 관련 follow-up: `/rules-forge:write-rules`, `/llm-wiki:bootstrap-wiki`
