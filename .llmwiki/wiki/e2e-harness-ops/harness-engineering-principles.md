---
id: harness-engineering-principles
aliases: [harness-engineering, self-improvement-loop, guide-and-sensor, test-as-sensor-and-spec, evaluator-optimizer-deterministic]
last_verified: 2026-06-17
status: active
volatility: stable
sources: 2
---

# Harness-engineering principles (why E2E for agents)

Design rationale behind the `e2e-harness` plugin — the transferable "why/how", separate from the version-pinned facts in [[playwright-ai-harness]]. Harness = everything outside the model weights (instruction files, MCP, skills, LLM-wiki, lint/tests); the job is to make each agent mistake non-repeatable.

## The case for E2E specifically

- **Verification is the bottleneck.** Agentic coding made writing ~1.5x faster (one dev: 227→340 merged PRs over comparable 9-month windows) but verification did not scale — nobody can locally check out and run every PR. The constraint moved from authoring to verifying, so harness investment should go to verification, not generation.
- **AI-era bugs cluster at component boundaries.** Each unit passes its unit test (middleware, server data-fetch, props, component) yet the composed flow breaks — data shape, state hand-off, env-specific API. Mock-at-boundary unit tests structurally cannot see this; only a boundary-spanning E2E run can. This is why the trophy's top (E2E) became mandatory, not optional, once agents write the code.

## Test code is a sensor AND a spec (one artifact, two faces)

A Playwright test, **run**, is a deterministic sensor of real user behavior; **read**, it is a living spec ("press 조회 → result shows") that cannot drift from the code. One artifact solves verification + always-current spec at once. This is Anthropic's evaluator-optimizer pattern, but with the grader swapped from an expensive/slow/non-deterministic LLM to a **deterministic, cheap, fast** test — that swap is the point. Models are lenient on their own code ("good enough") and stop early, so giving the model an external verification sensor is the highest-leverage harness move, and more important with stronger models, not less.

## The self-improvement loop = the delegation criterion

The loop: generate → verify (sensor) → debug (trace) → fix → re-run. An agent need not one-shot a task if it can self-correct inside this loop. "Can I build a self-improvement loop for this?" is the modern test for how much to delegate. The loop needs two parts:

- a **guide** that sets direction *before* action (AGENTS.md, MCP, skills, the E2E SSOT doc), and
- a **sensor** that enables self-correction *after* action (tests, linters, type-checkers, the trace).

## Installing the official agents is not enough — onboard them like a new hire

Playwright's planner/generator/healer, out of the box, skip auth setup, can't resolve project-known API errors, and don't know test-account usage — they lack codebase context. The actual harness work is supplying that context: a whole-codebase guide (AGENTS.md), a separate E2E-operation SSOT (env, auth scenarios, what-to-test/not, prior decisions — distinct from AGENTS.md), reusable auth/state-setup helpers, and an MCP server for specs/design/issues/PRs. (See [[playwright-ai-harness]] for the concrete generated files.)

## Test-design patterns that keep the loop trustworthy

- **Independent tests via API state-setup, not UI replay.** Don't re-run a shared prefix (consent → phone auth) through the UI in every test. Call a test API to put the user at the branch's start state, then assert only that branch. Prevents cascade failures and cumulative runtime; matches Playwright's "tests must be independent".
- **Mock external deps by call-site.** Browser-side calls → `page.route`; SSR/BFF server-side calls → an E2E-only env flag returning fixed responses (server fetches never cross `page.route`). "Test only what you control."
- **Catch flakes at authoring, before merge.** Burn-in (`--repeat-each`) right after writing — one failure = flaky = blocked; tracking a flake post-merge costs far more. Plus: condition-based waits (no hard `waitForTimeout`), semantic `getByRole(role,{name})` locators (survive design changes).

## The human's enduring role

- **Delegate thinking, not understanding (Karpathy).** CI passing ≠ knowing the production impact; merge-readiness and domain decisions stay human-owned.
- **The harness evolves with the model.** It fills what the model can't do *now*; as models improve, some of it automates but harder work moves up to humans — it changes shape, never disappears. Design north star (Vercel): *make the right thing easy to do.*

> See-also: [[playwright-ai-harness]] — version-pinned Playwright facts the principles above are realized with.

## Sources

1. "AI가 쓴 코드 누가 검증하나 — AI 에이전트를 위한 Playwright E2E 테스트 하네스 구축하기", Naver Financial FE talk (2026), transcript. Cites Mitchell Hashimoto (harness def.), Boris Cherny (give the model verification means), Kent C. Dodds (testing trophy), Martin Fowler (E2E confidence), Karpathy (delegate thinking not understanding), Anthropic "Building Effective Agents" (evaluator-optimizer), Vercel agent principles.
2. The `e2e-harness` plugin built from this talk (this repo) — corroborating application of the principles.
