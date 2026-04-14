# Feature Specification: codex-bridge — OMC plugin skill → Codex sync

**작성일**: 2026-04-14
**대상 플러그인**: `plugins/codex-bridge/` (신규, 21 번째 OMC 플러그인)
**상태**: Draft — 인터뷰 완료, 구현 대기

---

## Overview

이 repo 의 `plugins/*/skills/**` 에 있는 OMC 플러그인 skill 들을 **Codex CLI 가 네이티브로 로드하는 `~/.codex/skills/`** 에 idempotent 하게 복사·변환하는 브리지 도구. Claude Code 에서 쓰는 skill 을 독립 Codex CLI 세션에서도 동일한 의도로 쓸 수 있게 한다.

**핵심 원칙**: OMC source 는 **단일 소스 (SSOT)** 로 불변, Codex 쪽은 **생성물 (derived artifact)** 로 매 재실행마다 재생성. 양방향 sync 아님.

---

## Background

### 발견된 환경 (2026-04-14 리서치)

- **Codex CLI** (`codex-cli 0.120.0`) 이 `~/.codex/skills/*/SKILL.md` 를 네이티브로 로드 (implicit description auto-trigger + explicit `$skill-name`)
- **OMX (`oh-my-codex`, npm 패키지)** 가 `~/.codex/` 를 관리 중. `omx setup --scope user` 가 OMX 자체 25 개 skill 을 `~/.codex/skills/` 에 이미 설치함.
- **현재 갭**: `~/.codex/skills/` 에 있는 25 개는 전부 OMX core skill. OMC 플러그인 skill (`changelog-guide`, `cv-notebook`, `create-slide`, `interview-methodology`, `readme-guide`, ... 26 개) 은 Codex 쪽에 전혀 없음.
- **OMC 와 OMX 는 이름·네임스페이스 완전 분리** — Codex 는 "OMC" 개념을 모름. 따라서 충돌 가능성은 `plan`, `review` 같은 generic 이름에서만 발생.

### SKILL.md 포맷 호환성

OMC 와 Codex 둘 다 동일한 YAML frontmatter + markdown body 컨벤션 사용:
```markdown
---
name: <name>
description: <one-liner>
---
# Title
본문...
```

따라서 **구조 변환은 불필요**. 경로·키워드 치환 수준의 mechanical transform 이면 충분.

### 이중 경로 경고

`~/.agents/skills/` (legacy pre-`~/.codex` 경로) 와 `~/.codex/skills/` (canonical) 가 공존하면 Codex 가 둘 다 읽어서 중복 항목 발생 (출처: `~/.codex/skills/omx-setup/SKILL.md:47`). 본 도구는 canonical `~/.codex/skills/` 만 타깃.

---

## User Story

> Claude Code 에서 OMC 의 `$create-slide`, `$changelog-guide`, `$interview-methodology` 등을 쓰던 사용자가, 터미널에서 `codex` 직접 실행한 독립 Codex CLI 세션에서도 **같은 의도의 skill 들을** `$omc-create-slide`, `$omc-changelog-guide`, `$omc-interview-methodology` 로 호출할 수 있다. OMC 쪽에서 skill 을 수정하거나 새로 추가하면 `$codex-sync` 한 번 돌려서 Codex 쪽을 즉시 align 한다.

---

## Out of Scope (명시적 제외)

