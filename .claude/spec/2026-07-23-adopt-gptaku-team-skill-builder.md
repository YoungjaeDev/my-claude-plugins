# Feature Specification: gptaku 2종 diverge-fork — team-builder + skill-builder (2026-07-23)

## 한눈에 보기
gptaku-plugins marketplace의 `kkirikkiri`(0.21.7)와 `skillers-suda`(1.4.4)를 이
marketplace로 가져와 각각 **team-builder**, **skill-builder**라는 이름의 자체 관할
플러그인(각 1.0.0)으로 만든다. 업스트림과는 완전 절연하고, 이식과 동시에 대수술
(rename + 퍼널 제거 + SKILL.md 재구조화 + 3-런타임 재설계 + 영어 본문화)을 한 번에
수행한다. 이 문서는 `/interview:interview-methodology` relentless(grill-me) 세션의
결정 레코드이며, 이 세션에서는 아무것도 구현하지 않았다. 구현은 후속 세션의
`decompose-issue` → `resolve-issue` 체인으로 진행한다.

## 원본 사실 (읽기 전용 조사, 2026-07-23)
| | kkirikkiri 0.21.7 | skillers-suda 1.4.4 |
|---|---|---|
| SKILL.md | 1,432줄 (전부 한국어) | 804줄 (전부 한국어) |
| references | 10개, 약 2,458줄 | 15개 + agents 템플릿 3개 |
| 스크립트 | Node 외부 CLI job runner 3종(run-cli-job/worker, check-env, 약 700줄; provider = codex/agy/gjc) | Python 11종 + eval-viewer(HTML 2 + py 1) |
| 라이선스 | MIT (c) 2026 fivetaku | MIT + THIRD_PARTY_LICENSES — Python 스크립트 11개 중 7개(run_eval, utils, aggregate_benchmark, generate_report, run_loop, improve_description, package_skill)가 Anthropic `claude-plugins-official/skill-creator`의 Apache-2.0 코드 |
| 퍼널 | setup.sh star-ask + gptaku-update-check.cjs + `.in_use`/`.jobs` 런타임 마커 | 동일 구조 (star-ask + update-check) |

## 동기 — §4 삼분류 밖의 제4차선 "diverge-fork"
`.llmwiki/wiki/plugin-ops/skill-authoring-source-grounded-then-audit.md` §4의
adopt-triage(gap-filler는 설치해서 그대로 쓴다 / insight-reflection / skip)에 이번
케이스는 해당하지 않는다. 목적이 "설치해서 쓰기"가 아니라 **업스트림이 받아줄 리
없는 방향 전환**이기 때문이다. 인터뷰에서 확정된 실제 통증은 세 가지다.

1. 업스트림이 안 해줄 개조 — SKILL.md 축약·재구조화, 이 스택의 규율(3-런타임 계약,
   인라인 primary 원칙)에 맞춘 재설계.
2. 퍼널·원격 훅 제거 — star-ask, 업데이트 알림 훅, 사용 마커.
3. rename — 기존 이름이 마음에 들지 않음. rename 덕분에 gptaku 원본과의 이름 충돌
   문제는 자동 해소된다.

"업데이트가 느리다"는 표면 증상이었고, fork는 업데이트를 빠르게 하는 것이 아니라
0으로 만든다는 점을 인터뷰에서 짚은 뒤 **완전 절연**을 명시적으로 선택했다.
두 플러그인 모두 실사용 빈도는 "핵심 루틴"으로 확인되어 소유 유지비를 지불할
가치가 있다고 판단했다.

## 확정 결정 (사용자, 2026-07-23)

### 이름·버전·절연
- `kkirikkiri` → **`team-builder`** (자연어 → 에이전트 팀 구성·실행).
- `skillers-suda` → **`skill-builder`** (아이디어 → 전문가 토론 → 스킬 생성 → eval 루프).
  후보였던 "skill-creator-advanced"는 설치된 Anthropic skill-creator와의 트리거
  경합·종속 인상 때문에 기각.
- 초기 버전은 둘 다 **1.0.0 리셋** (원본 버전 승계 없음).
- 업스트림 fivetaku 저장소와는 **완전 절연**. 이후 diff 추적이나 cherry-pick 없음.
- 숨은 2차 업스트림: skill-builder 스크립트 7종의 원산지인 Anthropic skill-creator는
  플러그인으로 계속 설치 상태를 유지해 그쪽 개선을 관찰하는 창으로 쓴다(아래 라우팅).

### 수술 범위 — 플러그인당 한 방 대수술
이식과 재구조화를 한 PR에서 함께 수행한다(2단계 분리안은 기각). 포함 항목:

1. **rename** — 디렉터리·매니페스트·스킬/커맨드 이름·내부 식별자(예: KKIRIKKIRI_DIR).
2. **퍼널 제거** — setup/ 디렉터리(star-ask, gptaku-update-check.cjs), `.in_use`/`.jobs`
   런타임 마커, 커맨드의 Step 0 star 흐름.
3. **배포 껍데기 제거** — 다국어 README(es/ja/zh 등), hero PNG, DISCLAIMER.md,
   VERSIONING.md, docs/REDESIGN 문서. README는 이 repo 관례대로 단일화.
4. **SKILL.md 재구조화** — 1,432줄/804줄 본문을 슬림 오케스트레이터 + references
   분해(progressive disclosure)로 재편.
