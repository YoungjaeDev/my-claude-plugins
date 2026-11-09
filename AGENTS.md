# AGENTS.md

> 이 파일이 정본이다. 루트 `CLAUDE.md` 는 `@AGENTS.md` 한 줄 포인터이므로 편집은 항상 여기에 한다 (Claude Code 는 `CLAUDE.md` 를 통해, Codex 는 직접 읽는다).

## 기본 원칙

- 이 저장소는 Claude Code 플러그인 marketplace 다. 변경 전에 이 문서, `README.md`, 해당 플러그인의 `plugins/<name>/CLAUDE.md` 를 먼저 읽는다.
- 사용자가 한국어로 요청하면 한국어로 응답한다.
- 변경은 요청 범위에만 한정하고, 관련 없는 파일이나 기존 사용자 변경을 되돌리지 않는다.
- 파일 탐색과 검색은 `rg`, `rg --files` 를 우선 쓴다.
- 라이브러리·런타임·플랫폼 사실은 기억이나 사본이 아니라 실행 시점에 확인한다: 벤더 공식 문서(`https://code.claude.com/docs/llms.txt`, `https://developers.openai.com/codex/llms.txt` 등)와 설치된 도구의 `--help`. 조회 순서와 실패 시 동작은 `plugins/docs/skills/skill-forge/references/live-lookup.md`.
- 설계 결정을 묻는 질문에는 `docs/adr/` 를, 용어는 `GLOSSARY.md` 를 먼저 읽는다. 이 저장소에는 `.llmwiki/` 가 없다 (바깥 지식이 없다).
- 코드 변경 시 `README.md`, 이 문서, marketplace manifest 의 동기화 필요성을 항상 확인한다.

플러그인 트리 하나를 Claude Code 와 Codex CLI 가 함께 읽고 (one source, two runtimes), Codex 는 두 매니페스트를 네이티브 폴백으로 직접 읽으므로 생성 계층이 없다.

## Plugins (9)

설명은 `jq -r '.plugins[] | "\(.name): \(.description)"' .claude-plugin/marketplace.json` 으로 읽는다. `check-doc-consistency.mjs` 가 아래 표의 이름 집합을 marketplace.json 과 대조한다.

| Plugin | Category | 런타임 |
|--------|----------|--------|
| `dev` | Development | 공통 |
| `docs` | Documentation | 공통 |
| `scout` | Research & Search | 공통 |
| `ml` | Development | 공통 |
| `wiki` | Outside Knowledge | 공통 |
| `deck` | Documentation | 공통 |
| `council` | AI Models | Claude 전용 |
| `codex-image` | AI Models | Claude 전용 |
| `aside` | Browser Automation | Claude 전용 |

플러그인 스킬은 항상 `/plugin:skill` 로 노출되고, 플러그인은 `.claude/settings.json` 에서 auto-load 된다. 사용법은 `README.md`.

## 저장소 구조

아래는 `ls` 로는 알 수 없는 역할과 편집 금지 여부다.

- `CLAUDE.md.global`: 사용자 전역 지침의 정본 (Claude·Codex 공통). 고친 뒤 `cp CLAUDE.md.global ~/.claude/CLAUDE.md` 와 `cp CLAUDE.md.global ~/.codex/AGENTS.md` 로 설치 사본을 갱신하고, 심볼릭 링크는 걸지 않는다 (브랜치 전환과 미커밋 편집이 즉시 전역에 발효된다). 동기화 안내는 이 저장소에만 두고 전역 파일에는 규칙 외의 줄을 넣지 않는다.
- `README.md`: 사용자용 설치·마이그레이션·플러그인 문서.
- `code_review.md`: Codex cloud reviewer 용 상세 리뷰 룰 (아래 `## Code Review Rules` 가 참조).
- `.claude/settings.json`: 로컬 플러그인 auto-load 목록. 플러그인을 추가하면 여기도 등록한다 (어떤 가드도 누락을 잡지 않는다).
- SessionStart 훅(`scripts/check-plugin-cache.mjs`)은 설치 캐시가 소스 버전보다 뒤처지거나 `core.hooksPath` 가 상대 경로 `.githooks` 가 아니면 경고한다 (절대 경로면 워크트리가 메인 체크아웃의 훅을 돌린다). 캐시 경고가 뜨면 갱신 전까지 Skill 도구 대신 `plugins/<name>/skills/<skill>/SKILL.md` 를 직접 읽는다.
- `.claude-plugin/marketplace.json`: marketplace 레지스트리와 플러그인 버전. Codex 도 이 카탈로그를 읽는다.
- `.claude/rules/`: 경로 스코프 규칙 (Claude 전용). `plugin-versioning.md` 는 매니페스트를, `state-envelope.md` 는 `.claude/state/*.json` 을 만질 때만 로드되고, `@import` 로 바꾸면 스코핑이 죽으므로 포인터는 백틱으로 둔다.
- `plugins/<name>/`: 플러그인 원본. `.claude-plugin/plugin.json` 이 매니페스트이자 버전이며 두 런타임이 같은 파일을 읽는다.
- `scripts/`: 가드 스크립트. Node 18+ 내장 모듈만 쓰고 런타임 의존성을 추가하지 않는다.
- `docs/adr/`: 결정 기록. `GLOSSARY.md`: 용어집. 두 런타임이 읽어야 하므로 결정이나 용어를 `.claude/rules/` 로 옮기지 않고, 지식 종류별 위치는 ADR 0003 을 따른다.

