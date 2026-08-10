# PRD — skill-forge 스킬 저작 하네스

> 전체 결정 근거와 흡수 지도는 `.claude/spec/2026-08-05-skill-forge-and-singleton-absorption.md` 에 있다. 이 PRD 는 그 스펙 중 **이슈 B (skill-forge + 가드)** 범위만 다룬다.

## 목표

스킬을 쓰고·진단하고·전수 검토하는 자립 스킬 `skill-forge` 를 `docs-forge` 플러그인 안에 만들고, 기계 판정 가능한 위반을 커밋 시점에 차단하는 가드를 붙인다.

현재 이 저장소는 스킬 50개를 3런타임(Claude Code / Codex 0.135 / Hermes)에 싣지만, 스킬을 어떻게 쓸지에 대한 규약이 어디에도 없다. 그 결과 조용히 깨지는 위반이 이미 존재한다 — 프론트매터 키가 스킬마다 다르고(`argument-hint` 2건, `version` 3건, `license` 1건), Codex 가 description 1024자 초과 스킬을 말없이 건너뛰는 것을 막는 장치가 없다.

## 배경 — 왜 외부 스킬로 대체할 수 없나

외부에 스킬 저작 도구가 셋 있다(`skill-creator`, `superpowers:writing-skills`, Hermes `hermes-agent-skill-authoring`). 셋 다 이 저장소의 3런타임 패키징 계약을 모른다 — Codex silent skip, YAML `: ` 함정, `${CLAUDE_PLUGIN_ROOT}` 미export, Hermes 명시 로드, 버전 범프·매니페스트 재생성 의무. 저작 시점에 그 내용을 읽고 합성하되, **런타임에는 어느 것도 참조하지 않는다.**

## 범위

### 이 골이 하는 일

| 마일스톤 | 산출물 |
|---|---|
| M1 skill-forge | `docs-forge` 안에 스킬 3종 + references 4종 + scripts 1종 |
| M2 자기검수 | 흡수된 스킬 전체를 skill-forge 로 진단, rename 판정 기록 (실행 없음) |
| M3 가드 | `scripts/check-skill-contract.mjs` + pre-commit / CI 배선 |

### 선행 조건 (#198 — 해소됨)

단일스킬 플러그인 11개 흡수(플러그인 24 → 14)는 #198 에서 사람이 처리했고, PR #200 (`c56bd25`) 으로 머지됐다. M2 는 그 결과를 검수하므로 이 골은 선행 조건 없이 착수할 수 있다.

흡수된 11개는 `brightdata-guide`, `gws-sync`, `interview`, `notebook`, `plaud-note-taking`, `rules-forge`, `spec-state`, `tally-form`, `tcrei-prompt`, `translator`, `voice-prompt` 다.

