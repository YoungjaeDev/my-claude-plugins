# PLAN — skill-forge

## 목표

스킬을 쓰고·진단하고·전수 검토하는 자립 스킬 `skill-forge` 를 `docs-forge` 안에 만들고, 3런타임에서 조용히 깨지는 위반 5종을 커밋 시점에 차단하는 가드를 붙인다.

## 참조 문서

- PRD.md (`docs/prd/skill-forge/01_PRD.md`)
- VALIDATION.md
- RECOVERY.md
- 전체 결정 근거: `.claude/spec/2026-08-05-skill-forge-and-singleton-absorption.md`

## 마일스톤 1: 선행 확인

- 범위(Scope): 스펙에 `unverified` 로 남은 3건을 근거와 함께 확정한다. Hermes 어댑터 생존 여부, 스킬 프론트매터에서 `argument-hint` 인식 여부, `disable-model-invocation` 동작 여부.
- 완료 조건: 3건 각각에 대해 확인됨 또는 확인 불가가 근거와 함께 기록되고, 그 결과가 `references/frontmatter.md` 초안에 반영된다. 확인 못 한 항목은 `unverified` 로 표기하고 금지 문구로 쓰지 않는다.
- 검증: `docs/prd/skill-forge/PROGRESS.md` 에 3건의 판정과 근거(파일·라인 또는 실행 결과)가 기록됨.

## 마일스톤 2: skill-forge

- 범위(Scope): `plugins/docs-forge/skills/` 아래 스킬 3종(`skill-forge`, `skill-audit`, `skill-fleet-review`), references 4종(`frontmatter`, `writing-levers`, `structure`, `runtime-contract`), `scripts/measure-skills.mjs` 를 만든다. `docs-forge` 버전 범프와 매니페스트 재생성, `AGENTS.md` / `README.md` 갱신까지 포함한다.
- 완료 조건: PRD 의 M1 acceptance 15건이 전부 통과한다. 특히 외부 마켓플레이스 스킬 참조 0건, bare `${CLAUDE_PLUGIN_ROOT}` 0건, 각 SKILL.md 300줄 이하.
- 검증: VALIDATION.md의 필수 검증 6종 + M1 마일스톤별 검증.

## 마일스톤 3: 자기검수

- 범위(Scope): #198 이 수행하고 PR #200 (`c56bd25`) 으로 머지된 흡수 결과를 `skill-audit` 으로 진단한다. 참조 정합성, 트리거 충돌, 경로 서술, rename 판정. 판정만 하고 흡수 자체는 건드리지 않는다.
- 완료 조건: PRD 의 M2 acceptance 6건 통과. `docs/audit/<date>-absorption-check.md` 에 진단 결과와 rename 적용분·보류분이 근거와 함께 남는다.
- 검증: 소멸한 플러그인을 가리키는 **live** 참조 0건 (grep hit 를 live / 이력 으로 판정) + 수동 검토 절차 3.

## 마일스톤 4: 가드

- 범위(Scope): `scripts/check-skill-contract.mjs` 를 만들어 위반 5종을 차단하고, fixture 기반 RED/GREEN 테스트와 pre-commit / CI 배선을 붙인다.
- 완료 조건: PRD 의 M3 acceptance 7건 통과. 현재 저장소 전 스킬에 대해 실행해 통과하거나 위반 목록을 보고한다.
- 검증: `node scripts/check-skill-contract.mjs` + fixture 테스트 + 배선 grep.

## 최종 완료 기준

- [ ] 모든 마일스톤 완료
- [ ] VALIDATION.md의 모든 검증 통과
- [ ] scope 위반 없음
- [ ] PROGRESS.md 업데이트
