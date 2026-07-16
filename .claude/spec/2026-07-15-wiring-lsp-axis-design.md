---
title: "project-init:wiring 15번째 축 — 언어 서버(LSP) 검사 설계 노트"
status: design
date: 2026-07-15
owner: unassigned
kind: design-first
scope: plugins/project-init (wiring)
supersedes: none
---

# wiring LSP 축 — 설계 노트 (구현 아님)

## 한눈에 보기 (jargon-free)

사용자는 `/project-init:wiring` 진단에 15번째 검사 항목을 더하고 싶어 한다: "이 프로젝트에서 언어 서버(코드 자동완성·정의 이동을 담당하는 백그라운드 프로그램)가 실제로 살아 움직이는가". 문제는 기존 14개 검사가 전부 **파일만 들여다보는** 정적 검사라는 점이다. 파일을 열어 값이 맞는지 비교할 뿐, 프로그램을 실행하거나 응답을 기다리지 않는다. 1초 안에 끝나고, 언제 돌려도 같은 결과가 나오며, 아무 프로세스도 새로 띄우지 않는다. "언어 서버가 살아 있나"를 진짜로 확인하려면 서버를 **띄우고**, 표준입출력으로 요청을 보내고, **응답을 기다려야** 한다 — 이 세 가지가 전부 기존 검사의 암묵적 불변식(invariant)을 깬다.

그래서 이 문서는 코드를 쓰지 않는다. 대신 **긴장(무엇이 왜 충돌하는가)을 특징짓고, 두 가지 구현 모양(A/B)과 "안 넣음" 선택지를 나란히 제시하고, 소유자가 골라야 할 결정 6개를 열거**한다. 구현 PR 은 결정이 내려진 뒤 별개로 진행한다.

## 관계 다이어그램 + 섹션 안내

```
기존 14축 (정적)                        새 요청 (동적)
┌─────────────────────────────┐        ┌──────────────────────────┐
│ project_state.sh            │        │ "언어 서버 liveness"      │
│  · 순수 read-only           │        │  · 서버 spawn 필요        │
│  · 파일 존재/값 비교만       │  ⟵깨짐│  · stdio JSON-RPC 왕복    │
│  · <1s, 결정론, spawn 0     │        │  · 응답 대기(수백 ms~수초)│
│  · command -v gws = 상한선  │        │  · 첫 실행 캐시 쓰기 가능 │
└─────────────────────────────┘        └──────────────────────────┘
        │                                        │
        │  Shape A: 탐지 전용 (계약 안)          │  Shape B: 진짜 프로브 (계약 밖)
        ▼                                        ▼
  config/바이너리 신호만 → INFO/OK/SKIP    별도 스크립트 + opt-in + 영구 INFO
  (liveness 주장 안 함, 런타임 무추가)      + spawn/timeout/cleanup 계약
```

| 섹션 | 답하는 질문 |
|---|---|
| Part 1 — 긴장 | 왜 이 축은 코드보다 설계 결정이 먼저인가 |
| Part 2 — 근거 | 기존 계약이 실제로 어디에 성문화돼 있나 (파일:라인) |
| Part 3 — 세 후보 | A(탐지 전용) · B(진짜 프로브) · C(안 넣음) 의 모양과 트레이드오프 |
| Part 4 — 결정 | 소유자가 착수 전 골라야 할 6개 (Open decision 16-21) |
| Part 5 — 권고 | 기본값 제안 + 구현을 미루는 이유 |
| Part 6 — 리스크 | 설계를 건너뛰고 바로 구현할 때 깨지는 것 |
| 용어 | LSP·stdio·JSON-RPC·liveness·flapping |

## Part 1 — 긴장 특징화 (왜 design-first 인가)

`wiring` 의 14개 축은 하나의 **암묵적 불변식**을 공유한다. 문서에 "축은 프로세스를 띄우면 안 된다"고 명시된 규칙은 없지만, 14개가 전부 그렇게 동작한다:

