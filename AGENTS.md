# AGENTS.md

> **이 파일이 정본이고, 루트 `CLAUDE.md` 는 이 파일을 `@AGENTS.md` 로 import 하는 한 줄짜리 포인터다.** 두 런타임이 서로 다른 파일명을 찾기 때문이다 — Claude Code 는 `CLAUDE.md` 만 읽고 그 안의 `@AGENTS.md` import 로 이 파일을 끌어오며, Codex 는 `AGENTS.md` 를 그대로 읽는다. 내용을 이 파일 한 곳에만 두어 미러 유지 부담을 없앴다.
>
> `CLAUDE.md` 를 따로 편집하지 마라 — `@AGENTS.md` 한 줄 import 일 뿐이다. 편집은 항상 `AGENTS.md` 에 한다.

## 기본 원칙

- 이 저장소는 Claude Code 플러그인 marketplace 저장소입니다. 변경 전에는 이 문서, `README.md`, 관련 플러그인의 `plugins/<name>/CLAUDE.md`를 먼저 확인하세요.
- 사용자가 한국어로 요청하면 한국어로 응답하세요.
- 변경은 요청 범위에만 한정하고, 관련 없는 파일이나 기존 사용자 변경 사항은 되돌리지 마세요.
- 파일 탐색과 검색은 우선 `rg`, `rg --files`를 사용하세요.
- 플러그인 개발 중 라이브러리·런타임·플랫폼 사실을 확인할 때는 `docs/llm-doc-sources.md` 에 정리된 LLM 문서 소스(mcpdocs 등록 + deepwiki 타깃)를 먼저 사용하세요.
- 문서와 매니페스트가 함께 움직이는 저장소이므로 코드 변경뿐 아니라 `README.md`, 이 문서, marketplace manifest의 동기화 필요성을 항상 확인하세요.
- 저장소에 `.llmwiki/wiki/index.md` 가 있으면 lore 성 질문에 답하기 전에 그 MOC 를 먼저 읽으세요 (구 query-wiki 스킬의 규약을 흡수한 한 줄).

플러그인 트리 하나를 Claude Code 와 Codex CLI 가 함께 읽습니다 — one source, two runtimes. Codex 는 `.claude-plugin/marketplace.json` 과 `plugins/*/.claude-plugin/plugin.json` 을 네이티브 매니페스트 폴백으로 직접 읽으므로 생성 계층이 없습니다.

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

- `AGENTS.md`: 이 문서. 두 런타임 공통 최상위 지침 + 플러그인 목록 + 구조 요약.
- `CLAUDE.md`: `@AGENTS.md` 를 import 하는 한 줄 파일. Claude Code 진입점일 뿐, 별도 내용이 없습니다.
- `CLAUDE.md.global` / `CLAUDE.md.global.ko`: Claude 와 Codex 가 공통으로 사용하는 사용자 전역 지침의 저장소 정본과 손으로 유지하는 한국어 번역. 영문 `CLAUDE.md.global` 이 저장소 정본이다. 영어를 먼저 고치고 `.ko` 를 미러한다.
  - 저장소 정본을 `cp CLAUDE.md.global ~/.claude/CLAUDE.md` 와 `cp CLAUDE.md.global ~/.codex/AGENTS.md` 로 복사해 두 런타임의 설치 사본을 갱신한다. `.ko` 는 어떤 에이전트도 로드하지 않는다.
  - 사본을 이 워킹트리로의 심볼릭 링크로 걸지 않는다. 브랜치 전환과 커밋하지 않은 편집이 즉시 전역 지침으로 발효될 수 있다.
  - 동기화 안내는 이 저장소에만 둔다. 모든 프로젝트에서 로드되는 전역 파일에는 규칙 외의 내용을 추가하지 않는다.
- `README.md`: 사용자용 설치 및 플러그인 문서.
- `.claude/settings.json`: 로컬 플러그인 로드 설정.
- `.claude-plugin/marketplace.json`: marketplace 레지스트리와 플러그인 버전 목록. Codex 도 이 카탈로그를 네이티브로 읽는다.
- `.claude/rules/`: 특정 경로에 적용되는 상세 규칙 (Claude 전용 — Codex 는 읽지 못함).
- `plugins/<name>/`: 각 플러그인의 원본 디렉터리. `plugins/<name>/.claude-plugin/plugin.json` 이 플러그인별 매니페스트와 버전이며, Claude 와 Codex 가 같은 파일을 읽는다.

