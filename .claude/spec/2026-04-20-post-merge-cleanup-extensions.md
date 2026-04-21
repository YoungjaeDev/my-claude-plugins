# Feature Specification: `/github-dev:cleanup` + post-merge Content-First Note

## Overview

저장소 전반의 임시파일/캐시/stale 문서를 카테고리별로 감지·정리하는 **범용 슬래시 명령 `/github-dev:cleanup`**을 신설한다. `.omc/`는 주요 카테고리 중 하나일 뿐, 실제 스코프는 빌드 산출물·로그·오래된 spec·`docs/`·`research/` 등을 포괄. post-merge.md는 최소 수정 — Step 6/7 서두에 "Content-First, File-Last" 원칙 1-2줄만 추가해 기존 "Content Removal" 규칙을 강화한다.

## 배경과 설계 전환 근거

- **초안(2026-04-20 v1)**: post-merge.md에 Step 10/11을 끼워 넣고 merge-worktree까지 동기화하는 full spec → YAGNI 과설계.
- **A안(2026-04-20 v2)**: `/github-dev:cleanup-omc` OMC 전용 명령 → `.omc/`에 너무 특화돼 실제 사용 맥락(캐시/빌드/stale 문서 공통 정리) 놓침.
- **v3 (현안)**: 범용 `/github-dev:cleanup` 명령 + 카테고리 기반 선택 정리. OMC 종속성 제거, 플러그인 repo뿐 아니라 일반 프로젝트에서도 재사용 가능.
- OMC(4.13.1)에 동일 역할 커맨드 부재 확인(`cancel`은 모드 state만, `ai-slop-cleaner`는 소스 코드 대상). 업스트림 중복 아님.

## Guiding Principle: Content-First, File-Last

문서/메모리/rules 정리는 항상 **내용 다듬기 → 통합 → (결과적으로) 파일 삭제** 순서.

- 1순위: 파일 안의 내용을 검토. 중복 bullet 병합, stale 서술 교체, `## Post-Merge` 헤더 내용을 topical 섹션으로 분산 이동 — 파일 자체는 유지.
- 2순위: 여러 파일에 흩어진 같은 주제를 한 곳으로 통합.
- 3순위: 내용이 전부 이전됐거나 orphan인 파일만 삭제.

`.omc/` 같은 ephemeral 디렉토리와 빌드 산출물은 이 원칙에서 예외 — 내용 검토 가치 없으므로 바로 archive/삭제 가능.

## User Stories

- AS 플러그인 repo 유지자, I WANT `/github-dev:cleanup` 단일 명령으로 `.omc/` 누적, `dist/` 빌드 산출물, `*.log`, 90일+ 지난 spec을 한 번에 감지·정리할 수 있기를 원한다, SO THAT `rm -rf`를 여기저기 수동 입력하지 않는다.
- AS post-merge 실행자, I WANT Step 6/7 서두에서 "내용 다듬기가 우선"임을 상기받기를 원한다, SO THAT config/memory 정리 시 파일부터 지우는 실수를 피한다.
- AS 사용자, I WANT 프로젝트마다 추가로 정리하고 싶은 경로(예: `tmp/exports/`, `.cache/`)를 명령어 인자로 넘길 수 있기를 원한다, SO THAT 프로젝트별 맞춤 정리를 동일 인터페이스로 처리한다.

## Requirements

### Must Have (P0)

