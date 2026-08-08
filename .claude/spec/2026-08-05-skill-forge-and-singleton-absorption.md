# skill-forge 신설 + 단일스킬 플러그인 흡수 — my-claude-plugins

> Status: proposed (2026-08-05). 인터뷰(`interview:interview-methodology`, breadth-first)로 확정한 결정을 고정한 durable 계획. 구현은 아직 없음. 근거 수치는 전부 2026-08-05 repo 실측이며, 확인 못 한 항목은 `unverified` 로 표시했다.

## 한눈에 보기

두 갈래 작업을 한 계획으로 묶는다.

1. **skill-forge 신설** — 스킬을 쓰고·진단하고·전수 검토하는 **자립 스킬**. 저작 시점에 네 소스(`skill-creator`, `superpowers:writing-skills`, Hermes `hermes-agent-skill-authoring`, mattpocock `writing-for-agents`)의 내용을 읽고 합성하되, **런타임에는 그 어느 것도 참조하지 않는다.** 그 위에 이 저장소의 3런타임 패키징 계약을 얹는다 — 네 소스 어느 것도 이 계약을 모른다.
2. **단일스킬 플러그인 흡수** — 파편화의 실체는 단일 스킬 플러그인 13개다. 이미 번들인 10개(`github-dev` 8스킬, `llm-wiki` 5, `ml-toolkit` 5, `docs-forge` 4 …)는 손대지 않는다. 흡수 비용은 교차참조 44곳이고 결과는 플러그인 24 → 14.

핵심 판단 세 가지.