(미사용 플러그인 3종 삭제는 PR #164 / #191 에서 이미 끝났다. 이 PRD 초판은 낡은 로컬 `main` 을 근거로 삼아 그것이 남은 작업이라고 적었다.)

### Non-goals

- 플러그인 흡수·rename 실행 (#198)
- 스킬 50개 전수 검토와 그에 따른 리팩토링 (skill-forge 완성 후 별도 이슈)
- `docs/audit/` 기존 감사 산출물 삭제·이동 — 과거 기록으로 그대로 둔다
- eval 벤치마크 / description 트리거 최적화 루프 이식
- 이미 번들인 플러그인 11개의 재편

## 설계 제약

### C1. 자립 (하드 룰)

- 본문·references·scripts 어디에서도 외부 마켓플레이스 스킬을 읽으라고 지시하지 않는다.
- 출처 표기는 귀속일 뿐이며, 그 파일을 열라는 뜻으로 읽히지 않게 표기한다.
- 측정 스크립트는 `docs/audit/measure-skills.mjs` 를 참조하지 않고 번들 `scripts/` 에 자체 보유한다.
- 저장소 내부 스킬 위임도 필수 경로에 두지 않는다 — 있으면 가속, 없으면 인라인 진행.
- MCP 서버·외부 CLI 를 전제하지 않는다.

### C2. 구조

```
plugins/docs-forge/skills/
├── skill-forge/
│   ├── SKILL.md
│   ├── references/{frontmatter,writing-levers,structure,runtime-contract}.md
│   └── scripts/measure-skills.mjs
├── skill-audit/SKILL.md
└── skill-fleet-review/SKILL.md
```

3개로 나누는 이유는 호출 시점이 다르고 각각 독립 트리거를 갖기 때문이다. 하나로 합치면 전수 검토의 긴 절차가 단건 작성 경로에 항상 실려 sprawl 이 된다.

### C3. 가드가 잡을 위반 6종

1. `description` > 1024자 (Codex silent skip)
2. `description` 에 인용되지 않은 `: ` (YAML 파싱 붕괴)
3. resolver 블록 없는 bare `${CLAUDE_PLUGIN_ROOT}` (Codex 미export)
4. `name` 비-kebab 또는 > 64자
5. frontmatter 가 byte 0 에서 `---` 로 시작하지 않음
6. `name` 이 스킬 디렉터리명과 불일치 (Claude/Codex 는 frontmatter 이름을, 생성된 Hermes 어댑터는 디렉터리명을 등록 → 런타임별 스킬 정체성 분열). 초판은 5종이었고, PR #202 리뷰에서 CodeRabbit·Codex 가 각각 지적해 추가했다 — 실제로 기존 위반 1건(`paper-search-tools`)을 잡았다.

기존 가드 4종(`check-skill-prose` 비차단 측정, `check-skill-tool-portability` 툴 이식성, `check-doc-consistency` 문서 동기화, `check-shell-portability` GNU 전용 구문)과 역할이 겹치지 않아야 한다.

## Acceptance Criteria

### M0 — 선행 확인 (unverified 해소, M1 착수 전)

- [x] ~~Hermes 어댑터 생존 여부 확정~~ — 해소됨 (2026-08-06). 어댑터는 유효하다: `plugin.yaml` / `__init__.py` 실재 + `--check` 가 `.githooks/pre-commit:16` 과 `.github/workflows/validate-codex.yml:24` 에 배선. `npx skills` 는 어댑터와 무관한 별도 경로 (`README.md:736`)
- [ ] 스킬 프론트매터에서 `argument-hint` 가 인식되는지 확정 (현재 `tally-form`, `codex-image` 2건)
- [ ] `disable-model-invocation` 이 이 저장소 런타임 조합에서 동작하는지 확정
- [ ] 세 결과를 `references/frontmatter.md` 에 반영 — 확인 못 하면 `unverified` 로 표기하고 금지 문구를 쓰지 않는다

### M1 — skill-forge

- [ ] `plugins/docs-forge/skills/skill-forge/SKILL.md` 생성, frontmatter 는 `name` + `description` 만
- [ ] `references/` 에 `frontmatter.md`, `writing-levers.md`, `structure.md`, `runtime-contract.md` 4종 존재, 디렉토리 깊이 1
- [ ] `scripts/measure-skills.mjs` 생성 — Node 18+ built-in 만, 런타임 의존성 0
- [ ] `measure-skills.mjs` 가 줄 수 / body 토큰 / description 길이 / 섹션 수 / references 깊이 / scripts 유무 / 프론트매터 키 인벤토리를 출력
- [ ] `skill-audit/SKILL.md`, `skill-fleet-review/SKILL.md` 생성
- [ ] 스킬 3종 본문에 `skill-creator` / `superpowers:` / `hermes-agent-skill-authoring` 을 읽으라는 지시가 없다 (grep 0건)
- [ ] 스킬 3종에 bare `${CLAUDE_PLUGIN_ROOT}` 가 없다 (resolver 블록 사용)
- [ ] 각 SKILL.md 300줄 이하
- [ ] 스킬 3종의 `description` 이 각각 1024자 이하이고 `: ` 를 포함하면 인용돼 있다
- [ ] `docs-forge` `plugin.json` MINOR 범프 + `marketplace.json` 해당 엔트리 + `metadata.version` 갱신
- [ ] `node scripts/sync-codex-manifests.mjs --check` 통과
- [ ] `node scripts/sync-hermes-manifests.mjs --check` 통과 (M0 결과가 어댑터 유효일 때)
- [ ] `node scripts/check-skill-tool-portability.mjs --check` 통과
- [ ] `node scripts/check-doc-consistency.mjs` 통과
- [ ] `node scripts/check-shell-portability.mjs` 통과
- [ ] `AGENTS.md` 와 `README.md` 의 `docs-forge` 설명이 새 스킬을 반영

### M2 — 자기검수

- [ ] 흡수된 스킬 전체에 `skill-audit` 실행, 결과를 `docs/audit/<date>-absorption-check.md` 로 기록
- [ ] 소멸한 플러그인을 가리키는 **live `plugin:skill` 참조 0건**. 이력·fixture 는 보존 대상이므로 0건 대상이 아니다. grep 이 surfacing 한 hit 전부를 live / 이력 으로 판정하고 그 근거를 감사 문서에 남긴다 (근거: `.llmwiki/wiki/llm-wiki-design/deleted-subject-not-stale.md`)
- [ ] `docs-forge` 전 스킬(M1 이후 11개)의 `description` 트리거 충돌 검토 완료. 겹치는 브랜치가 있으면 문구 조정
- [ ] 스킬 본문의 "이 플러그인" / 번들 경로 서술이 새 위치와 일치
- [ ] rename 판정을 skill-forge 의 포인터 원칙으로 수행하고 근거와 함께 기록한다. **rename 실행은 이 골의 범위가 아니므로 전부 보류로 남긴다** (PLAN 마일스톤 3 과 동일 계약)
- [ ] `docs-forge` 의 `{readme,changelog,moc,deploy-doc}-guide` 는 동명 커맨드와의 충돌 회피 명명이므로 rename 하지 않는다

### M3 — 가드

- [ ] `scripts/check-skill-contract.mjs` 생성 — Node 18+ built-in 만
- [ ] C3 의 5종 검사 구현, 위반 시 exit 1 + 위반 파일·사유 출력
- [ ] fixture 기반 자체 테스트 — 5종 각각 RED(위반 감지) / GREEN(정상 통과)
- [ ] `.githooks/pre-commit` 에 배선
- [ ] `.github/workflows/validate-codex.yml` 에 배선
- [ ] 현재 저장소 전 스킬에 대해 실행, 통과하거나 위반 목록을 보고
- [ ] 기존 가드 4종과 검사 항목이 중복되지 않음을 문서화

## 완료로 보지 않는 조건

- 가드가 통과했지만 fixture 테스트가 없다 — 회귀를 못 잡는다
- SKILL.md는 썼지만 `plugin.json` / `marketplace.json` 범프가 빠졌다 — 캐시로 게이트된 사용자에게 안 내려간다
- `--check` 가드 중 하나라도 실패한 상태로 남았다
- M0 의 unverified 3건을 확인 없이 단정해 `frontmatter.md` 에 금지 규칙으로 적었다
- skill-forge 본문이 외부 스킬을 읽으라고 지시한다 (C1 위반)

## Open questions

- `skill-forge` 를 다른 저장소에도 설치 가능한 범용 스킬로 낼지, 이 저장소 전용으로 둘지. `runtime-contract.md` 가 이 저장소 계약을 담고 있어 범용화하려면 분기 처리가 필요하다. M1 착수 시 결정.
- `skill-fleet-review` 의 팬아웃 축 7개를 한 번에 다 구현할지, M1 에서는 축 정의만 두고 실행은 후속 이슈로 미룰지.