## Codex 통합 (native shared-source)

Claude Code 와 Codex 가 **동일한** `plugins/<name>/` 트리와 `.claude-plugin/` 매니페스트를 직접 읽는다. 별도 생성 계층 없음 (구 `sync-codex-manifests.mjs` + `.agents/` + `.codex-plugin/` 은 2026-08 재개편에서 제거 — Codex 의 매니페스트 폴백이 `.codex-plugin` → `.claude-plugin` 순으로 탐색하고, marketplace 카탈로그도 `.agents/plugins/marketplace.json` → `.claude-plugin/marketplace.json` 순으로 폴백한다).

- `commands` / `agents` 는 Claude 전용 표면이다 — Codex 는 매니페스트의 미지원 필드를 무시하고 `skills/` 만 읽는다. skill 로직을 agent 정의로 옮기지 않는다 (Codex 에는 agents surface 가 없어 옮긴 로직이 조용히 사라진다).
- Skill `description` frontmatter 는 1024자 미만으로 유지하세요. Codex 는 1024자 초과 description 을 가진 skill 을 **silent 하게 skip** 합니다 (Claude Code 는 제한이 없어 위반이 안 보임). `scripts/check-skill-contract.mjs` 가 이를 검증하고 `.githooks/pre-commit` 이 매 커밋마다 실행합니다 — clone 당 한 번 `git config core.hooksPath .githooks` 로 활성화하세요.
- Skill `description` frontmatter 에 콜론+공백(`: `) 이 들어가면 반드시 따옴표로 감싸세요 (또는 `>-` block scalar). 안 하면 YAML frontmatter 가 nested mapping 으로 파싱돼 skill 이 양쪽 런타임에서 silent 하게 로드 안 됩니다.
- 번들 `scripts/` 를 호출하는 skill 본문은 `${CLAUDE_PLUGIN_ROOT}` 를 그대로 쓰지 마세요 — Codex 는 이 변수를 export 하지 않아 첫 단계에서 실패합니다. 크로스 런타임 `PLUGIN_ROOT` resolver 블록(`CLAUDE_PLUGIN_ROOT` → 소스트리 `plugins/<name>` → Codex 캐시 탐색)을 본문에 포함하세요 (레퍼런스 구현: project-init, mem0-ops).
- **`AGENTS.md` 를 `CLAUDE.md` 로의 포인터로 축약하지 않는다.** Codex 는 `@` 를 확장하지 않아 `@CLAUDE.md` 는 죽은 텍스트이고, "CLAUDE.md 를 먼저 읽어라" 식 산문 redirect 는 Codex GitHub cloud reviewer 에 닿지 않는다 (이 리뷰어는 `## Review guidelines` 섹션을 시스템 프롬프트에 직접 로드한다 — 임의 산문 redirect 는 따라가지 않고, `AGENTS.md` 가 명시적으로 참조하는 `code_review.md` 만 예외적으로 따라갈 수 있다[소프트 개런티, best-practices 문서]). 실패는 조용하다 — 에러 없이 지침만 사라진다. 이 저장소는 반대 방향을 택했다: `AGENTS.md` 가 SSOT 이고 `CLAUDE.md` 는 `@AGENTS.md` 한 줄을 import 한다.

## Cross-runtime interactive input policy

사용자에게 되묻는 상호작용은 런타임마다 노출 도구가 다르다. 공유 스킬 본문은 특정 도구가 항상 존재한다고 가정하지 말고 **capability-aware** 게이트로 쓴다.

| 런타임 | 상호작용 도구 |
|---|---|
| Claude Code | `AskUserQuestion` |
| Codex | `request_user_input` (노출된 경우). 노출 안 되면, 틀린 가정의 비용이 큰 지점에서만 짧은 blocking 질문 하나를 던지고, 그 외에는 문서화된 안전한 기본값으로 진행한다 |

## 플러그인 변경 규칙

