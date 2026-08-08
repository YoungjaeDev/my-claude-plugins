# AGENTS.md

> **이 파일이 정본이고, 루트 `CLAUDE.md` 는 이 파일을 `@AGENTS.md` 로 import 하는 한 줄짜리 포인터다.** 세 런타임이 서로 다른 파일명을 찾기 때문이다 — Claude Code 는 `CLAUDE.md` 만 읽고 그 안의 `@AGENTS.md` import 로 이 파일을 끌어오며, Codex 와 Hermes 는 `AGENTS.md` 를 그대로 읽는다. 내용을 이 파일 한 곳에만 두어 미러 유지 부담을 없앴다.
>
> `CLAUDE.md` 를 따로 편집하지 마라 — `@AGENTS.md` 한 줄 import 일 뿐이다. 편집은 항상 `AGENTS.md` 에 한다.

## 기본 원칙

- 이 저장소는 Claude Code 플러그인 marketplace 저장소입니다. 변경 전에는 이 문서, `README.md`, 관련 플러그인의 `plugins/<name>/CLAUDE.md`를 먼저 확인하세요.
- 사용자가 한국어로 요청하면 한국어로 응답하세요.
- 변경은 요청 범위에만 한정하고, 관련 없는 파일이나 기존 사용자 변경 사항은 되돌리지 마세요.
- 파일 탐색과 검색은 우선 `rg`, `rg --files`를 사용하세요.
- 플러그인 개발 중 라이브러리·런타임·플랫폼 사실을 확인할 때는 `docs/llm-doc-sources.md` 에 정리된 LLM 문서 소스(mcpdocs 등록 + deepwiki 타깃)를 먼저 사용하세요.
- 문서와 매니페스트가 함께 움직이는 저장소이므로 코드 변경뿐 아니라 `README.md`, 이 문서, marketplace manifest의 동기화 필요성을 항상 확인하세요.

플러그인 트리 하나를 Claude Code, Codex 0.135(`scripts/sync-codex-manifests.mjs`), Hermes Agent(`scripts/sync-hermes-manifests.mjs`)가 함께 읽습니다 — one source, three runtimes.

## Plugins (14)

각 플러그인이 무엇을 하는지는 `jq -r '.plugins[] | "\(.name): \(.description)"' .claude-plugin/marketplace.json` 으로 읽는다 — 설명을 여기에 다시 적으면 매니페스트와 표 두 곳을 손으로 맞춰야 하고, `check-doc-consistency.mjs` 는 이름 집합만 검사하므로 설명 drift 는 조용히 남는다. 아래 표는 이름·분류만 유지한다 (가드가 이 이름 집합을 marketplace.json 과 대조한다).

| Plugin | Category |
|--------|----------|
| `core-config` | Core |
| `github-dev` | GitHub |
| `e2e-harness` | Testing |
| `code-scout` | Research & Search |
| `deepwiki` | Research & Search |
| `paper-search-tools` | Research & Search |
| `codex-image` | AI Models |
| `council` | AI Models |
| `ml-toolkit` | Development Tools |
| `publish` | Content & Translation |
| `project-init` | Planning |
| `docs-forge` | Documentation |
| `mem0-ops` | Memory & Lore |
| `llm-wiki` | Memory & Lore |

플러그인은 `.claude/settings.json` 에서 auto-load 됩니다. 사용법 상세는 `README.md`.

## 저장소 구조

디렉터리 배치 자체는 `ls plugins/` 로 확인한다. 아래는 그 배치만 봐서는 알 수 없는 각 경로의 역할과 편집 금지 여부다.

- `AGENTS.md`: 이 문서. 세 런타임 공통 최상위 지침 + 플러그인 목록 + 구조 요약.
- `CLAUDE.md`: `@AGENTS.md` 를 import 하는 한 줄 파일. Claude Code 진입점일 뿐, 별도 내용이 없습니다.
- `CLAUDE.md.global` / `CLAUDE.md.global.ko`: 사용자 전역 지침(`~/.claude/CLAUDE.md`)의 정본과 손으로 유지하는 한국어 번역. 영어 파일이 SoT — 영어를 먼저 고치고 `.ko` 를 미러한 뒤 `cp CLAUDE.md.global ~/.claude/CLAUDE.md` 로 사본을 갱신한다. `.ko` 는 어떤 에이전트도 로드하지 않는다. 사본을 이 워킹트리로의 심볼릭 링크로 걸지 않는다 — 그러면 브랜치 전환과 커밋 안 된 편집이 그 순간 전역 지침으로 발효된다. 이 지침이 전역 파일 헤더가 아니라 여기 있는 이유는, 전역 파일은 모든 프로젝트에서 로드되는데 이 파일 쌍은 이 저장소에만 있어서다. 전역 파일 자체는 sync 안내조차 싣지 않는다. 모든 세션에 로드되는 파일에서 규칙이 아닌 줄은 전부 비용이기 때문이다.
- `README.md`: 사용자용 설치 및 플러그인 문서.
- `.claude/settings.json`: 로컬 플러그인 로드 설정.
- `.claude-plugin/marketplace.json`: marketplace 레지스트리와 플러그인 버전 목록.
- `.claude/rules/`: 특정 경로에 적용되는 상세 규칙 (Claude 전용 — Codex/Hermes 는 읽지 못함).
- `plugins/<name>/`: 각 플러그인의 원본 디렉터리.
- `plugins/<name>/.claude-plugin/plugin.json`: 플러그인별 매니페스트와 버전.
- `plugins/<name>/.codex-plugin/plugin.json`: Codex 0.135 용 매니페스트 (generated, do not edit by hand).
- `plugins/<name>/plugin.yaml` + `plugins/<name>/__init__.py`: Hermes Agent 어댑터 (HERMES_ELIGIBLE 플러그인만, generated, do not edit by hand).
- `.agents/plugins/marketplace.json`: Codex marketplace 카탈로그 (generated).
- `scripts/sync-codex-manifests.mjs`: Codex 매니페스트 생성기. `--check` 로 drift 가드, `--dry-run` 으로 출력 미리보기.
- `scripts/sync-hermes-manifests.mjs`: Hermes 어댑터 생성기. `--check` drift + orphan 가드, `--dry-run` 미리보기.

