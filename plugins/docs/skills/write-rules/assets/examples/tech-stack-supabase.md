<!--
Adapted from: codefactory-co/golden-rabbit-antigravity-v1
Original path: 10/ecommerce/.agent/rules/tech-stack.md
Adaptation:
- frontmatter trigger: always_on → removed entirely (always-load)
  rationale: tool rules cross-cut code, no clear path boundary
- content compressed from ~180 to ~125 lines
- restructured into Role / Do / Don't / Source of Truth
License: see source repository
-->

# Tech Stack: Supabase + Tailwind + TypeScript

## Role

Operational rules for the cross-cutting tool layer — database client
(Supabase), styling system (Tailwind v4), type system (TypeScript),
package manager (npm). Always-load: these rules apply repo-wide
regardless of which file is being edited.

## Supabase

### Do

- **Supabase CLI 로 타입 자동 생성**: 생성된 `Database` 타입을
  제네릭으로 client 에 전달 → 완전한 타입 추론.
- **`@supabase/ssr` 사용** for Next.js: 쿠키 기반 세션 관리.
  Middleware / Server Actions / Server Components 에서 서버 사이드
  클라이언트 유틸리티 활용.
- **모든 테이블 RLS (Row Level Security) 활성화**.
- **Migration 은 `supabase/migrations/`**: 수정·삭제·신규 생성 시
  반드시 사용자 허가.

### Don't

- 클라이언트 사이드에서 `supabase-js` 직접 호출로 민감 작업 금지.
- Service Key 일반 비즈니스 로직 사용 금지. 관리자 작업에만 제한.
- DB 스키마 변경 후 타입 재생성 누락 금지 — `any` 폴백 회피.

## Tailwind CSS

### Do

- **Utility-First**: 가능한 한 Tailwind 유틸리티 클래스 사용.
- **조건부 스타일**: `clsx` / `tailwind-merge` 로 깔끔하게 처리.
- **디자인 토큰은 CSS 변수**: 색상·여백을 CSS 변수로 관리, Tailwind
  설정에서 참조.

### Don't

- `@apply` 과도 사용 금지 — 컴포넌트화로 재사용.
- 임의의 hex / rgb 값 직접 사용 금지 — 디자인 토큰 참조.

## TypeScript

### Do

- **`strict: true` 유지** (`tsconfig.json`).
- **Explicit Return Types** for utility / 주요 비즈니스 함수 —
  의도 명확화.
- **`unknown` + Type Guard** 으로 안전하게 타입 좁히기.
- **객체 형태 + 확장 필요** → `interface`. **유니온 / 튜플** → `type`.

### Don't

- `any` 사용 금지. 필요하면 `unknown` 후 좁히기.
- `// @ts-ignore` / `// @ts-expect-error` 무근거 사용 금지 —
  사용 시 한 줄 코멘트로 사유 첨부.

## Package Manager

### Do

- **npm 사용** (이 프로젝트 표준).
- **`package-lock.json` Git 포함** — 팀원 의존성 버전 일치 보장.

### Don't

- `yarn` / `pnpm` 으로 lock 파일 생성 금지 — `package-lock.json` 만.

## Source of Truth

- Supabase docs: https://supabase.com/docs
- Tailwind v4 docs: https://tailwindcss.com/docs
- Project ADRs: `docs/adr/`
