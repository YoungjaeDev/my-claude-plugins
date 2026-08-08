<!--
Adapted from: codefactory-co/golden-rabbit-antigravity-v1
Original path: 10/ecommerce/.agent/rules/nextjs-framework.md
Adaptation:
- frontmatter trigger: always_on → paths: scoped to app/components routes
- content compressed from ~200 to ~120 lines
- restructured into Role / Do / Don't / Examples / Source of Truth
License: see source repository
-->
---
paths:
  - "src/app/**/*.{ts,tsx}"
  - "src/components/**/*.{ts,tsx}"
---

# Next.js Framework Conventions

## Role

Codifies how to use Next.js App Router in this project — rendering
strategy, data fetching, Server Actions, performance defaults, and
metadata. Anchors decisions that affect bundle size, first-paint
latency, and SEO.

## Do

- **Server Component first**: 모든 컴포넌트는 기본적으로 Server
  Component. Client Component (`'use client'`) 는 상호작용
  (onClick / onChange), 브라우저 API (window / localStorage),
  React Hook (useState / useEffect) 이 꼭 필요한 경우에만.
- **Client Component 는 Leaf 로 격리**: 전체 페이지 `'use client'`
  금지. 상호작용 부분만 별도 컴포넌트로 분리.
- **Server Actions 로 mutation**: API Routes 대신 Server Actions
  사용. 폼은 `action` prop 활용.
- **데이터 패칭은 Server Component 에서**: `useEffect + fetch` 의
  클라이언트 패칭 지양. 초기 데이터는 서버에서 주입.
- **early return 으로 indent 줄이기**: 한 파일이 300줄 넘어가면
  서브 컴포넌트 / 훅 / 유틸 분리.
- **Metadata API 사용**: `<head>` 직접 수정 금지. 정적은
  `export const metadata`, 동적은 `generateMetadata`.

## Don't

- 전체 `Navbar` 를 `'use client'` 로 만들지 말 것 — `LoginButton`
  같은 leaf 만.
- 일반 `<img>` 태그 사용 금지 — `next/image` 사용 (Lazy Loading,
  Resizing 자동).
- 폰트 직접 link 태그 금지 — `next/font` 사용 (CLS 방지).
- 한 파일에 여러 메인 컴포넌트 작성 금지. 컴포넌트당 한 파일.
- Server Component 안에서 `useState` / `useEffect` 사용하려 하지
  말 것 — 컴파일 에러 발생 신호.

## Examples

### Isolated Client Component

```tsx
// app/_components/login-button.tsx
'use client';

import { useState } from 'react';

export function LoginButton() {
  const [pending, setPending] = useState(false);
  return <button disabled={pending}>Login</button>;
}
```

```tsx
// app/page.tsx — Server Component (default)
import { LoginButton } from './_components/login-button';

export default async function Page() {
  const user = await fetchCurrentUser();  // server-side
  return (
    <main>
      <h1>{user.name}</h1>
      <LoginButton />
    </main>
  );
}
```

### Server Action (mutation)

```tsx
// app/posts/actions.ts
'use server';

export async function createPost(formData: FormData) {
  // ... composition root assembly ...
  return { ok: true };
}

// app/posts/new/page.tsx
import { createPost } from '../actions';

export default function NewPost() {
  return <form action={createPost}>...</form>;
}
```

### Dynamic Metadata

```tsx
// app/posts/[id]/page.tsx
export async function generateMetadata({ params }) {
  const post = await fetchPost(params.id);
  return { title: post.title, description: post.excerpt };
}
```

## Source of Truth

- Next.js docs: https://nextjs.org/docs/app
- Project decision record: `docs/architecture/rendering.md`