## Codex 통합

- `commands` / `agents` 는 Claude 전용 표면이다. Codex 는 미지원 필드를 무시하고 `skills/` 만 읽으므로, skill 로직을 agent 정의로 옮기지 않는다 (Codex 에서 조용히 사라진다).
- Skill `description` 은 1024자 미만으로 유지한다. Codex 는 초과한 skill 을 조용히 건너뛰고 Claude 쪽에는 위반이 보이지 않는다. `scripts/check-skill-contract.mjs` 가 검증한다.
- `description` 에 콜론+공백(`: `) 이 들어가면 따옴표로 감싼다. 안 하면 YAML 이 nested mapping 으로 파싱돼 두 런타임 모두에서 skill 이 로드되지 않는다.
- 번들 `scripts/` 를 부르는 skill 본문은 `${CLAUDE_PLUGIN_ROOT}` 를 그대로 쓰지 않는다. Codex 는 이 변수를 export 하지 않으므로 `CLAUDE_PLUGIN_ROOT` → 소스트리 `plugins/<name>` → Codex 캐시 순의 `PLUGIN_ROOT` resolver 블록을 본문에 둔다 (참조 구현: `dev:new`).
- Codex 훅은 `codex plugin add` 만으로 실행되지 않는다: 수동 `~/.codex/hooks.json` 등록과 `/hooks` 의 trust 승인 전에는 아무 신호 없이 죽어 있다. `UserPromptSubmit`/`PostToolUse` 훅은 plain stdout 이 아니라 `hookSpecificOutput.additionalContext` JSON 을 내야 Codex 가 읽는다 (공유 스크립트는 `codex` 인자로 분기).
- 사용자에게 되묻는 상호작용은 capability-aware 게이트로 쓴다: Claude 는 `AskUserQuestion`, Codex 는 `request_user_input` (노출된 경우), 없으면 틀린 가정의 비용이 큰 지점에서만 짧은 blocking 질문 하나를 던지고 그 외에는 문서화된 안전한 기본값으로 진행한다.
- `AGENTS.md` 를 `CLAUDE.md` 로의 포인터로 축약하지 않는다. Codex 는 `@` 를 확장하지 않고, cloud reviewer 는 `## Code Review Rules` 를 직접 로드할 뿐 산문 redirect 를 따라가지 않으며, 실패는 조용하다.
- 부작용 있는 스킬(push, GitHub 쓰기, 태그, 릴리스, 저장소 생성, Drive 업로드)과 사용자 호출 전용 스킬(`md-audit`)은 `agents/openai.yaml` 에 `policy.allow_implicit_invocation: false` 를 둬 Codex 자동 호출을 막는다. 사용자 호출 전용이면 `disable-model-invocation: true` 도 둔다.

## 플러그인 변경 규칙

