# Feature Specification: codex-bridge — OMC plugin skill → Codex sync

**작성일**: 2026-04-14
**대상 플러그인**: `plugins/codex-bridge/` (신규, 21 번째 OMC 플러그인)
**상태**: Draft — 인터뷰 완료, 구현 대기

---

## Overview

이 repo 의 `plugins/*/skills/**` 에 있는 OMC 플러그인 skill 들을 **Codex CLI 가 네이티브로 로드하는 `~/.agents/skills/`** (OpenAI 공식 USER scope) 에 idempotent 하게 복사·변환하는 브리지 도구. Claude Code 에서 쓰는 skill 을 독립 Codex CLI 세션에서도 동일한 의도로 쓸 수 있게 한다.

**핵심 원칙**: OMC source 는 **단일 소스 (SSOT)** 로 불변, Codex 쪽은 **생성물 (derived artifact)** 로 매 재실행마다 재생성. 양방향 sync 아님.

---

## Background

### 발견된 환경 (2026-04-14 리서치)

- **Codex CLI** (`codex-cli 0.120.0`) 이 SKILL.md 를 네이티브로 로드 (implicit description auto-trigger + explicit `$skill-name`).
- **공식 USER scope 경로**: `$HOME/.agents/skills/` (per [OpenAI Codex Skills doc](https://developers.openai.com/codex/skills) 및 [Customization concept doc](https://developers.openai.com/codex/concepts/customization), 표 본문 직접 인용).
- **비공식 경로 — `~/.codex/skills/`**: OMX 의 `omx-setup` SKILL.md 가 "current Codex CLI natively loads" 한다고 주장하며 25 개 skill 설치. 공식 docs 에는 언급 없음. Codex CLI 가 두 경로 모두 스캔하는 것으로 보임 (실측: 두 디렉토리 모두 활성 skill 보유, 별도 inode).
- **OMX (`oh-my-codex`, npm 패키지, author Yeachan Heo)** 가 `~/.codex/` 와 `~/.agents/` 둘 다 관리 (omx 소스의 setup.js, doctor.js, uninstall.js 가 양쪽 경로 reference).
- **현재 갭**: 두 디렉토리 통틀어 OMC 플러그인 skill (`changelog-guide`, `cv-notebook`, `create-slide`, `interview-methodology`, `readme-guide`, ... 26 개) 이 0 건. Codex 쪽에서 전혀 호출 불가.
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

### 경로 정설 (verified 2026-04-15)

OMX `omx-setup` SKILL.md:47 와 OpenAI 공식 docs 가 충돌:

| 출처 | 주장 | 권위 |
|---|---|---|
| OMX `omx-setup` SKILL.md:47 | `~/.codex/skills/` 가 canonical, `~/.agents/skills/` 는 legacy | 비공식, 사용자 본인이 아님 |
| OpenAI Codex Skills doc + Customization doc | `$HOME/.agents/skills/` 가 USER scope (legacy 언급 없음) | 공식 (developers.openai.com) |

**결론**: 본 도구는 **OpenAI 공식 path (`~/.agents/skills/`) 채택**. 이유:
1. 공식 docs 가 권위
2. Codex CLI 의 내부 스캔 로직 변경에도 안정 (OMX 의 비공식 경로는 deprecated 위험)
3. OMX 가 `~/.codex/skills/` 에 깔아둔 skill 들과 디렉토리 분리 → orphan-prune 시 OMX 영역 침범 0
4. `omx doctor` 가 `~/.agents/` 도 인지하므로 OMX 진단에서도 보임

Codex CLI 가 양쪽 다 스캔하므로 사용자는 `$create-slide` 호출시 `~/.agents/skills/create-slide/` (OMC) 와 `~/.codex/skills/create-slide/` (만약 OMX 가 같은 이름 추가) 둘 다 노출 — Codex docs 에 따르면 "둘 다 selector 에 표시" (병합 안 함).

**`CODEX_HOME` env 의 역할**: state/config/log 디렉토리 base. **skill 디렉토리 결정에는 영향 없음** (config-reference.md 에 `skills_directory` / `skill_paths` 같은 override 키 없음, verified).

---

## User Story

> Claude Code 에서 OMC 의 `$create-slide`, `$changelog-guide`, `$interview-methodology` 등을 쓰던 사용자가, 터미널에서 `codex` 직접 실행한 독립 Codex CLI 세션에서도 **같은 이름·같은 의도의 skill 을** `$create-slide`, `$changelog-guide`, `$interview-methodology` 로 그대로 호출할 수 있다. 프리픽스 없이 OMX core skill 과 동일 네임스페이스 공유. OMC 쪽에서 skill 을 수정하거나 새로 추가하면 `$codex-sync` 한 번 돌려서 Codex 쪽을 즉시 align 한다.

---

## Out of Scope (명시적 제외)

| 제외 항목 | 이유 |
|---|---|
| **Task / subagent delegation 재작성** | Claude Code `Task(subagent_type=...)` → Codex native subagent 매핑은 의미론적 변환이라 V1 의 mechanical substitution 범위 초과. V2. |
| **AGENTS.md 섹션 inject** | `~/.codex/AGENTS.md` 는 OMX 가 `<!-- omx:generated:agents-md -->` 마커로 관리 중. 침범 금지. |
| **양방향 sync** | OMC 는 SSOT. Codex 쪽 수정사항은 매 sync 에서 덮어쓰기 (스펙 명시). |
| **프로젝트 `.agents/skills/` 타깃** | V1 은 user-level `~/.agents/skills/` 만. 프로젝트 레벨 (`$REPO_ROOT/.agents/skills`) 은 V2. |
| **MCP server config 동기화** (`config.toml`) | 서버 등록은 OMX `omx setup` 이 담당. 본 도구 책임 외. |
| **파일 변경시 자동 sync (hook)** | 명시적 `$codex-sync` 호출 또는 CLI 실행. Hook 은 V2. |
| **npm 바이너리 배포** | V2. V1 은 repo 내 실행만. |
| **프리픽스 기반 격리** | 현 시점 OMX 25 개 vs OMC 26 개 skill 이름 충돌 0 건 확인 (2026-04-14). V1 은 프리픽스 없이 동일 네임스페이스 공유. 미래 OMX 업데이트가 동일 이름 skill 추가할 경우에 대비한 collision-fallback 프리픽스 부여 로직은 V2. |

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
- [ ] **Frontmatter 처리**:
  - `name` 필드 원본 유지 (프리픽스 없음)
  - `description:` 등 기존 필드 보존
  - **`bridge_source: <plugin>/<skill>` 필드 주입** — provenance 마커. orphan prune 식별자로 사용. 사용자 눈에 띄지 않는 메타, transform 대상 아님
- [ ] **Mechanical content 치환** (Transform rules 테이블 참고). **body (frontmatter 아래) 만 치환 대상**, frontmatter 는 불변 (bridge_source 마커 보존 위함)
- [ ] **타깃 경로**: `$HOME/.agents/skills/<original-name>/SKILL.md` (OpenAI 공식 USER scope, verified). `CODEX_HOME` 은 state 디렉토리이지 skill 디렉토리 아님 — 영향 없음
- [ ] **Overwrite-always**: `bridge_source` 마커 있는 기존 파일은 무조건 덮어쓰기. 마커 없는 파일은 OMC 외부 소유로 간주, **안 건드림** (safety guard)
- [ ] **Orphan auto-prune**: `~/.agents/skills/*/SKILL.md` 중 `bridge_source` 가 있으나 그 경로에 원본이 없는 skill 자동 삭제. `bridge_source` 없는 skill 은 스캔 대상 외 (OMX 가 `~/.codex/skills/` 에 깐 것은 디렉토리 자체가 다르므로 절대 영향 없음)
- [ ] **OMX 충돌 탐지**: 동일 이름의 `bridge_source` 없는 skill (= OMX 소유) 이 이미 있으면 stderr warning + 해당 skill skip. `omx doctor` 안내 출력
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
- [ ] **`[[skills.config]]` 인지**: 사용자가 `~/.codex/config.toml` 에서 `[[skills.config]] enabled = false` 로 OMC skill 을 disable 한 경우, sync 가 그 항목을 prune 하지 않고 그대로 둠 (사용자 의도 존중). config.toml 파싱은 read-only.

### Nice to Have (V2)

- [ ] **Task → Codex native subagent 매핑 테이블** + 자동 rewrite
- [ ] **AGENTS.md inject**: OMX 마커 외부에 `<!-- omc-bridge:start -->` 섹션 삽입
- [ ] **파일 변경 hook**: `plugins/*/skills/**` Write/Edit 시 자동 sync
- [ ] **npm 바이너리**: `npx @youngjaedev/omc-codex-sync`
- [ ] **Project-level 지원**: `--scope project` → `$REPO_ROOT/.agents/skills/` (Codex docs 의 REPO scope)
- [ ] **Collision-fallback 프리픽스**: OMX 가 나중에 동일 이름 skill 추가하면 자동으로 `omc-<name>` 으로 전환. V1 은 skip-with-warning, V2 는 자동 rename
- [ ] **양방향 diff 리포트**: OMC ↔ Codex 양쪽 drift 탐지
- [ ] **`agents/openai.yaml` sidecar 생성**: skill 별 `policy.allow_implicit_invocation`, `dependencies.tools[]` (e.g. `mcp__plugin_*`), `interface.display_name` (한국어 라벨 등) 자동 생성. `bridge_source` frontmatter 마커도 이쪽으로 이전 가능 (`agents/codex-bridge.yaml`)
- [ ] **agentskills.io 표준 호환 audit**: synced SKILL.md 가 [agentskills.io specification](https://agentskills.io/specification) 과 호환되는지 검증 → 호환되면 다른 호환 에이전트에서도 작동
- [ ] **Codex Plugin 패키징**: `omc-bridge@youngjaedev` 형태로 plugin manifest 생성 → 사용자가 `/plugins` UI 에서 install/uninstall (현재는 직접 sync 실행)

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

| 치환 전 | 치환 후 | 매칭 모드 | 근거 |
|---|---|---|---|
| `.omc/` | `.omx/` | literal | OMC state dir → OMX state dir |
| `CLAUDE.md` | `AGENTS.md` | literal | Claude Code → Codex 상위 컨벤션 |
| `/oh-my-claudecode:<X>` | `$<X>` | literal | slash command → explicit skill invocation |
| `oh-my-claudecode` (brand text) | `oh-my-codex` | literal | 브랜딩 |
| `~/.claude/` | `~/.codex/` | literal | user config 디렉토리 |
| `\bomc\b` | `omx` | word-boundary | 하드코딩된 단일 토큰 "omc" → "omx". 오탐 방지 위해 word-boundary 매칭 |
| `\bOMC\b` | `OMX` | word-boundary | 대문자 변형 |
| `claude-code-guide` (agent name) | `codex-guide` (V2 예정) | literal | V1 에선 as-is, warning only |
| `Task(subagent_type=...)` | (변환 안 함, V2) | — | V1 scope 제한 |

**매칭 모드**:
- `literal`: `String.prototype.replaceAll()` 의 고정 문자열 치환. 예측 가능성 최고.
- `word-boundary`: `/\bX\b/g` 정규식. 영숫자/언더스코어 이외 문자로 둘러싸인 X 만 매칭. `omc.json` 은 치환 O, `economic` 은 치환 X (경계 없음).

**frontmatter 면제**: 각 파일의 `---` 구분자 사이 YAML frontmatter 는 치환 대상 아님. 이유: `bridge_source` 메타 필드 보존, 그리고 사용자가 의도적으로 넣은 skill 이름/description 이 오염되지 않도록.

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
    "agentsHome": null,
    "_comment": "scope=user → $HOME/.agents/skills (OpenAI 공식). agentsHome=<path> 로 override (테스트용). CODEX_HOME 은 영향 없음 — config-reference.md 에 skill path override 키 없음."
  },
  "collisionFallbackPrefix": "omc-",
  "exclude": [
    "plugins/interactive-review/**",
    "plugins/midjourney/**"
  ],
  "transform": {
    "bodyOnly": true,
    "rules": [
      { "from": ".omc/", "to": ".omx/", "mode": "literal" },
      { "from": "CLAUDE.md", "to": "AGENTS.md", "mode": "literal" },
      { "from": "/oh-my-claudecode:", "to": "$", "mode": "literal" },
      { "from": "oh-my-claudecode", "to": "oh-my-codex", "mode": "literal" },
      { "from": "~/.claude/", "to": "~/.codex/", "mode": "literal" },
      { "from": "omc", "to": "omx", "mode": "word-boundary" },
      { "from": "OMC", "to": "OMX", "mode": "word-boundary" }
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
2. `node plugins/codex-bridge/scripts/sync.mjs` 실행 후 `~/.agents/skills/<name>/` 에 이 repo 의 모든 OMC skill (blacklist·OMX 충돌 제외) 이 존재
3. 각 synced skill 의 frontmatter 에 `bridge_source: <plugin>/<skill>` 필드 존재
4. Transform rules 적용 확인 (body 영역: `.omc/` → `.omx/`, word-boundary `omc` → `omx` 등. frontmatter 는 불변)
5. OMC 에서 임의 skill 삭제 후 재실행 → `~/.agents/skills/<deleted>` 에서 `bridge_source` 가 그 경로면 사라짐. 마커 없는 skill 은 손 안 댐
6. `omx doctor` 실행 → 충돌 보고 없음 (현 시점 충돌 0 건 기준)
7. `codex` 세션 열어서 `$changelog-guide`, `$create-slide` 등 OMC 출신 skill 직접 호출 가능
8. Windows/Linux/macOS 전부에서 실행 (CI 또는 수동 검증)
9. 동일-이름 스킬 시뮬레이션 (임의의 `~/.agents/skills/create-slide/SKILL.md` 을 `bridge_source` 없이 미리 두고 sync 실행) → 해당 skill skip + warning, 다른 skill 은 정상 처리
10. `~/.codex/skills/` 의 OMX skill 25 개 sync 전후 동일 (절대 침범 없음)

---

## Edge Cases

| 시나리오 | V1 기대 동작 |
|---|---|
| `~/.agents/` 디렉토리 없음 | 자동 생성 (mkdir recursive) |
| `~/.agents/skills/` 없음 | 자동 생성 |
| `~/.agents/.skill-lock.json` 존재 | 건드리지 않음 (Codex/OMX 관리 영역) |
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
| OMX 또는 사용자가 동일 이름 skill 을 `~/.agents/skills/` 에 이미 설치 (`bridge_source` 없음) | sync skip + stderr warning. V2 에서 collision-fallback 프리픽스로 재시도 옵션 |
| OMX 가 `~/.codex/skills/` 에 동일 이름 skill 보유 | 영향 없음 — 디렉토리 분리. Codex 가 둘 다 selector 에 표시 (병합 안 함, 공식 docs) |
| `~/.codex/config.toml` 에 사용자가 `[[skills.config]] enabled = false` 로 OMC skill disable | sync prune 대상 제외. 사용자 의도 존중 |
| AGENTS.md `project_doc_max_bytes` 32 KiB 캡 (현재 27 KiB) | V1 은 AGENTS.md 미관여라 영향 없음. V2 inject 추가 시 사용자 `config.toml` 에 `project_doc_max_bytes = 65536` 권장 안내 |
| word-boundary `omc` 가 의도치 않게 매칭 (예: 변수명 `my_omc_config`) | `my_omx_config` 로 변환 — 변수명은 word 로 인정됨. 사용자가 특정 변수를 보호하려면 blacklist 로 해당 skill 제외 |
| frontmatter 안의 `omc` 문자열 (예: `description` 에 "omc" 언급) | **변환 안 됨** (bodyOnly: true). 원본 SKILL.md 를 사용자가 의도적으로 "omx" 로 작성하거나 V2 frontmatter-transform 옵션 사용 |

---

## Cross-platform 고려

### Windows
- `path.join()` + `path.sep` 사용 (하드코딩된 `/` 금지)
- 타깃 경로: `os.homedir() + '/.agents/skills'` (OpenAI 공식, hardcoded). config 의 `target.agentsHome` 으로만 override (테스트용). `CODEX_HOME` env 는 무시 — skill 디렉토리 결정에 영향 없음 (verified 2026-04-15)
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
- **Codex CLI 0.120.0+** — `~/.agents/skills/` USER scope 네이티브 스캔 지원 (per [Skills doc](https://developers.openai.com/codex/skills))

### 개발
- Node test runner (`node --test`) — V1 테스트에 사용, 외부 deps 0

---

## Open Questions

1. **Blacklist 초기값** — V1 에서 기본 제외할 skill 이 무엇인지 결정 필요.
   - 후보: `interactive-review` (Claude Code 전용 MCP 서버 기반), `midjourney` (외부 MCP 서버 의존)
   - 결정 시점: 구현 도중 각 skill 본문을 보면서 판단
2. **`mcp__plugin_*` tool 이름 처리** — OMC 쪽 plugin MCP 서버 이름은 `mcp__plugin_<name>_<action>` 형태. Codex 쪽에서도 동일 네임으로 등록돼 있다면 그대로 작동하지만, 등록 안 돼 있으면 skill 실행 실패. V1 scope 외 — 사용자 `config.toml` 에 수동 등록 가정. V2 의 `agents/openai.yaml` `dependencies.tools[]` 로 자동 안내 가능.
3. **V2 시점 판단** — V1 배포 후 사용 경험에서 AGENTS.md inject 필요성 체감할지, Task 재작성이 중요할지 관찰 후 V2 우선순위 결정.
4. **Codex `AGENTS.override.md` 관례** — `~/.codex/AGENTS.override.md` 가 있으면 Codex 가 AGENTS.md 대신 그걸 읽음. 이게 skill 자체에는 영향 없지만, 향후 AGENTS.md inject 기능 추가시 override 체인 고려 필요.
5. **`bridge_source` frontmatter vs `agents/openai.yaml` sidecar** — 현 V1 은 frontmatter 마커. 공식 docs 권장은 sidecar. Sidecar 로 옮기면 frontmatter 가 100% 원본 그대로 보존되는 장점, 하지만 파일 추가 1 개. V2 에서 sidecar 도입시 frontmatter 마커는 backward-compatible 로 유지하다 폐기.
6. ~~경로 결정 (`~/.codex/skills/` vs `~/.agents/skills/`)~~ → **resolved 2026-04-15**: OpenAI 공식 docs 우선, `~/.agents/skills/` 채택 (verification log 참조).

---

## Implementation Plan (구현시 참고)

### Phase 1 — 스켈레톤 + 기본 sync
1. `plugins/codex-bridge/plugin.json` 생성 + marketplace 등록
2. 빈 `sync.mjs` 에 argument parsing + dry-run 모드 구현
3. Source discovery (`plugins/*/skills/**/SKILL.md` glob)
4. Frontmatter YAML 파서 (표준 라이브러리만 — 수동 파싱 혹은 최소 구현)
5. **동일-이름 충돌 탐지**: `~/.agents/skills/<name>/SKILL.md` 존재 & `bridge_source` 없음 → skip + warning (OMC 영역 외부 소유로 간주)
6. Overwrite-always + directory copy (충돌 통과한 것만)
7. **bridge_source 마커 주입**: frontmatter 에 `bridge_source: <plugin>/<skill>` 필드 추가

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