## 멀티런타임 통합 (Claude Code ↔ Codex ↔ Hermes Agent)

이 저장소는 Claude Code, Codex CLI, Hermes Agent 세 런타임으로 구동된다. 지침/hook/lore 를 한쪽 표면에만 두면 다른 도구체인에는 안 보인다. 동작에 영향을 주는 변경은 짝 표면을 같은 변경에서 점검한다. (Claude 쪽 SSOT: `.claude/rules/dual-integration.md` — Codex/Hermes 는 `.claude/rules/` 를 `@import` 못 하므로 이 블록이 미러다.)

| 관심사 | Claude Code 표면 | Codex 표면 | Hermes 표면 |
|---|---|---|---|
| 최상위 지침 | `CLAUDE.md` (`@AGENTS.md` import), `.claude/rules/*.md` (auto-load) | `AGENTS.md` (verbatim 로드 — `@import` 메커니즘 자체가 없음) | `AGENTS.md` (verbatim) |
| 프롬프트 주입 hook | 플러그인 `UserPromptSubmit` (`plugin.json` → `hooks/*.sh`) | 번들 `hooks/codex-hooks.json` → 매니페스트 `hooks` 배선 (`codex` 포맷 인자, `/hooks` trust). 레거시 수동 `~/.codex/hooks.json` 도 여전히 동작 | (별도 hook surface — 현재 미사용) |
| skill | `plugins/*/skills` (native) | 같은 트리 in-place + generated `.codex-plugin/plugin.json` (아래 "Codex 통합") | 같은 트리 in-place + generated `plugin.yaml` + `__init__.py` (아래 "Hermes 통합") |
| command / subagent | `plugins/*/{commands,agents}` (native) | Codex 0.135 미지원 (Claude-only) | Hermes 미지원 (skill 만) |
| skill 본문 도구명 | Claude 도구명 (`Bash`, `Read`, ...) | Claude 와 동일 (본문 그대로 읽음) | 본문의 호환 표로 Hermes 도구명 매핑 (`Bash`→`terminal`, `AskUserQuestion`→`clarify`, ...) |
| 공유 중립 lore | `.llmwiki/` (세 에이전트 동일 루트, fork 금지) | `.llmwiki/` | `.llmwiki/` |

- 최상위 지침은 이 파일 한 곳에만 쓴다. `CLAUDE.md` 는 `@AGENTS.md` 한 줄 import 라 편집할 내용이 없다.
- Claude hook 을 추가/변경하면 Codex 대응을 점검한다: 플러그인이 번들 `hooks/codex-hooks.json` 디스크립터를 실으면 `node scripts/sync-codex-manifests.mjs` 가 이를 매니페스트 top-level `hooks` 로 배선한다 (레거시 수동 `~/.codex/hooks.json` 경로는 여전히 유효). 어느 쪽이든 Codex hook 은 별도 `/hooks` trust 승인이 필요하다 (자동 등록 안 됨).
- skill / 버전 / description 을 바꾸면 Codex 매니페스트 재생성(`node scripts/sync-codex-manifests.mjs`) + (Hermes-eligible 이면) Hermes 어댑터 재생성(`node scripts/sync-hermes-manifests.mjs`)이 필요한지 점검한다 ("Codex 통합" / "Hermes 통합" 섹션 + `plugin-versioning.md`).
- skill 본문을 추가/변경할 때 Hermes 호환 표(Claude/Codex 도구 용어 → Hermes 도구)를 점검한다 — 3런타임 포터블.
- subagent 위임은 Claude 전용 가속일 뿐이다 — skill 단계의 인라인 크로스런타임 경로가 primary 로 남아야 하고, skill 로직을 agent 정의로 옮기지 않는다 (Codex 0.135 / Hermes 는 agents surface 가 없어 옮긴 로직이 조용히 사라진다).
- wiki lore 는 `.claude/rules/` 로 승격하지 않는다 — Codex/Hermes 가 못 읽는다. cross-agent insight 는 `.llmwiki/insight/` 로 graduate 후 공유 주입 hook 으로 노출한다.
- `.llmwiki/` 를 per-agent 로 fork 하지 않는다.
- Instruction and skill documentation prose is written in English (skill bodies, reference docs, plugin `CLAUDE.md`) so all three runtimes and the Codex cloud reviewer read one language. Domain content is exempt and stays in its source language — copy, form presets, humanize samples, illustrative example outputs, and the i18n / trigger phrases inside a skill `description:` frontmatter field (translating those breaks skill matching).
- **`AGENTS.md` 를 `CLAUDE.md` 로의 포인터로 축약하지 않는다.** Codex/Hermes 는 `@` 를 확장하지 않아 `@CLAUDE.md` 는 죽은 텍스트이고, "CLAUDE.md 를 먼저 읽어라" 식 산문 redirect 는 Codex GitHub cloud reviewer 에 닿지 않는다 (이 리뷰어는 `## Review guidelines` 섹션을 시스템 프롬프트에 직접 로드한다 — 임의 산문 redirect 는 따라가지 않고, `AGENTS.md` 가 명시적으로 참조하는 `code_review.md` 만 예외적으로 따라갈 수 있다[소프트 개런티, best-practices 문서]). 실패는 조용하다 — 에러 없이 지침만 사라진다. 이 저장소는 반대 방향을 택했다: `AGENTS.md` 가 SSOT 이고 `CLAUDE.md` 는 `@AGENTS.md` 한 줄을 import 한다 (`@import` 는 Claude 전용이라 `CLAUDE.md` 쪽에만 두면 되고, Codex/Hermes 는 `AGENTS.md` 를 직접 읽는다). 심볼릭 링크도 같은 효과를 내지만 Windows 체크아웃에서 `core.symlinks` 가 꺼져 있으면 `CLAUDE.md` 가 링크 대상 문자열 그대로 풀려 깨지므로, 포터블한 `@import` 를 택했다.

