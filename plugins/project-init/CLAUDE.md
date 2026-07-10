# Project-Init Plugin

프로젝트의 **에이전트 하네스 lifecycle** 을 orchestrate. 두 방향이 대칭을 이룬다.

- `new` — Day-1 셋업 (`.claude/`, CLAUDE.md, AGENTS.md, README/CHANGELOG, gh repo create+push). **빈 디렉토리 전용.**
- `wiring` — 이미 존재하는 repo 의 하네스 설정 진단. **`new` 의 역방향.** read-only 탐지 후 `AskUserQuestion` 게이트 뒤에서만 수정.

## Surfaces

| Surface | Entry | Description |
|---------|-------|-------------|
| Command | `/project-init:new` | 명시적 사용자 호출 — bootstrap 의 primary surface. |
| Skill | `new` | Codex (및 Claude Code) 의 capability-discovery 용. description 이 좁게 잡혀 "bootstrap a new project in this empty dir" 류만 매치. |
| Skill | `wiring` | 기존 repo 진단. command surface 없음 — `/project-init:wiring` 스킬 호출로 충분하고, command 는 Codex 로 emit 되지 않아 본문만 이중화된다. |

`new` 의 두 surface 는 본문 첫 블록에 **preflight hard guard** 를 둔다 — `.git/` / `.claude/` / source-file 이 cwd 에 하나라도 있으면 abort. description 기반 매칭에만 기대지 않고 runtime 에서 강제. `wiring` 에는 이 가드가 없다 (정의상 비어있지 않은 repo 에서만 의미).

## 탐지 SSOT

`scripts/project_state.sh` 가 프로젝트 상태 탐지를 **혼자** 담당한다. 순수 read-only, JSON 한 덩어리 출력.

- `wiring` 은 14 축 전체를 소비한다. 그중 4 축은 "파일이 있나"가 아니라 **"그 설정이 실제로 발효하나"** 를 본다 — `core.hooksPath`(clone 마다 켜야 함), `.claude/rules` 의 `paths:` 스코핑을 `@import` 가 무력화했는지, 같은 MCP 서버가 두 user-scope 파일에 등록돼 한쪽 정의가 통째로 버려지는지, Codex `AGENTS.md` 가 `project_doc_max_bytes` 예산 안에 드는지.
- 결함이 아니라 **결정**인 축(`git remote`, `gws-sync`)은 `ASK` 로 낸다. 답은 `.claude/state/wiring.json` 의 `answers` 에 적히고 스크립트가 그대로 실어 보낸다 — 스킬은 이미 답한 항목을 다시 묻지 않는다. 값은 머신마다 다르므로(Drive 폴더 id 등) gitignored state 에 남고, `CLAUDE.md` 에는 **경로 포인터 한 줄**만 둔다. 매번 짖는 경고는 사람이 무시하게 되고, 그러면 진짜 `FAIL` 도 같이 묻힌다.
- **고아 MCP 등록은 다루지 않는다.** 삭제된 플러그인이 남긴 서버는 사용 이력이 있어야 판정 가능해 내장 `/doctor` 의 영역이다. 반면 **중복 등록**은 두 파일 키의 교집합이라 순수 계산이다 — 결정론으로 못 잡는 걸 잡는 척하지 않는다.
- `idempotent-seed.sh diagnose` 는 이 스크립트를 감싸 legacy 출력 형태(`cwd`/`dir_name`/`git`/`seeded`/`code_signal`)만 골라낸다. 탐지 로직을 다시 구현하지 않는다.
- **`new` 의 Step 0 hard guard 는 여기에 흡수하지 않는다.** 가드는 의존성 0 (순수 `find`) 이고 `PLUGIN_ROOT` 리졸버보다 **먼저** 돌아야 한다. 스크립트 호출로 바꾸면 "PLUGIN_ROOT 해석 실패 시 가드가 조용히 실행되지 않는" 실패 모드가 새로 생긴다. 안전 장치는 lazy-load 뒤로 옮기지 않는다.

`find` 는 "없음" 을 exit 1 로 표현한다. `set -o pipefail` 아래서 `find ... | wc -l` 는 정상적인 빈 결과에 스크립트를 죽인다. 모든 `find` 는 `find_or_empty` / `count_files` 헬퍼를 거치고, `code_signal` 은 `head` 로 인한 SIGPIPE 오탐을 피하려고 `-print -quit` 를 쓴다.

## 원칙