| 제외 항목 | 이유 |
|---|---|
| **Task / subagent delegation 재작성** | Claude Code `Task(subagent_type=...)` → Codex native subagent 매핑은 의미론적 변환이라 V1 의 mechanical substitution 범위 초과. V2. |
| **AGENTS.md 섹션 inject** | `~/.codex/AGENTS.md` 는 OMX 가 `<!-- omx:generated:agents-md -->` 마커로 관리 중. 침범 금지. |
| **양방향 sync** | OMC 는 SSOT. Codex 쪽 수정사항은 매 sync 에서 덮어쓰기 (스펙 명시). |
| **프로젝트 `.codex/skills/` 타깃** | V1 은 user-level `~/.codex/skills/` 만. 프로젝트 레벨은 V2. |
| **MCP server config 동기화** (`config.toml`) | 서버 등록은 OMX `omx setup` 이 담당. 본 도구 책임 외. |
| **파일 변경시 자동 sync (hook)** | 명시적 `$codex-sync` 호출 또는 CLI 실행. Hook 은 V2. |
| **npm 바이너리 배포** | V2. V1 은 repo 내 실행만. |
| **충돌시만 프리픽스 적용** | V1 은 항상 `omc-` 프리픽스. V2 에서 smart-prefix 옵션. |

---

## Requirements

### Must Have (P0)

- [ ] **플러그인 스켈레톤**: `plugins/codex-bridge/`
  - `plugin.json` (버전 1.0.0, marketplace metadata)
  - `.claude-plugin/plugin.json` 등록
  - `marketplace.json` 최상위 엔트리 추가
  - `CLAUDE.md` — 플러그인 소개 + 사용법
- [ ] **Node sync 스크립트**: `plugins/codex-bridge/scripts/sync.mjs`
  - Node 18+ 표준 모듈만 (`fs`, `path`, `url`, `process`) — deps zero
  - OS 무관 (path.join, `os.homedir()`)
- [ ] **OMC skill wrapper**: `plugins/codex-bridge/skills/codex-sync/SKILL.md`
  - Claude Code 에서 `$codex-sync` 로 호출
  - Internal 로 Node 스크립트 delegate
- [ ] **Source 자동 탐색**: `plugins/*/skills/**/SKILL.md` 전부 스캔
  - 중첩 허용 (`plugins/<name>/skills/<skill>/SKILL.md` 또는 `plugins/<name>/skills/<subdir>/<skill>/SKILL.md`)
- [ ] **Skill 디렉토리 통째 복사**: SKILL.md 옆의 scripts/, references/, assets/, 기타 파일 전부 이동
- [ ] **Frontmatter 변환**:
  - `name: X` → `name: omc-X`
  - `description:` 등 나머지 필드 보존
- [ ] **Mechanical content 치환** (Transform rules 테이블 참고)
- [ ] **타깃 경로**: `${CODEX_HOME:-~/.codex}/skills/omc-<original-name>/SKILL.md`
- [ ] **Overwrite-always**: 기존 `omc-*` 파일은 무조건 덮어쓰기
- [ ] **Orphan auto-prune**: source 에 없는 `omc-*` 디렉토리는 기본 삭제 (별도 플래그 불필요)
- [ ] **Blacklist 설정**: `plugins/codex-bridge/codex-bridge.config.json`
- [ ] **Dry-run 모드**: `--dry-run` — 파일 변경 0, 계획만 출력
- [ ] **Verbose 모드**: `--verbose` — 파일별 행위 출력
- [ ] **UTF-8 강제 stdout**: Windows cp949/cp932 인코딩 사고 방지 (core-config 선례 참고)
- [ ] **Exit code**: 0 (성공), 1 (부분 실패), 2 (치명적)

### Should Have (P1)

- [ ] **`--plugin` 플래그**: `--plugin github-dev,core-config` — 런타임 subset 선택
- [ ] **`--config <path>`**: 사용자 지정 config 파일
- [ ] **`--no-prune`**: auto-prune 비활성화 (드물게 필요할 때)
- [ ] **JSON report**: `--report <path>` — 머신-판독 가능 실행 결과 (added/updated/removed/skipped)
- [ ] **Collision detection**: 동일 원본 이름이 복수 플러그인에서 나오면 warning + last-wins
- [ ] **Test 스크립트**: `plugins/codex-bridge/tests/` — mock filesystem 으로 sync 동작 검증

### Nice to Have (V2)

