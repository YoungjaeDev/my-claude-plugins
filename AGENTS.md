# AGENTS.md

> 이 파일이 정본이다. 루트 `CLAUDE.md` 는 `@AGENTS.md` 한 줄로 이 파일을 import 하는 포인터일 뿐이므로 편집은 항상 여기에 한다. Claude Code 는 `CLAUDE.md` 를 통해, Codex 는 `AGENTS.md` 를 직접 읽는다.

## 기본 원칙

- 이 저장소는 Claude Code 플러그인 marketplace 다. 변경 전에 이 문서, `README.md`, 해당 플러그인의 `plugins/<name>/CLAUDE.md` 를 먼저 읽는다.
- 사용자가 한국어로 요청하면 한국어로 응답한다.
- 변경은 요청 범위에만 한정하고, 관련 없는 파일이나 기존 사용자 변경을 되돌리지 않는다.
- 파일 탐색과 검색은 `rg`, `rg --files` 를 우선 쓴다.
- 라이브러리·런타임·플랫폼 사실은 `docs/llm-doc-sources.md` 의 LLM 문서 소스로 먼저 확인한다.
- lore 성 질문에 답하기 전에 `.llmwiki/wiki/index.md` 를 먼저 읽는다.
- 문서와 매니페스트가 함께 움직이는 저장소이므로 코드 변경 시 `README.md`, 이 문서, marketplace manifest 의 동기화 필요성을 항상 확인한다.

플러그인 트리 하나를 Claude Code 와 Codex CLI 가 함께 읽는다 (one source, two runtimes). Codex 는 `.claude-plugin/marketplace.json` 과 `plugins/*/.claude-plugin/plugin.json` 을 네이티브 폴백으로 직접 읽으므로 생성 계층이 없다.

## Plugins (8)

각 플러그인의 설명은 `jq -r '.plugins[] | "\(.name): \(.description)"' .claude-plugin/marketplace.json` 으로 읽는다. 아래 표는 이름과 분류만 유지하고, `check-doc-consistency.mjs` 가 이 이름 집합을 marketplace.json 과 대조한다.

| Plugin | Category | 흡수한 옛 플러그인 |
|--------|----------|-------------------|
| `core` | Core | core-config |
| `dev` | Development | github-dev, project-init, e2e-harness |
| `docs` | Documentation | docs-forge, publish |
| `scout` | Research & Search | code-scout, deepwiki, paper-search-tools |
| `ml` | Development | ml-toolkit |
| `wiki` | Memory & Lore | llm-wiki, mem0-ops |
| `council` | AI Models | (단독 유지, Claude 전용) |
| `codex-image` | AI Models | (단독 유지, Claude 전용) |

플러그인명을 짧게 둔 이유는 슬래시 자동완성이다. 플러그인 스킬은 항상 `/plugin:skill` 로 노출되고 매칭은 전체 이름 기준이라, 접두사가 길면 스킬명을 아무리 잘 지어도 찾기 어렵다. 플러그인은 `.claude/settings.json` 에서 auto-load 된다. 사용법은 `README.md`.

## 저장소 구조

디렉터리 배치는 `ls plugins/` 로 확인한다. 아래는 배치만 봐서는 알 수 없는 역할과 편집 금지 여부다.

- `AGENTS.md`: 이 문서. 두 런타임 공통 최상위 지침 + 플러그인 목록 + 변경 규칙.
- `CLAUDE.md`: `@AGENTS.md` 한 줄. Claude Code 진입점일 뿐 별도 내용이 없다.
- `CLAUDE.md.global`: 사용자 전역 지침의 저장소 정본 (Claude 와 Codex 공통). 고친 뒤 `cp CLAUDE.md.global ~/.claude/CLAUDE.md` 와 `cp CLAUDE.md.global ~/.codex/AGENTS.md` 로 두 런타임의 설치 사본을 갱신한다. 사본을 이 워킹트리로의 심볼릭 링크로 걸지 않는다 (브랜치 전환과 커밋 안 된 편집이 즉시 전역 지침으로 발효된다). 동기화 안내는 이 저장소에만 두고, 모든 프로젝트에서 로드되는 전역 파일에는 규칙 외의 줄을 넣지 않는다.
- `README.md`: 사용자용 설치·마이그레이션·플러그인 문서.
- `code_review.md`: Codex cloud reviewer 용 상세 리뷰 룰 (아래 `## Review guidelines` 가 참조).
- `.claude/settings.json`: 로컬 플러그인 auto-load 목록. 플러그인을 추가하면 여기도 등록한다 (어떤 가드도 누락을 잡지 않는다).
- `.claude-plugin/marketplace.json`: marketplace 레지스트리와 플러그인 버전. Codex 도 이 카탈로그를 읽는다.
- `.claude/rules/`: 경로 스코프 상세 규칙 (Claude 전용, Codex 는 못 읽는다). `plugin-versioning.md` 는 매니페스트를 만질 때, `state-envelope.md` 는 `.claude/state/*.json` 을 만질 때만 로드된다. 포인터를 `@import` 로 바꾸면 스코핑이 죽으므로 백틱으로 둔다.
- `plugins/<name>/`: 플러그인 원본. `.claude-plugin/plugin.json` 이 매니페스트이자 버전이며 두 런타임이 같은 파일을 읽는다. `hooks/codex-hooks.json` (core, wiki) 은 수동 `~/.codex/hooks.json` 등록의 문서화된 소스다.
- `scripts/`: 가드 스크립트. Node 18+ 내장 모듈만 쓰고 런타임 의존성을 추가하지 않는다.
- `.llmwiki/`: 두 런타임이 공유하는 lore 루트. per-agent 로 fork 하지 않고, wiki lore 를 `.claude/rules/` 로 승격하지 않는다 (Codex 가 못 읽는다). cross-agent 규칙은 `.llmwiki/insight/` 로 graduate 해 `core` 의 prompt-inject 훅으로 노출한다.

