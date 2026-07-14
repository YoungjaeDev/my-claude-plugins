<!--
Catalog of starter rule categories for write-rules.

Use: NEW mode skill Read s this to suggest initial rule files based
on interview signals. SPLIT mode uses it to classify extracted
sections into named files. REORGANIZE mode uses it to check whether
existing rules/ files align with these category conventions.

Each entry: definition, suggested paths: glob, inspiration example,
default Do/Don't seeds.
-->

# Starter Rule Categories

## 1. architecture

**Definition**: Layering invariants, dependency direction, module
boundaries. Codifies "what depends on what" — the project's
high-level structural rules.

**Suggested paths**: `src/core/**`, `src/domain/**`, `lib/**`,
or wherever the architectural seams live. Often broad — sometimes
no `paths:` if architecture rules apply repo-wide.

**Inspiration**: `examples/nextjs-clean-arch.md` (Clean Architecture
with Composition Root pattern, dependency inversion).

**Do/Don't seeds**:
- Do: Define the dependency direction in one sentence at the top.
- Do: Name the Composition Root location (where DI assembly lives).
- Don't: Allow inner layers to import from outer layers.
- Don't: Mix data-model classes with business logic.

## 2. framework

**Definition**: Conventions for the primary framework — rendering
strategy, routing patterns, lifecycle hooks, framework-specific
optimization. Different from "tech-stack" which is about discrete
tools.

**Suggested paths**: `src/app/**`, `src/pages/**`, `src/components/**`
(framework-specific entry points).

**Inspiration**: `examples/nextjs-framework.md` (Server Component
first, Server Actions, performance optimization).

**Do/Don't seeds**:
- Do: State the rendering default (server-first vs client-first).
- Do: Define when to break out of the default (specific signals).
- Don't: Wrap entire pages in client-only mode without reason.
- Don't: Use raw `<img>` / `<head>` when framework provides
  optimized alternatives.

## 3. tech-stack

**Definition**: Tool-specific operational rules — database client,
ORM, styling system, type system strictness, package manager.
Cross-cuts code; usually no `paths:`.

**Suggested paths**: typically omitted (always-load).

**Inspiration**: `examples/tech-stack-supabase.md` (Supabase SSR,
RLS, type generation, Tailwind utility-first, TypeScript strict).

**Do/Don't seeds**:
- Do: Name the canonical client/session creation utility.
- Do: Specify the type-generation workflow.
- Don't: Bypass the canonical client (e.g., direct DB connection).
- Don't: Use `any` when `unknown` + type guard works.

## 4. testing

**Definition**: Test patterns, coverage expectations, test data
conventions, mock policy.

**Suggested paths**: `tests/**/*.test.{ts,py}`, `**/*.spec.ts`,
`tests/fixtures/**`.

**Inspiration**: No bundled example — adapt from this repo's own
`plugins/github-dev/skills/cr-fix/tests/` fixture suite (fixture-driven,
no network, run in `.githooks/pre-commit` + CI).

**Do/Don't seeds**:
- Do: Write the failing test before implementation.
- Do: Use real I/O (test DB, local server) at integration boundaries
  where mocks would diverge from production.
- Don't: Mock layers you control — test the real thing.
- Don't: Comment-out failing tests; fix or delete with justification.

## 5. service-spec

**Definition**: PRD-style hybrid rule — service overview, target
users, pricing tiers, UX flow, inferred data models. Not a coding
rule strictly, but indispensable project context that shapes
implementation decisions.

**Suggested paths**: typically omitted (always-load). The product
context applies repo-wide.

**Inspiration**: `examples/saas-service-spec.md` (CloudNote SaaS:
plans, features, UX flow, data model entities).

**Do/Don't seeds**:
- Do: Maintain the current pricing tier table here, not in code.
- Do: List inferred data model entities with primary fields.
- Don't: Duplicate the pricing logic — code references this file.
- Don't: Treat this as marketing copy; keep facts terse.

## Category selection guide

When picking starter categories for a new project, the rough mapping is:

| Project type | Suggested categories |
|---|---|
| Web app (Next.js / Remix / similar) | architecture, framework, tech-stack |
| Backend service | architecture, tech-stack, testing |
| ML / research repo | tech-stack (uv/torch versions), testing (dataset fixtures), framework (training-pipeline conventions) |
| SaaS product | architecture, framework, tech-stack, service-spec |
| Library | architecture, testing, tech-stack |

Pick 2-4 starting categories. More is usually overkill for fresh
projects — the rule set grows organically as patterns emerge.

## Naming convention

Filename uses kebab-case, singular noun or noun phrase:

- `architecture.md` (not `Architecture.md` or `architectures.md`)
- `nextjs-framework.md` (when scoping to a specific framework)
- `tech-stack-supabase.md` (when scoping to a stack flavor)

Avoid generic names like `rules.md` or `guidelines.md` — every file
in `.claude/rules/` is already a rule file.