- 플러그인 버전을 올릴 때는 `plugins/<name>/.claude-plugin/plugin.json`과 `.claude-plugin/marketplace.json`의 해당 항목을 같은 변경에 포함하세요.
- `plugins/<name>/` 아래 **어떤 파일이든** 바뀌면 버전 범프 대상입니다 — 코드/스킬뿐 아니라 번들 `references/`·`docs`·asset 편집도 포함. 캐시로 게이트된 사용자는 버전 범프가 있어야 새 내용을 받으므로, 문서만 고쳐도 해당 플러그인 PATCH + `metadata.version`을 올립니다. 반면 루트 문서(`AGENTS.md`, `README.md`, `code_review.md`, `.claude/rules/*`)는 플러그인 콘텐츠가 아니라 어떤 플러그인도 범프하지 않습니다.
- 어떤 플러그인 버전이든 변경하면 `.claude-plugin/marketplace.json`의 `metadata.version`도 marketplace release 버전으로 올리세요.
- 플러그인의 스킬을 다른 번들로 **흡수**할 때는 흡수처 배선이 아니라 **흡수된 스킬 본문을 먼저 감사**하세요. 배선은 쉬운 쪽이고, 깨지는 건 스킬이 여전히 자기를 옛 플러그인 소속으로 아는 부분입니다: Codex 캐시를 `*/<옛-플러그인>/*` 로 훑는 `PLUGIN_ROOT` resolver (`CLAUDE_PLUGIN_ROOT` 가 없는 순간 "script not resolved" 로 죽음), 네임스페이스 없는 `/skill-name` 예제, 그리고 흡수처 버전 미범프(캐시로 게이트된 사용자에게 이동 자체가 안 내려감). 옮긴 트리에서 옛 플러그인명을 grep 해 확인하세요.
- 플러그인을 추가하거나 제거하면 이 문서의 `## Plugins (N)` 수와 목록, `README.md`의 플러그인 수와 목록도 갱신하세요. 카운트가 자기 SoT 바로 옆에 있고 어떤 가드도 검사하지 않는 재진술은 유지하지 말고 지우세요 — SoT 를 읽으면 나오는 숫자를 손으로 유지하는 비용만 남습니다.
- 버전은 semver를 따릅니다. 버그 수정은 PATCH, 하위 호환 기능은 MINOR, 깨지는 변경은 MAJOR입니다. 단 이 semver 규칙이 적용되는 대상은 per-plugin `version` 뿐입니다 — `.claude-plugin/marketplace.json` 의 `metadata.version` 은 semver 가 아니라 릴리스 카운터라, 소비자에게 하위 호환이 깨지는 변경(플러그인 제거 등)이어도 MINOR 로 올립니다. 어느 쪽 규칙이 걸리는지는 변경의 성격이 아니라 **어느 버전 필드를 만지는가**로 갈립니다. 리뷰어가 `metadata.version` 을 "깨지는 변경 → MAJOR" 로 지적하면 오탐이며, 근거는 `.claude/rules/plugin-versioning.md` 의 "Plugin Removal" 절입니다.
- Claude Code 플러그인 캐시 이슈 때문에 사용자 문서나 릴리스 안내에는 필요 시 `rm -rf ~/.claude/plugins/cache/my-claude-plugins/` 후 marketplace update 및 Claude Code 재시작 절차를 유지하세요.

## Modular Rules

`.claude/rules/*.md` is auto-loaded by Claude Code — no `@import` required, and Codex cannot read the directory at all. A rule carrying `paths:` frontmatter loads only when Claude touches a matching file; `@import`ing that same rule expands it unconditionally at launch and kills the scoping, so the pointers below are deliberately plain (backticks, not `@`).

- `.claude/rules/plugin-versioning.md` — plugin version bump contract and cache-refresh workflow. Scoped via `paths:` to the manifest files, so it loads only when you touch them.
- `.claude/rules/state-envelope.md` — the state-envelope v0 run-record convention (`.claude/state/<pipeline>-<key>.json` + archive rotation + per-skill jq, no shared library). Scoped via `paths:` to `.claude/state/*.json`. Its concept mirror for Codex is the "State-envelope 실행 기록" section below.

## State-envelope 실행 기록 (run records, v0)

> `.claude/rules/state-envelope.md` 의 Codex 미러다 (Codex 는 `.claude/rules/` 를 못 읽는다). Claude 는 위 `## Modular Rules` 포인터로 원본 규칙에 닿고, Codex 에게는 이 미러가 유일 소스이므로 실행 jq 를 아래에 그대로 싣는다 (규칙 파일로 미루지 않는다).

