---
name: usecase
description: Use Case(유스케이스) 문서 작성. "유스케이스", "사용자 시나리오", "Use Case" 등의 요청에 사용.
version: 1.0.0
disable-model-invocation: true
allowed-tools:
  - Read
  - Write
  - AskUserQuestion
  - mcp__plugin_interactive-review_interactive_review__start_review
---

# Use Case 작성 스킬

사용자 시나리오와 유스케이스를 체계적으로 문서화합니다.

## 트리거 예시

- "Use Case 작성해줘"
- "유스케이스 문서 만들어줘"
- "사용자 시나리오 정리"

## 역할

UX 분석가로서 PRD의 사용자 여정을 구체적인 Use Case로 확장합니다.

## 핵심 규칙

1. **PRD 기반**: 기존 PRD의 User Journey를 확장
2. **액터 중심**: 각 사용자 유형별 시나리오 정의
3. **구체성**: 단계별 상호작용 명확히 기술
4. **예외 흐름**: 정상 흐름과 예외 상황 모두 포함
5. **스코프 경계**: 다음 내용은 Use Case에 포함하지 않음
   - 고수준 제품 목표, 배경 → PRD 영역
   - 화면 레이아웃, 네비게이션 구조 → IA 영역
   - 기술 구현 방식, API 설계 → Tech Spec 영역

## 작성 프로세스

### Phase 1: 기반 정보 확인

1. PRD 파일 확인 (있으면 User Journey 섹션 참조)
2. 없으면 AskUserQuestion으로 기본 정보 수집:
   - 프로젝트 개요
   - 주요 사용자 유형
   - 핵심 기능

**Note**: PRD가 있는 경우 User Journey를 참조하여 확장하되, PRD의 고수준 여정을 구체적인 Use Case 흐름으로 상세화합니다.

### Phase 2: 액터 정의

AskUserQuestion으로 수집:
- 주요 액터 목록 (사용자 유형)
- 각 액터의 역할과 목표
- 시스템 액터 (외부 서비스 등)

### Phase 3: Use Case 도출

각 액터별로 AskUserQuestion으로 수집:
- 주요 Use Case 목록
- 각 Use Case의 목표
- 선행 조건
- 기본 흐름 (Happy Path)
- 대안 흐름 (Alternative Flow)
- 예외 흐름 (Exception Flow)
- 후행 조건

### Phase 4: 검토 및 확정

1. 전체 Use Case 문서 초안 작성
2. `mcp__plugin_interactive-review_interactive_review__start_review`로 리뷰 요청
3. 피드백 반영
4. 최종 파일 저장

## 질문 패턴 예시

```
PRD가 있나요? 있다면 경로를 알려주세요.

이 시스템의 주요 사용자 유형(액터)은 누구인가요?
예: 일반 사용자, 관리자, 외부 시스템 등

[액터명]이 이 시스템에서 수행하는 주요 작업은 무엇인가요?

[Use Case명]의 기본 흐름을 단계별로 설명해주세요.
1. 사용자가 ...
2. 시스템이 ...

이 과정에서 발생할 수 있는 예외 상황은 무엇인가요?
```

## 출력

- **경로**: `docs/usecase/{project-name}-usecase.md`
- **파일명**: PRD와 동일한 프로젝트명 사용

## Use Case 템플릿 구조

```markdown
# {프로젝트명} - Use Case Document

## 1. Overview
### 1.1 Purpose
### 1.2 Scope
### 1.3 Definitions

## 2. Actors
### 2.1 Primary Actors
### 2.2 Secondary Actors
### 2.3 System Actors

## 3. Use Case List
| ID | Use Case | Actor | Priority |
|----|----------|-------|----------|

## 4. Use Case Details

### UC-001: {Use Case 이름}

**Actor**: {액터}

**Goal**: {목표}

**Preconditions**:
- {선행 조건 1}
- {선행 조건 2}

**Basic Flow**:
1. {단계 1}
2. {단계 2}
3. {단계 3}

**Alternative Flows**:
- **AF-1**: {대안 흐름 설명}
  1. {단계}

**Exception Flows**:
- **EF-1**: {예외 상황}
  1. {처리 방법}

**Postconditions**:
- {후행 조건}

**Business Rules**:
- {관련 비즈니스 규칙}

---

### UC-002: ...

## 5. Use Case Diagram
(Mermaid 또는 텍스트 기반 다이어그램)

## 6. Traceability Matrix
| Use Case | PRD Requirement | Epic |
|----------|-----------------|------|
```
