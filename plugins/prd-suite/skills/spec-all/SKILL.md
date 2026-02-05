---
name: spec-all
description: PRD, Tech Spec, Use Case, IA 전체 문서 순차 작성. "전체 스펙", "문서 세트", "spec-all" 등의 요청에 사용.
version: 1.0.0
disable-model-invocation: true
allowed-tools:
  - Read
  - Write
  - AskUserQuestion
  - Skill
  - mcp__plugin_interactive-review_interactive_review__start_review
---

# Spec-All 통합 워크플로우

PRD, Tech Spec, Use Case, IA 4개 문서를 순차적으로 작성합니다.

## 트리거 예시

- "전체 스펙 문서 작성해줘"
- "프로젝트 문서 세트 만들어줘"
- "spec-all"
- "PRD부터 IA까지 다 작성해줘"

## 워크플로우 개요

```
1. PRD 작성
   └─ interactive-review 검토
2. Tech Spec 작성 (PRD 기반)
   └─ interactive-review 검토
3. Use Case 작성 (PRD 기반)
   └─ interactive-review 검토
4. IA 작성 (PRD + Use Case 기반)
   └─ interactive-review 검토
5. 완료 요약
```

## 문서 간 역할 분담

각 문서는 명확히 구분된 영역을 담당합니다. 중복 작성을 피하세요.

| 문서 | 담당 영역 | 제외 영역 |
|------|----------|----------|
| PRD | 목표, 요구사항, 고수준 UX | 상세 흐름, 화면 구조, 기술 스택 |
| Use Case | 상세 사용자 흐름, 예외 처리 | 제품 목표, 화면 레이아웃, API 설계 |
| Tech Spec | 기술 스택, API, 구현 방식 | 제품 목표, Use Case 흐름, 화면 구조 |
| IA | 화면 구조, 네비게이션, 정보 계층 | 제품 목표, Use Case 흐름, 기술 스택 |

## 실행 방법

### Step 1: 프로젝트 정보 수집

AskUserQuestion으로 기본 정보 수집:
- 프로젝트 이름
- 프로젝트 한 줄 설명
- 전체 문서 모두 필요한지 확인

### Step 2: PRD 작성

`prd-suite:prd` 스킬의 워크플로우 실행:
1. 프로젝트 기본 정보 (일부는 Step 1에서 수집됨)
2. 요구사항 정의
3. 사용자 경험 설계
4. 범위 정의
5. interactive-review 검토
6. `docs/prd/{project}-prd.md` 저장

### Step 3: Tech Spec 작성

`prd-suite:tech-spec` 스킬의 워크플로우 실행:
1. PRD 파일 참조 (`docs/prd/{project}-prd.md`)
2. 기술 정보 수집
3. 8개 섹션 작성
4. interactive-review 검토
5. `docs/tech-spec/{project}-tech-spec.md` 저장

### Step 4: Use Case 작성

`prd-suite:usecase` 스킬의 워크플로우 실행:
1. PRD 파일 참조
2. 액터 정의
3. Use Case 도출
4. interactive-review 검토
5. `docs/usecase/{project}-usecase.md` 저장

### Step 5: IA 작성

`prd-suite:ia` 스킬의 워크플로우 실행:
1. PRD, Use Case 파일 참조
2. 사이트맵/앱 구조
3. 화면 목록
4. 네비게이션 설계
5. interactive-review 검토
6. `docs/ia/{project}-ia.md` 저장

### Step 6: 완료 요약

생성된 문서 목록과 위치 안내:

```
프로젝트 문서 생성 완료:

docs/
├── prd/
│   └── {project}-prd.md
├── tech-spec/
│   └── {project}-tech-spec.md
├── usecase/
│   └── {project}-usecase.md
└── ia/
    └── {project}-ia.md
```

## 중단/재개

각 문서 작성 완료 시점에서 중단 가능합니다.

AskUserQuestion으로 확인:
- "다음 문서(Tech Spec)로 진행할까요?"
- 옵션: 진행 / 나중에 계속 / 여기서 종료

재개 시:
- 이미 작성된 문서는 건너뜀
- 다음 단계부터 진행

## 출력 구조

```
docs/
├── prd/
│   └── {project-name}-prd.md
├── tech-spec/
│   └── {project-name}-tech-spec.md
├── usecase/
│   └── {project-name}-usecase.md
└── ia/
    └── {project-name}-ia.md
```

## 소요 시간 안내

전체 완료까지 상당한 대화가 필요합니다:
- PRD: 10-15분
- Tech Spec: 10-15분
- Use Case: 5-10분
- IA: 5-10분
- 총: 30-50분 (프로젝트 복잡도에 따라 다름)

## 주의사항

- 각 문서는 이전 문서를 참조하므로 순서대로 진행
- PRD가 가장 중요하므로 충분히 상세하게 작성
- 중간에 중단해도 작성된 문서는 저장됨