- **Preflight hard guard is non-negotiable**: `commands/new.md` 와 `skills/new/SKILL.md` 양쪽 Step 0 에 동일한 가드가 박혀 있다. description 만으로 잘못된 트리거를 막을 수 없다는 전제 — 모델이 description 을 잘못 해석해도 runtime 이 막는다. 가드 제거는 사용자의 명시적 (high-friction, 의도적) 결정이어야 한다.
- **wiring 은 남의 영역을 진단하지 않는다**: 위키 페이지 건강도는 `/llm-wiki:lint-wiki`, mem0 스토어/설정 자세는 `/mem0-ops:doctor` 가 소유한다. wiring 은 파일시스템 신호만 본다 — "위키가 있는가 / 레이아웃이 맞는가 / 미드레인 캡처가 쌓였는가" 까지. 겹치면 두 진단이 서로 다른 답을 내는 날이 온다.
- **결함마다 담당 스킬을 지목한다**: 다음 행동이 없는 판정은 노이즈다. 기계적·되돌릴 수 있는 수정 (`.gitignore` 라인, `.tmp/` 생성, `core.hooksPath`, serena `project_name`) 만 wiring 이 직접 고치고, 판단이 필요한 것 (`.staging` 큐레이션, wiki bootstrap/migrate, CLAUDE.md 저작, spec 이전, Serena 온보딩, mem0 변경) 은 전부 위임한다.
- **Minimal seeding, explicit follow-ups**: Day-1 에 필요한 것만 시드. tech-stack 기반 rules 생성과 wiki 도메인 인터뷰는 **호출 X, 안내만**. 빈 프로젝트에 generic 콘텐츠 만들면 사용자 덮어쓰기 비용 발생.
- **Owner gate is mandatory**: 사용자가 personal + 다중 org 컨텍스트라 owner 자동 결정 금지. `AskUserQuestion` 으로 명시 선택.
- **Codex GitHub reviewer surface**: AGENTS.md `## Review guidelines` 섹션이 Codex GitHub cloud reviewer 가 자동으로 읽는 영역. **레포 생성 시점에 시드**해야 첫 PR 부터 효과.
- **Idempotent re-runs**: 같은 디렉토리에서 두 번째 호출 시 기존 파일 보존 + 단계 skip + 안내 메시지. 절대 덮어쓰지 않음. (단, hard guard 가 .git/.claude 존재만으로도 abort 시키므로 일반 경로에서는 idempotent 재실행이 발생하지 않는다 — 가드를 우회한 partial seed 회복 경로에서만 의미.)

## 파일 구성

```text
plugins/project-init/
├── .claude-plugin/plugin.json
├── commands/new.md                     # 명시적 슬래시 surface (preflight guard + 포인터)
├── skills/
│   ├── new/SKILL.md                    # bootstrap 스킬 surface (동일 preflight guard + 포인터)
│   └── wiring/SKILL.md                # 기존 repo 진단 (read-only 탐지 + 게이트 수정)
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
│   ├── idempotent-seed.sh              # 충돌 가드 + .claude/ + .llmwiki/ 시드 (diagnose = 래퍼)
│   └── project_state.sh                # 탐지 SSOT — read-only 14 축 JSON
└── CLAUDE.md                           # this file
```

## Preflight guard contract

`commands/new.md` 와 `skills/new/SKILL.md` Step 0 에 동일한 POSIX shell 블록:

```bash
FIRST_EXISTING=$(find . -mindepth 1 -maxdepth 5 \
  \( -name '.git' -o -path './.git/*' \
   -o -name '.DS_Store' -o -name 'Thumbs.db' \
   -o -name 'desktop.ini' \) -prune \
  -o -print 2>/dev/null | head -1)

if [ -d .git ] || [ -n "$FIRST_EXISTING" ]; then
  echo "[abort] project-init refuses to run in a non-empty directory."
  ...
  exit 1
fi
```

- **Rejection rule**: anything in cwd that is not `.git/`, `.DS_Store`, `Thumbs.db`, or `desktop.ini` causes abort. `Dockerfile`, `Makefile`, `.env`, `docs/`, `src/app/main.py` — all of those trigger.
- **Search depth**: 5 levels (`find -maxdepth 5`). Deep-nested source files do not slip past the guard.
- **Abort message**: surfaces cwd + the first offending entry + a redirect to `/rules-forge:write-rules` or `/llm-wiki:bootstrap-wiki` for the "scaffold an existing project" case.
- **Non-POSIX hosts**: PowerShell-default environments must invoke via `bash -c '<guard>'` (Git Bash / WSL / Cygwin). The intent of the check, not the literal shell, is what matters — equivalent PowerShell rewrites are acceptable as long as they refuse the same conditions.

수정할 때는 두 파일 양쪽을 동시에 업데이트해야 한다. 한쪽만 바꾸면 surface 간 동작이 갈린다.

## Cross-runtime plugin root resolution

`references/new-procedure.md` Phase 0 opens with a `PLUGIN_ROOT` resolver:

```bash
PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$PLUGIN_ROOT" ]; then
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  if sort -V </dev/null >/dev/null 2>&1; then
    candidate=$(ls -1d "$cache_root"/*/project-init/* 2>/dev/null | sort -V | tail -1)
  else
    candidate=$(ls -1d "$cache_root"/*/project-init/* 2>/dev/null | sort | tail -1)
  fi
  [ -n "$candidate" ] && [ -d "$candidate" ] && PLUGIN_ROOT="$candidate"
fi
[ -n "$PLUGIN_ROOT" ] && [ -d "$PLUGIN_ROOT/scripts" ] || { echo "[abort] ..."; exit 1; }
```

- Under **Claude Code**, `${CLAUDE_PLUGIN_ROOT}` is set automatically and the resolver short-circuits on the first branch.
- Under **Codex 0.135**, no equivalent env var is currently exposed, so the resolver falls back to `~/.codex/plugins/cache/<marketplace>/project-init/<version>/`. Users can override with `CODEX_PLUGIN_CACHE` or set `PLUGIN_ROOT` directly.
- All subsequent bash blocks reference `${PLUGIN_ROOT}/scripts/...` and `${PLUGIN_ROOT}/assets/...`. Adding a new asset / script means updating only the procedure file — no per-surface duplication.

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