## Cross-runtime interactive input policy

사용자에게 되묻는 상호작용은 런타임마다 노출 도구가 다르다. 공유 스킬 본문(세 런타임이 verbatim 으로 읽음)은 특정 도구가 항상 존재한다고 가정하지 말고 **capability-aware** 게이트로 쓴다.

| 런타임 | 상호작용 도구 |
|---|---|
| Claude Code | `AskUserQuestion` |
| Codex | `request_user_input` (노출된 경우). 노출 안 되면, 틀린 가정의 비용이 큰 지점에서만 짧은 blocking 질문 하나를 던지고, 그 외에는 문서화된 안전한 기본값으로 진행한다 |
| Hermes | `clarify` |

- 새 스킬 본문이 `AskUserQuestion` 을 쓰면 파일럿의 "Cross-runtime interactive input" 블록(위 3런타임 매핑)을 같이 넣거나, 이관을 미룰 경우 `scripts/check-skill-tool-portability.mjs` 의 baseline 에 등록한다. `scripts/check-skill-tool-portability.mjs --check` 가 `.githooks/pre-commit` + `.github/workflows/validate-codex.yml` 에서 이를 강제한다 — 파일럿은 표준 매핑을, baseline 은 등록 사실을, 그 외 새 경로는 실패로 잡는다.
- **Follow-up debt (#123):** 현재 파일럿은 `docs-forge:interview-methodology`, `github-dev:decompose-issue`, `council:convene`, `docs-forge:voice-prompt`, `llm-wiki:plaud-note-taking` 5개뿐이다. 나머지 15개 스킬(baseline)은 아직 body 에서 `AskUserQuestion` 을 실제로 하드코딩하고 있으며, 표준 매핑으로의 이관은 후속 플릿 작업으로 의도적으로 미룬다. Hermes 호환표 행이나 frontmatter `allowed-tools:` 에만 `AskUserQuestion` 이 있고 실제 대화 게이트가 없는 스킬은 debt 가 아니라 가드가 제외한다. baseline 에서 파일럿으로 옮기며 점진 이관한다.

## 플러그인 변경 규칙

- 플러그인 버전을 올릴 때는 `plugins/<name>/.claude-plugin/plugin.json`과 `.claude-plugin/marketplace.json`의 해당 항목을 같은 변경에 포함하세요.
- `plugins/<name>/` 아래 **어떤 파일이든** 바뀌면 버전 범프 대상입니다 — 코드/스킬뿐 아니라 번들 `references/`·`docs`·asset 편집도 포함. 캐시로 게이트된 사용자는 버전 범프가 있어야 새 내용을 받으므로, 문서만 고쳐도 해당 플러그인 PATCH + `metadata.version`을 올립니다 (Codex-eligible 이면 매니페스트 재생성). 반면 루트 문서(`AGENTS.md`, `README.md`, `code_review.md`, `.claude/rules/*`)는 플러그인 콘텐츠가 아니라 어떤 플러그인도 범프하지 않습니다.
- Hermes-eligible 플러그인: `plugins/<name>/plugin.yaml`(Hermes 어댑터)의 `version`은 `sync-hermes-manifests.mjs` 가 marketplace 에서 파생해 생성하므로, 버전 범프 후 `node scripts/sync-hermes-manifests.mjs` 재실행으로 갱신하세요. `sync-hermes-manifests.mjs --check` 가 drift 를 가드하므로 수동 동기화는 불필요합니다 (단 Codex `--check` 는 Codex 매니페스트만 봅니다).
- 어떤 플러그인 버전이든 변경하면 `.claude-plugin/marketplace.json`의 `metadata.version`도 marketplace release 버전으로 올리세요.
- 플러그인의 스킬을 다른 번들로 **흡수**할 때는 흡수처 배선이 아니라 **흡수된 스킬 본문을 먼저 감사**하세요. 배선은 쉬운 쪽이고, 깨지는 건 스킬이 여전히 자기를 옛 플러그인 소속으로 아는 부분입니다: Codex 캐시를 `*/<옛-플러그인>/*` 로 훑는 `PLUGIN_ROOT` resolver (`CLAUDE_PLUGIN_ROOT` 가 없는 순간 "script not resolved" 로 죽음), `hermes plugins install .../plugins/<옛-플러그인>` 안내, 이동으로 뒤집힌 Hermes eligibility 서술, 네임스페이스 없는 `/skill-name` 예제, 그리고 흡수처 버전 미범프(캐시로 게이트된 사용자에게 이동 자체가 안 내려감). 옮긴 트리에서 옛 플러그인명을 grep 해 확인하세요.
- **eligibility 는 그 플러그인의 스킬 전체에 걸립니다.** `HERMES_ELIGIBLE` 에 이름을 추가하면 생성된 어댑터가 그 `skills/` 전부를 등록하므로, Hermes 매핑이 필요 없던 스킬까지 노출됩니다 — 매핑 없는 본문은 로드된 뒤 첫 도구 호출에서 멈춥니다. `CODEX_EXCLUDED` 는 반대 방향으로 같은 논리입니다: 제외 대상을 번들에 넣으면 **번들 전체가** Codex 에서 빠지므로 `codex-image` 와 `council` 은 단독으로 둡니다.
- 플러그인을 추가하거나 제거하면 이 문서의 `## Plugins (N)` 수와 목록, `README.md`의 플러그인 수와 목록도 갱신하세요. 이 문서의 미러 카운트(Hermes allowlist `현재 N개`, Codex 검증 주석 `# N entries`)와 `README.md` 의 "CI 가드가 지키는 것" 절에 산문으로 적힌 총계(`총 N / Codex-eligible N / Hermes N`)도 같은 변경에서 함께 갱신하세요 — `--check` 가 못 잡습니다. 마지막 것은 `check-doc-consistency` 가 README 총계를 `(\d+) / (\d+) 플러그인` 형태로만 매칭하는데 그 문장은 숫자 뒤에 `플러그인` 이 없어서입니다. 가드가 자기 자신을 설명하는 문장이 stale 해도 가드는 통과합니다. 반대 방향도 규칙입니다 — 카운트가 자기 SoT 바로 옆에 있고(배열 바로 위 주석처럼) 어떤 가드도 검사하지 않는다면, 위 동기화 목록에 항목을 늘리지 말고 그 재진술 자체를 지우세요. SoT 를 읽으면 나오는 숫자를 손으로 유지하는 비용만 남고, 그 숫자를 검사하는 가드가 있다면 대개 실행할 때마다 라이브 값을 이미 출력합니다.
- 버전은 semver를 따릅니다. 버그 수정은 PATCH, 하위 호환 기능은 MINOR, 깨지는 변경은 MAJOR입니다. 단 이 semver 규칙이 적용되는 대상은 per-plugin `version` 뿐입니다 — `.claude-plugin/marketplace.json` 의 `metadata.version` 은 semver 가 아니라 릴리스 카운터라, 소비자에게 하위 호환이 깨지는 변경(플러그인 제거 등)이어도 MINOR 로 올립니다. 어느 쪽 규칙이 걸리는지는 변경의 성격이 아니라 **어느 버전 필드를 만지는가**로 갈립니다. 리뷰어가 `metadata.version` 을 "깨지는 변경 → MAJOR" 로 지적하면 오탐이며, 근거는 `.claude/rules/plugin-versioning.md` 의 "Plugin Removal" 절입니다.
- Claude Code 플러그인 캐시 이슈 때문에 사용자 문서나 릴리스 안내에는 필요 시 `rm -rf ~/.claude/plugins/cache/my-claude-plugins/` 후 marketplace update 및 Claude Code 재시작 절차를 유지하세요.

## Modular Rules

`.claude/rules/*.md` is auto-loaded by Claude Code — no `@import` required, and Codex/Hermes cannot read the directory at all (their mirror is the "멀티런타임 통합" section above). A rule carrying `paths:` frontmatter loads only when Claude touches a matching file; `@import`ing that same rule expands it unconditionally at launch and kills the scoping, so the first pointer below is deliberately plain (backticks, not `@`).

- `.claude/rules/plugin-versioning.md` — plugin version bump contract and cache-refresh workflow. Scoped via `paths:` to the manifest files, so it loads only when you touch them.
- `.claude/rules/state-envelope.md` — the state-envelope v0 run-record convention (`.claude/state/<pipeline>-<key>.json` + archive rotation + per-skill jq, no shared library). Scoped via `paths:` to `.claude/state/*.json`. Its concept mirror for Codex/Hermes is the "State-envelope 실행 기록" section below.
- `.claude/rules/dual-integration.md` — keeping the Claude Code, Codex, and Hermes surfaces in sync when editing guidance, hooks, or derived artifacts. Scoped via `paths:` to the paired surfaces themselves (`AGENTS.md`, `.claude/rules/`, plugin manifests / hooks / skill bodies, the generators). The always-loaded summary is the "멀티런타임 통합" section above — which is also the only copy Codex and Hermes read — so the full rule loads lazily when you actually touch a paired surface. Pointer is deliberately plain (backticks, not `@`): an `@import` would expand it at launch and kill the scoping.

## State-envelope 실행 기록 (run records, v0)

> `.claude/rules/state-envelope.md` 의 Codex/Hermes 미러다 (그 두 런타임은 `.claude/rules/` 를 못 읽는다). Claude 는 위 `## Modular Rules` 포인터로 원본 규칙에 닿고, Codex/Hermes 에게는 이 미러가 유일 소스이므로 실행 jq 를 아래에 그대로 싣는다 (규칙 파일로 미루지 않는다).

여러 단계로 이어지는 파이프라인 스킬이 자기 진행 상태를 기계가 읽을 수 있게 남기는 per-run 상태 파일 규약이다. v0 는 **문서화된 규약 + per-skill `jq`** 일 뿐, **공유 라이브러리/스크립트를 두지 않는다**. 각 채택 스킬이 자기 본문에 jq 를 인라인한다.

- **위치·회전**: live 파일은 `.claude/state/<pipeline>-<key>.json` (예: `post-merge-114.json`, 기존 `cr-fix-<PR>.json` 명명 미러). 같은 key 로 재실행하면 새로 쓰기 전에 이전 live 파일을 `.claude/state/archive/<pipeline>-<key>-<timestamp>-$$.json` 로 회전한다 (cr-fix Step 2 미러). `.claude/state/` 는 gitignore + 머신 로컬 — run record 는 절대 커밋하지 않고 스킬의 `RUN_TOUCHED` 스테이징 집합에도 넣지 않는다.
- **스키마**: `{schema:"state-envelope/v0", run_id, status(queued|in_progress|completed), conclusion, started_at, updated_at, anchor_sha, attempt, session_id, steps[]}`. `steps[]` 는 top-level 단계가 닫힐 때마다 `{step, status: done|skipped, reason?}` 한 항목 (`reason` 은 skipped 에만).
- **spec-state 와 직교(orthogonal)**: run record 는 `.claude/state/spec.json` 이 **아니다**. `spec.json` (owner: `github-dev:state-tracker`) 은 spec→issue→PR 파이프라인의 크로스런 집계이고, run record 는 스킬 단일 실행의 단계 로그다. 서로 다른 파일·다른 소유자이며 서로 읽거나 쓰지 않는다.
- **v0 채택자**: `github-dev:post-merge` (Step 1-10 per-step 기록) 와 `project-init:new` (Phase 0.5 run record — resume 지원 + fail-loud 쓰기). 다른 스킬 상태 파일의 retrofit 은 후속 변경으로 의도적으로 미룬다.

**실행 jq (Codex/Hermes 자립용 — Claude 도 동일 패턴).** 채택 스킬이 본문에 인라인한다 (공유 라이브러리 없음). Init 은 archive 회전 실패 시 이전 기록을 덮어쓰지 않도록 abort 한다:

```bash
REC=".claude/state/<pipeline>-<key>.json"; mkdir -p .claude/state/archive
if [ -f "$REC" ]; then
  mv "$REC" ".claude/state/archive/<pipeline>-<key>-$(date +%Y%m%d-%H%M%S)-$$.json" \
    || { echo "state-envelope: archive rotation failed" >&2; exit 1; }
fi
jq -n --arg rid "<pipeline>-<key>" --arg sha "$ANCHOR_SHA" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{schema:"state-envelope/v0", run_id:$rid, status:"in_progress", conclusion:null,
    started_at:$now, updated_at:$now, anchor_sha:($sha // null), attempt:1,
    session_id:(env.CLAUDE_SESSION_ID // null), steps:[]}' > "$REC"
```

각 단계가 닫힐 때 한 항목 append, 마지막에 finalize — shell 상태는 tool 호출 간 유지되지 않으므로 함수가 아니라 인라인 jq 로 (`reason` 은 skip 에만):

```bash
# record a completed step:
tmp=$(mktemp); jq --argjson step "$N" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '.updated_at=$now | .steps += [{step:$step, status:"done"}]' "$REC" > "$tmp" && mv "$tmp" "$REC"
# record a skipped step — reason is REQUIRED; guard it so a skip is never written without one:
[ -n "$reason" ] || { echo "state-envelope: a skipped step needs a reason" >&2; exit 1; }
tmp=$(mktemp); jq --argjson step "$N" --arg reason "$reason" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '.updated_at=$now | .steps += [{step:$step, status:"skipped", reason:$reason}]' "$REC" > "$tmp" && mv "$tmp" "$REC"
# finalize (terminal):
tmp=$(mktemp); jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '.status="completed" | .conclusion="success" | .updated_at=$now' "$REC" > "$tmp" && mv "$tmp" "$REC"
```

## Setup answers

`/project-init:wiring` records decisions the filesystem cannot infer — whether this project wants a git remote, whether its deliverables go to Drive — in `.claude/state/wiring.json` (gitignored; values are machine-local). Read that file before re-asking.

## cr-fix 경로 이식성 (해소됨)

cr-fix 의 스크립트·레퍼런스 경로는 `plugins/github-dev/skills/cr-fix/SKILL.md` Step 1 의 `SKILL_DIR` resolver (`CLAUDE_PLUGIN_ROOT` → 소스트리 `plugins/github-dev/skills/cr-fix` → Codex 캐시 → Hermes 순) 로 해소된다. 이후 모든 bash 블록은 하드코딩 경로가 아니라 `$SKILL_DIR/scripts/...`·`$SKILL_DIR/references/...` 를 경유하므로 marketplace dogfood 뿐 아니라 일반 user repo·Codex·Hermes 에서도 동작한다. SKILL.md 에 남은 `plugins/github-dev/skills/cr-fix` 리터럴은 전부 resolver 의 fallback 분기 내부이며, `tests/run-tests.sh` 의 "Step 1 SKILL_DIR resolver" 케이스가 회귀를 가드한다.

## Codex 통합 (shared-source)

```bash
node scripts/sync-codex-manifests.mjs           # write manifests
node scripts/sync-codex-manifests.mjs --check   # CI drift guard
```

- Claude 와 Codex 0.135 가 **동일한** `plugins/<name>/` 트리를 직접 읽습니다. 별도 mirror / body transform 없음 (구 `codex-bridge` 플러그인은 1.40.0 에서 제거). Skill 본문은 in-place 로 읽히므로 transform 이 없고, frontmatter 유효성만 남습니다.
- 생성물은 `.agents/plugins/marketplace.json` + 플러그인별 `.codex-plugin/plugin.json`, eligible 12개 대상. `.agents/` 와 `plugins/<name>/.codex-plugin/` 하위 파일은 손으로 편집하지 마세요 — `scripts/sync-codex-manifests.mjs` 가 진실의 원천입니다.
- 새 플러그인 추가 / 기존 플러그인의 `version` / `description` / `category` 변경 시 반드시 `node scripts/sync-codex-manifests.mjs` 를 실행해 매니페스트를 재생성하세요. `--check` 는 플러그인 제거 후 남은 orphan 매니페스트도 감지합니다.
- Skill `description` frontmatter 는 1024자 미만으로 유지하세요. Codex 0.135 는 1024자 초과 description 을 가진 skill 을 **silent 하게 skip** 합니다 (Claude Code 는 제한이 없어 위반이 안 보임). `--check` 가 drift 외에 description 길이도 검증하고, 공유 `.githooks/pre-commit` 이 매 커밋마다 실행합니다 — clone 당 한 번 `git config core.hooksPath .githooks` 로 활성화하세요. 전체 trigger 목록 / per-tool rationale 는 description 이 아니라 skill 본문에 두세요.
- Skill `description` frontmatter 에 콜론+공백(`: `) 이 들어가면 반드시 따옴표로 감싸세요 (또는 `>-` block scalar). 안 하면 YAML frontmatter 가 nested mapping 으로 파싱돼 `mapping values are not allowed here` 로 실패하고 skill 이 양쪽 런타임에서 silent 하게 로드 안 됩니다. `plugin.json` / `marketplace.json` 은 JSON 이라 무관; lenient 매니페스트 생성기와 `--check` 는 못 잡습니다.
- Codex 0.135 manifest top-level 은 `skills` / `hooks` / `mcpServers` / `apps` 만 지원합니다 (참조: `~/.codex/skills/.system/plugin-creator/references/plugin-json-spec.md`). `commands` / `agents` 는 생성기가 emit 하지 않습니다 — Claude 만 인식하는 필드입니다.
- **번들 Codex hooks**: 플러그인이 소스 관리되는 `hooks/codex-hooks.json` 디스크립터를 실으면 생성기가 이를 매니페스트 top-level `hooks: "./hooks/codex-hooks.json"` 로 배선합니다 (Codex 는 이 파일명을 기본 탐색 `hooks/hooks.json` 로 자동 발견하지 못하므로 매니페스트 선언이 필수). 디스크립터 shape 는 `{ "hooks": { <Event>: [ { "matcher"?, "hooks": [ { "type":"command", "command": "bash \"$PLUGIN_ROOT/…\"" } ] } ] } }` — 이벤트명은 Codex hook 이벤트 집합 (`UserPromptSubmit` / `SessionStart` / `Stop` / `SubagentStop` / `PostToolUse` 등), plugin-root env-var 는 `PLUGIN_ROOT` (`CLAUDE_PLUGIN_ROOT` 는 호환 alias), 경로에 공백이 있을 수 있어 따옴표로 감쌉니다. `--check` 가 디스크립터 파싱·shape·참조 스크립트 존재·orphan (`hooks` 선언 있는데 소스 없음) 을 검증합니다 (`scripts/sync-codex-manifests.test.mjs` 가 fixture 로 RED/GREEN 커버). Codex hook 은 여전히 `/hooks` trust 승인이 필요합니다. `UserPromptSubmit`/`PostToolUse` 훅은 plain stdout 이 아니라 `hookSpecificOutput.additionalContext` JSON 을 내보내야 Codex 가 읽습니다 (공유 스크립트는 `codex` 인자로 분기: core-config `prompt_inject.sh`, llm-wiki `wiki_stale_check.sh` / `wiki_post_commit_hint.sh`).
- Codex 에서 제외할 플러그인은 `scripts/manifest-eligibility.mjs` 의 `CODEX_EXCLUDED` 셋에 등록하세요 (현재: `codex-image`, `council` 둘). `codex-image` 는 Claude->Codex 브리지라 Codex 로 sync 하면 순환입니다. `council` 은 codex 를 의석으로 앉히므로 Codex 에서 돌리면 codex 가 자기 자신을 소환하는 순환이고, Claude 의석이 Agent 도구를 필요로 하는데 Codex 에는 대응 표면이 없습니다. `core-config` 는 skill 이 없지만 이제 번들 Codex hooks (`hooks/codex-hooks.json`) 를 실어 hooks-only 매니페스트로 sync 되므로 더 이상 제외 대상이 아닙니다 (native Codex `UserPromptSubmit` 훅). 이후 marketplace 에서 제거된 플러그인은 EXCLUDED 에 남길 필요 없습니다 — drift 가드의 orphan 감지가 매니페스트 잔존을 잡아냅니다.
- 생성기는 Node 18+ built-in 만 사용합니다. 런타임 의존성을 추가하지 마세요.

## Hermes 통합 (shared-source)

```bash
node scripts/sync-hermes-manifests.mjs           # write adapters
node scripts/sync-hermes-manifests.mjs --check   # CI drift guard (validate-codex.yml + .githooks/pre-commit)
```

- Hermes Agent 도 **동일한** `plugins/<name>/` 트리를 직접 읽습니다. 어댑터(`plugin.yaml` + `__init__.py`)는 `scripts/sync-hermes-manifests.mjs` 가 `.claude-plugin/marketplace.json` 으로부터 생성합니다 — `plugins/<name>/plugin.yaml` / `__init__.py` 를 손으로 편집하지 마세요.
- 대상은 생성기의 `HERMES_ELIGIBLE` allowlist (Codex `EXCLUDED` denylist 의 대칭). 현재 4개: `github-dev`, `docs-forge`, `code-scout`, `ml-toolkit`. 커버리지 확장은 allowlist 에 이름 추가.
- Hermes-eligible 플러그인의 `version` / `description` 을 바꾸면 `node scripts/sync-hermes-manifests.mjs` 를 실행해 어댑터를 재생성하세요. `plugin.yaml` 의 `version` 은 marketplace 파생이므로 `--check` 가 drift + orphan 어댑터를 잡습니다 (수동 동기화 불필요 — 생성으로 해소).
- `__init__.py` 는 `skills/*/SKILL.md` 를 `<plugin>:<skill>` 으로 등록하는 제네릭 엔트리포인트입니다 (플러그인별 로직 없음, `import yaml`=PyYAML 가정).
- 공유 skill 본문은 3런타임 포터블이어야 합니다. Claude/Codex 는 도구명이 동일하므로, 본문에 Claude/Codex 도구 용어를 Hermes 도구로 매핑하는 호환 표(`Bash`→`terminal`, `Read`→`read_file`, `Edit`→`patch`, `AskUserQuestion`→`clarify`, `Task`→`delegate_task`, `Skill`→`skill_view`, 이미지 생성→`image_generate`, `NotebookEdit`→Hermes Jupyter Live Kernel / `write_file`·`patch` 등)를 둡니다. 새 skill 추가/도구 사용 변경 시 이 표를 점검하세요. 신규·편집 skill 은 이 표를 본문마다 다시 타이핑하는 대신 번들 `references/<harness>-tools.md` 로 중앙화하고 본문이 그것을 가리키는 형태를 우선합니다 — 점진 이관이므로 이미 그 본문의 도구 사용을 편집 중일 때만 채택하고, 표를 옮기려고 기존 본문을 새로 쓰지는 않습니다 (surgical-diff).
- 번들 `scripts/` 를 호출하는 skill 본문은 `${CLAUDE_PLUGIN_ROOT}` 를 그대로 쓰지 마세요 — Codex 0.135 는 이 변수를 export 하지 않아 첫 단계에서 실패합니다. 크로스 런타임 `PLUGIN_ROOT` resolver 블록(`CLAUDE_PLUGIN_ROOT` → 소스트리 `plugins/<name>` → Codex 캐시 탐색)을 본문에 포함하세요 (레퍼런스 구현: project-init, mem0-ops).
- Hermes plugin 스킬은 **명시 로드**입니다 (passive index 아님) — Claude Code/Codex 0.135 가 `description` 으로 skill 을 자동 표면화하는 것과 달리, Hermes 는 `--enable` 후 새 세션에서 `skill_view("<plugin>:<skill>")` 로 명시 호출해야만 로드됩니다. trigger 문구는 여전히 `description` 에 두되 로드 자체는 의도된 호출이므로, "description 으로 자동 선택됐다" 고 가정하는 본문은 Hermes 에서 틀립니다 (본문 상단 Hermes 호환 노트를 로드 계약으로 취급). 어댑터와 무관한 스킬 단위 설치는 `node scripts/install-skills.mjs` (`npx skills`) 로 가능합니다.
- 생성기는 Node 18+ built-in 만 사용합니다. 런타임 의존성을 추가하지 마세요.

## 검증

- Codex / Hermes 매니페스트 drift 가드 (모든 PR 에서 실행):

```bash
node scripts/sync-codex-manifests.mjs --check
node scripts/sync-hermes-manifests.mjs --check
node scripts/check-doc-consistency.mjs
node scripts/check-shell-portability.mjs
```

`check-doc-consistency.mjs` 는 README 구조 트리·`## Plugins` 표·문서에 박힌 카운트 문자열을 marketplace.json 과 대조하고 `.githooks/pre-commit` 에서 차단한다. 문서 블록이 관례가 아니라 기계적으로 강제된다는 뜻이므로, 어떤 문서 내용을 "코드에서 재생성 가능하니 지워도 된다" 고 판단하기 전에 훅이 그 블록을 요구하는지 먼저 확인한다. 가드 6종 전체 설명은 `README.md` 의 "CI 가드가 지키는 것".

`check-shell-portability.mjs` 는 `code_review.md` P1 의 크로스플랫폼 규칙을 기계적으로 강제한다 — GNU 전용 구문(`md5sum`·`sed -i`·`grep -P`·`date -d`·`stat -c`·`timeout`·`${VAR,,}`·`mapfile`·`declare -A` 등)이 **폴백도 capability probe 도 없이** 쓰인 경우만 잡는다. 정상 폴백 쌍(`stat -c … || stat -f …`)과 probe 분기는 통과하며, 증거는 **코드여야 하고 주석은 인정하지 않는다** (대체재를 언급하는 주석이 실제 폴백으로 계수되면 이 가드가 존재하는 이유인 `md5sum` 자체가 새어나간다). 정말 예외인 줄은 `# portability-ok: <사유>` 로 표시한다. `.llmwiki/`·`.claude/spec/`·`code_review.md`·`AGENTS.md` 는 그 구문을 *설명*할 뿐이라 스캔에서 제외된다.

macOS CI 레그(`validate-codex.yml` 의 `macos` job)는 BSD 폴백이 실제로 실행되는 유일한 지점이다. `env -i PATH=/usr/bin:/bin` 는 쓰지 않는다 — macOS 에서 `jq` 가 Homebrew 경로에 있어 스위트가 도구 부재로 죽는다. 대신 `sed`/`date`/`stat` 이 `--version` 을 거부하는지(=BSD 빌드인지) assert 하고, Homebrew coreutils 가 시스템 도구를 가리면 시끄럽게 실패시킨다. 스위트는 `bash` 가 아니라 `/bin/bash` 로 돌려 bash 3.2 를 강제한다 (러너 PATH 의 Homebrew bash 5 로 돌면 bash-4 전용 구문이 여기서 통과하고 사용자에게서 깨진다).

- 로컬 Codex CLI 에서 marketplace 등록 확인:

```bash
codex plugin marketplace add ~/.claude/plugins/marketplaces/my-claude-plugins
codex plugin list --marketplace my-claude-plugins   # 12 entries
codex plugin marketplace remove my-claude-plugins   # 검증 후 정리
```

- Python 테스트가 필요한 경우 해당 플러그인 디렉터리에서 `uv run pytest`를 우선 사용하세요.

## 문서 작성 스타일

- 사용자-facing 문서는 한국어 설명을 자연스럽게 유지하고, 명령어와 경로는 코드 포맷으로 표기하세요.
- README류 문서는 실제 설치/사용 흐름을 우선하고, 플러그인 수, 플러그인 이름, 명령어 예시는 매니페스트와 일치시켜야 합니다.
- 큰 구조 변경 없이 문서만 보강하는 경우에도 관련 count, badge, 목록이 stale하지 않은지 확인하세요.

## Review guidelines

> 이 섹션은 Codex GitHub cloud reviewer 가 자동으로 읽는 영역이다. 한국어로 리뷰한다. 발견사항은 영향 + 근거 (파일/라인) + 수정 방향 순서로 제시한다. 근거가 부족하면 `unverified` 로 표시한다.
>
> **상세 리뷰 룰 (Do-not-flag / P0 / P1 / Domain-specific 전문) 은 루트 [`code_review.md`](code_review.md) 로 분리했다.** OpenAI Codex best-practices 문서 기준, `AGENTS.md` 가 참조하는 `code_review.md` 를 리뷰어가 리뷰 시 따라가 읽을 수 있다 (소프트 개런티 — <https://developers.openai.com/codex/learn/best-practices>). 이 `## Review guidelines` 섹션 자체는 리뷰어 시스템 프롬프트에 **직접** 로드되므로 (하드 개런티), 아래에 핵심 최소본을 인라인으로 남겨 `code_review.md` 를 따라가지 못하는 경우에도 P0/P1 은 항상 적용되게 한다. GitHub cloud reviewer 는 P0/P1 만 코멘트로 표면화한다 (<https://developers.openai.com/codex/code-review>).

### 핵심 최소본 (전문은 `code_review.md`)
- **P0 (must-block)** — secret/token 노출, 사용자 확인 없는 destructive `gh` 명령 (`gh pr merge` / `gh repo create` / `gh api`), Codex 매니페스트 (`.agents/**`, `plugins/*/.codex-plugin/**`) 손편집, shell injection (사용자 입력 unquoted).
- **P1 (should-block)** — 모든 should-block 규칙은 하드 유지한다 (soft-follow 미검증이므로 code_review.md 로 demote 하지 않는다): plugin version/count drift (`plugin.json` ↔ `marketplace.json` ↔ AGENTS 플러그인 목록·README 트리·배지·`metadata.version`), idempotency 회귀 (재실행 시 사용자 파일 덮어쓰기·`nothing to commit` abort·`origin` 충돌), cross-platform shell 가정 (`sed -i`·`realpath -m`·`md5sum`·`date -d`·`stat -c`·`timeout` GNU-only / `${VAR,,}` Bash 4+ / 이식성 수정은 양방향 — `python`→`python3` 는 macOS 를 고치고 Windows 를 깬다, 인터프리터는 이름 고정이 아니라 탐지), `gh api --paginate`+`--jq` 에 `--slurp` 누락, sed 치환 안전성 (`&`·구분자·`\` escape, 사용자 입력 정화), API 실패를 빈 결과로 삼키는 패턴 (`gh api ... || echo "[]"`) 과 그 write 쪽 쌍 (변환 실패 결과를 검사 없이 `gh issue/pr edit --body` 로 내보내 원격 본문을 공백으로 파괴), 종료 상태가 사라지는 자리 (파이프라인 중간 명령은 `set -e` 를 발동시키지 못한다 / 상태 자체가 검사 신호인 자리의 `|| true` / `cmd -v X && X … || true` 는 "X 없음"만이 아니라 "X 실행 실패"까지 삼키므로 `if …; then …; fi` 로 흡수 범위를 한정), skill/command frontmatter `name`/`description` 누락·오류, `Read`/`Edit` 영역을 `Bash cat`/`sed` 로 우회, 새 dependency·GitHub Actions·CI/CD 권한 변경 (최소 권한·lockfile·supply-chain).
- **Do not flag** — 포매터 영역 (들여쓰기·따옴표·trailing whitespace), import 순서, 단순 typo, 루트 `CLAUDE.md` 가 `@AGENTS.md` 한 줄 포인터인 것 ("CLAUDE.md 가 없다/내용 없다" 지적은 오탐 — 역방향도 오탐으로, 이 규칙은 루트 한정이라 `plugins/<name>/CLAUDE.md` 가 내용을 갖는 것은 정상이다).
- 위 P0/P1/Do-not-flag 은 하드 최소본이다. **elaboration 만 soft** — 발견사항 제시 순서, Domain-specific 플러그인 추가/제거·skill 추가 문서 동기화 상세 체크리스트, 도입-버전 마커 오탐 예외, plugin-cache refresh 등 **전문은 [`code_review.md`](code_review.md)**.

## CodeRabbit / Codex 조율

이 저장소는 PR 머지 전 자동 리뷰로 **CodeRabbit + ChatGPT-Codex** 를 사용한다. `/github-dev:cr-fix` 스킬이 양쪽을 동시에 처리한다 (`plugins/github-dev/skills/cr-fix/SKILL.md` + `references/` + `scripts/`). PR-bot rate-limit 시 `--cr-source auto` 가 로컬 `coderabbit` CLI 또는 Codex-only 로 silent fallback (~30s 감지, 1800s spin 해소).

| Source | Tier 정책 |
|--------|-----------|
| CR `🚨 Bug` / `⚠️ Potential issue` / `🔒 Security` / `🔴 Critical-High` / `🟠 Major` | `gated` — per-issue 확인 |
| CR `🛠️ Refactor` (`🟡 Minor` / `🟢 Trivial` / `🟢 Info`) | `auto` — 자동 적용 |
| CR `📝 Nitpick` | `skip` |
| Codex P1 (red), P2 (yellow) | `gated` |
| Codex P3 (green) | `skip` |

cr-fix 기본 동작 (둘 다 default ON, opt-out flag): **minor soft-stop** — iter 2 부터 low-severity-only 사이클(deferred 0)이면 `final_state=minor_floor` 로 조기 정지(auto-merge 불가, `user_declined` 동급), `--no-minor-stop` 으로 비활성화. **same-file generalization** — `real` + high-confidence + grep 가능한 finding 은 같은 파일 내 동일 패턴 형제 위치도 같은 커밋에 수정(cross-file 절대 금지, `generalized_to` audit log), `--no-generalize` 으로 비활성화. `/github-dev:post-merge` 는 머지 후 cr-fix state 파일의 deferred/cap-stopped 항목을 `leftover-reviews:` 체크포인트 한 줄로 surface 한다 (informational, 정리 차단 안 함).
