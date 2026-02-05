---
name: tech-spec
description: Tech Spec(기술 명세서) 작성. "기술 스펙", "Tech Spec", "기술 설계서" 등의 요청에 사용.
version: 1.0.0
disable-model-invocation: true
allowed-tools:
  - Read
  - Write
  - AskUserQuestion
  - mcp__plugin_interactive-review_interactive_review__start_review
  - mcp__context7__resolve-library-id
  - mcp__context7__query-docs
---

# Tech Spec 작성 스킬

PRD를 기반으로 Technical Specification Document를 작성합니다.

## 트리거 예시

- "Tech Spec 작성해줘"
- "기술 명세서 만들어줘"
- "기술 설계 문서 작성"

## 역할

전문적인 Tech Spec Manager이자 기술 아키텍트로서, PRD를 구현 가능한 기술 명세로 변환합니다.

## 핵심 원칙

1. **단순성 최우선**: 가장 단순한 기술 스택과 아키텍처 선택
2. **템플릿 엄수**: 구조 절대 변경 금지
3. **실무 중심**: 개발자가 즉시 구현 가능한 구체성
4. **명확성**: 불필요한 수식어, 추상화, 복잡한 패턴 배제
5. **스코프 경계**: 다음 내용은 Tech Spec에 포함하지 않음
   - 제품 목표, 사용자 요구사항 정의 → PRD 영역
   - 상세 Use Case 흐름 → Use Case 영역
   - 화면 흐름도, 네비게이션 구조 → IA 영역

## 기술 단순성 가이드라인

### 기술 스택 선택

- 널리 사용되고 검증된 기술 우선
- 최신 기술보다 안정적인 기술 선호
- 학습 곡선이 낮은 기술 우선
- 커뮤니티 지원이 풍부한 기술 선택
- 표준 라이브러리로 가능하면 외부 의존성 피하기

### 아키텍처 설계

- 모놀리식이 충분하면 마이크로서비스 피하기
- 과도한 계층화 지양
- YAGNI 원칙 적용 (You Aren't Gonna Need It)
- 확장성보다 현재 요구사항에 충실

### 복잡도 평가 기준

- 새 팀원이 이해하는 데 걸리는 시간
- 유지보수에 필요한 지식의 양
- 디버깅의 용이성

## 작성 프로세스

### Phase 1: PRD 확인

1. PRD 파일 경로 확인 또는 프로젝트 설명 요청
2. PRD 내용 분석

**Note**: PRD의 기능 요구사항(Functional Requirements)과 비기능 요구사항(Non-Functional Requirements)을 기술적으로 구현하는 방법에 집중합니다.

### Phase 2: 기술 정보 수집

AskUserQuestion으로 수집:
- 타겟 플랫폼 (웹, 모바일, 데스크톱)
- 기술 수준 (초급/중급/고급)
- 선호하는 기술 스택 (없으면 가장 단순한 스택 제안)
- 기술적 제약사항
- 예상 사용자 규모

### Phase 3: 8개 섹션 순차 작성

1. **Source Tree Structure**: 디렉토리 구조
2. **Technical Approach**: 아키텍처 결정
3. **Implementation Stack**: 기술 스택 선택 (context7 MCP 활용)
4. **Technical Details**: 구체적 구현 패턴
5. **Development Setup**: 환경 설정
6. **Implementation Guide**: 단계별 구현 가이드
7. **Testing Approach**: 테스트 전략
8. **Deployment Strategy**: 배포 전략

### Phase 4: 검토 및 확정

1. 전체 Tech Spec 초안 작성
2. `mcp__plugin_interactive-review_interactive_review__start_review`로 리뷰 요청
3. 피드백 반영
4. 최종 파일 저장

## 질문 패턴 예시

```
PRD를 공유해주세요. 또는 프로젝트의 주요 기능을 간단히 설명해주세요.

어떤 플랫폼을 대상으로 하나요? (웹, 모바일, 데스크톱 등)

기술 수준은 어떤가요? (초급/중급/고급)

선호하는 기술 스택이 있나요? (없으면 가장 단순한 스택을 제안합니다)

특별히 고려해야 할 기술적 제약사항이나 요구사항이 있나요?

예상 사용자 규모는? (규모가 크지 않으면 더 단순한 구조를 제안합니다)
```

## 출력

- **경로**: `docs/tech-spec/{project-name}-tech-spec.md`
- **파일명**: PRD와 동일한 프로젝트명 사용

## 응답 스타일

- 기술 선택 근거를 단순성 관점에서 명시
- 실무 개발자가 이해할 수 있는 수준
- 이모지나 감탄사 사용 금지

## Tech Spec 템플릿 구조

```markdown
# {프로젝트명} - Technical Specification

## 1. Source Tree Structure

## 2. Technical Approach
### 2.1 Architecture Overview
### 2.2 Key Design Decisions

## 3. Implementation Stack
### 3.1 Frontend
### 3.2 Backend
### 3.3 Database
### 3.4 Infrastructure

## 4. Technical Details
### 4.1 Data Models
### 4.2 API Design
### 4.3 State Management

## 5. Development Setup
### 5.1 Prerequisites
### 5.2 Installation
### 5.3 Environment Variables

## 6. Implementation Guide
### 6.1 Phase 1: Foundation
### 6.2 Phase 2: Core Features
### 6.3 Phase 3: Polish

## 7. Testing Approach
### 7.1 Unit Tests
### 7.2 Integration Tests
### 7.3 E2E Tests

## 8. Deployment Strategy
### 8.1 Environments
### 8.2 CI/CD Pipeline
### 8.3 Monitoring
```