- 버전은 손으로 고치지 않고 `node scripts/bump-version.mjs <plugin>... [--minor|--major] [--base <ref>]` 로 올린다: `plugin.json` 과 `marketplace.json` 의 해당 항목, `metadata.version` 을 같은 변경에서 함께 올린다. 기본값 `origin/main` 기준이라 다시 돌려도 같은 값이고, 병렬 PR 의 버전 줄 충돌은 높은 쪽을 고른 뒤 다시 돌리면 풀린다.
- `plugins/<name>/` 아래 어떤 파일이든 바뀌면 버전 범프 대상이다 (`references/`·asset 편집 포함). 캐시로 게이트된 사용자는 범프가 있어야 새 내용을 받는다. 루트 문서(`AGENTS.md`, `README.md`, `code_review.md`, `.claude/rules/*`)는 어떤 플러그인도 범프하지 않는다.
- per-plugin `version` 은 semver (PATCH 수정 / MINOR 기능 / MAJOR 깨짐). `metadata.version` 은 릴리스 카운터라 플러그인 제거처럼 깨지는 변경이어도 MINOR 로 올린다 ("MAJOR" 지적은 오탐). 이름이 바뀐 플러그인은 새 엔트리이므로 1.0.0 부터 시작한다.
- 스킬을 다른 번들로 흡수하면 배선보다 흡수된 스킬 본문을 먼저 감사한다: Codex 캐시를 `*/<옛-플러그인>/*` 로 훑는 resolver, 네임스페이스 없는 `/skill-name` 예제, 흡수처 버전 미범프가 깨진다. 옮긴 트리에서 옛 플러그인명을 grep 해 확인한다.
- 플러그인을 추가·제거하면 이 문서의 `## Plugins (N)` 표, `README.md` 의 배지·"N개 플러그인 모음"·목록·상세·구조 트리, `.claude/settings.json` 을 같은 변경에서 갱신한다. `check-doc-consistency.mjs` 가 이름 집합과 카운트를 대조한다.
- 도입 시점을 기록한 버전 마커(예: "0.7.0부터")는 역사이므로 버전 sweep 에서 건드리지 않는다.
- 사용자 문서와 릴리스 안내에는 `rm -rf ~/.claude/plugins/cache/my-claude-plugins/` 후 marketplace update + Claude Code 재시작 절차를 유지한다 (플러그인 캐시 버그).

## 검증

마지막 줄이 `verify: ok` 이면 통과다. 가드가 실패하면 체인이 그 자리에서 멈추고 그 출력이 마지막에 남는다.

```bash
git add -A \
  && node scripts/check-doc-consistency.mjs \
  && node scripts/check-shell-portability.mjs \
  && node scripts/check-shell-portability.test.mjs \
  && node scripts/check-skill-contract.mjs \
  && node scripts/bump-version.mjs --check \
  && node scripts/bump-version.mjs --selftest \
  && node scripts/check-plugin-cache.mjs --selftest \
  && node scripts/check-korean-copy.mjs \
  && bash plugins/dev/tests/resolver_smoke.sh \
  && bash plugins/dev/skills/review-loop/tests/run-tests.sh \
  && bash plugins/dev/skills/post-merge/tests/run-tests.sh \
  && bash plugins/council/skills/convene/tests/run-tests.sh \
  && echo "verify: ok"
```

- `git add -A` 가 먼저다: 가드는 git-tracked 파일만 스캔한다.
- `bump-version.mjs --check` 는 이 브랜치가 바꾼 플러그인의 버전이 `origin/main` 보다 크지 않으면 실패하므로 먼저 `git fetch origin` 한다. review-loop 의 base 직행 push 도 base 쪽 pre-commit 으로 이 검사를 받는다.
- `.githooks/pre-commit` 이 매 커밋 같은 가드를 돌리고, 플러그인 테스트 스위트는 그 플러그인(`plugins/dev/`, `plugins/council/`)이나 훅이 staged 일 때만 돈다 (review-loop 하나가 Windows 에서 11-15분). clone 당 한 번 `git config core.hooksPath .githooks` 로 활성화한다.
- `check-shell-portability.mjs` 는 폴백도 capability probe 도 없는 GNU 전용 셸 구문을 잡는다 (증거는 코드만, 예외는 `# portability-ok: <사유>`). 상세는 `README.md` 의 "CI 가드가 지키는 것".
- CI(`validate-codex.yml`)는 릴리스 태그 `vX.Y.Z` push 와 `workflow_dispatch` 에서만 돌고 `/dev:release` 는 그 결과를 기다리지 않으므로, 평소 게이트는 pre-commit 훅이다 (Node 가 없으면 커밋 거부).
- BSD 폴백은 CI 의 `macos` job (`/bin/bash`, bash 3.2) 에서만 실행된다. 릴리스 사이에는 Mac 에서 review-loop·post-merge 스위트를 `/bin/bash` 로 돌린다.
- Codex 카탈로그 확인은 일회용 `CODEX_HOME` 에서 돌린다 (9 entries). 실제 홈에서 돌리면 `marketplace add` 가 기존 등록과 충돌하고 `remove` 가 원래 등록을 지운다.

  ```bash
  set -e
  CH=$(mktemp -d)
  trap 'rm -rf "$CH"' EXIT
  CODEX_HOME="$CH" codex plugin marketplace add "$PWD"
  CODEX_HOME="$CH" codex plugin list --marketplace my-claude-plugins --available --json \
    | jq -e '[.available[].name] | sort == ["aside","codex-image","council","deck","dev","docs","ml","scout","wiki"]' >/dev/null
  ```
