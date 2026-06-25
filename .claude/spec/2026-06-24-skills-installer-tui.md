# Feature Specification: Skills Installer TUI (hermes / codex)

## Overview

이 repo(`my-claude-plugins`)의 SKILL.md들을 골라 **Hermes Agent**와 **Codex**에 설치하는 in-repo 터미널(TUI) 도구. `npx skills`(vercel-labs/skills) CLI를 **래핑**한다. 자체 exporter는 만들지 않는다.

> 상태: 구현·머지 완료. 산출물 `scripts/install-skills.mjs` (P0 설치). remove/update/미리보기/검증은 후속(P1·P2).

## Decisions made (인터뷰 + 조사 확정)

| 결정 | 값 |
|---|---|
| 구현 방식 | **WRAP** — `npx skills` 래핑. TUI = picker + `npx skills add` spawn (자체 exporter X) |
| 대상 런타임 | **Hermes Agent**(`-a hermes-agent`) + **Codex**(`-a codex`). hermes = Nous Research Hermes Agent CLI 확정(~90%) |
| 용도 | **내 로컬 dev 도구** — repo 체크아웃 상태에서 로컬 `plugins/` 트리로부터 설치. in-repo `.mjs` 스크립트 |
| 선택 단위 | **플러그인 그룹 트리(양쪽)** — 플러그인 줄 체크 = 그 안 skill 전부, 펼쳐 개별 skill 토글 |
| 스택 | Node ESM(>=18) + `@clack/prompts`(group multiselect) + `yaml` |

## Scope facts (조사 근거)

- **우리 표면**: 25 플러그인 / 47 SKILL.md / 설치 대상 **24개**(`core-config`=skill 0개 제외). frontmatter 계약 = `name`(필)·`description`(필, ≤1024)·`version`·`allowed-tools`(옵). 분포: github-dev 8, llm-wiki 5, ml-toolkit·docs-forge 4, e2e-harness·code-scout 3, paper-search·deepwiki 2, 나머지 16개 각 1.
- **commands/agents = Claude 전용**(hermes/codex 미이식): code-scout(A), council·deepwiki·docs-forge·paper-search-tools·project-init(C). skill만 설치된다.
- **npx skills**(vercel-labs/skills, npm `skills`): `add`/`remove`/`update`(alias `upgrade`)/`experimental_sync`/`use`. `.claude-plugin/marketplace.json`/`plugin.json`을 읽음. 기본 symlink + copy fallback. 75+ 타겟.
- **충돌**: 무조건 덮어쓰기(백업·사용자수정 보호 없음). **삭제**: `remove` 멀티에이전트 청소 + ref-count canonical. **버전**: lockfile 2개(전역 tree-SHA + 프로젝트 content-hash SHA-256, 후자는 VCS 커밋 권장) 해시 드리프트 감지, 기록된 ref에서 always-latest(커밋 SHA 핀 없음).
- **hermes profile**: profile = 격리된 `HERMES_HOME`. skill이 **profile별로 분리** — default=`~/.hermes/skills`, named=`~/.hermes/profiles/<name>/skills`. **npx skills는 profile 미인식** → `HERMES_HOME` env를 직접 export해야만 특정 profile로 설치됨. codex엔 profile 개념 없음(단일 `~/.codex/skills`).

## Requirements

### Must Have (P0)
- [ ] 로컬 `plugins/*/skills/*/SKILL.md` 스캔 + `.claude-plugin/marketplace.json` 읽어 **플러그인 그룹 트리** 구성(skill 0개 플러그인은 비활성/회색).
- [ ] `@clack/prompts` group multiselect: 플러그인 단위 / 개별 skill 단위 양쪽 선택.
- [ ] 타겟 다중 선택(`hermes-agent`, `codex`) + scope 선택(global `~/` vs project `./`).
- [ ] **hermes profile 선택기**: `~/.hermes/profiles/*` 스캔 + default; 선택 profile로 `HERMES_HOME` export 후 `npx skills` spawn.
- [ ] 선택 결과를 `npx skills add <local-skill-path> -a <agents> [-g] -y`로 실행(충돌·삭제·버전 처리는 CLI 상속).

