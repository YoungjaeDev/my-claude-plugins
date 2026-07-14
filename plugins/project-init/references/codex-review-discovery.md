# Codex Review Discovery — AGENTS.md vs `/review` CLI

This document explains why Phase 4 (AGENTS.md seed) of `/project-init:new` is only effective when seeded at repo-creation time.

## Two Codex review paths

| Path | Trigger | AGENTS.md effect |
|------|--------|----------------|
| **Codex GitHub cloud reviewer** | PR open / `@codex review` comment | **Automatically** loads the `## Review guidelines` section of the repo-root `AGENTS.md` into the system prompt |
| **Codex CLI (`mcp__codex-cli__review` or `chatgpt-codex review`)** | explicit local invocation | AGENTS.md is read the same way if it is in the same location/format (the CLI discovers `AGENTS.md` in cwd) |

Key fact: the Codex cloud reviewer preferentially consults the content under the `## Review guidelines` header of `AGENTS.md`. Other sections (`## Project context`, `## Build / Test / Lint`) also enter the system prompt, but the critical path for review is the review-guidelines section.

> Source: [OpenAI Codex GitHub integration](https://developers.openai.com/codex/integrations/github) — "Codex reads `AGENTS.md` to learn the codebase conventions before reviewing".

Important correction (2026-07-13): the impression that "the reviewer only reads `AGENTS.md` sections and does not follow referenced files" is overstated. The best-practices doc names an exception — *"If you and your team have a `code_review.md` file and reference it from `AGENTS.md`, Codex can follow that guidance during review as well."* So the reviewer **can follow** a root `code_review.md` that `AGENTS.md` explicitly references (but "can follow" is a soft guarantee, weaker than the hard system-prompt injection of the `## Review guidelines` section itself. It differs from an arbitrary prose "read X" redirect — the reviewer does not follow that, only a referenced review file). This repo adopted this pattern: a hard P0/P1 minimum in `AGENTS.md` plus the full text in a root `code_review.md`.

> Source: [OpenAI Codex best practices](https://developers.openai.com/codex/learn/best-practices) (verified 2026-07-13) — the `code_review.md` soft guarantee. The GitHub cloud reviewer surfaces only P0/P1 as comments: [Codex code review](https://developers.openai.com/codex/code-review).

## Why seed it "at repo-creation time"

1. **Effective from the first PR**: if AGENTS.md is not on the main branch, Codex reviews the first PR against generic criteria (lint stuff, style nits).
2. **Default branch protection**: including AGENTS.md in the first commit means every PR sees guidelines already present in the base, regardless of protected-branch policy.
3. **User-learning effect**: with AGENTS.md present in an empty project, the first PR author knows up front "these are the standards here".

## Core structure of the Review guidelines section

The pattern that makes Codex review work well — 4 sections:

1. **`### Do not flag`** (linter/formatter territory) — **placed first**. Blocks the cost of Codex commenting on generic lint nits.
2. **`### P0 — Correctness / Security`** — must-block items.
3. **`### P1 — Performance / Maintainability`** — should-block items.
4. **`### Domain-specific`** — project-unique invariants. Differs per variant.

### Why "Do not flag" comes first

Negative scoping reduces review noise more effectively than positive scoping. Codex, on seeing a new PR, tends to comment on lint-level diffs first; when "do not flag" appears first, that urge is suppressed at the system-prompt stage.

## Coordination with CodeRabbit

CodeRabbit does not read `AGENTS.md` — it uses its own `.coderabbit.yaml` or review-instruction system. Therefore:

- The review guidelines in AGENTS.md primarily target Codex.
- CodeRabbit instructions (if needed) are managed separately with `.coderabbit.yaml` or `.github/CODEOWNERS`.
- The `/github-dev:cr-fix` command processes both bots' results at once and cleans up noise with a tier policy.

> See: `.claude/spec/2026-05-06-codex-review-integration.md` — details of `cr-fix`'s CR + Codex integration.

## When AGENTS.md already exists

Phase 4 of `/project-init:new` has an idempotent guard:

- If AGENTS.md already exists, do not overwrite it, and advise the user "if your existing AGENTS.md has no `## Review guidelines` section, adding one manually is recommended".
- Grep to check whether the existing AGENTS.md lacks a review-guidelines section, then gate on the user's decision.