## Codex 통합

- `commands` / `agents` 는 Claude 전용 표면이다. Codex 는 미지원 필드를 무시하고 `skills/` 만 읽으므로, skill 로직을 agent 정의로 옮기지 않는다 (Codex 에서 조용히 사라진다).
- Skill `description` 은 1024자 미만으로 유지한다. Codex 는 초과 description 을 가진 skill 을 silent 하게 skip 하고 Claude 쪽에서는 위반이 보이지 않는다. `scripts/check-skill-contract.mjs` 가 검증한다.
- `description` 에 콜론+공백(`: `) 이 들어가면 따옴표로 감싼다. 안 하면 YAML 이 nested mapping 으로 파싱돼 두 런타임 모두에서 skill 이 로드되지 않는다.
- 번들 `scripts/` 를 부르는 skill 본문은 `${CLAUDE_PLUGIN_ROOT}` 를 그대로 쓰지 않는다. Codex 는 이 변수를 export 하지 않으므로 `CLAUDE_PLUGIN_ROOT` → 소스트리 `plugins/<name>` → Codex 캐시 순의 `PLUGIN_ROOT` resolver 블록을 본문에 둔다 (참조 구현: `dev:new`, `wiki:cleanup`).
- Codex 훅은 `codex plugin add` 만으로 실행되지 않는다. 수동 `~/.codex/hooks.json` 등록 후 `/hooks` 에서 trust 승인이 있어야 발화하고, 승인 전에는 아무 신호 없이 죽어 있다. `UserPromptSubmit`/`PostToolUse` 훅은 plain stdout 이 아니라 `hookSpecificOutput.additionalContext` JSON 을 내야 Codex 가 읽는다 (공유 스크립트는 `codex` 인자로 분기).
- 사용자에게 되묻는 상호작용은 capability-aware 게이트로 쓴다: Claude 는 `AskUserQuestion`, Codex 는 `request_user_input` (노출된 경우), 없으면 틀린 가정의 비용이 큰 지점에서만 짧은 blocking 질문 하나를 던지고 그 외에는 문서화된 안전한 기본값으로 진행한다.
- `AGENTS.md` 를 `CLAUDE.md` 로의 포인터로 축약하지 않는다. Codex 는 `@` 를 확장하지 않아 `@CLAUDE.md` 는 죽은 텍스트이고, Codex cloud reviewer 는 `## Review guidelines` 를 시스템 프롬프트에 직접 로드하므로 산문 redirect 를 따라가지 않는다. 실패는 조용하다.

## 플러그인 변경 규칙