### Should Have (P1)
- [ ] 실행 전 미리보기: 설치될 (skill x 타겟 x scope/profile) 매트릭스와 대상 경로를 보여주고 확정.
- [ ] 설치 후 요약(어디에 무엇이 깔렸는지) + lockfile 위치 안내.
- [ ] pre-flight 검증: `description` ≤1024 + frontmatter 유효성(기존 `scripts/sync-codex-manifests.mjs` 규칙 재사용)으로 깨진 skill 사전 차단.

### Nice to Have (P2)
- [ ] `remove`/`update`를 TUI에서 노출(`npx skills remove/update` 래핑) — v1은 설치 위주.
- [ ] 프리셋 빠른 선택(예: Codex-eligible 22).
- [ ] 배포 가능 구조로 분리(나중에 자체 npx 패키지화). v1은 로컬 우선.

## Technical Constraints
- Node >=18 ESM, repo의 `.mjs` 툴체인과 일관(@clack/prompts, yaml).
- npx skills는 profile 미인식 → **HERMES_HOME env 브리지는 우리 래퍼 책임**.
- commands/agents/hooks/MCP는 hermes/codex 미이식 — **skill만** 설치(트리에서 비-skill 컴포넌트는 제외/회색).
- 설치 메커니즘(symlink vs copy)·충돌·remove·update·lockfile은 모두 `npx skills`에 위임(재구현 금지).

## Edge Cases
| 시나리오 | 기대 동작 |
|---|---|
| skill 0개 플러그인 선택 시도(core-config) | 트리에서 비활성, 선택 불가 |
| 같은 이름 skill이 이미 설치됨 | npx skills 기본 덮어쓰기에 위임(우리 추가 보호 없음 — Out of Scope) |
| hermes 미설치(`~/.hermes` 없음) | profile 선택기 비활성 + 안내; codex만 진행 가능 |
| named profile 선택 | `HERMES_HOME=~/.hermes/profiles/<p>` export 후 `-g` 설치 |
| 로컬 경로 add가 marketplace 메타 미인식 | skill 디렉토리를 직접 지정해 add (Open Question 참조) |

## Out of Scope (v1)
- 자체 exporter(frontmatter 파싱+검증+복사 직접 구현) — WRAP로 대체.
- 커밋 SHA 핀/재현성 — npx skills의 가변 ref 동작 그대로 수용.
- update 시 사용자 수정본 보호 — npx skills 덮어쓰기 그대로 수용.
- 비-skill·Claude 전용 컴포넌트(commands/agents/hooks) 설치, core-config/midjourney/codex-image류.
- codex profile(개념 없음).

## Open Questions
- **설치 소스 메커니즘**: `npx skills add ./plugins/<name>/skills/<skill>`(로컬 경로) 방식이 우리 marketplace 메타를 인식하는지 실측 필요. 미인식이면 skill 디렉토리 직접 지정으로 우회.
- **검증 패리티(P1) 실제 포함 여부**: 우리 skill은 이미 Codex `--check` 통과 → pre-flight 검증의 한계효용이 낮을 수 있음.
- **remove/update(P2) 노출**: 설치-only v1으로 끊을지, 처음부터 3-mode로 갈지.

## Sources
- vercel-labs/skills: `src/agents.ts`(hermes-agent 타겟/HERMES_HOME), `installer.ts`(충돌·symlink), `remove.ts`, `update.ts`, `skill-lock.ts`, `local-lock.ts`, `cli.ts`
- NousResearch/hermes-agent: `hermes_cli/profiles.py`(per-profile skills), `main.py`(`-p` → HERMES_HOME)
- 로컬: `scripts/sync-codex-manifests.mjs`, `.claude-plugin/marketplace.json`
