# {프로젝트명} - Use Case Document

---

## 1. Overview

### 1.1 Purpose

{이 문서의 목적}

### 1.2 Scope

{Use Case가 다루는 범위}

### 1.3 Definitions

| Term | Definition |
|------|------------|
| {용어 1} | {정의} |
| {용어 2} | {정의} |

---

## 2. Actors

### 2.1 Primary Actors

| Actor | Description | Goals |
|-------|-------------|-------|
| {액터 1} | {설명} | {주요 목표} |
| {액터 2} | {설명} | {주요 목표} |

### 2.2 Secondary Actors

| Actor | Description | Interaction |
|-------|-------------|-------------|
| {액터} | {설명} | {시스템과의 상호작용} |

### 2.3 System Actors

| Actor | Description |
|-------|-------------|
| {외부 시스템} | {설명} |

---

## 3. Use Case List

| ID | Use Case | Primary Actor | Priority | Status |
|----|----------|---------------|----------|--------|
| UC-001 | {Use Case 이름} | {액터} | P0 | Draft |
| UC-002 | {Use Case 이름} | {액터} | P0 | Draft |
| UC-003 | {Use Case 이름} | {액터} | P1 | Draft |

---

## 4. Use Case Details

### UC-001: {Use Case 이름}

**Actor**: {Primary Actor}

**Goal**: {사용자가 달성하고자 하는 목표}

**Trigger**: {Use Case가 시작되는 조건}

**Preconditions**:
- {선행 조건 1}
- {선행 조건 2}

**Basic Flow (Happy Path)**:

| Step | Actor | System |
|------|-------|--------|
| 1 | {액터 행동} | |
| 2 | | {시스템 응답} |
| 3 | {액터 행동} | |
| 4 | | {시스템 응답} |

**Alternative Flows**:

**AF-1: {대안 흐름 이름}**
- Trigger: {이 흐름이 발생하는 조건}
- Steps:
  1. {단계}
  2. {단계}
- Resume: Step {N} of Basic Flow

**Exception Flows**:

**EF-1: {예외 상황}**
- Trigger: {예외 발생 조건}
- Steps:
  1. 시스템이 에러 메시지를 표시한다
  2. {복구 단계}
- Result: {결과}

**Postconditions**:
- **Success**: {성공 시 상태}
- **Failure**: {실패 시 상태}

**Business Rules**:
- BR-001: {비즈니스 규칙}

**Notes**:
- {추가 참고사항}

---

### UC-002: {Use Case 이름}

**Actor**: {Primary Actor}

**Goal**: {목표}

**Trigger**: {트리거}

**Preconditions**:
- {선행 조건}

**Basic Flow**:

| Step | Actor | System |
|------|-------|--------|
| 1 | {액터 행동} | |
| 2 | | {시스템 응답} |

**Postconditions**:
- **Success**: {성공 시 상태}

---

## 5. Use Case Diagram

```
+------------------+
|     System       |
|                  |
|  +------------+  |        +--------+
|  | UC-001     |<-|--------|  User  |
|  +------------+  |        +--------+
|        |         |
|        v         |
|  +------------+  |
|  | UC-002     |  |
|  +------------+  |
|                  |
+------------------+
```

---

## 6. Traceability Matrix

| Use Case | PRD Requirements | Epic | Priority |
|----------|------------------|------|----------|
| UC-001 | FR-001, FR-002 | Epic 1 | P0 |
| UC-002 | FR-003 | Epic 1 | P0 |
| UC-003 | FR-004, FR-005 | Epic 2 | P1 |

---

## Document Info

| Item | Value |
|------|-------|
| Version | 1.0 |
| Created | {YYYY-MM-DD} |
| Last Updated | {YYYY-MM-DD} |
| Author | {작성자} |
| Related PRD | {PRD 파일 경로} |