- **read-only.** `wiring/SKILL.md:14` — "Detection is read-only. `scripts/project_state.sh` never writes. Run it first, always." `project_state.sh` 헤더도 "순수 read-only — 어떤 파일도 만들거나 고치지 않는다".
- **정적.** 발효(efficacy) 축 4개(`core.hooksPath`, `@import` 스코프 무력화, MCP 중복 등록, Codex `AGENTS.md` 바이트 예산)조차 전부 **선언적 config 비교**다 — 프로세스를 띄워 동작을 관찰하지 않고, 설정 파일의 값으로 발효 여부를 **추론**한다.
- **spawn 0 / sub-second / 결정론.** `project_state.sh` 에는 `timeout`·`&`(백그라운드)·`nohup`·`setsid` 가 하나도 없다(grep = 0). 한 번의 `find`·`jq`·`sed` 패스로 끝난다.

LSP liveness 는 이 셋을 **동시에** 깬다. 서버 프로세스를 새로 띄우고(spawn≠0), stdio 로 `initialize` JSON-RPC 를 주고받고, 응답을 **기다린다**(sub-second·결정론 붕괴 — 서버 콜드스타트는 수백 ms~수초, 부하·캐시 상태에 따라 결과가 흔들린다). 게다가 많은 서버가 첫 실행 시 인덱스 캐시를 디스크에 쓴다(read-only 위반).

가장 가까운 기존 축인 **serena**(`project_state.sh:127-136`)조차 `.serena/project.yml` 존재와 메모리 파일 **개수**만 세지, serena MCP 를 **호출하지 않는다**. 현 계약이 "실행"에 허용하는 유일한 상한선은 `command -v gws`(`project_state.sh:180`, `GWS_CLI=$(b command -v gws)`) — **"바이너리가 PATH 에 있나"** 라는 존재 확인이 전부다. 이것이 곧 Shape A 의 천장이다.

따라서 "축을 하나 더"가 아니라 **계약을 바꿀 것인가**의 문제다 — design-first 인 이유.

