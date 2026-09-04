# AGENTS.md

이 저장소에서 Codex (GitHub cloud reviewer + CLI), Cursor, Windsurf, Gemini CLI 등 비-Claude 에이전트가 따라야 할 루트 지침이다. 상세 규칙의 authoritative source 는 `CLAUDE.md` 이며, 이 파일은 빠른 참조와 리뷰 기준을 정리한다.

## Project context

{{PROJECT_NAME}} — {{ONE_LINER}}

Owner: {{OWNER}}
Domain: Web / fullstack — frontend + backend API 통합 프로젝트.

> 코드 일정 수준 쌓이면 `/docs:write-rules` 로 tech-stack 기반 CLAUDE.md + `.claude/rules/*.md` 를 재생성하고, 이 파일도 그 결과에 맞춰 업데이트한다.

## Build / Test / Lint

<!-- TODO: 코드 추가되면 채운다. Web 프로젝트 기본 패턴: -->
<!-- ```bash -->
<!-- # Install -->
<!-- # pnpm install   # 또는 npm / yarn / bun -->
<!-- -->
<!-- # Dev server -->
<!-- # pnpm dev -->
<!-- -->
<!-- # Test -->
<!-- # pnpm test          # 단위 테스트 (vitest / jest) -->
<!-- # pnpm test:e2e      # E2E (playwright / cypress) -->
<!-- -->
<!-- # Lint / Type-check -->
<!-- # pnpm lint -->
<!-- # pnpm typecheck     # tsc --noEmit -->
<!-- ``` -->

## Review guidelines

> 이 섹션은 Codex GitHub cloud reviewer 가 자동으로 읽는 영역이다 ([공식 문서](https://developers.openai.com/codex/integrations/github)). 한국어로 리뷰한다. 발견사항은 영향 + 근거 (파일/라인) + 수정 방향 순서로 제시한다. 근거가 부족하면 `unverified` 로 표시한다.

### Do not flag (린터/포매터 영역)

- 들여쓰기, 따옴표, 세미콜론 스타일 — Prettier / Biome 가 처리.
- import 순서 — ESLint `import/order` 가 처리.
- 단순 typo / 영문 문법, 변수명 취향 — 결함이 아니면 skip.
- React component file 안 hook 순서 micro-optimization — 정확성 문제 아니면 skip.

### P0 — Correctness / Security

- Secret / API key 가 client bundle 로 노출 (`NEXT_PUBLIC_*` 에 server-only 키 포함).
- XSS — `dangerouslySetInnerHTML` 에 unsanitized user input, `v-html` 에 raw HTML.
- SQL injection / NoSQL injection — ORM 우회한 raw query 에 user input concat.
- Auth bypass — middleware 누락된 protected route, JWT verification skip.
- CSRF — state-changing endpoint 에 SameSite / origin check 누락.
- 사용자 데이터 (DB row, 파일 storage, session token) destructive 변경이 transaction / undo 없이 실행.
- `npm`/`pnpm` 새 의존성 supply-chain — lockfile 변경 동반되지 않거나 typosquat 의심.

### P1 — Performance / Maintainability

- **N+1 쿼리** — loop 안에서 ORM/fetch 가 호출되는 경로.
- **Server / Client component 경계 위반** (Next.js App Router) — `"use client"` 누락 또는 server-only 모듈을 client component 에서 import.
- **데이터 mutation 변경** — atomicity, idempotency, rollback, partial-failure 처리가 빠진 경우.
- **Public API / schema / config / env var 변경** 이 하위 호환성 또는 docs/test 없이 들어온 경우.
- **Regression test 부재** — 핵심 로직 변경에 단위/통합 테스트 없음.
- 새 dependency, GitHub Actions, CI/CD 권한 변경 — 최소 권한, lockfile, supply-chain.
- 명시된 invariant (아키텍처 계층 경계, 런타임/패키지 관리 규칙) 위반.

### Domain-specific (Web)

- **Hydration mismatch** — SSR 렌더 결과와 client 첫 렌더가 다른 경우 (`Date.now()`, `Math.random()` 사용, `useEffect` 없이 `localStorage` 접근).
- **Form validation** — 서버사이드 validation 누락 (client validation 만으로 충분하지 않음).
- **Loading / error / empty state** — 데이터 fetch 컴포넌트가 success path 만 다루는 경우.
- **Accessibility (a11y)** — `<button>` 대신 `<div onClick>`, `<img alt>` 누락, focus management 깨짐.
- **CORS / cookie SameSite** — 인증 쿠키 정책이 새 도메인 추가 시 함께 업데이트되는지.
- **Bundle size 회귀** — heavy library 가 client bundle 에 새로 들어가는데 dynamic import 미사용.
- **DB migration** — schema 변경에 down migration 또는 backfill 전략 부재.

<!-- 코드 일정 수준 쌓이면 `.claude/rules/frontend.md`, `.claude/rules/backend.md`, `.claude/rules/db.md` 로 분리하고 여기서는 `@.claude/rules/<file>.md` 로 참조. -->

## CodeRabbit / Codex 조율

이 저장소는 PR 머지 전 자동 리뷰로 **CodeRabbit + ChatGPT-Codex** 를 사용한다. `/dev:cr-fix` 명령이 양쪽을 동시에 처리한다.

| Source | Tier 정책 |
|--------|-----------|
| CodeRabbit `🚨 Bug` / `⚠️ Potential issue` / `🔒 Security` / `🔴 Critical-High` / `🟠 Major` | `gated` — 사용자 per-issue 확인 |
| CodeRabbit `🛠️ Refactor` (`🟡 Minor` / `🟢 Trivial` / `🟢 Info`) | `auto` — 자동 적용 |
| CodeRabbit `📝 Nitpick` | `skip` |
| Codex P1 (red), P2 (yellow) | `gated` |
| Codex P3 (green) | `skip` |

## 완료 보고

- 변경한 핵심 파일, 동작 변화, 영향받은 page / API endpoint 를 짧게 말한다.
- 실행한 검증 (테스트, typecheck, lint, dev server 수동 확인) 과 결과를 말한다.
- 실행하지 못한 검증 (예: E2E 전체) 이 있으면 이유를 밝힌다.
- 발견했지만 범위 밖인 문제는 임의로 고치지 말고 별도 메모로만 언급한다.

## Anti-patterns

- AI / Claude attribution 을 커밋, PR, 이슈, 문서에 추가하지 않는다.
- 이모지를 코드와 문서에 넣지 않는다.
- Drive-by refactor — 요청 범위 밖 코드를 임의로 리팩터링하지 않는다.
- 출력 파일, 빌드 산출물을 프로젝트 루트에 만들지 않는다 (`dist/`, `.next/` 등 dedicated 디렉토리, gitignore 대상).