- Python 테스트는 해당 플러그인 디렉터리에서 `uv run pytest`.

## 문서 작성 스타일

- 모든 md 의 모양과 톤 기준은 `plugins/docs/references/writing-standard.md` 하나이고, 숫자는 `/docs:md-audit` 가 잰다.
- 사용자-facing 문서는 한국어 설명을 유지하고, 명령어와 경로는 코드 포맷으로 쓴다. README 의 플러그인 수·이름·명령어 예시는 매니페스트와 일치시킨다.
- 스킬 본문과 플러그인 `CLAUDE.md` 는 영어로 쓴다 (두 런타임과 Codex cloud reviewer 가 한 언어를 읽는다). 도메인 콘텐츠와 `description:` 의 한국어 트리거 문구는 예외다.
- 각색한 스킬의 출처 표기는 `README.md` 와 `.claude/spec/` 에만 둔다 (스킬 본문의 크레딧은 에이전트를 원본으로 보낸다).

## Code Review Rules

> 이 섹션은 Codex GitHub cloud reviewer 가 자동으로 읽는다. 한국어로 리뷰하고, 발견사항은 영향 + 근거 (파일/라인) + 수정 방향 순서로 제시하며, 근거가 부족하면 `unverified` 로 표시한다.
>
> 이 헤딩(Codex 규정 이름) 아래는 리뷰어 시스템 프롬프트에 직접 로드되어 아래 최소본이 항상 적용된다. 전문은 루트 [`code_review.md`](code_review.md) 이고, 리뷰어가 따라 읽는 것은 소프트 개런티다 (<https://learn.chatgpt.com/guides/best-practices>). GitHub cloud reviewer 는 P0/P1 만 코멘트로 표면화한다.

### 핵심 최소본 (전문은 `code_review.md`)

- **P0 (must-block)**: secret/token 노출, 사용자 확인 없는 destructive `gh` 명령 (`gh pr merge` / `gh repo create` / `gh api`), shell injection (사용자 입력이 셸에 코드로 도달, quote 유무 무관).
- **P1 (should-block)**: 아래 규칙은 모두 하드로 유지한다 (soft-follow 미검증이므로 code_review.md 로 demote 하지 않는다).
  - plugin version/count drift (`plugin.json` ↔ `marketplace.json` ↔ AGENTS 플러그인 목록·README 트리·배지·`metadata.version`).
  - idempotency 회귀 (재실행 시 사용자 파일 덮어쓰기·`nothing to commit` abort·`origin` 충돌).
  - cross-platform shell 가정: `sed -i`·`realpath -m`·`md5sum`·`date -d`·`stat -c`·`timeout` GNU-only, `${VAR,,}` Bash 4+.
  - `git diff` 의 `+++` 헤더는 비ASCII 경로를 octal escape 하고 공백 있는 경로 뒤에 탭을 덧붙이므로, 경로를 텍스트 비교하려면 `-c core.quotePath=false` + 탭 절단이 필요하다.
  - zsh 는 인용 없는 파라미터를 단어 분리하지 않아 `cmd $MULTI_VALUE` 가 한 인자로 넘어간다. `set -o shwordsplit 2>/dev/null || true` 로 요청한다.
  - 이식성 수정은 양방향이다: `python`→`python3` 는 macOS 를 고치고 Windows 를 깬다. 인터프리터는 이름 고정이 아니라 탐지한다.
  - `gh api --paginate`+`--jq` 에 `--slurp` 누락.
  - 봇 신원 매처의 앵커 누락: `test("coderabbit"; "i")` 같은 어간·prefix 매칭은 부분 문자열 매칭이고, `coderabbit-evil` 은 등록 가능한 GitHub 로그인이라 외부 계정이 리뷰 루프에 지시문을 주입한다. `test("^coderabbitai(\\[bot\\])?$"; "i")` 로 양끝을 고정한다 (`[`·`]` 는 로그인 불가 문자라 `(\\[bot\\])?$` 는 위조 불가이고 REST·GraphQL 두 철자를 함께 덮는다).
  - 로그인 고정은 봇 개명 시 silent-zero 를 되살리므로 회귀 테스트가 같이 있어야 한다.
  - sed 치환 안전성 (`&`·구분자·`\` escape, 사용자 입력 정화).
  - API 실패를 빈 결과로 삼키는 패턴 (`gh api ... || echo "[]"`).
  - 출력과 종료 상태가 독립인 명령에 붙인 `|| <기본값>`: `gh pr checks` 는 `--json` 없이 돌리면 pending 8 / 실패 1 로 끝나면서 개수를 출력하므로 값이 두 개가 되어 뒤의 파서가 깨진다 (`--json` 이면 체크 상태로는 0 이지만 네트워크·인증·API 오류는 여전히 1). stdout 과 rc 를 따로 받는다.
  - 그 write 쪽 쌍: 변환 실패 결과를 검사 없이 `gh issue/pr edit --body` 로 내보내 원격 본문을 공백으로 파괴하는 것.
  - 종료 상태가 사라지는 자리: 파이프라인 중간 명령은 `set -e` 를 발동시키지 못하고, 상태 자체가 검사 신호인 자리의 `|| true` 도 상태를 지운다. `cmd -v X && X … || true` 는 "X 없음"만이 아니라 "X 실행 실패"까지 삼키므로 `if …; then …; fi` 로 흡수 범위를 한정한다.
  - skill/command frontmatter `name`/`description` 누락·오류.
  - `Read`/`Edit` 영역을 `Bash cat`/`sed` 로 우회.
  - 새 dependency·GitHub Actions·CI/CD 권한 변경 (최소 권한·lockfile·supply-chain).
- **Do not flag**: 포매터 영역 (들여쓰기·따옴표·trailing whitespace), import 순서, 단순 typo, 루트 `CLAUDE.md` 가 `@AGENTS.md` 한 줄 포인터인 것. "CLAUDE.md 가 없다/내용 없다" 지적과 그 역방향은 오탐이다 (루트 한정이라 `plugins/<name>/CLAUDE.md` 가 내용을 갖는 것은 정상).
- 위 P0/P1/Do-not-flag 은 하드 최소본이다. 발견사항 제시 순서, 플러그인 추가/제거·skill 추가 문서 동기화 체크리스트, 도입-버전 마커 오탐 예외, plugin-cache refresh 같은 elaboration 은 [`code_review.md`](code_review.md) 에 있다 (soft).

## CodeRabbit / Codex 조율

- 이 저장소는 PR 머지 전 자동 리뷰로 CodeRabbit + ChatGPT-Codex 를 쓰고, `/dev:review-loop` 스킬이 양쪽을 함께 처리한다.
- 티어, finding 자율 판정, HEAD 판정 대기, 정지 상태, 머지 게이트, PR 댓글 한도는 `plugins/dev/skills/review-loop/references/coordination.md` 에 있다 (결정 근거는 ADR 0002·0006).
- 플래그는 `plugins/dev/skills/review-loop/references/arguments.md`.

`final_state` enum: `clean`, `user_declined`, `minor_floor`, `churn`, `iteration_cap`, `timeout`, `failure`, `cr_inactive`, `rate_limited`, `cli_failed`, `reviewers_unavailable`, `codex_failed`, `ci_failing`, `merged_externally`, `unknown` (트리거와 조치: `plugins/dev/skills/review-loop/references/failure-modes.md`).

## Agent skills

### Issue tracker

이슈와 spec 은 이 저장소의 GitHub Issues 에 `gh` CLI 로 둔다. 상세는 `docs/agents/issue-tracker.md`.

### Triage labels

기본 5개 (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`) 를 이름 그대로 쓴다. 상세는 `docs/agents/triage-labels.md`.

### Domain docs

single-context: 루트 `GLOSSARY.md` + `docs/adr/`. 상세는 `docs/agents/domain.md`.