- [ ] **신규 명령 `/github-dev:cleanup` 생성**
  - 파일: `plugins/github-dev/commands/cleanup.md`
  - frontmatter:
    ```yaml
    ---
    description: Archive or delete stale files across OMC state, build artifacts, logs, old docs, and user-specified paths
    argument-hint: "[--dry-run] [--paths path1,path2]"
    ---
    ```
  - 워크플로우:
    1. **카테고리 탐지** (각 존재 여부 확인):
       - **A. OMC 임시파일** (`.omc/` 존재 시):
         - `plans/*`, `research/*` → archive 후보.
         - `handoffs/*`, `state/checkpoints/*`, `sessions/*.json` (비활성 UUID), `state/sessions/<비활성>/` → 삭제 후보.
         - `state/project-tracking-*.json` 중 모든 이슈 `closed` → archive 후보.
         - 보호: open 이슈 있는 tracking, `project-memory.json`, `prd.json`, 런타임 파일(`mission-state.json`, `hud-stdin-cache.json`, `subagent-tracking.json`, `workflow-progress.json`, `agent-replay-*.jsonl`).
       - **B. 빌드 산출물 & 로그**:
         - `dist/`, `build/` 디렉토리가 존재하고 gitignore 대상이면 → 삭제 후보.
         - `*.log`, `**/*.log` (gitignore 대상) → 삭제 후보.
         - 보호: gitignore 대상 아닌 파일(사용자가 의도적으로 커밋한 산출물).
       - **C. 날짜 기반 stale 문서**:
         - `.claude/spec/<YYYY-MM-DD>-*.md` 중 오늘 기준 90일+ → archive 후보.
         - `.omc/plans/`, `.omc/research/`는 카테고리 A에서 이미 처리.
         - 다른 위치의 `<YYYY-MM-DD>-*.md` 파일 중 90일+ → 후보 목록에 포함 (사용자 확인 필수).
       - **D. 프로젝트 문서 디렉토리**:
         - `docs/`, `research/` 디렉토리 최상위의 stale 항목 — 이 카테고리는 **사용자 확인 필수**. 자동 후보 제안하되 기본 "건너뜀" 선택.
         - 판정 기준: 파일명에 날짜 prefix + mtime 90일+ + 타 파일에서 참조 없음.
       - **E. 사용자 지정 경로**:
         - `--paths path1,path2,...` 인자로 넘어온 glob을 후보로 추가.
         - 인자 없으면 AskUserQuestion으로 선택 입력 받는 단계 제공 (skip 가능).
    2. **활성 세션 탐지** (카테고리 A에만 적용):
       - `CLAUDE_SESSION_ID` 환경변수 확인 → 해당 UUID 보호.
       - fallback: `state/sessions/` 하위 중 mtime 24시간 이내 디렉토리 보호.
       - 탐지 불확실 시 `sessions/*.json` + `state/sessions/<*>/` 전체 건너뜀, 사용자 경고.
    3. **프롬프트** (`AskUserQuestion` 필수):
       - 카테고리 A-E 각각에 대해 multi-select: "archive 이동 / 삭제 / 건너뜀".
       - 기본 권장값: A(plans·research·닫힌 tracking → archive, 나머지 → 삭제), B(삭제), C(archive), D(건너뜀), E(사용자 결정).
       - description에 항목 수와 총 용량 명시.
    4. **실행**:
       - archive: `.omc/_archive/<YYYY-MM-DD>/<카테고리>/<원본경로구조>/`로 `mv`. 같은 날 여러 실행 허용(append).
       - 삭제: `rm -rf` (승인 대상만).
       - `--dry-run` 시 실제 작업 없이 분류 결과만 출력.
    5. **보고**:
       - archive된 경로, 삭제된 항목 수, 건너뛴 항목 목록 출력.
       - 총 확보된 용량 추산.

- [ ] **post-merge.md Step 6/7 서두에 Content-First 주석 추가**
  - Step 6 시작 (`Read the PR diff...` 직전)에 1-2줄:
    > **Content-First principle**: 기존 섹션의 stale/중복 내용을 **in-place로 다듬는 것**이 우선. 파일 단위 삭제는 해당 파일이 비거나 orphan일 때만.
  - Step 7 시작 (`Integrate PR learnings into Serena memory...` 직전)에 동일 1-2줄.
  - 기존 Step 6/7 절차는 변경하지 않음.