여러 단계로 이어지는 파이프라인 스킬이 자기 진행 상태를 기계가 읽을 수 있게 남기는 per-run 상태 파일 규약이다. v0 는 **문서화된 규약 + per-skill `jq`** 일 뿐, **공유 라이브러리/스크립트를 두지 않는다**. 각 채택 스킬이 자기 본문에 jq 를 인라인한다.

- **위치·회전**: live 파일은 `.claude/state/<pipeline>-<key>.json` (예: `post-merge-114.json`, 기존 `cr-fix-<PR>.json` 명명 미러). 같은 key 로 재실행하면 새로 쓰기 전에 이전 live 파일을 `.claude/state/archive/<pipeline>-<key>-<timestamp>-$$.json` 로 회전한다 (cr-fix Step 2 미러). `.claude/state/` 는 gitignore + 머신 로컬 — run record 는 절대 커밋하지 않고 스킬의 `RUN_TOUCHED` 스테이징 집합에도 넣지 않는다.
- **스키마**: `{schema:"state-envelope/v0", run_id, status(queued|in_progress|completed), conclusion, started_at, updated_at, anchor_sha, attempt, session_id, steps[]}`. `steps[]` 는 top-level 단계가 닫힐 때마다 `{step, status: done|skipped, reason?}` 한 항목 (`reason` 은 skipped 에만).
- **spec-state 와 직교(orthogonal)**: run record 는 `.claude/state/spec.json` 이 **아니다**. `spec.json` (owner: `github-dev:state-tracker`) 은 spec→issue→PR 파이프라인의 크로스런 집계이고, run record 는 스킬 단일 실행의 단계 로그다. 서로 다른 파일·다른 소유자이며 서로 읽거나 쓰지 않는다.
- **v0 채택자**: `github-dev:post-merge` (Step 1-10 per-step 기록) 와 `project-init:new` (Phase 0.5 run record — resume 지원 + fail-loud 쓰기). 다른 스킬 상태 파일의 retrofit 은 후속 변경으로 의도적으로 미룬다.

**실행 jq (채택 스킬이 본문에 인라인한다, 공유 라이브러리 없음).** Init 은 archive 회전 실패 시 이전 기록을 덮어쓰지 않도록 abort 한다:

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

cr-fix 의 스크립트·레퍼런스 경로는 `plugins/github-dev/skills/cr-fix/SKILL.md` Step 1 의 `SKILL_DIR` resolver (`CLAUDE_PLUGIN_ROOT` → 소스트리 `plugins/github-dev/skills/cr-fix` → Codex 캐시 순) 로 해소된다. 이후 모든 bash 블록은 하드코딩 경로가 아니라 `$SKILL_DIR/scripts/...`·`$SKILL_DIR/references/...` 를 경유하므로 marketplace dogfood 뿐 아니라 일반 user repo·Codex 에서도 동작한다. SKILL.md 에 남은 `plugins/github-dev/skills/cr-fix` 리터럴은 전부 resolver 의 fallback 분기 내부이며, `tests/run-tests.sh` 의 "Step 1 SKILL_DIR resolver" 케이스가 회귀를 가드한다.

## 검증

- 문서/스킬 일관성 가드 (모든 PR 에서 실행):

```bash
node scripts/check-doc-consistency.mjs
node scripts/check-shell-portability.mjs
node scripts/check-skill-contract.mjs
```

`check-doc-consistency.mjs` 는 README 구조 트리·README `## 플러그인 상세` 의 `<summary>` 이름 집합·`## Plugins` 표·문서에 박힌 카운트 문자열을 marketplace.json 과 대조하고 `.githooks/pre-commit` 에서 차단한다. 상세 절이 뒤늦게 추가된 이유가 이 가드의 성질을 말해준다 — 트리 엔트리와 `<details>` 블록은 같은 문서의 **서로 다른 표면**이라, 한쪽을 대조해도 다른 쪽은 안 대조된다. 플러그인 제거 후 상세 절에 죽은 항목 11개가 남고 살아있는 항목 1개가 빠진 채로 이 가드가 통과한 적이 있다. 문서 한 종류를 지킨다고 그 문서 전체가 지켜지는 게 아니므로, 새 문서 블록을 만들 때 어느 표면이 실제로 검사되는지 확인한다.