- [ ] **Task → Codex native subagent 매핑 테이블** + 자동 rewrite
- [ ] **AGENTS.md inject**: OMX 마커 외부에 `<!-- omc-bridge:start -->` 섹션 삽입
- [ ] **파일 변경 hook**: `plugins/*/skills/**` Write/Edit 시 자동 sync
- [ ] **npm 바이너리**: `npx @youngjaedev/omc-codex-sync`
- [ ] **Project-level 지원**: `--scope project` → `.codex/skills/`
- [ ] **충돌시만 프리픽스** 모드: `--prefix-mode collision-only`
- [ ] **양방향 diff 리포트**: OMC ↔ Codex 양쪽 drift 탐지

---

## Technical Design

### Architecture

```
plugins/codex-bridge/
├── .claude-plugin/plugin.json
├── CLAUDE.md
├── codex-bridge.config.json       # 기본 blacklist + transform rules
├── scripts/
│   └── sync.mjs                   # 실제 로직
├── skills/
│   └── codex-sync/
│       └── SKILL.md               # Claude Code 진입점 ($codex-sync)
└── tests/
    ├── fixtures/
    │   ├── source-skill.md
    │   └── expected-output.md
    └── sync.test.mjs
```

### 진입점 (3 중)

1. **Claude Code skill**: `$codex-sync [args]` — wrapper 가 Node 호출
2. **Direct CLI**: `node plugins/codex-bridge/scripts/sync.mjs [options]`
3. **V2 npm**: `npx @youngjaedev/omc-codex-sync [options]`

V1 은 1+2, V2 에서 3 추가.

### Transform Rules (V1 — mechanical substitution)

| 치환 전 | 치환 후 | 근거 |
|---|---|---|
| `.omc/` | `.omx/` | OMC state dir → OMX state dir |
| `CLAUDE.md` | `AGENTS.md` | Claude Code → Codex 상위 컨벤션 |
| `/oh-my-claudecode:<X>` | `$<X>` | slash command → explicit skill invocation |
| `oh-my-claudecode` (brand text) | `oh-my-codex` | 브랜딩 |
| `~/.claude/` | `~/.codex/` | user config 디렉토리 |
| `claude-code-guide` (agent name) | `codex-guide` (V2 예정) | V1 에선 as-is, warning only |
| `Task(subagent_type=...)` | (변환 안 함, V2) | V1 scope 제한 |

Regex 가 아니라 **literal substring replacement** — 예측 가능성·감사 가능성 우선. 각 치환은 `{from, to}` 객체 배열로 config 에 수록, 사용자가 추가/수정 가능.

### Directory/File handling

- SKILL.md 의 skill 디렉토리 안 모든 파일을 타깃으로 복사
- Symlink: resolve 후 실제 파일 복사
- 바이너리 파일 (이미지 등): 치환 없이 그대로 복사 (확장자 화이트리스트: `.md`, `.yml`, `.yaml`, `.json`, `.sh`, `.mjs`, `.js`, `.py`, `.ts` 만 치환 대상)

### Config 파일 스키마

`plugins/codex-bridge/codex-bridge.config.json`:
```json
{
  "$schema": "./codex-bridge.schema.json",
  "target": {
    "scope": "user",
    "codexHome": null
  },
  "prefix": "omc-",
  "exclude": [
    "plugins/interactive-review/**",
    "plugins/midjourney/**"
  ],
  "transform": {
    "rules": [
      { "from": ".omc/", "to": ".omx/" },
      { "from": "CLAUDE.md", "to": "AGENTS.md" },
      { "from": "/oh-my-claudecode:", "to": "$" },
      { "from": "oh-my-claudecode", "to": "oh-my-codex" },
      { "from": "~/.claude/", "to": "~/.codex/" }
    ],
    "textExtensions": [".md", ".yml", ".yaml", ".json", ".sh", ".mjs", ".js", ".py", ".ts"]
  }
}
```

### CLI 인터페이스

