# Codex Review Discovery — AGENTS.md vs `/review` CLI

이 문서는 `/project-init:new` 의 Phase 4 (AGENTS.md seed) 가 왜 레포 생성 시점에 시드해야 효과적인지 정리한다.

## 두 가지 Codex review 경로

| 경로 | 트리거 | AGENTS.md 영향 |
|------|--------|----------------|
| **Codex GitHub cloud reviewer** | PR open / `@codex review` 댓글 | **자동**으로 레포 루트 `AGENTS.md` 의 `## Review guidelines` 섹션을 로드해 시스템 프롬프트에 포함 |
| **Codex CLI (`mcp__codex-cli__review` 또는 `chatgpt-codex review`)** | 로컬에서 명시적 호출 | AGENTS.md 는 같은 위치/형식이면 동일하게 읽힘 (CLI 가 cwd 의 `AGENTS.md` discover) |

핵심 사실: Codex cloud reviewer 는 `AGENTS.md` 의 `## Review guidelines` 헤더 아래 콘텐츠를 우선적으로 참고한다. 다른 섹션 (`## Project context`, `## Build / Test / Lint`) 도 시스템 프롬프트에 들어가지만 review 의 critical path 는 review guidelines 섹션이다.

> 출처: [OpenAI Codex GitHub integration](https://developers.openai.com/codex/integrations/github) — "Codex reads `AGENTS.md` to learn the codebase conventions before reviewing".

핵심 정정 (2026-07-13): "리뷰어는 `AGENTS.md` 섹션만 읽고 참조 파일은 따라가지 않는다" 는 인상은 과장이다. best-practices 문서가 예외를 명시한다 — *"If you and your team have a `code_review.md` file and reference it from `AGENTS.md`, Codex can follow that guidance during review as well."* 즉 `AGENTS.md` 가 명시적으로 참조하는 루트 `code_review.md` 는 리뷰어가 **따라갈 수 있다** (단 "can follow" = 소프트 개런티로, `## Review guidelines` 섹션 자체의 시스템 프롬프트 하드 주입보다 약하다. 임의 산문 "read X" redirect 와는 다르다 — 그건 참조된 리뷰 파일이 아니라 안 따라간다). 이 저장소는 이 패턴을 채택했다: `AGENTS.md` 에 하드 P0/P1 최소본 + 루트 `code_review.md` 전문.

> 출처: [OpenAI Codex best practices](https://developers.openai.com/codex/learn/best-practices) (verified 2026-07-13) — `code_review.md` 소프트 개런티. GitHub cloud reviewer 는 P0/P1 만 코멘트로 표면화: [Codex code review](https://developers.openai.com/codex/code-review).

## 왜 "레포 생성 시점에" 시드해야 하나

1. **첫 PR 부터 효과**: AGENTS.md 가 main 브랜치에 없으면 첫 PR 리뷰 시 Codex 가 generic 기준 (lint stuff, style nits) 으로 리뷰한다.
2. **Default branch protection**: AGENTS.md 를 첫 commit 에 포함하면 protected branch policy 와 무관하게 모든 PR 이 이미 base 에 깔린 가이드라인을 본다.
3. **사용자 학습 효과**: 빈 프로젝트에 AGENTS.md 가 있으면 첫 PR 작성자가 "여기는 이런 기준" 을 미리 인지.

## Review guidelines 섹션 핵심 구조

Codex review 가 잘 작동하는 패턴 — 4 개 섹션:

1. **`### Do not flag`** (린터/포매터 영역) — **선두에 배치**. Codex 가 generic lint nit 을 코멘트하는 비용을 차단.
2. **`### P0 — Correctness / Security`** — must-block 항목.
3. **`### P1 — Performance / Maintainability`** — should-block 항목.
4. **`### Domain-specific`** — 프로젝트 고유 invariant. variant 별로 다름.

### "Do not flag" 가 선두인 이유

부정형 (negative) 스코핑이 긍정형 (positive) 보다 review noise 를 더 효과적으로 줄인다. Codex 는 새 PR 을 보면 lint-level diff 부터 코멘트하려는 경향이 있는데, "do not flag" 가 먼저 보이면 그 욕구가 시스템 프롬프트 단계에서 억제된다.

## CodeRabbit 와의 조율

CodeRabbit 은 `AGENTS.md` 를 읽지 않는다 — 자체 `.coderabbit.yaml` 또는 review-instruction 시스템을 사용한다. 따라서:

- AGENTS.md 의 review guidelines 는 Codex 만을 1차 타겟.
- CodeRabbit instruction (필요 시) 은 별도 `.coderabbit.yaml` 또는 `.github/CODEOWNERS` 와 함께 관리.
- `/github-dev:cr-fix` 명령이 두 봇의 결과를 동시에 처리하며 tier 정책으로 noise 를 정리.

> 참고: `.claude/spec/2026-05-06-codex-review-integration.md` — `cr-fix` 의 CR + Codex 통합 세부 내용.

## AGENTS.md 가 이미 존재하는 경우

`/project-init:new` 의 Phase 4 는 idempotent 가드를 가진다:

- AGENTS.md 가 이미 있으면 덮어쓰지 않음 + 사용자에게 "기존 AGENTS.md 에 `## Review guidelines` 섹션이 없으면 manual 추가 권장" 안내.
- 기존 AGENTS.md 에 review guidelines 섹션이 없는지 grep 으로 확인 후 사용자 결정 게이트.
