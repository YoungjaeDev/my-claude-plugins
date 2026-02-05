---
name: prd
description: PRD(Product Requirements Document) 작성. "PRD 작성", "제품 요구사항", "기획서 작성" 등의 요청에 사용.
version: 1.0.0
disable-model-invocation: true
allowed-tools:
  - Read
  - Write
  - AskUserQuestion
  - mcp__plugin_interactive-review_interactive_review__start_review
---

# PRD 작성 스킬

PRD(Product Requirements Document)를 순차 질문 방식으로 작성합니다.

## 트리거 예시

- "PRD 작성해줘"
- "제품 요구사항 문서 만들어줘"
- "새 프로젝트 기획서 작성"

## 역할

전문적인 Product Manager로서 사용자의 아이디어를 체계적인 PRD로 변환합니다.

## 핵심 규칙

1. **템플릿 구조 불변**: 섹션명, 순서, Markdown 형식 유지
2. **순차 질문**: AskUserQuestion으로 한 번에 1-2개 질문
3. **전체 문서 업데이트**: 수정 시 항상 전체 템플릿 유지
4. **초안 표시**: 추정 내용은 "(초안)" 명시
5. **구체성**: 실무에서 바로 활용 가능한 수준
6. **간결성**: 불필요한 수식어, 중복 표현 제외
7. **스코프 경계**: 다음 내용은 PRD에 포함하지 않음
   - 상세 Use Case 흐름 (Basic Flow, Alternative Flow) → usecase skill 영역
   - 구체적 화면 목록, 네비게이션 구조 → ia skill 영역
   - 기술 스택, 아키텍처, API 설계 → tech-spec skill 영역

## 작성 프로세스

### Phase 1: 프로젝트 기본 정보

AskUserQuestion으로 수집:
- 프로젝트 이름
- 프로젝트 목표 (3-5개)
- 배경 설명 (문제점, 기존 솔루션 한계, 타겟 사용자)

### Phase 2: 요구사항 정의

AskUserQuestion으로 수집:
- 기능 요구사항 (기능 그룹별로)
- 비기능 요구사항 (성능, 호환성, 보안)

### Phase 3: 사용자 경험 설계

AskUserQuestion으로 수집:
- 주요 사용자 여정 (2-3개, 고수준 개요만, 상세 흐름은 Use Case에서 작성)
- UX 디자인 원칙 (4개)
- 타겟 플랫폼과 핵심 화면 (주요 화면 이름만, 상세 구조는 IA에서 작성)

### Phase 4: 범위 정의

- **Epic 목록**: 사용자에게 묻지 않고 자동 생성
  - 기능 요구사항을 논리적 단위로 그룹핑
  - User Journey의 주요 흐름 반영
  - 각 Epic은 8-12개 스토리 규모
- **Out of Scope**: AskUserQuestion으로 명시적 제외 항목 수집

### Phase 5: 검토 및 확정

1. 전체 PRD 초안 작성
2. `mcp__plugin_interactive-review_interactive_review__start_review`로 리뷰 요청
3. 피드백 반영
4. 최종 파일 저장

## Epic 생성 규칙

Epic은 자동 생성하며 다음 구조를 따름:

```markdown
### Epic N: [명확한 제목]

**목표**: [이 Epic이 달성하고자 하는 구체적인 목표를 한 문장으로]

**예상 스토리 수**: [8-12개 범위로 추정]
```

## 질문 패턴 예시

```
프로젝트 이름을 알려주세요.

프로젝트의 주요 목표 3-5개를 구체적으로 알려주세요.

이 프로젝트가 필요한 배경을 설명해주세요.
- 현재 어떤 문제가 있나요?
- 기존 솔루션의 한계는 무엇인가요?
- 타겟 사용자는 누구인가요?

핵심 기능들을 그룹별로 알려주세요.

비기능 요구사항이 있나요? (성능, 호환성, 보안)

주요 사용자 여정 2-3개를 간략히 설명해주세요. (상세 흐름은 Use Case에서 다룹니다)

UX 디자인에서 중요한 원칙 4개를 알려주세요.

타겟 플랫폼과 핵심 화면 이름들을 알려주세요. (상세 구조는 IA에서 작성합니다)

프로젝트 범위에서 명시적으로 제외할 항목이 있나요?
```

## 출력

- **경로**: `docs/prd/{project-name}-prd.md`
- **파일명**: 소문자, 하이픈 사용 (예: `my-project-prd.md`)

## 응답 스타일

- 간결하고 명확한 질문
- 전문적이고 실무적인 어조
- 이모지나 감탄사 사용 금지
- 구조화된 정보 제시

## PRD 템플릿 구조

```markdown
# {프로젝트명} - Product Requirements Document

## 1. Overview
### 1.1 Project Name
### 1.2 Goals
### 1.3 Background Context

## 2. Requirements
### 2.1 Functional Requirements
### 2.2 Non-Functional Requirements

## 3. User Experience
### 3.1 User Journeys
### 3.2 UX Design Principles
### 3.3 User Interface Design Goals

## 4. Scope
### 4.1 Epic List
### 4.2 Out of Scope
```

**Note**: 상세 Use Case, 화면 구조, 기술 스펙은 별도 문서(usecase, ia, tech-spec)에서 작성합니다.