```
Usage: node sync.mjs [options]

Options:
  --dry-run              파일 변경 없이 계획만 출력
  --verbose              파일별 행위 상세 출력
  --config <path>        커스텀 config 경로 (기본: codex-bridge.config.json)
  --plugin <list>        쉼표 구분 플러그인 필터 (예: --plugin github-dev,core-config)
  --no-prune             auto-prune 비활성화 (orphan 유지)
  --report <path>        JSON 리포트 파일 출력
  --help                 도움말 출력

Exit codes:
  0  모든 skill 성공 처리
  1  일부 skill 처리 실패 (전체는 continue)
  2  치명적 오류 (config 파싱 실패, 권한 없음 등)
```

### Verification (DoD)

V1 완료 기준:
1. `node plugins/codex-bridge/scripts/sync.mjs --dry-run` 시 예상 변경 계획이 정확히 출력됨
2. `node plugins/codex-bridge/scripts/sync.mjs` 실행 후 `~/.codex/skills/omc-*` 에 이 repo 의 모든 OMC skill (blacklist 제외) 이 존재
3. 각 skill 의 frontmatter `name` 이 `omc-<original>` 로 변경
4. Transform rules 적용 확인 (예: `.omc/` 가 `.omx/` 로 바뀜)
5. OMC 에서 임의 skill 삭제 후 재실행 → `~/.codex/skills/omc-<deleted>` 사라짐
6. `omx doctor` 실행 → OMX 본래 skill 과 충돌 보고 없음
7. `codex` 세션 열어서 `$omc-changelog-guide` 호출 가능 확인
8. Windows/Linux/macOS 전부에서 실행 (CI 또는 수동 검증)

---

## Edge Cases

