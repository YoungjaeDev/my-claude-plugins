# E2E Operating Guidelines (SSOT)

> This is the **single source of truth** for how E2E is run on this project. It is read by the Playwright agents (planner / generator / healer) and by humans. It is intentionally separate from the repo `AGENTS.md` / `CLAUDE.md` — those cover the whole codebase; this file covers *only* E2E policy.
>
> Replace every `<...>` placeholder. Delete sections that do not apply. Keep it short and current — a stale SSOT is worse than none.

## 1. Scope — what we test and what we do NOT

E2E is expensive and slow. Reserve it for **critical user flows (CUFs)** — flows where a regression breaks revenue, data integrity, or user trust.

**In scope (CUFs):**
- [ ] `<e.g. Sign up -> verify email -> first login>`
- [ ] `<e.g. Add to cart -> checkout -> payment success>`
- [ ] `<e.g. Create record -> edit -> delete, with persistence>`

**Explicitly OUT of scope (covered by unit/integration, or not worth E2E):**
- `<e.g. form field validation messages — unit-tested>`
- `<e.g. pure presentational components — covered by component tests>`
- `<e.g. third-party widget internals — not ours to test>`

## 2. Authentication scenarios

How tests obtain an authenticated session. Prefer a one-time `auth.setup.ts` that saves `storageState`, reused by all tests (no per-test login).

| Role | How auth is established | storageState file |
|------|-------------------------|-------------------|
| `<standard user>` | `<UI login / API token / seeded session>` | `<playwright/.auth/user.json>` |
| `<admin>` | `<...>` | `<playwright/.auth/admin.json>` |
| `<unauthenticated>` | n/a (no setup dependency) | n/a |

**Credentials source:** `<env vars E2E_USER / E2E_PASS — never hardcoded; injected in CI via secrets>`

## 3. Environments

| Environment | Base URL | When used | Notes |
|-------------|----------|-----------|-------|
| local | `<http://localhost:3000>` | dev authoring | `<webServer auto-start in playwright.config>` |
| CI | `<http://localhost:3000 or preview URL>` | every gated PR | `<deterministic; network mocked where noted>` |
| staging | `<https://staging.example.com>` | `<smoke only / nightly>` | `<may hit real backends — keep CUF-only>` |

## 4. Network determinism (mocking policy)

E2E must be deterministic. Decide per-flow whether to hit real backends or mock.

- **Mock at the network boundary** (`page.route`) for: `<3rd-party APIs, flaky upstreams, payment sandboxes, SSR/BFF fetches>`.
- **Hit real** (no mock) for: `<the app's own backend on the CUF happy path, when seeded deterministically>`.
- **Fixtures location:** `<e2e/fixtures/>` — keep mock payloads versioned and named after the endpoint.

> If this is a Next.js (or other SSR/BFF) app, remember that server-side fetches do NOT pass through `page.route` — they run on the server, before the browser. Mock those at the BFF/server layer or via an E2E-only env flag that swaps in fixed responses. See the route-mock scaffold for the pattern.

## 5. Conventions

- **Locators:** semantic only — `getByRole(role, { name })`, `getByLabel`, `getByText`. No brittle CSS/XPath selectors.
- **Test step naming:** `<test.step('...') with English | Korean step names — pick one and be consistent>`.
- **File layout:** `<e2e/<feature>.spec.ts>`; plans in `<specs/<feature>.md>`.
- **No conditional assertions / no waits on arbitrary timeouts** — use web-first assertions (`expect(locator).toBeVisible()`).
- **Test independence via API state-setup:** each test starts at *its branch's* start state, set through a test API — do NOT replay a shared UI prefix (e.g. consent -> phone auth) in every test. `<which test API / endpoint puts a user at each branch start>`. This prevents cascade failures and cumulative runtime, and matches Playwright's "tests must be independent" (distinct from `storageState`, which only carries auth, not mid-flow app state).

## 6. Flake & burn-in policy

- New/changed specs must pass a burn-in (`--repeat-each=<3>`) before merge. A single failure in burn-in = flaky = blocked.
- CI retries: `<retries=2 on CI, 0 locally>`. A test that only passes on retry is a flake to fix, not to accept.
- Quarantine: a flake that cannot be fixed within `<3>` healer attempts is `test.skip`-ped with a linked tracking issue — never left red.

## 7. CI gating

- E2E runs on: `<PRs touching app code (path filter) OR PRs labeled "e2e">` — not every push.
- Artifacts on failure: `<playwright-report/ + trace.zip uploaded>`.
- Failure surfaces as: `<a PR comment with the report/trace link>`.