> **NO-TOUCH 참고**: 원 마일스톤(#115)의 NO-TOUCH 세트에 `wiring` 이 명시돼 있었다. 그 마일스톤은 이 축을 의도적으로 건드리지 않았고, 이 문서는 그 후속 설계일 뿐 아직 구현 승인이 아니다.

## Part 2 — 근거 (파일:라인, 조사 시점 2026-07-15)

| 주장 | 근거 |
|---|---|
| 탐지는 read-only, 항상 먼저 실행 | `plugins/project-init/skills/wiring/SKILL.md:14` |
| `project_state.sh` 는 어떤 파일도 만들지/고치지 않음 | `plugins/project-init/scripts/project_state.sh` 헤더 4-5행 |
| 발효 축도 전부 선언적 config 비교 | `wiring/SKILL.md:92-100` (efficacy 축 서술) |
| serena 축도 config·메모리 개수만, MCP 미호출 | `project_state.sh:127-136` |
| "바이너리 on PATH" 탐지의 유일 precedent = 현 계약 상한 | `project_state.sh:180` (`GWS_CLI=$(b command -v gws)`) |
| 신규 축 영역 (충돌 없음) | `git grep -niE 'language.server|\blsp\b' plugins/project-init` = 0 |
| 정적 계약 확인 (spawn/timeout 없음) | `project_state.sh` 에 `timeout`/`&`/`nohup`/`setsid` grep = 0 |

## Part 3 — 세 후보 (모양 + 트레이드오프)

### Shape A — 탐지 전용 축 (현 계약 내부)

**무엇**: `project_state.sh` 에 `lsp` 블록을 추가하되, **liveness 를 주장하지 않는다**. per-language 설정·등록 신호만 정적으로 읽는다:

- config 존재: `pyrightconfig.json`, `tsconfig.json`, `.clangd`, `rust-project.json`, `go.mod` 등.
- 서버 바이너리 on PATH: `command -v pyright`/`typescript-language-server`/`clangd`/`rust-analyzer`/`gopls` — `GWS_CLI` 패턴을 그대로 미러.
- 에디터 등록 힌트: `.vscode/settings.json` 의 언어 서버 관련 키(있으면).

**verdict**: `INFO`(신호 요약) / `OK`(config+바이너리 둘 다) / `SKIP`(해당 언어 없음). **"살아 있다"고 말하지 않는다** — "설정과 바이너리가 갖춰져 있다"까지만.

**런타임 추가**: 0. spawn 0, sub-second, 결정론 유지. 계약 무변경.

**한계**: 바이너리가 설치돼 있어도 **실제로 뜨는지**는 모른다(깨진 설정·버전 불일치·크래시 서버를 못 잡는다). 사용자의 원 요청("살아 움직이는가")을 **부분적으로만** 충족.

### Shape B — 진짜 liveness 프로브 (현 계약 밖)

**무엇**: 서버를 실제로 띄워 `initialize` 를 주고받고 응답을 확인한다.

- **위치**: `project_state.sh` **밖**의 별도 스크립트(예: `scripts/probe-lsp.sh`). `project_state.sh` 의 never-writes/never-spawns 불변식을 보존하기 위해 절대 인라인하지 않는다.
- **cadence**: 명시적 opt-in. `wiring` Step 1 기본 실행에 **포함하지 않는다**(기본 진단은 여전히 <1s·spawn 0). 사용자가 `--probe-lsp` 같은 플래그로 요청할 때만.
- **verdict**: **영구 INFO-only**. timeout·콜드스타트가 `FAIL` 로 둔갑하면 안 된다(느린 머신·CI 콜드캐시에서 거짓 실패 = flapping). "응답함/무응답(참고용)"까지만.
- **부작용 계약**: 크로스플랫폼 `timeout`(GNU/BSD 분기, `sed -i` 선례처럼), orphan 프로세스 kill(프로브가 남긴 서버 정리), 첫 실행 인덱스 캐시 쓰기를 **명시적으로 인정**(그 디렉터리는 read-only 위반이 아니라 "프로브가 쓴다"고 문서화).

**이점**: 원 요청을 진짜로 충족(깨진 서버를 잡는다).

**비용**: 새 실패 모드 3종(아래 Part 6), 크로스플랫폼 프로세스 관리, per-language 프로브 프로토콜 유지보수. `wiring` 의 "결정론적 <1s 진단" 정체성과 영구적으로 분리 운영해야 한다.

### Shape C — 안 넣음

**무엇**: 15번째 축을 추가하지 않는다. 언어 서버 상태 확인은 에디터/`/doctor` 영역으로 남긴다.

**근거**: `wiring` 의 CLAUDE.md 원칙 — "wiring 은 다른 소유자의 영역을 진단하지 않는다"(wiki-page health → `lint-wiki`, mem0 → `mem0-ops:doctor`). 언어 서버 liveness 는 에디터/LSP 클라이언트의 런타임 관심사이지 "하네스 배선" 신호가 아니라고 볼 수 있다. 오탐(설치됐지만 안 뜸)을 감수하느니 축을 안 만드는 게 나을 수 있다.

### 나란히 비교

```
                     Shape A (탐지)    Shape B (프로브)    Shape C (안 넣음)
현 계약 유지          O                X (별도 계약)       O
원 요청 충족          부분              완전               X
런타임 추가           0                spawn+timeout+대기   0
새 실패 모드          없음              3종 (Part 6)        없음
유지보수 부담         낮음              높음(per-lang)      0
정체성 훼손           없음              분리 운영 필요       없음
```

## Part 4 — 착수 전 결정 (Open decision 16-21)

소유자가 구현 PR 전에 확정해야 한다. 결정 없이 구현하면 Part 6 리스크가 실현된다.

| # | 결정 | 선택지 |
|---|---|---|
| 16 | **축 범위** | 세션 내장 LSP 도구를 볼 것인가 vs 외부 per-language 서버를 볼 것인가 |
| 17 | **verdict shape** | 새 verdict class 신설 vs 영구 `INFO-only`(timeout 이 false FAIL 안 되게) |
| 18 | **다언어 결과 shape** | 언어별 배열형(`[{lang, config, binary, live?}]`) vs 단일 요약 |
| 19 | **프로브 위치** | `project_state.sh` 내부(계약 깸) vs sibling 스크립트(계약 보존) |
| 20 | **cadence** | Step 1 기본 실행 vs opt-in 플래그 전용 |
| 21 | **부작용 억제** | orphan cleanup + 크로스플랫폼 timeout + 첫 실행 캐시 쓰기 계약을 어디까지 명문화 |

## Part 5 — 권고 (기본값 제안)

- **가장 안전한 진입점은 Shape A**다. 현 계약을 지키고(런타임 0, read-only, 결정론), `GWS_CLI` precedent 를 그대로 확장하며, 사용자의 요청을 "설정·바이너리 준비 상태" 선에서 즉시 충족한다. 오탐 위험이 낮고, 축 하나 추가로 끝난다.
- **Shape B 는 진짜 liveness 가 반복적으로 필요하다는 증거가 나온 뒤**에 별도로. 그때도 `project_state.sh` 밖 + opt-in + 영구 INFO-only + 부작용 계약을 전제로. Shape A 를 먼저 깔면 B 는 "A 로 부족한 케이스"만 다루면 되므로 스코프가 좁아진다.
- **Shape C(안 넣음)** 도 정당한 선택이다 — 특히 결정 16 에서 "이건 에디터/`/doctor` 영역"이라는 답이 나오면.

**권고 순서**: 결정 16-21 을 먼저 답한다 → A 로 착수(권장) 또는 C 로 종결 → B 는 명시적 후속. 이 문서는 구현 PR 을 만들지 않는다(design-first 계약).

## Part 6 — 설계 skip 시 구현 리스크

1. **`project_state.sh` 접붙이기 → sub-second/zero-spawn 붕괴.** 프로브를 SSOT 스크립트에 인라인하면 `wiring` 의 모든 실행이 갑자기 프로세스를 띄우고 느려진다. `idempotent-seed.sh diagnose` 도 이 스크립트를 감싸므로 부수 피해가 전파된다.
2. **timeout liveness → flapping verdict.** 콜드스타트·부하로 프로브가 timeout 하면 같은 프로젝트가 실행마다 `OK`/`FAIL` 을 오간다. "매 실행 짖는 경고는 무시하도록 훈련시킨다"(wiring CLAUDE.md 원칙) — 진짜 FAIL 이 묻힌다.
3. **spawn 서버가 캐시 작성 → read-only 위반.** 첫 실행에 인덱스 캐시를 쓰는 서버는 `project_state.sh:4-5` 의 "어떤 파일도 만들지 않는다" 계약을 깬다. 계약을 지키려면 프로브가 그 쓰기를 명시적으로 인정·격리해야 한다(결정 21).

## 용어

- **LSP (Language Server Protocol)**: 에디터와 언어 서버가 코드 자동완성·정의 이동·진단을 주고받는 표준 프로토콜.
- **stdio JSON-RPC**: LSP 가 표준입출력 위에서 JSON-RPC 메시지(예: `initialize`)로 통신하는 방식.
- **liveness**: "설치돼 있나"가 아니라 "실제로 떠서 응답하나"를 확인하는 검사.
- **flapping**: 입력이 안 변했는데 검사 결과가 실행마다 뒤집히는 현상(비결정론의 증상).
- **verdict**: `wiring` 이 각 축에 매기는 판정 — `FAIL`/`WARN`/`ASK`/`INFO`/`SKIP`/`OK`.
- **efficacy 축**: 설정이 "존재하는가"가 아니라 "실제로 발효하는가"를 보는 축(`core.hooksPath` 등 4개).

## 참고

- 상위 계획: `.claude/spec/2026-07-15-fleet-audit-followups.md` (W4-1 항목).
- 계약 근거: `plugins/project-init/skills/wiring/SKILL.md`, `plugins/project-init/scripts/project_state.sh`, `plugins/project-init/CLAUDE.md`(Detection SSOT 원칙).
