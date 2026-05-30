# AGENTS.md

이 저장소에서 Codex (GitHub cloud reviewer + CLI), Cursor, Windsurf, Gemini CLI 등 비-Claude 에이전트가 따라야 할 루트 지침이다. 상세 규칙의 authoritative source 는 `CLAUDE.md` 이며, 이 파일은 빠른 참조와 리뷰 기준을 정리한다.

## Project context

{{PROJECT_NAME}} — {{ONE_LINER}}

Owner: {{OWNER}}

> 코드 일정 수준 쌓이면 `rules-forge:write-rules` 로 tech-stack 기반 CLAUDE.md + `.claude/rules/*.md` 를 재생성하고, 이 파일도 그 결과에 맞춰 업데이트한다.

## Build / Test / Lint

<!-- TODO: 코드 추가되면 채운다. 예시: -->
<!-- ```bash -->
<!-- # Build -->
<!-- # uv sync               # Python -->
<!-- # pnpm install          # Node -->
<!-- -->
<!-- # Test -->
<!-- # uv run pytest -q -->
<!-- # pnpm test -->
<!-- -->
<!-- # Lint / Format -->
<!-- # uv run ruff check . -->
<!-- # pnpm lint -->
<!-- ``` -->

## Review guidelines

> 이 섹션은 Codex GitHub cloud reviewer 가 자동으로 읽는 영역이다 ([공식 문서](https://developers.openai.com/codex/integrations/github)). 한국어로 리뷰한다. 발견사항은 영향 + 근거 (파일/라인) + 수정 방향 순서로 제시한다. 근거가 부족하면 `unverified` 로 표시한다.

### Do not flag (린터/포매터 영역)

- 들여쓰기, 줄바꿈, 따옴표 스타일 — 포매터 (`ruff format`, `prettier`, `gofmt` 등) 가 처리한다.
- import 순서, alphabetization — `ruff --select I`, `eslint-plugin-import` 가 처리한다.
- 단순 typo / 영문 문법 — 결함으로 이어지지 않는 한 코멘트하지 않는다.
- 변수명 취향, 한 줄 짜리 helper 추출 같은 단순 리팩터링 — 동작 변경이 없으면 skip.
- 주석/문서 문구 개선 — 의미가 틀린 것이 아니면 skip.

### P0 — Correctness / Security (반드시 차단)

- Secret / API key / token 노출, `.env` / credentials 파일 commit.
- 인증/권한 우회, 사용자 데이터 또는 원본 산출물 (DB, 모델 체크포인트, gt 라벨) 파괴 가능성.
- `rm -rf`, `git push --force`, `DROP TABLE` 류 destructive command 가 사용자 확인 없이 실행되는 흐름.
- SQL injection, command injection, path traversal, SSRF, unsafe deserialization (pickle / eval / unserialize).
- Untrusted PR input 을 직접 shell / DB 쿼리로 흘리는 경로.

### P1 — Performance / Maintainability

- 데이터 저장 / 마이그레이션 / 동기화 변경에서 atomicity, idempotency, rollback, partial-failure 처리가 빠진 경우.
- Public API, schema, config/env var, serialization format 변경이 하위 호환성 또는 docs/test 없이 들어온 경우.
- 핵심 로직 변경에 regression test 가 없거나, 실패한 검증을 무시하거나, 검증 불가 사유가 없는 경우.
- 새 dependency, GitHub Actions, CI/CD 권한 변경 — 최소 권한, lockfile, supply-chain, secret exposure 관점.
- 명시된 invariant (재현성 기준, 데이터 보존, 아키텍처 계층 경계, 런타임/패키지 관리 규칙) 위반.
- O(N²) 이상의 알고리즘이 hot path 에 추가됐는데 입력 크기 가정이 없는 경우.

### Domain-specific

<!-- TODO: 프로젝트 도메인 규칙을 여기에 추가한다. 예시는 `.claude/rules/*.md` 가 채워지면 거기로 옮기고 여기서는 `@.claude/rules/<file>.md` 참조만 둔다. -->

## CodeRabbit / Codex 조율

이 저장소는 PR 머지 전 자동 리뷰로 **CodeRabbit + ChatGPT-Codex** 를 사용한다. `github-dev:cr-fix` 명령이 양쪽을 동시에 처리한다.

| Source | Tier 정책 |
|--------|-----------|
| CodeRabbit `🚨 Bug` / `⚠️ Potential issue` / `🔒 Security` / `🔴 Critical-High` / `🟠 Major` | `gated` — 사용자 per-issue 확인 |
| CodeRabbit `🛠️ Refactor` (`🟡 Minor` / `🟢 Trivial` / `🟢 Info`) | `auto` — 자동 적용 |
| CodeRabbit `📝 Nitpick` | `skip` — 노출 X |
| Codex P1 (red), P2 (yellow) | `gated` |
| Codex P3 (green) | `skip` |

리뷰는 한국어로 작성하되, CR / Codex 의 영어 코멘트는 그대로 받아 들인다.

## 완료 보고

- 변경한 핵심 파일과 동작 변화를 짧게 말한다.
- 실행한 검증 명령과 결과를 말한다.
- 실행하지 못한 검증이 있으면 이유를 밝힌다.
- 발견했지만 범위 밖인 문제는 임의로 고치지 말고 별도 메모로만 언급한다.

## Anti-patterns

- AI / Claude attribution 을 커밋, PR, 이슈, 문서에 추가하지 않는다.
- 이모지를 코드와 문서에 넣지 않는다.
- Drive-by refactor — 요청 범위 밖 코드를 임의로 리팩터링하지 않는다.
- 출력 파일, 임시 파일, 분석 산출물을 프로젝트 루트에 만들지 않는다.
