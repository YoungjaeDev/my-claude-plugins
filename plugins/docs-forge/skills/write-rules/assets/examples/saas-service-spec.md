<!--
Adapted from: codefactory-co/golden-rabbit-antigravity-v1
Original path: 11/saas/.agent/rules/service.md
Adaptation:
- frontmatter trigger: always_on → removed entirely (always-load)
  rationale: product/service context applies repo-wide
- content compressed from ~180 to ~140 lines
- preserved PRD-rules hybrid character (overview + tiers + UX flow +
  inferred data models all in one file)
License: see source repository
-->

# Service Spec: CloudNote (example)

## Role

Hybrid PRD-rules document — service identity, target users, pricing
tiers, UX flow, and inferred data model entities in one always-load
file. This is the kind of "rule" file that Korean dev teams often
want: not strictly coding conventions, but indispensable product
context that shapes every implementation decision.

Use this style when the project is product/service-oriented and the
absence of this context would make many code decisions ambiguous
(e.g., "should this feature be Pro-only?" / "what fields does User
have?").

## Service Overview

**CloudNote** is an intelligent cloud-based memo service that
securely stores user notes and uses AI to organize and summarize them.
Targets individual users to enterprise teams; provides seamless UX
across web and mobile.

## Target Audience

- **개인 사용자 (Free)**: 간단한 메모 작성·저장이 필요한 일반 사용자.
- **파워 유저 (Pro / Professional)**: 많은 메모를 관리하고 고급 AI
  기능과 대용량 저장공간이 필요한 전문가.
- **기업·팀 (Enterprise)**: 협업·보안·통합 관리가 필요한 조직.

## Pricing Tiers

| 기능 | Free | Pro (월 9,900원) | Enterprise (월 29,900원) |
|---|---|---|---|
| 메모 수 | 100개 | 무제한 | 무제한 |
| 저장 공간 | 1GB | 10GB | 무제한 |
| AI 기능 | 기본 요약 | 고급 요약 + 검색 | 고급 기능 전체 |
| 동기화 | 기기 1대 | 모든 기기 실시간 | 모든 기기 |
| 협업 | — | 팀 공유 | 고급 협업 + SSO |

## Core Features

### 핵심 기능

- **클라우드 동기화**: 모든 기기 (Web / Mobile / Tablet) 실시간 동기화.
- **AI 인텔리전스**: 자동 요약 + 스마트 검색 (문맥 이해).
- **체계적 관리**: 폴더 / 태그 / 프로젝트 단위 정리.

### 결제 프로세스

- 주문 요약: 플랜 + 주기 + 총액 (부가세 포함) 명확 제시.
- 결제 수단: 신용카드 / 카카오페이 / 네이버페이 / 토스페이.
- 약관 동의: 구매 조건 + 개인정보 처리방침.
- 환불 정책: 7일 이내 미사용 시 전액 환불 안내.

## UX Flow

### 1. 랜딩 / 온보딩

- 가치 제안 + 기능 소개 + 요금제 비교로 가입 유도.
- 이메일·비밀번호 + 소셜 (Google / Kakao) 로그인.

### 2. 대시보드 (로그인 후 첫 화면)

- **사용자 환영**: 이름 + 플랜 (Pro Flag) 표시.
- **구독 현황 카드**: 플랜·상태 / 다음 결제일 / 결제 수단 / 플랜 변경.
- **사용량 모니터링**: 메모 수 / 저장 공간 / AI 요약 횟수 progress bar.
- **최근 활동 피드**: 메모 작성·요약·공유·로그인 시간순.

### 3. 구독·결제

- 플랜 선택 → 주문 요약 → 결제 수단 → 약관 동의 → 결제 완료 →
  영수증.

## Inferred Data Models

Primary entities and fields implied by the design:

- **User**: `id`, `name`, `email`, `profileImage`, `authProvider`
  (`Google` / `Kakao` / `Email`), `currentPlanId` (→ Plan)
- **Plan**: `id`, `name` (`Free` / `Pro` / `Enterprise`), `price`,
  `currency`, `limits` (JSON: `{ storage, noteCount, aiSummaries }`)
- **Subscription**: `id`, `userId`, `planId`, `status`
  (`Active` / `Canceled` / `Expired`), `startDate`, `nextBillingDate`,
  `paymentMethod`
- **Usage**: `userId`, `storageUsed`, `noteCount`, `aiSummaryCount`,
  `lastUpdated`
- **ActivityLog**: `id`, `userId`, `type`
  (`CREATE_NOTE` / `USE_AI` / `SHARE` / `LOGIN`), `description`,
  `metadata`, `createdAt`
- **Payment**: `id`, `orderNumber`, `userId`, `amount`, `status`,
  `method`, `approvedAt`

## Design System Anchor

- **Primary Color**: Blue `#137fec` (신뢰 + 클라우드 + 인텔리전스 상징)
- 추가 토큰 / 폰트 / 컴포넌트 라이브러리는 `docs/design-system.md` 참조.

## Source of Truth

- 디자인 시안: 별도 Figma 링크 (프로젝트별 작성)
- 결제 약관·환불 정책: `docs/policy/`
- 데이터 모델 ERD: `docs/architecture/data-model.md`
