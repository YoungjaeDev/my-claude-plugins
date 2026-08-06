<!--
Adapted from: codefactory-co/golden-rabbit-antigravity-v1
Original path: 10/ecommerce/.agent/rules/architecture.md
Adaptation:
- frontmatter trigger: always_on → paths: scoped to core layers
- content compressed from ~250 to ~140 lines
- restructured into Role / Do / Don't / Examples / Source of Truth
License: see source repository
-->
---
paths:
  - "src/core/**/*.ts"
  - "src/infrastructure/**/*.ts"
  - "src/app/actions.ts"
  - "src/app/**/actions.ts"
---

# Clean Architecture for Next.js App Router

## Role

Defines layering invariants, dependency direction, and Composition
Root location for projects following Clean Architecture with Next.js
App Router. Keeps business logic isolated from framework, database,
and UI so each can change independently.

## Layer Map

```
src/
├── core/                          # 내부 계층 (의존성 없음)
│   ├── domain/
│   │   ├── entities/              # User, Post, Order (순수 TS)
│   │   └── errors/                # DomainError 계층
│   └── application/
│       ├── use-cases/             # CreatePost, Login (execute())
│       ├── interfaces/            # Repository / Service ports
│       └── dtos/                  # 계층 간 데이터 모델
├── infrastructure/                # 외부 계층 (Adapters)
│   ├── repositories/              # SupabaseUserRepository 등
│   ├── services/                  # EmailService 등
│   └── config/                    # 환경 변수
├── app/                           # Presentation
│   ├── (routes)/
│   ├── _components/
│   ├── api/
│   └── actions.ts                 # ★ Composition Root
└── components/                    # 공용 UI (Design System)
```

## Do

- **의존성은 안쪽으로만**: Domain ← Application ← Infrastructure / Presentation.
- **Repository 는 Application 에서 interface 정의만, Infrastructure 에서 구현**
  (Dependency Inversion).
- **유스케이스는 `execute()` 단일 메서드 클래스**로 구현.
- **입출력은 DTO 사용** — domain entity 가 외부 경계 넘지 않게.
- **Composition Root 는 `src/app/actions.ts`** (또는 도메인별 `actions.ts`).
  모든 DI 조립이 여기서 일어남.
- **Domain entity 에 비즈니스 메서드 캡슐화** — anemic model 회피.

## Don't

- Domain layer 에서 외부 라이브러리 import 금지 (Next.js / Supabase /
  Prisma / Axios 등). 순수 TypeScript 만.
- Application layer 에서 Repository **구현체** import 금지 — interface 만.
- Presentation 컴포넌트 내부에 비즈니스 로직 작성 금지. UI 는
  데이터를 보여주는 역할만.
- 한 파일에서 Repository 인스턴스 `new` 직접 호출 금지. 항상 DI
  통해 주입.

## Examples

### Use Case (Application Layer)

```typescript
// src/core/application/use-cases/create-post.ts
import { PostRepository } from '../interfaces/post-repository';
import { CreatePostInput, CreatePostOutput } from '../dtos/post';

export class CreatePostUseCase {
  constructor(private readonly postRepo: PostRepository) {}

  async execute(input: CreatePostInput): Promise<CreatePostOutput> {
    const post = Post.create(input);  // entity 자체 검증
    await this.postRepo.save(post);
    return { id: post.id, createdAt: post.createdAt };
  }
}
```

### Composition Root (Presentation Layer)

```typescript
// src/app/actions.ts
'use server';

import { CreatePostUseCase } from '@/core/application/use-cases/create-post';
import { SupabasePostRepository } from '@/infrastructure/repositories/supabase-post-repository';

export async function createPostAction(formData: FormData) {
  // DI 조립
  const repo = new SupabasePostRepository();
  const useCase = new CreatePostUseCase(repo);

  return useCase.execute({
    title: String(formData.get('title')),
    body: String(formData.get('body')),
  });
}
```

## Source of Truth

- Robert C. Martin, "Clean Architecture" (2017)
- Project decision record: `docs/architecture/layering.md`