- 버전을 올릴 때는 `plugins/<name>/.claude-plugin/plugin.json` 과 `.claude-plugin/marketplace.json` 의 해당 항목을 같은 변경에 포함한다. 어떤 플러그인 버전이든 바뀌면 `metadata.version` 도 올린다.
- `plugins/<name>/` 아래 어떤 파일이든 바뀌면 버전 범프 대상이다 (`references/`·asset 편집 포함). 캐시로 게이트된 사용자는 범프가 있어야 새 내용을 받는다. 루트 문서(`AGENTS.md`, `README.md`, `code_review.md`, `.claude/rules/*`)는 어떤 플러그인도 범프하지 않는다.
- per-plugin `version` 은 semver (PATCH 수정 / MINOR 기능 / MAJOR 깨짐). `metadata.version` 은 릴리스 카운터라 플러그인 제거처럼 깨지는 변경이어도 MINOR 로 올린다. 리뷰어가 이를 "MAJOR" 로 지적하면 오탐이며 근거는 `.claude/rules/plugin-versioning.md` 다. 이름이 바뀐 플러그인은 새 엔트리이므로 1.0.0 부터 시작한다.
- 스킬을 다른 번들로 흡수할 때는 배선이 아니라 흡수된 스킬 본문을 먼저 감사한다. 깨지는 것은 스킬이 자기를 옛 플러그인 소속으로 아는 부분이다: Codex 캐시를 `*/<옛-플러그인>/*` 로 훑는 resolver, 네임스페이스 없는 `/skill-name` 예제, 흡수처 버전 미범프. 옮긴 트리에서 옛 플러그인명을 grep 해 확인한다.
- 플러그인을 추가·제거하면 이 문서의 `## Plugins (N)` 표, `README.md` 의 배지·"N개 플러그인 모음"·목록·상세·구조 트리, `.claude/settings.json` 을 같은 변경에서 갱신한다. `check-doc-consistency.mjs` 가 이름 집합과 카운트를 대조한다.
- 도입 시점을 기록한 버전 마커(예: "0.7.0부터")는 역사이므로 버전 sweep 에서 건드리지 않는다.
- 사용자 문서와 릴리스 안내에는 `rm -rf ~/.claude/plugins/cache/my-claude-plugins/` 후 marketplace update + Claude Code 재시작 절차를 유지한다 (플러그인 캐시 버그).

## 검증

```bash
git add -A                                  # 가드는 git-tracked 파일만 스캔한다
node scripts/check-doc-consistency.mjs
node scripts/check-shell-portability.mjs
node scripts/check-shell-portability.test.mjs
node scripts/check-skill-contract.mjs
node scripts/windows-codex-hooks.test.mjs   # Windows 에서만 실행, 그 외 skip
bash plugins/dev/skills/cr-fix/tests/run-tests.sh
bash plugins/council/skills/convene/tests/run-tests.sh
```

- `.githooks/pre-commit` 이 매 커밋마다 같은 가드를 돌린다. clone 당 한 번 `git config core.hooksPath .githooks` 로 활성화한다.
- `check-shell-portability.mjs` 는 GNU 전용 셸 구문이 폴백도 capability probe 도 없이 쓰인 경우만 잡는다. 증거는 코드여야 하고 주석은 인정하지 않는다. 예외는 `# portability-ok: <사유>` 로 표시한다. 상세는 `README.md` 의 "CI 가드가 지키는 것".
- macOS CI 레그(`validate-codex.yml` 의 `macos` job)가 BSD 폴백이 실제로 실행되는 유일한 지점이다. `/bin/bash` 로 돌려 bash 3.2 를 강제한다.
- Codex 카탈로그 확인: `codex plugin marketplace add "$PWD" && codex plugin list --marketplace my-claude-plugins && codex plugin marketplace remove my-claude-plugins` (8 entries).
- Python 테스트는 해당 플러그인 디렉터리에서 `uv run pytest`.

## 문서 작성 스타일

- 사용자-facing 문서는 한국어 설명을 유지하고, 명령어와 경로는 코드 포맷으로 쓴다.
- README 류는 실제 설치·사용 흐름을 우선하고, 플러그인 수·이름·명령어 예시는 매니페스트와 일치시킨다.
- 스킬 본문과 플러그인 `CLAUDE.md` 는 영어로 쓴다 (두 런타임과 Codex cloud reviewer 가 한 언어를 읽는다). 도메인 콘텐츠와 `description:` 의 한국어 트리거 문구는 예외다.

## Review guidelines