- **skill-forge 는 외부 스킬이 하나도 설치되지 않은 환경을 가정한다.** 네 소스는 지식의 출처(provenance)일 뿐 의존 대상이 아니다. 본문·references·scripts 어디에서도 외부 마켓플레이스 스킬, 플러그인, MCP 서버를 전제하지 않는다. 저장소 내부 스킬 위임조차 "있으면 가속, 없으면 인라인 진행"이어야 한다.
- **이미 번들인 플러그인을 더 합치지 않는다.** 합치면 버전 범프 폭발 반경만 커지고 참조 수정 비용은 385곳으로 뛴다. 단일스킬만 흡수하면 44곳이다.
- **전수 검토는 skill-forge 의 새 기준으로 처음부터 다시 돌린다.** `docs/audit/skill-content-structure-audit.md`(PR #136, 이슈 #117)는 **선례이자 baseline 비교군**이지 재사용할 산출물이 아니다. 그 감사는 5축이었고 skill-forge 의 기준은 훨씬 넓다 — 포인터 문구, 완료 기준의 clarity/demand, 정보 계층, leading word, negation, pruning 5종, 프론트매터 스키마, 런타임 계약 4종. 전수 검토는 **흡수 작업과 독립**이며, 흡수를 안 해도 돌려야 하는 작업이다.

---

## 확정된 결정

| # | 결정 | 선택 | 근거 |
|---|---|---|---|
| D1 | 신규 스킬 이름 | `skill-forge` | `docs-forge` / `rules-forge` 관례와 일치. 외부 `skill-creator` 와 트리거 충돌 없음. `great-` / `advanced-` 접두는 마케팅 워드 금지 규칙을 스스로 위반하므로 기각 |
| D2 | 검증 레이어 | 기계 판정 가능한 것만 새 가드 1개 (`scripts/check-skill-contract.mjs`) | 판단이 필요한 항목(no-op 산문, sediment, completion criterion)은 스킬 본문 체크리스트로. eval 벤치마크 루프 이식은 기각 — 이 저장소 스킬 다수가 주관적 워크플로라 assertion 이 안 맞음 |
| D3 | 팀 기반 리뷰 메커니즘 | Agent 서브에이전트 팬아웃 | PR #136 에서 이미 리뷰어 3개 팬아웃으로 검증된 패턴. Claude 전용 가속이므로 인라인 순차 경로가 primary 로 남아야 함 |
| D4 | 플러그인 삭제 | ~~`slidev`, `ppt-yeong-style`, `anti-slop-design`~~ — **이미 완료** | PR #164(slidev), PR #191(디자인 2종)에서 처리됨. 이 스펙 초안은 25 커밋 뒤처진 로컬 `main` 을 근거로 써서 셋이 남아 있다고 잘못 판단했다. `paper-search-tools` 는 계속 유지 — `code-scout/agents/paper-scout.md` 가 감싸고 있어 끊으면 paper 축이 깨짐 |
| D5 | ppt-yeong-style 미커밋 작업 | 폐기 | 담고 있던 플러그인이 PR #191 에서 이미 삭제돼 복원 대상이 없다. `archive/ppt-yeong-style` 브랜치를 만들었다가 같은 이유로 제거함 |
| D6 | 재편 단위 | 단일스킬 플러그인만 흡수. 이미 번들인 10개는 불변 | 참조 44곳 vs 385곳 |
| D7 | authoring 번들 이름 | `docs-forge` 유지, 스킬만 흡수 | docs-forge 참조 14곳을 안 건드림. 바뀌는 건 `rules-forge`(27) + `interview`(6) + `tcrei-prompt`(0) |
| D8 | `codex-image` | 단독 유지 | `CODEX_EXCLUDED` 가 플러그인 단위라 번들에 넣으면 번들째 Codex 에서 빠짐 |
| D9 | 실행 순서 | 삭제 → 흡수 → skill-forge → 가드 → 전수검토 | 이름이 다 확정된 뒤 검토를 돌려야 리포트가 rename 으로 무효화되지 않음 |
| D10 | skill-forge 의 외부 의존 | 없음 — 자립 | 네 소스는 전부 외부 마켓플레이스라 사용자 환경에 없을 수 있다. 런타임 참조는 조용한 실패가 된다 |
| D11 | 기존 스킬명 rename | 허용. 판정 기준은 skill-forge 의 포인터 원칙 | 흡수 대상은 PR2 에서(참조를 어차피 손대므로 한 번에), 흡수 안 하는 플러그인의 스킬은 PR3.5 에서 |
| D12 | 프론트매터 | skill-forge 가 스키마를 소유 (`references/frontmatter.md`) | 실측상 이미 어긋나 있다 — `argument-hint` 가 스킬 2개, `version` 2개, `license` 1개에만 붙어 있다 |

---

## 실측 근거 (2026-08-06, `origin/main` = 871898a)

플러그인 **24개** / marketplace `metadata.version` 2.11.0.

> 이 절의 초판은 25 커밋 뒤처진 로컬 `main` 을 근거로 써서 플러그인 25개에 삭제 대상 3개가 남아 있다고 적었다. 실제로는 `slidev`(PR #164)와 `ppt-yeong-style`·`anti-slop-design`(PR #191)이 이미 제거됐고, 그 사이 `council`(PR #189)과 `voice-prompt`(PR #193)가 추가됐다. 아래는 최신 트리 재실측이다.

분포: **이미 번들(스킬 ≥2) 10개 / 단일스킬 13개 / hooks-only 1개**.

단일스킬 플러그인의 유입 교차참조(`plugin:skill` 형태, 자기 플러그인·생성 트리·이 스펙/PRD 제외):

```
rules-forge 27   spec-state 7   interview 5   council 3
codex-image 2    gws-sync 2     voice-prompt 2   plaud-note-taking 1
brightdata-guide 0  notebook 0  translator 0  tcrei-prompt 0  tally-form 0
```

흡수 대상 11개의 참조 합계는 44곳이다. `codex-image`(2)와 `council`(3)은 단독 유지라 참조가 바뀌지 않는다.

런타임 eligibility 현재값:

- `CODEX_EXCLUDED` = `codex-image`, `council` — 둘 다 Codex 를 호출하는 브리지라 sync 하면 순환이다. 번들에 넣으면 번들 전체가 Codex 에서 빠지므로 단독 유지가 강제된다.
- `HERMES_ELIGIBLE` = `github-dev`, `interview`, `tcrei-prompt`, `ml-toolkit`, `brightdata-guide` — 삭제된 2개는 이미 정리됐다. 흡수로 `interview`·`tcrei-prompt`·`brightdata-guide` 가 사라지므로 새 소속인 `docs-forge`·`code-scout` 를 allowlist 에 넣어야 그 스킬들이 Hermes 에 계속 실린다.

프론트매터 키 사용 실태 (스킬 54개):

```
name 54   description 54   allowed-tools 16   version 2   argument-hint 2   license 1
```

`argument-hint` 는 커맨드 전용 필드로 알려져 있는데 스킬 2개(`tally-form`, `codex-image`)에 붙어 있다 — 스킬에서 인식되는지 `unverified`. `version`(`interview`, `plaud-note-taking`)과 `license`(`brightdata-guide`)는 Hermes 관례를 일부 스킬만 따라간 흔적이다. 프론트매터 규약이 없어서 생긴 표류이며, D12 의 근거다.

기존 감사 산출물(**선례 / baseline 비교군**, 재사용 대상 아님): `docs/audit/measure-skills.mjs`, `docs/audit/skill-measurements.csv`, `docs/audit/skill-content-structure-audit.md`. 그 감사의 restructure worklist(PR #118)는 **실행되지 않았다** — `slidev/create-slide` 844→842줄, `github-dev/cr-fix` 649→648줄로 사실상 그대로다.

---

## 흡수 지도

```
docs-forge   + write-rules, tcrei-prompt, interview-methodology,   ← 스킬 8개
               voice-prompt  (기존 4종 유지)
github-dev   + spec-state                                          ← 스킬 9개
ml-toolkit   + notebook                                            ← 스킬 6개
code-scout   + brightdata-guide                                    ← 스킬 4개
llm-wiki     + plaud-note-taking                                   ← 스킬 6개
publish(신설) translator, tally-form, gws-sync                      ← 스킬 3개

그대로       e2e-harness, mem0-ops, project-init, deepwiki, paper-search-tools
단독         core-config (hooks-only), codex-image·council (CODEX_EXCLUDED)
```

`skill-forge` 는 이슈 B 에서 `docs-forge` 에 추가되므로 최종 스킬 수는 9개가 된다. 이 흡수 PR 의 범위에는 들어가지 않는다.

결과: 플러그인 24 → 14. 소멸 11개, 신설 1개(`publish`).

흡수처는 발명이 아니라 기존 의존 관계다.

| 흡수 대상 | 참조 | 흡수처 | 이미 존재하는 의존 |
|---|---:|---|---|
| `rules-forge` | 27 | `docs-forge` | 둘 다 에이전트가 읽는 문서를 생성 |
| `spec-state` | 7 | `github-dev` | `.claude/state/spec.json` 이 spec→issue→PR 집계, github-dev 가 씀 |
| `interview` | 5 | `docs-forge` | `project-init:new`, `plaud-note-taking`, `github-dev:decompose-issue` 가 호출 |
| `voice-prompt` | 2 | `docs-forge` | `tcrei-prompt` 와 같은 결 — 사용자 입력을 에이전트가 쓸 형태로 다듬는다 |
| `gws-sync` | 2 | 신설 `publish` | 산출물을 Drive 로 내보냄 |
| `plaud-note-taking` | 1 | `llm-wiki` | `.llmwiki/raw/transcripts/` 에 씀 |
| `notebook` | 0 | `ml-toolkit` | `ml-toolkit:cv-notebook` 이 이미 있음 |
| `brightdata-guide` | 0 | `code-scout` | `web-scout` 가 tier-3 fetch fallback 으로 사용 |
| `tcrei-prompt` | 0 | `docs-forge` | 프롬프트 재작성 — 에이전트 입력 설계 |
| `translator`, `tally-form` | 0 | 신설 `publish` | 산출물을 다른 표면으로 내보냄 |

---

## skill-forge 설계

`plugins/docs-forge/skills/` 아래 3개 스킬로 나눈다. 분할 기준은 **호출 시점이 다르고 각각 독립 트리거를 가진다**는 것이다. 하나로 합치면 전수 검토의 긴 절차가 단건 작성 경로에 항상 실려 sprawl 이 된다.

```
plugins/docs-forge/skills/
├── skill-forge/                  # 작성·개정 (author)
│   ├── SKILL.md
│   ├── references/
│   │   ├── frontmatter.md        # 프론트매터 스키마 (D12)
│   │   ├── writing-levers.md     # 작성 이론
│   │   ├── structure.md          # 섹션 구조 + 완료 기준
│   │   └── runtime-contract.md   # 3런타임 계약 + 패키징
│   └── scripts/
│       └── measure-skills.mjs    # 기계 측정 (번들 내부, 자립)
├── skill-audit/SKILL.md          # 단일 스킬 진단 → 등급 + 수정안
└── skill-fleet-review/SKILL.md   # 전수 검토 (팬아웃)
```

### 자립 제약 (D10) — 구현 시 하드 룰

- 본문·references·scripts 어디에서도 외부 마켓플레이스 스킬(`skill-creator`, `superpowers:*`, Hermes authoring skill)을 **읽으라고 지시하지 않는다.** 필요한 내용은 references 안에 자체 보유한다.
- 출처 표기는 귀속(provenance)일 뿐이다. "출처: mattpocock writing-for-agents" 는 그 파일을 열라는 뜻이 아니며, 구현 시 그렇게 읽히지 않도록 표기한다.
- 측정 스크립트는 `docs/audit/measure-skills.mjs` 를 **참조하지 않고 번들 `scripts/` 로 이관**한다. 다른 저장소에 설치돼도 동작해야 하기 때문이다. `docs/audit/` 의 기존 파일은 과거 감사 기록으로 그대로 둔다.
- 저장소 내부 스킬(`interview:interview-methodology` 등) 위임도 필수 경로에 두지 않는다 — 있으면 가속, 없으면 인라인 진행.
- MCP 서버, 외부 CLI(`gh`, `codex`, `agy`)를 전제하지 않는다. 쓴다면 부재 시 분기를 본문에 둔다.

### references/frontmatter.md — 스키마 (D12)

Claude Code 스킬 프론트매터의 필드별 소유·검증 규칙. 실측 표류(`argument-hint` 2건 등)를 정리 대상으로 명시하고, 필드마다 다음을 고정한다.

- `name` — 필수. lowercase-kebab, 64자 이하, 디렉터리명과 일치.
- `description` — 필수. 유일한 트리거 메커니즘. 1024자 상한(Codex silent skip), `: ` 포함 시 인용 필수, 트리거 브랜치를 앞쪽에.
- `allowed-tools` — 선택. 붙이면 그 목록이 곧 이식성 계약이 되므로 `AskUserQuestion` 포함 시 크로스런타임 게이트 필요.
- `disable-model-invocation` — 선택. user-invoked 로 전환해 context load 를 0 으로 만드는 레버 (`unverified` — 이 저장소에 사용 사례 없음, 구현 전 확인).
- `version` / `license` / `argument-hint` — 이 저장소 스킬에서는 **쓰지 않는다.** 버전은 `plugin.json` + `marketplace.json` 이 소유하고, `argument-hint` 는 커맨드 필드다.

### references/writing-levers.md — 작성 이론

- **context pointer**: description 은 항상 로드되는 포인터다. 도달 조건을 인코딩하며, 대상이 아니라 **문구**가 도달 신뢰도를 정한다. 브랜치 하나당 트리거 하나, 동의어 나열 금지.
- **두 개의 부하**: context load(모델 창에 매 턴 얹히는 비용) vs cognitive load(사람이 무엇이 존재하는지 기억하는 비용). 후자는 최소화 대상이 아니라 사람의 판단권 가격이다.
- **정보 계층 사다리**: in-file step → in-file reference → disclosed reference. progressive disclosure 는 토큰 최적화가 아니라 계층 보호 수단. 분기 테스트 — 모든 분기가 쓰는 건 인라인, 일부만 도달하는 건 포인터 뒤로.
- **co-location**: 개념의 정의·규칙·예외를 한 제목 아래에. duplication(한 의미가 두 곳)과 구별되는 실패는 scattering(한 의미가 여러 곳에 파편화).
- **completion criterion 의 두 속성**: clarity(done/not-done 구분 가능한가 — 모호하면 premature completion) + demand(얼마나 요구하는가 — legwork 를 끌어냄). 방어 순서는 기준을 먼저 날카롭게, 그래도 서두르면 그때 시퀀스를 분할. 분할은 실제 컨텍스트 경계(핸드오프/서브에이전트)에서만 효과가 있다.
- **leading word**: 사전학습에 이미 있는 압축 개념(`tight loop`, `root cause`, `tracer bullet`)을 토큰으로 반복. 직접 만든 단어는 prior 를 못 부르므로 기존 단어 우선.
- **negation 실패 모드**: 금지로 조종하면 금지 대상이 오히려 컨텍스트에 올라온다. 목표 행동을 긍정문으로 쓴다. 하드 가드레일일 때만 금지를 쓰고, 그때도 긍정 목표를 짝지운다.
- **pruning**: 단일 진실 원천 / 환경도 진실 원천이며 그걸 베낀 문서는 cache(비싼 조회만 캐시) / relevance / no-op(기본 동작 대비 행동을 바꾸는가 — 모델 상대적 판정, 실행으로 결정) / sediment.
- **invocation 선택** (SKILL-MECHANICS): model-invoked 는 description 이 영구 context load, user-invoked 는 cognitive load. 에이전트나 다른 스킬이 스스로 도달해야 할 때만 model-invoked.

### references/structure.md — 구조와 완료 기준

- 섹션 순서: `# Title` → `## Overview` → `## When to Use`(+ 반대 트리거) → `## Prerequisites` → `## How to Run` → `## Quick Reference` → `## Procedure` → `## Pitfalls` → `## Verification`. 내용이 없으면 생략.
- 분량 목표: 단순 100줄 / 복잡 200줄. `check-skill-prose.mjs` 의 500줄 천장은 상한이지 목표가 아니다.
- `scripts/` = 비자명 로직(모델이 매번 재작성하지 않게), `references/` = 부피 크거나 분기별, `assets/` = 산출물에 쓰이는 파일. `references/` 깊이는 정확히 1.
- 툴 프레이밍: 하네스 툴 이름을 쓴다 — `cat`/`head` 대신 `Read`, `grep`/`find` 대신 `Grep`/`Glob`, `sed` 대신 `Edit`. Hermes 매핑은 `runtime-contract.md`.
- 품질 실패 5종: premature completion / duplication / sediment / sprawl / no-op prose.

### references/runtime-contract.md — 이 저장소 계약 (네 소스 어디에도 없는 부분)

silent failure 4종과 패키징 의무를 한 곳에 모은다.

| 위반 | 증상 | 탐지 |
|---|---|---|
| `description` > 1024자 | Codex 0.135 가 스킬을 **조용히 skip** (Claude 에선 안 보임) | `check-skill-contract.mjs` |
| `description` 에 인용 없는 `: ` | YAML frontmatter 가 nested mapping 으로 파싱 실패 → 양 런타임 로드 안 됨 | `check-skill-contract.mjs` |
| bare `${CLAUDE_PLUGIN_ROOT}` | Codex 가 export 안 함 → 첫 단계에서 실패. `PLUGIN_ROOT` resolver 블록 필요 | `check-skill-contract.mjs` |
| `AskUserQuestion` 하드코딩 | Hermes 에 없음 → 대화 게이트 정지 | `check-skill-tool-portability.mjs` (기존) |

패키징 의무: 플러그인 하위 **어떤 파일이든** 바뀌면 `plugin.json` PATCH + `marketplace.json` 해당 엔트리 + `metadata.version` 을 같은 변경에 포함. 문서·asset 편집도 포함(캐시 게이트). 이후 `sync-codex-manifests.mjs`, (해당되면) `sync-hermes-manifests.mjs` 재생성.

subagent 위임은 Claude 전용 가속이다 — 인라인 크로스런타임 경로가 primary 로 완전해야 하고, 스킬 로직을 agent 정의로 옮기지 않는다.

### 지식 출처와 미채택 (provenance)

아래는 저작 시점에 읽고 합성한 출처의 기록이다. **skill-forge 는 이 중 어느 것도 런타임에 참조하지 않는다** (D10) — 내용은 references 안에 자체 보유한다.

| 출처 | 가져온 것 | 가져오지 않은 것 |
|---|---|---|
| mattpocock `writing-for-agents` | context pointer, 두 부하, 정보 계층 사다리, completion criterion 의 clarity/demand, leading word, negation, pruning 5종, invocation 선택 | 없음 |
| Hermes `hermes-agent-skill-authoring` + HARDLINE | 섹션 순서, 분량 목표, 툴 프레이밍, `scripts`/`references`/`templates` 분리, 품질 실패 5종 | Hermes 종속 요소 — `skill_manage`, `~/.hermes/skills/`, 카테고리 목록, `platforms:` frontmatter |
| `skill-creator` | 테스트 프롬프트로 트리거를 확인한다는 발상, description 이 유일한 트리거 메커니즘이라는 관점 | with-skill vs baseline 벤치마크, `run_loop.py` description 최적화 루프 (D2 — 주관적 워크플로에 assertion 부적합, 실행당 토큰 비용 큼) |
| `superpowers:writing-skills` | "이 줄이 기본 동작을 바꾸는가"의 실행 기반 판정 | TDD RED 베이스라인 강제, 서브에이전트 압박 시나리오 |

---

## check-skill-contract.mjs (D2)

`scripts/check-skill-contract.mjs`, Node 18+ built-in 만. 차단 검사 5종:

1. `description` > 1024자
2. `description` 에 인용되지 않은 `: `
3. 스킬 본문의 bare `${CLAUDE_PLUGIN_ROOT}` (resolver 블록 없이)
4. `name` 이 비-kebab 또는 > 64자
5. frontmatter 가 byte 0 에서 `---` 로 시작하지 않음

기존 가드와 역할 분리:

| 스크립트 | 성격 | 겹침 |
|---|---|---|
| `check-skill-prose.mjs` | 비차단 경고 (500줄, references 깊이) | 없음 — 측정 |
| `check-skill-tool-portability.mjs` | 차단 (AskUserQuestion 이관) | 없음 — 툴 이식성 |
| `docs/audit/measure-skills.mjs` | 측정 CSV 생성 | 없음 — fleet-review 가 재사용 |
| `check-skill-contract.mjs` (신규) | 차단 (silent failure 5종) | 없음 |

배선: `.githooks/pre-commit` + `.github/workflows/validate-codex.yml`.

---

## skill-fleet-review 설계

**흡수(PR2)와 독립된 작업이다.** 흡수를 하나도 안 해도 돌려야 한다 — 대상은 스킬의 내용 품질이지 소속이 아니다. PR #136 은 절차의 선례이고 그때의 등급(2 grade-C, 12 grade-B)은 **개선 여부를 비교할 baseline** 으로만 쓴다. 산출물을 이어받지 않는다.

skill-forge 의 기준이 #136 의 5축보다 넓으므로 검토 축을 재정의한다.

| 축 | 판정 대상 | #136 에 있었나 |
|---|---|---|
| 프론트매터 | 필드 스키마, description 상한/인용, 트리거 브랜치 배치 | 길이만 |
| 포인터 | description 이 브랜치를 몇 개 담는가, 동의어 중복, 본문이 이미 가진 정체성 재기술 | 없음 |
| 구조 | 섹션 순서, 분량, `references` 깊이, scripts 분리 | 일부 |
| 완료 기준 | 각 단계가 done/not-done 을 구분시키는가(clarity), 요구량이 legwork 을 끌어내는가(demand) | 없음 |
| 정보 계층 | 인라인 vs 포인터 뒤 배치가 분기 테스트를 통과하는가, co-location | 일부 |
| pruning | no-op 산문, 중복, sediment, negation, 환경을 베낀 cache | 없음 |
| 런타임 계약 | silent failure 4종, 위임이 Claude 전용 가속인가 | 위임만 |

절차:

1. **측정** — `node <skill-forge>/scripts/measure-skills.mjs`. 번들 내부 스크립트를 쓴다(D10). 줄 수, body 토큰, description 길이, 섹션 수, references 깊이, scripts 유무 + 프론트매터 키 인벤토리(신규).
2. **코호트 선정** — 기계 위반자 전부 + 줄 수/토큰 상위 N. 전 스킬에 LLM 을 돌리지 않는다(measurement-first). 다만 **포인터 축은 전 스킬 대상**이다 — description 은 짧아서 비용이 낮고, 흡수로 한 번들에 8스킬이 모이면 충돌이 여기서 드러난다.
3. **팬아웃** (D3) — 축별 리뷰어 Agent 를 병렬 dispatch, read-only. **인라인 순차 경로가 primary 로 남아야 한다** — Codex/Hermes 에는 agents surface 가 없다.
4. **판정 티어** — P0 = silent failure 유발(가드 5종) / P1 = 구조·완료 기준·포인터 충돌 / P2 = 문체·pruning.
5. **산출** — `docs/audit/<date>-fleet.md` + CSV, #136 대비 등급 변화 열 포함. 적용은 티어와 플러그인을 골라 승인한 뒤 배치.

---

## PR 순서 (D9)

| PR | 내용 | 버전 영향 |
|---|---|---|
| ~~PR1~~ | ~~삭제 3개~~ — **PR #164 / #191 에서 이미 완료** | — |
| PR2 | 단일스킬 11개 흡수 + `publish` 신설. 교차참조 44곳, `.claude/settings.json`, `marketplace.json`, `plugin.json`, `HERMES_ELIGIBLE` 재조정, Codex/Hermes 매니페스트 재생성, AGENTS/README 동기화. **흡수 대상 스킬의 rename 을 여기 포함** (D11 — 어차피 참조를 손대므로 한 번에) | 흡수처 플러그인 MINOR + 신설 `publish` + `metadata.version` |
| PR3 | `skill-forge` 3스킬 + references 4종 + `scripts/measure-skills.mjs` | `docs-forge` MINOR |
| PR3.5 | skill-forge 로 흡수 결과 자기검수 + 흡수 안 한 플러그인의 스킬 rename (D11) | 대상 플러그인별 PATCH |
| PR4 | `check-skill-contract.mjs` + pre-commit/CI 배선 | 루트 스크립트 — 플러그인 범프 없음 |
| PR5+ | 전수 검토 → 티어별 리팩토링 (흡수와 독립) | 대상 플러그인별 |

### PR3.5 자기검수 (필수)

흡수는 스킬 **본문 안의** 상호 참조와 분기도 바꾼다. PR2 시점엔 기계적 참조 치환만 하고, 판단이 필요한 항목은 skill-forge 가 생긴 뒤로 미룬다. 확인 대상:

- `plugin:skill` 호출 표기가 새 이름을 가리키는가 (`rules-forge:write-rules` → `docs-forge:write-rules` 등)
- 스킬 본문의 "이 플러그인" / 번들 경로 서술이 새 위치와 맞는가
- 흡수로 같은 번들에 들어온 스킬끼리 description 트리거가 겹치지 않는가 (`docs-forge` 는 스킬 8개 — 포인터 충돌 위험이 가장 큼)
- `related_skills` / 참조 링크가 소멸한 플러그인을 가리키지 않는가
- 흡수처의 `CLAUDE.md` 가 새 스킬을 반영하는가
- 흡수 안 한 플러그인의 스킬 rename (D11)

**rename 판정 기준은 skill-forge 의 포인터 원칙**이지 취향이 아니다. 후보와 반례 예시:

| 스킬 | 판정 |
|---|---|
| `spec-state:state-tracker` → `github-dev:*` | rename 후보 — "state" 가 `spec.json` 인지 run record 인지 이름으로 안 드러남 |
| `deepwiki:ask`, `paper-search-tools:setup`, `project-init:new` | rename 후보 — 일반명사 단독. prefix 가 없으면 무엇에 대한 ask/setup/new 인지 불명 |
| `code-scout:resource-finder` vs `research-orchestrator` | rename 후보 — 둘의 경계가 이름으로 안 갈림 |
| `docs-forge:{readme,changelog,moc,deploy-doc}-guide` | **rename 대상 아님** — `commands/` 에 동명 커맨드가 1:1 로 있어 `-guide` 는 충돌 회피용 근거 있는 명명 |

---

## Out of scope

- 이미 번들인 10개 플러그인의 재편 (D6)
- `paper-search-tools` 삭제 (D4 — 보류)
- eval 벤치마크 / description 트리거 최적화 루프 이식 (D2)
- `CODEX_EXCLUDED` 를 스킬 단위 제외로 확장 (D8 로 불필요해짐. `codex-image` 를 번들에 넣기로 바뀌면 그때 필요)
- PR #118 restructure worklist 의 개별 항목 — PR5+ 의 전수 검토가 이를 재산출한다
- `docs/audit/` 기존 파일 삭제·이동 — 과거 감사 기록으로 그대로 둔다. skill-forge 는 번들 내부 사본을 쓴다 (D10)

---

## Open questions / unverified

- ~~**Hermes 어댑터 생존 여부**~~ — **해소됨 (2026-08-06)**. 어댑터는 살아 있다: `plugin.yaml` / `__init__.py` 가 실재하고, `sync-hermes-manifests.mjs --check` 가 `.githooks/pre-commit:16` 과 `.github/workflows/validate-codex.yml:24` 양쪽에 배선돼 있다. `npx skills`(`scripts/install-skills.mjs`)는 어댑터와 무관한 별도의 스킬 단위 설치 경로이며 `README.md:736` 이 그렇게 명시한다. 둘은 공존한다. 어댑터가 은퇴했다는 mem0 기억이 틀렸고 저장소 실측이 맞다.
- ~~**`ppt-yeong-style` 보존 위치**~~ — **무효**. 담고 있던 플러그인이 PR #191 에서 이미 삭제됐다.
- **`publish` 번들의 근거 강도**: `translator` / `tally-form` / `gws-sync` 는 서로 호출하지 않는다. 묶는 근거가 의미론적("산출물을 내보냄")일 뿐이라, 셋을 단독 유지하는 쪽으로 재고할 여지가 있다.
- **낡은 근거로 스펙을 쓰지 않기**: 이 문서의 초판은 25 커밋 뒤처진 로컬 `main` 을 실측 근거로 삼아 삭제 대상 3개가 남아 있다고 단정했다. 실측 전에 `git fetch` 로 원격과의 차이를 먼저 확인해야 한다.
- **프론트매터 필드 두 건 (`unverified`)**: 스킬에서 `argument-hint` 가 인식되는지(현재 `tally-form`, `codex-image` 2건), `disable-model-invocation` 이 이 저장소 런타임 조합에서 동작하는지. PR3 의 `references/frontmatter.md` 작성 전에 확인해야 규약을 단정할 수 있다.
- **skill-forge 의 이식 범위**: D10 의 자립 제약은 다른 저장소 설치를 가능하게 하지만, `references/runtime-contract.md` 는 이 저장소의 3런타임 계약을 담는다. 범용 스킬로 낼지(계약 부분을 분기 처리) 이 저장소 전용으로 둘지는 PR3 착수 시 결정한다.
