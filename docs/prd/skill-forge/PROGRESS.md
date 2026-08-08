# PROGRESS

## 골 검토 요약 (Step 8 자동 생성)

- 이슈: #199 (이 골) / 선행 조건 #198 (플러그인 정리, 수동)
- 목표: 자립 스킬 `skill-forge` 를 `docs-forge` 안에 만들고 3런타임 silent failure 5종을 차단하는 가드를 붙인다
- 마일스톤: 선행 확인 / skill-forge / 자기검수 / 가드
- 필수 검증: `sync-codex-manifests --check`, `sync-hermes-manifests --check`, `check-skill-tool-portability --check`, `check-doc-consistency`, `check-skill-contract`, `measure-skills`
- scope 잠금: 플러그인 흡수·rename 실행 금지(#198), `docs/audit/` 기존 파일 수정 금지, 전수 검토 착수 금지, 외부 마켓플레이스 스킬 참조 금지

---

## 현재 골

스킬을 쓰고·진단하고·전수 검토하는 자립 스킬 `skill-forge` 를 `docs-forge` 안에 만들고, 3런타임에서 조용히 깨지는 위반 5종을 차단하는 가드를 붙인다.

## 현재 마일스톤

마일스톤 1 시작 전

## 완료

(없음)

## 마지막 검증 결과

```text
(골 실행 전)
```

## 실패 시도

| 시도 | 변경 | 결과 | 배운 점 |
| --- | --- | --- | --- |

## 현재 가장 안정적인 상태

골 실행 전 — 초기 상태

## 다음 단계

PLAN.md의 마일스톤 1(선행 확인)부터 시작

## 리스크 / 블로커

- `skill-forge` 를 다른 저장소에도 설치 가능한 범용 스킬로 낼지, 이 저장소 전용으로 둘지 미정. `runtime-contract.md` 가 이 저장소 계약을 담고 있어 범용화하려면 분기 처리가 필요하다. 마일스톤 2 착수 시 결정.
- `skill-fleet-review` 의 팬아웃 축 7개를 한 번에 다 구현할지, 축 정의만 두고 실행은 후속 이슈로 미룰지 미정.
- 마일스톤 3 은 #198(흡수)의 완료를 전제한다. #198 이 안 끝났으면 마일스톤 3 에서 정지하고 사람의 결정을 기다린다.

## 인수인계 메모

이 PROGRESS.md는 골잡이가 생성했다. 골 실행 중 매 체크포인트마다 갱신된다.