| 시나리오 | V1 기대 동작 |
|---|---|
| `~/.codex/` 디렉토리 없음 | 자동 생성 (mkdir recursive) |
| `~/.codex/skills/` 없음 | 자동 생성 |
| SKILL.md frontmatter 없음 | skip + stderr warning (source 결함) |
| frontmatter `name` 필드 누락 | 디렉토리명으로 fallback + warning |
| 원본에 non-ASCII (em-dash, 한글) | UTF-8 로 읽기·쓰기 명시, Windows cp949 사고 없음 |
| 동일 원본 skill 이름이 복수 플러그인 | 마지막 발견이 win + warning |
| config 파일 없음 | 내장 기본값 사용 (exclude 비어있음) |
| config JSON 파싱 실패 | exit code 2 + stderr |
| `$codex-sync` 로 skill 호출시 Node 미설치 | stderr 로 guidance 출력 ("Install Node 18+") |
| Symlinked source file | realpath 로 resolve 후 실제 파일 복사 |
| blacklist glob pattern 에 매칭 | skip + verbose 로그 |
| target 쓰기 권한 없음 | exit code 2 + stderr 에 path 포함 |
| 중간에 Ctrl+C | 부분 쓰기 방지 위해 임시 디렉토리 렌더링 후 atomic rename 사용 |
| SKILL.md 가 아닌 스킬 진입점 (예: commands/*.md) | V1 scope 외 — skills/ 디렉토리만 |
| OMC skill 본문에 AskUserQuestion / Task tool 참조 | V1 은 변환 없이 복사 (Codex 에서 tool 호출 실패시 사용자가 인지). V2 에서 blacklist 기본값으로 추가 |

---

## Cross-platform 고려

### Windows
- `path.join()` + `path.sep` 사용 (하드코딩된 `/` 금지)
- `CODEX_HOME` env 있으면 우선, 없으면 `os.homedir() + '/.codex'`
- stdout UTF-8 모드: Node 는 기본 UTF-8 이라 Python 같은 cp949 사고 없음. 단, 하위 프로세스 호출시에는 `{ encoding: 'utf-8' }` 명시.

### macOS / Linux
- `os.homedir()` 정상 동작
- `~/.codex` 내장 쉘 확장 미사용 (문자열로 resolve)

### 모든 플랫폼
- Line ending: source 보존 (LF/CRLF mix 대응), `\r\n` 을 `\n` 으로 정규화 안 함
- File mode: executable bit 보존 (`fs.copyFile` + `fs.chmod`)

---

## Dependencies

### 런타임
- **Node 18+** — OMX 가 이미 요구. 추가 요구사항 아님.
- **OMX 설치** — optional 이지만 강력 권장. `~/.codex/` 구조를 OMX 가 세팅.
- **Codex CLI 0.120.0+** — `~/.codex/skills/` 네이티브 지원 버전

### 개발
- Node test runner (`node --test`) — V1 테스트에 사용, 외부 deps 0

---

## Open Questions

1. **Blacklist 초기값** — V1 에서 기본 제외할 skill 이 무엇인지 결정 필요.
   - 후보: `interactive-review` (Claude Code 전용 MCP 서버 기반), `midjourney` (외부 MCP 서버 의존)
   - 결정 시점: 구현 도중 각 skill 본문을 보면서 판단
2. **`mcp__plugin_*` tool 이름 처리** — OMC 쪽 plugin MCP 서버 이름은 `mcp__plugin_<name>_<action>` 형태. Codex 쪽에서도 동일 네임으로 등록돼 있다면 그대로 작동하지만, 등록 안 돼 있으면 skill 실행 실패. V1 scope 외 — 사용자 `config.toml` 에 수동 등록 가정.
3. **V2 시점 판단** — V1 배포 후 사용 경험에서 AGENTS.md inject 필요성 체감할지, Task 재작성이 중요할지 관찰 후 V2 우선순위 결정.
4. **Codex `AGENTS.override.md` 관례** — `~/.codex/AGENTS.override.md` 가 있으면 Codex 가 AGENTS.md 대신 그걸 읽음. 이게 skill 자체에는 영향 없지만, 향후 AGENTS.md inject 기능 추가시 override 체인 고려 필요.

---

## Implementation Plan (구현시 참고)

### Phase 1 — 스켈레톤 + 기본 sync
1. `plugins/codex-bridge/plugin.json` 생성 + marketplace 등록
2. 빈 `sync.mjs` 에 argument parsing + dry-run 모드 구현
3. Source discovery (`plugins/*/skills/**/SKILL.md` glob)
4. Frontmatter YAML 파서 (표준 라이브러리만 — 수동 파싱 혹은 최소 구현)
5. Overwrite-always + directory copy

### Phase 2 — Transform + prune + config
6. Config 파일 로드 + 검증
7. Transform rules 적용 (literal substring)
8. Orphan prune 로직
9. Blacklist glob 매칭

### Phase 3 — Skill wrapper + 테스트
10. `skills/codex-sync/SKILL.md` — Node CLI delegate
11. Test fixtures + `node --test` 케이스
12. 다중 OS 수동 검증

### Phase 4 — V1 릴리즈
13. README + CLAUDE.md 완성
14. 본 spec 의 Open Questions 1 번 (blacklist 초기값) 확정
15. marketplace version bump + commit

예상 공수: Phase 1-3 ≈ 4~6 시간, Phase 4 ≈ 1 시간.

---

## 참조

- OpenAI Codex Skills: https://developers.openai.com/codex/skills
- OpenAI Codex AGENTS.md: https://developers.openai.com/codex/guides/agents-md
- OMX `omx-setup` skill: `~/.codex/skills/omx-setup/SKILL.md`
- OMX generated AGENTS.md 마커: `<!-- omx:generated:agents-md -->` (`~/.codex/AGENTS.md:7`)
- Codex 이중 경로 경고 출처: `~/.codex/skills/omx-setup/SKILL.md:47`
- 이전 CORCA 리서치 (참고): `CORCA_RESEARCH_SUMMARY.md` (untracked)

---

## 변경 이력

| 일자 | 작성자 | 변경 |
|---|---|---|
| 2026-04-14 | 사용자 인터뷰 (4 라운드) + Claude | 최초 작성 |