5. **3-런타임 재설계** — 목표는 Claude + Codex + Hermes. AGENTS.md 기존 규칙 준수:
   인라인 크로스런타임 경로가 primary, Agent Teams·Workflow 도구·병렬 Task 스폰은
   Claude 전용 가속. AskUserQuestion은 capability-aware 파일럿 게이트 블록으로,
   번들 스크립트 호출은 PLUGIN_ROOT resolver로, Hermes 도구 매핑은
   `references/<harness>-tools.md` 중앙화 형태를 우선한다.
6. **본문 언어** — 지시 산문은 영어로 재작성(하우스 룰), 사용자에게 보여줄 한글
   출력물(팀 구성 제안 형식, 용어 병기 표, 한글 예시)은 원어 유지.

**유지 항목** (제거하지 않기로 명시 결정): 외부 CLI job runner 3종(council 규율과
정합; gjc는 이 머신에 미설치이므로 provider check의 graceful degradation 확인),
presets.md + pm-frameworks.md, metaphor-guide.md(재미 요소가 아니라 "공식 용어 +
한글 병기" 규약), skill-builder의 eval-viewer와 Python 스크립트 전부.

### 합격선 4종 (수술 완료 판정 기준)
1. **커버리지 매핑표** — 원본 SKILL.md의 모든 Step/Phase → 신판 위치 매핑. 누락은
   "의도적 삭제" 결정으로만 허용 (wiki §2 documented-vs-enforced 오디트 규율).
2. **대표 시나리오 dry-run** — 원본 vs 신판에 같은 요청을 넣어 실행 직전
   단계(팀 구성 제안 / 워크플로우 설계)까지 비교.
3. **skill-builder 자체 eval 실전 1건** — 신판으로 실제 스킬 하나를
   생성→eval→개선→패키징 끝까지 수행.
4. **Codex 실구동 + Hermes 정적 검사** — Codex는 CLI로 실구동 검증. Hermes는 실행
   런처가 이 머신 PATH에 없어(~/.hermes/config.yaml만 존재) 실구동은 unverified로
   명시하고, 어댑터 생성 + 호환표 + `sync-hermes-manifests.mjs --check` 통과까지만
   보증한다(기존 Hermes-eligible 7종과 동일 수준).

### PR 계획
- **플러그인당 1 PR, skill-builder(804줄) 먼저** — 작은 쪽으로 수술 방식을 검증한 뒤
  team-builder(1,432줄)에 적용. 각 PR은 cr-fix 루프 통과.
- 기계적 동기화(각 PR에 포함): `.claude-plugin/marketplace.json` 항목 추가 +
  `metadata.version` 범프, AGENTS.md `## Plugins (25)` → 26 → 27 + 구조 트리 +
  README 갱신, `sync-codex-manifests.mjs` 재생성(둘 다 Codex-eligible, 검증 주석
  카운트 24 → 26), HERMES_ELIGIBLE allowlist 7 → 9 + `sync-hermes-manifests.mjs`
  재생성, AskUserQuestion 파일럿 블록(또는 baseline 등록), description 1024자 미만 +
  colon-space 인용 준수.

### 라우팅·원본 거취
- 같은 도메인 스킬(Anthropic skill-creator, harness:harness, plugin-dev)과
  **공존 + 용도 분리** — skill-builder description에 "전문가 토론 + eval 풀
  파이프라인 전용" 트리거를 명시해 경합을 줄인다.
- gptaku 원본 2개는 **검증(합격선 4종) 완료까지 병행 설치 유지**. disable은
  사용자가 직접 수행한다(에이전트 범위는 검증까지). gptaku marketplace 자체는
  나머지 7개 플러그인 때문에 유지.

## 라이선스·표기
MIT (c) 2026 fivetaku — 개조·재배포 모두 허용. near-verbatim으로 남는 부분(특히
CLI job runner, Python 스크립트)에는 이 repo 관례대로
`Adapted from fivetaku/kkirikkiri (MIT)` / `Adapted from fivetaku/skillers-suda (MIT)`
한 줄을 유지한다. skill-builder에는 Apache-2.0 7종 때문에 THIRD_PARTY_LICENSES
파일을 반드시 동반 이동한다.

## Open Questions (decompose 시 확정)
- AGENTS.md 카테고리 배치 — team-builder를 기존 카테고리에 넣을지 "Orchestration"
  신설인지, skill-builder는 Development Tools인지.
- 커맨드 표면(commands/*.md, Claude 전용) 유지 여부와 신판 커맨드 이름.
- 단일화할 README의 언어·구성 상세.
- Hermes 실구동 검증 — 런처 복구는 별도 작업으로 미룸(현재 unverified).
- `.claude/state/spec.json` 등록(state-tracker `start`)은 decompose 시점에.

## Sources
- `~/.claude/plugins/cache/gptaku-plugins/kkirikkiri/0.21.7/`,
  `~/.claude/plugins/cache/gptaku-plugins/skillers-suda/1.4.4/` — 파일 트리, 줄 수,
  LICENSE/THIRD_PARTY, setup.sh, run-cli-job.js, metaphor-guide.md 직접 확인.
- `.llmwiki/wiki/plugin-ops/skill-authoring-source-grounded-then-audit.md` §2·§4 —
  커버리지 오디트 규율과 adopt-triage 방법론.
- 이 세션의 relentless 인터뷰 4라운드 + 검증 라운드 (2026-07-23).
- 선례 형식: `.claude/spec/2026-07-22-adopt-from-davidondrej-skills.md`.