- [ ] **`plugins/github-dev/CLAUDE.md` Commands 테이블에 신규 명령 1행 추가**
  - `| `/github-dev:cleanup` | Archive or delete stale files (OMC state, build artifacts, logs, old docs, user paths) |`

- [ ] **github-dev 플러그인 MINOR 버전 번프**
  - `plugins/github-dev/.claude-plugin/plugin.json`: `version` MINOR 번프.
  - `.claude-plugin/marketplace.json`의 `github-dev` entry `version` 동기화.
  - `.claude-plugin/marketplace.json`의 `metadata.version` MINOR 번프.

### Should Have (P1)

- [ ] **`--dry-run` 플래그 지원**
  - 감지·분류만 수행, 실제 이동/삭제 없음.

- [ ] **카테고리별 skip 플래그**
  - 예: `--skip-omc`, `--skip-build`, `--skip-docs` — CI 시나리오에서 선택적 사용.

### Nice to Have (P2)

- [ ] **archive 보관 가이드**
  - `plugins/github-dev/CLAUDE.md`에 "`.omc/_archive/`는 수동 정리 책임. 90일+ 경과 archive는 별도 삭제 권장" 1줄 추가.
- [ ] **각 카테고리별 용량 요약**
  - 탐지 단계에서 `du -sh` 또는 유사 계산으로 각 후보 디렉토리 용량을 AskUserQuestion description에 포함.

## 스코프에서 제외

- ~~post-merge.md Step 10/11 통합~~ → 독립 명령으로 분리.
- ~~merge-worktree.md Phase 6 동기화~~ → drift 비용 > 사용 빈도.
- ~~Step 6/7 Pre-audit 4단계 절차화~~ → 기존 Content Removal 규칙으로 충분.
- **Python/Node 캐시 자동 정리** (`__pycache__/`, `node_modules/`, `.venv/` 등) → 사용자 결정으로 제외. 재설치 비용이 크고 프로젝트 빌드 흐름 침해 가능. 사용자가 정말 필요하면 `--paths` 인자로 명시.
- **코드베이스 내 `@deprecated` 주석 grep** → 주관적 판정, 스코프 밖. 리뷰 단계에서 처리.
- **`rules/*.md`, memory 파일 자동 dedup** → 현재 post-merge Content Removal 규칙 + Content-First 주석으로 수동 처리 (충분).

## Technical Constraints

- **Zero runtime dependency**: Bash + `rg` + 내장 tool만.
- **Destructive UX**: 모든 삭제/이동은 `AskUserQuestion` 승인 필수.
- **gitignore 존중**: 카테고리 B는 gitignore 대상만 후보. 사용자가 의도적으로 커밋한 산출물은 제외.
- **archive 위치**: 항상 `.omc/_archive/<YYYY-MM-DD>/` (카테고리 무관 단일 루트). gitignore 대상.
- **`$ORIGINAL_REPO` prefix 불필요**: 독립 명령이므로 단순.

## Edge Cases

| Scenario | Expected Behavior |
|---|---|
| `.omc/` 미존재 | 카테고리 A 건너뜀. |
| `dist/` 또는 `build/`가 gitignore 대상 아님 | 카테고리 B에서 제외. |
| `.claude/spec/` 없음 | 카테고리 C 건너뜀. |
| `docs/` 또는 `research/` 없음 | 카테고리 D 건너뜀. |
| 활성 세션 탐지 실패 | `sessions/*.json` + `state/sessions/<*>/` 전체 보호. |
| `.omc/_archive/<YYYY-MM-DD>/` 이미 존재 | 같은 날짜에 append. 덮어쓰지 않음. |
| `AskUserQuestion` 거부 | 해당 카테고리만 건너뜀, 다른 카테고리 계속. |
| `--paths` 인자의 glob이 매칭 없음 | 로그만 남기고 계속. |
| `--dry-run` 모드 | 이동/삭제 실제 실행 안 함, 분류 결과만 출력. |
| archive 이동 중 permission denied | 실패 보고 후 해당 카테고리 중단. |
| `docs/` 내 stale 후보가 타 파일에서 참조됨 | 후보 목록에서 제외하고 사용자에게 알림. |

