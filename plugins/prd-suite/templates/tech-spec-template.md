# {프로젝트명} - Technical Specification

---

## 1. Source Tree Structure

```
{project-name}/
├── src/
│   ├── components/
│   ├── pages/
│   ├── utils/
│   └── index.ts
├── tests/
├── public/
├── package.json
└── README.md
```

---

## 2. Technical Approach

### 2.1 Architecture Overview

{아키텍처 개요 설명}

```
[Client] --> [API] --> [Database]
```

### 2.2 Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Architecture | {선택} | {단순성 관점 근거} |
| State Management | {선택} | {단순성 관점 근거} |
| API Style | {선택} | {단순성 관점 근거} |

---

## 3. Implementation Stack

### 3.1 Frontend

| Category | Technology | Version | Reason |
|----------|------------|---------|--------|
| Framework | {예: React} | {버전} | {선택 이유} |
| Styling | {예: Tailwind} | {버전} | {선택 이유} |
| Build Tool | {예: Vite} | {버전} | {선택 이유} |

### 3.2 Backend

| Category | Technology | Version | Reason |
|----------|------------|---------|--------|
| Runtime | {예: Node.js} | {버전} | {선택 이유} |
| Framework | {예: Express} | {버전} | {선택 이유} |

### 3.3 Database

| Category | Technology | Reason |
|----------|------------|--------|
| Primary DB | {예: PostgreSQL} | {선택 이유} |
| Cache | {예: Redis} | {선택 이유} |

### 3.4 Infrastructure

| Category | Service | Reason |
|----------|---------|--------|
| Hosting | {예: Vercel} | {선택 이유} |
| CI/CD | {예: GitHub Actions} | {선택 이유} |

---

## 4. Technical Details

### 4.1 Data Models

```typescript
// User
interface User {
  id: string;
  email: string;
  name: string;
  createdAt: Date;
}

// {Other Models}
```

### 4.2 API Design

| Endpoint | Method | Purpose |
|----------|--------|---------|
| /api/users | GET | 사용자 목록 조회 |
| /api/users/:id | GET | 사용자 상세 조회 |
| /api/users | POST | 사용자 생성 |

### 4.3 State Management

{상태 관리 전략 설명}

---

## 5. Development Setup

### 5.1 Prerequisites

- Node.js >= {버전}
- {기타 필수 도구}

### 5.2 Installation

```bash
# Clone repository
git clone {repo-url}
cd {project-name}

# Install dependencies
npm install

# Start development server
npm run dev
```

### 5.3 Environment Variables

```env
# Required
DATABASE_URL=
API_KEY=

# Optional
DEBUG=false
```

---

## 6. Implementation Guide

### 6.1 Phase 1: Foundation

1. 프로젝트 초기 설정
2. 기본 라우팅 구성
3. 데이터베이스 연결
4. 인증 기반 구축

### 6.2 Phase 2: Core Features

1. {핵심 기능 1} 구현
2. {핵심 기능 2} 구현
3. {핵심 기능 3} 구현

### 6.3 Phase 3: Polish

1. 에러 처리 강화
2. 성능 최적화
3. UI/UX 개선

---

## 7. Testing Approach

### 7.1 Unit Tests

- Framework: {예: Jest}
- Coverage Target: 80%
- Focus: Utility functions, Business logic

### 7.2 Integration Tests

- Framework: {예: Jest + Supertest}
- Focus: API endpoints, Database operations

### 7.3 E2E Tests

- Framework: {예: Playwright}
- Focus: Critical user flows

---

## 8. Deployment Strategy

### 8.1 Environments

| Environment | URL | Purpose |
|-------------|-----|---------|
| Development | localhost:3000 | 로컬 개발 |
| Staging | staging.example.com | QA 테스트 |
| Production | example.com | 실서비스 |

### 8.2 CI/CD Pipeline

```
Push → Lint → Test → Build → Deploy
```

### 8.3 Monitoring

- Error Tracking: {예: Sentry}
- Analytics: {예: Google Analytics}
- Logs: {예: CloudWatch}

---

## Document Info

| Item | Value |
|------|-------|
| Version | 1.0 |
| Created | {YYYY-MM-DD} |
| Last Updated | {YYYY-MM-DD} |
| Author | {작성자} |
| Related PRD | {PRD 파일 경로} |