`check-shell-portability.mjs` 는 `code_review.md` P1 의 크로스플랫폼 규칙을 기계적으로 강제한다 — GNU 전용 구문(`md5sum`·`sed -i`·`grep -P`·`date -d`·`stat -c`·`timeout`·`${VAR,,}`·`mapfile`·`declare -A` 등)이 **폴백도 capability probe 도 없이** 쓰인 경우만 잡는다. 정상 폴백 쌍(`stat -c … || stat -f …`)과 probe 분기는 통과하며, 증거는 **코드여야 하고 주석은 인정하지 않는다**. 정말 예외인 줄은 `# portability-ok: <사유>` 로 표시한다. `.claude/spec/`·`code_review.md`·`AGENTS.md` 는 그 구문을 *설명*할 뿐이라 스캔에서 제외된다.

이 가드는 **git-tracked 파일만** 스캔한다. 새 파일을 스테이징하기 전에 돌리면 그 파일을 한 줄도 보지 않고 통과하므로, 신규 파일을 만든 변경에서는 `git add` 후 재실행해야 결과가 유효하다 (스캔 파일 수가 늘어나는 것으로 확인 가능).

macOS CI 레그(`validate-codex.yml` 의 `macos` job)는 BSD 폴백이 실제로 실행되는 유일한 지점이다. `env -i PATH=/usr/bin:/bin` 는 쓰지 않는다 — macOS 에서 `jq` 가 Homebrew 경로에 있어 스위트가 도구 부재로 죽는다. 대신 `sed`/`date`/`stat` 이 `--version` 을 거부하는지(=BSD 빌드인지) assert 하고, Homebrew coreutils 가 시스템 도구를 가리면 시끄럽게 실패시킨다. 스위트는 `bash` 가 아니라 `/bin/bash` 로 돌려 bash 3.2 를 강제한다 (러너 PATH 의 Homebrew bash 5 로 돌면 bash-4 전용 구문이 여기서 통과하고 사용자에게서 깨진다).

- 로컬 Codex CLI 에서 marketplace 등록 확인 (네이티브 폴백 — 생성 카탈로그 없음):

```bash
codex plugin marketplace add <이 저장소 경로 또는 ~/.claude/plugins/marketplaces/my-claude-plugins>
codex plugin list --marketplace my-claude-plugins
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
- **P0 (must-block)** — secret/token 노출, 사용자 확인 없는 destructive `gh` 명령 (`gh pr merge` / `gh repo create` / `gh api`), shell injection (사용자 입력 unquoted).
- **P1 (should-block)** — 모든 should-block 규칙은 하드 유지한다 (soft-follow 미검증이므로 code_review.md 로 demote 하지 않는다): plugin version/count drift (`plugin.json` ↔ `marketplace.json` ↔ AGENTS 플러그인 목록·README 트리·배지·`metadata.version`), idempotency 회귀 (재실행 시 사용자 파일 덮어쓰기·`nothing to commit` abort·`origin` 충돌), cross-platform shell 가정 (`sed -i`·`realpath -m`·`md5sum`·`date -d`·`stat -c`·`timeout` GNU-only / `${VAR,,}` Bash 4+ / zsh 는 인용 없는 파라미터를 단어 분리하지 않아 `cmd $MULTI_VALUE` 가 한 인자로 넘어감, `set -o shwordsplit 2>/dev/null || true` 로 요청 / 이식성 수정은 양방향 — `python`→`python3` 는 macOS 를 고치고 Windows 를 깬다, 인터프리터는 이름 고정이 아니라 탐지), `gh api --paginate`+`--jq` 에 `--slurp` 누락, sed 치환 안전성 (`&`·구분자·`\` escape, 사용자 입력 정화), API 실패를 빈 결과로 삼키는 패턴 (`gh api ... || echo "[]"`) 과 그 write 쪽 쌍 (변환 실패 결과를 검사 없이 `gh issue/pr edit --body` 로 내보내 원격 본문을 공백으로 파괴), 종료 상태가 사라지는 자리 (파이프라인 중간 명령은 `set -e` 를 발동시키지 못한다 / 상태 자체가 검사 신호인 자리의 `|| true` / `cmd -v X && X … || true` 는 "X 없음"만이 아니라 "X 실행 실패"까지 삼키므로 `if …; then …; fi` 로 흡수 범위를 한정), skill/command frontmatter `name`/`description` 누락·오류, `Read`/`Edit` 영역을 `Bash cat`/`sed` 로 우회, 새 dependency·GitHub Actions·CI/CD 권한 변경 (최소 권한·lockfile·supply-chain).
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