## Out of Scope

- `.serena/`, `.sisyphus/`, `.omx/` 자동 정리 — 별도 플러그인 담당. `--paths`로 사용자 지정 가능.
- Python/Node 캐시 자동 정리.
- 자동 스케줄/cron 실행.
- GitHub Actions 훅 연동.
- 여러 repo 교차 정리.
- `_archive/` 자동 만료/삭제.
- Serena memory / CLAUDE.md 자동 dedup.
- 코드 내 `@deprecated` 주석 감지.

## Open Questions

- `CLAUDE_SESSION_ID` 환경변수가 Claude Code에서 실제 노출되는지 검증 필요. 미노출이면 mtime 24시간 fallback으로 안전하게 동작.
- 90일 기준이 적절한지 — 프로젝트별로 다를 수 있음. 초기 고정, 피드백 후 `--stale-days N` 플래그 검토.
- 플러그인 귀속 재검토: 이 명령이 `github-dev`에 있는 게 맞는지, 아니면 OMC 업스트림에 기여할지. 현재는 로컬 제어권 우선으로 `github-dev`에 두되 open question으로 기록.

## Implementation Plan

1. `plugins/github-dev/commands/cleanup.md` 신규 작성 (위 워크플로우).
2. `plugins/github-dev/commands/post-merge.md` Step 6/7 서두에 Content-First 주석 삽입 (2곳, 각 1-2줄).
3. `plugins/github-dev/CLAUDE.md` Commands 테이블에 `/github-dev:cleanup` 1행 추가.
4. `plugins/github-dev/.claude-plugin/plugin.json` version MINOR 번프.
5. `.claude-plugin/marketplace.json`의 `github-dev` + `metadata.version` 동기 번프.
6. 수동 드라이런: 현재 저장소 상태가 기대 카테고리로 정확히 분류되는지 확인 (A: 5+8+2+50+4+0개, B: `dist/` 등 없음, C: 현재 spec 1개(이 문서)는 90일 미만이라 제외, D: `docs/` 내 최근 문서만 있음, E: 인자 없음).
7. Conventional Commit: `feat(github-dev): 1.x.0 — /cleanup command + content-first note in post-merge`.

## Validation Checklist

- [ ] `/github-dev:cleanup` 실행 시 `.omc/plans/` 5개, `.omc/research/` 8개가 `_archive/2026-04-21/A/plans/`, `_archive/2026-04-21/A/research/`로 이동 제안되는가.
- [ ] `state/project-tracking-codex-bridge-v1-0.json`은 이슈 상태 판정 후 보호 또는 archive 제안되는가.
- [ ] 활성 세션 UUID 탐지가 현재 세션을 오삭제하지 않는가.
- [ ] gitignore 대상이 아닌 `dist/` 파일은 카테고리 B에서 제외되는가.
- [ ] `.claude/spec/` 내 90일+ 문서가 카테고리 C로 감지되는가 (현재는 해당 없음, 음성 테스트).
- [ ] `docs/` 하위의 최근 작성 문서가 카테고리 D에서 기본 "건너뜀"으로 제안되는가.
- [ ] `--paths tmp/exports` 인자가 카테고리 E로 추가되는가.
- [ ] `--dry-run` 모드에서 실제 파일 변경이 0건인가.
- [ ] `AskUserQuestion` 없이 이동/삭제가 발생하지 않는가.
- [ ] post-merge.md Step 6/7 서두 Content-First 주석이 기존 절차를 깨지 않는가.
- [ ] plugin.json + marketplace.json + metadata.version이 모두 동기 번프되었는가.