> 이 섹션은 Codex GitHub cloud reviewer 가 자동으로 읽는 영역이다. 한국어로 리뷰한다. 발견사항은 영향 + 근거 (파일/라인) + 수정 방향 순서로 제시한다. 근거가 부족하면 `unverified` 로 표시한다.
>
> **상세 리뷰 룰 (Do-not-flag / P0 / P1 / Domain-specific 전문) 은 루트 [`code_review.md`](code_review.md) 로 분리했다.** OpenAI Codex best-practices 문서 기준, `AGENTS.md` 가 참조하는 `code_review.md` 를 리뷰어가 리뷰 시 따라가 읽을 수 있다 (소프트 개런티 — <https://developers.openai.com/codex/learn/best-practices>). 이 `## Review guidelines` 섹션 자체는 리뷰어 시스템 프롬프트에 **직접** 로드되므로 (하드 개런티), 아래에 핵심 최소본을 인라인으로 남겨 `code_review.md` 를 따라가지 못하는 경우에도 P0/P1 은 항상 적용되게 한다. GitHub cloud reviewer 는 P0/P1 만 코멘트로 표면화한다 (<https://developers.openai.com/codex/code-review>).

### 핵심 최소본 (전문은 `code_review.md`)
- **P0 (must-block)** — secret/token 노출, 사용자 확인 없는 destructive `gh` 명령 (`gh pr merge` / `gh repo create` / `gh api`), shell injection (사용자 입력 unquoted).
- **P1 (should-block)** — 모든 should-block 규칙은 하드 유지한다 (soft-follow 미검증이므로 code_review.md 로 demote 하지 않는다): plugin version/count drift (`plugin.json` ↔ `marketplace.json` ↔ AGENTS 플러그인 목록·README 트리·배지·`metadata.version`), idempotency 회귀 (재실행 시 사용자 파일 덮어쓰기·`nothing to commit` abort·`origin` 충돌), cross-platform shell 가정 (`sed -i`·`realpath -m`·`md5sum`·`date -d`·`stat -c`·`timeout` GNU-only / `${VAR,,}` Bash 4+ / zsh 는 인용 없는 파라미터를 단어 분리하지 않아 `cmd $MULTI_VALUE` 가 한 인자로 넘어감, `set -o shwordsplit 2>/dev/null || true` 로 요청 / 이식성 수정은 양방향 — `python`→`python3` 는 macOS 를 고치고 Windows 를 깬다, 인터프리터는 이름 고정이 아니라 탐지), `gh api --paginate`+`--jq` 에 `--slurp` 누락, sed 치환 안전성 (`&`·구분자·`\` escape, 사용자 입력 정화), API 실패를 빈 결과로 삼키는 패턴 (`gh api ... || echo "[]"`) 과 그 write 쪽 쌍 (변환 실패 결과를 검사 없이 `gh issue/pr edit --body` 로 내보내 원격 본문을 공백으로 파괴), 종료 상태가 사라지는 자리 (파이프라인 중간 명령은 `set -e` 를 발동시키지 못한다 / 상태 자체가 검사 신호인 자리의 `|| true` / `cmd -v X && X … || true` 는 "X 없음"만이 아니라 "X 실행 실패"까지 삼키므로 `if …; then …; fi` 로 흡수 범위를 한정), skill/command frontmatter `name`/`description` 누락·오류, `Read`/`Edit` 영역을 `Bash cat`/`sed` 로 우회, 새 dependency·GitHub Actions·CI/CD 권한 변경 (최소 권한·lockfile·supply-chain).
- **Do not flag** — 포매터 영역 (들여쓰기·따옴표·trailing whitespace), import 순서, 단순 typo, 루트 `CLAUDE.md` 가 `@AGENTS.md` 한 줄 포인터인 것 ("CLAUDE.md 가 없다/내용 없다" 지적은 오탐 — 역방향도 오탐으로, 이 규칙은 루트 한정이라 `plugins/<name>/CLAUDE.md` 가 내용을 갖는 것은 정상이다).
- 위 P0/P1/Do-not-flag 은 하드 최소본이다. **elaboration 만 soft** — 발견사항 제시 순서, Domain-specific 플러그인 추가/제거·skill 추가 문서 동기화 상세 체크리스트, 도입-버전 마커 오탐 예외, plugin-cache refresh 등 **전문은 [`code_review.md`](code_review.md)**.

## CodeRabbit / Codex 조율

이 저장소는 PR 머지 전 자동 리뷰로 **CodeRabbit + ChatGPT-Codex** 를 사용한다. `/dev:cr-fix` 스킬이 양쪽을 동시에 처리한다 (`plugins/dev/skills/cr-fix/SKILL.md` + `references/` + `scripts/`). PR-bot rate-limit 시 `--cr-source auto` 가 로컬 `coderabbit` CLI 또는 Codex-only 로 silent fallback 한다.

| Source | Tier 정책 |
|--------|-----------|
| CR `🚨 Bug` / `⚠️ Potential issue` / `🔒 Security` / `🔴 Critical-High` / `🟠 Major` | `gated` — per-issue 확인 |
| CR `🛠️ Refactor` (`🟡 Minor` / `🟢 Trivial` / `🟢 Info`) | `auto` — 자동 적용 |
| CR `📝 Nitpick` | `skip` |
| Codex P1 (red), P2 (yellow) | `gated` |
| Codex P3 (green) | `skip` |

cr-fix 기본 동작 (둘 다 default ON, opt-out flag): **minor soft-stop** — iter 2 부터 low-severity-only 사이클(deferred 0)이면 `final_state=minor_floor` 로 조기 정지 (auto-merge 불가), `--no-minor-stop` 으로 비활성화. **same-file generalization** — `real` + high-confidence + grep 가능한 finding 은 같은 파일 내 동일 패턴 형제 위치도 같은 커밋에 수정 (cross-file 금지, `generalized_to` audit log), `--no-generalize` 으로 비활성화. `/dev:post-merge` 는 머지 후 cr-fix state 파일의 deferred/cap-stopped 항목을 `leftover-reviews:` 체크포인트 한 줄로 surface 한다.
