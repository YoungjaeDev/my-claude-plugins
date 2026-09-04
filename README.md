<div align="center">

<img src="assets/banner.png" width="600" alt="my-claude-plugins banner">

<br>

<img src="assets/logo.png" width="100" alt="my-claude-plugins logo">

# my-claude-plugins

Claude Code 를 위한 8개 플러그인 모음. GitHub 워크플로우, 리서치, 문서 저작, ML 개발, LLM-Wiki 메모리를 짧은 이름의 번들로 묶었다. Codex CLI 도 같은 소스 트리와 `.claude-plugin/` 매니페스트를 네이티브로 읽는다.

[![Plugins](https://img.shields.io/badge/plugins-8-blue.svg)](https://github.com/YoungjaeDev/my-claude-plugins)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-purple.svg)](https://docs.anthropic.com/claude-code)

[빠른 시작](#빠른-시작) | [플러그인 목록](#플러그인-목록) | [플러그인 상세](#플러그인-상세)

</div>

---

## 빠른 시작

```bash
# 1. Marketplace 추가
/plugin marketplace add YoungjaeDev/my-claude-plugins

# 2. 원하는 플러그인 설치
/plugin install dev@my-claude-plugins
/plugin install scout@my-claude-plugins
```

설치 후 `/dev:resolve-issue 123` 처럼 `/plugin:skill` 형태로 호출한다. 플러그인명을 짧게 둔 이유는 호출 길이와 가독성이다. 슬래시 메뉴는 `:`·`-`·`_` 를 무시하고 이름 안의 단어 시작에서도 매칭하므로 `/cr` 만 쳐도 `/dev:cr-fix` 가 하이라이트된다 (Claude Code 2.1.236 이상).

## 플러그인 업데이트

플러그인 캐시 버그([#17361](https://github.com/anthropics/claude-code/issues/17361), [#19197](https://github.com/anthropics/claude-code/issues/19197)) 때문에 업데이트 시 캐시 삭제가 필요하다. Auto-update 를 켜도 플러그인 파일은 갱신되지 않는다.

```bash
# 1. 캐시 삭제
#   macOS / Linux:
rm -rf ~/.claude/plugins/cache/my-claude-plugins/
#   Windows (PowerShell):
#   Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\plugins\cache\my-claude-plugins"

# 2. Marketplace 업데이트 후 Claude Code 재시작
/plugin marketplace update my-claude-plugins
```

### 2.30.0 마이그레이션 (14 → 8 번들)

2.30.0 에서 14개 플러그인을 8개 번들로 통합했다. 옛 이름은 marketplace 에서 사라졌으므로 옛 플러그인을 제거하고 새 번들을 설치한다. 스킬 이름은 그대로이고 네임스페이스만 바뀐다.

| 옛 플러그인 | 새 번들 | 예시 |
|---|---|---|
| `core-config` | `core` | (hooks 전용) |
| `github-dev`, `project-init`, `e2e-harness` | `dev` | `/github-dev:cr-fix` → `/dev:cr-fix`, `/project-init:new` → `/dev:new` |
| `docs-forge`, `publish` | `docs` | `/docs-forge:readme` → `/docs:readme`, `/publish:gws-sync` → `/docs:gws-sync` |
| `code-scout`, `deepwiki`, `paper-search-tools` | `scout` | `/deepwiki:ask` → `/scout:ask`, `code-scout:github-scout` → `scout:github-scout` |
| `ml-toolkit` | `ml` | `/ml-toolkit:cv-notebook` → `/ml:cv-notebook` |
| `llm-wiki`, `mem0-ops` | `wiki` | `/llm-wiki:ingest-finding` → `/wiki:ingest-finding`, `/mem0-ops:cleanup` → `/wiki:cleanup` |
| `council`, `codex-image` | 그대로 | 변경 없음 |

```bash
# 1. 캐시 삭제 (위 절차) 후 marketplace 업데이트
/plugin marketplace update my-claude-plugins

# 2. 옛 플러그인 제거 (설치했던 것만)
/plugin uninstall github-dev@my-claude-plugins
/plugin uninstall llm-wiki@my-claude-plugins
# ... core-config, project-init, e2e-harness, docs-forge, publish, code-scout, deepwiki, paper-search-tools, ml-toolkit, mem0-ops

# 3. 새 번들 설치 후 Claude Code 재시작
/plugin install core@my-claude-plugins
/plugin install dev@my-claude-plugins
/plugin install docs@my-claude-plugins
/plugin install scout@my-claude-plugins
/plugin install ml@my-claude-plugins
/plugin install wiki@my-claude-plugins
```

`~/.claude/settings.json` 의 `enabledPlugins` 에 옛 이름 키가 남아 있으면 지운다. Codex 사용자는 아래 "머신 로컬 운영 갱신" 절의 훅 경로 재지정도 필요하다.

## 플러그인 목록

| 플러그인 | 분류 | 내용 |
|---------|------|------|
| `core` | Core | Python 자동 포매팅, 터미널 알림, 매 프롬프트 behavioral 주입 훅 (`prompt_inject.sh`, Claude + Codex 공유). 스킬 없음 |
| `dev` | Development | GitHub 워크플로우 7 (commit-and-push, decompose-issue, resolve-issue, release, cr-fix, post-merge, state-tracker) + 프로젝트 셋업 2 (new, wiring) + Playwright E2E 하네스 3 (e2e-setup, e2e-author, e2e-debug) |
| `docs` | Documentation | 프로젝트 문서 커맨드 4 (readme, changelog, deploy-doc, moc) + 저작 스킬 (doc-guides, write-rules, interview-methodology, skill-forge, skill-audit, skill-fleet-review) + 내보내기 (translate-web-article, gws-sync) |
| `scout` | Research | research-orchestrator (5축 scout 에이전트 + synthesis), ask / generate-llmstxt (DeepWiki), paper-search (8개 학술 소스 MCP) |
| `ml` | Development | ml-dev-principles, gradio-cv-app, cv-notebook, edit-notebook |
| `wiki` | Memory & Lore | LLM-Wiki 3-layer (bootstrap-wiki, ingest-finding, lint-wiki, plaud-note-taking + hooks 5) + mem0 플릿 운영 (fleet-scan, cleanup) |
| `council` | AI Models | 이종 벤더 3인 심의 (`/council:convene`). Claude 전용 |
| `codex-image` | AI Models | Claude → Codex 이미지 생성 브리지. Claude 전용 |

## 설치 옵션

```bash
# 로컬 개발: 클론 후 실행하면 .claude/settings.json 이 전부 auto-load
git clone git@github.com:YoungjaeDev/my-claude-plugins.git && cd my-claude-plugins && claude

# Marketplace 설치 scope
/plugin install dev@my-claude-plugins                  # user (기본)
/plugin install dev@my-claude-plugins --scope project  # 팀 공유, git 추적
/plugin install dev@my-claude-plugins --scope local    # 개인용, 추적 안 함
```

## 플러그인 상세

<details>
<summary><strong>core</strong> - 훅 전용 기본 설정</summary>

스킬 없이 훅만 싣는다.

| Hook | Trigger | Description |
|------|---------|-------------|
| `prompt_inject.sh` | UserPromptSubmit, SessionStart(compact) | 한국어 응답 기본 + 핵심 규율 + `.llmwiki/insight/` 포인터 (cwd 에 knowledge root 가 있을 때) + `[council]` 위임 리마인더 (`codex` / `agy` 가 PATH 에 있을 때, Claude 전용). Codex 에서는 `codex` 인자로 `hookSpecificOutput` JSON 을 낸다 |
| `auto-format-python.py` | PostToolUse(Write, Edit) | ruff 로 Python 포매팅 |
| `notify_osc.py` | Stop, Notification | 크로스 플랫폼 터미널 알림 |

작업 가이드라인 자체는 `~/.claude/CLAUDE.md` (저장소 정본은 `CLAUDE.md.global`) 가 담당한다.

**Requirements:** `uv`, `ruff`

</details>

<details>
<summary><strong>dev</strong> - GitHub 워크플로우 + 프로젝트 셋업 + E2E 하네스</summary>

**GitHub 워크플로우**

| Skill | Description |
|-------|-------------|
| `/dev:commit-and-push` | 변경 분석, Conventional Commits 메시지, 커밋, 푸시 |
| `/dev:decompose-issue` | 이슈를 하위 작업으로 분해. 라벨 taxonomy 가 없으면 먼저 생성 |
| `/dev:resolve-issue` | 이슈 해결 E2E (worktree, 구현, 리뷰, 검증, PR) |
| `/dev:cr-fix` | CodeRabbit + Codex 리뷰를 pre-flight 로 감지해 finding 별로 apply / defer / skip 을 판단하고 clean 까지 루프. `--auto-merge`, `--cr-source <auto\|pr-bot\|cli\|codex-only>` (rate-limit 시 로컬 CLI 또는 Codex-only 폴백) |
| `/dev:post-merge` | 머지 후 브랜치 정리, Project/milestone + `.claude/state/spec.json` 동기화, 학습을 CLAUDE.md / AGENTS.md / rules 에 통합, 필수 wiki lore 적재, 커밋 |
| `/dev:release` | 버전 릴리스 + CHANGELOG |
| `/dev:state-tracker` | `.claude/state/spec.json` (spec / issue / PR 파이프라인 집계) `read` / `init` / `start` / `complete` |

**프로젝트 셋업**

| Skill | Description |
|-------|-------------|
| `/dev:new` | 빈 디렉터리에서 인터뷰 → `.claude/` 스캐폴드 → CLAUDE.md + AGENTS.md (Codex reviewer guidelines, general / ml / web 변형) + README / CHANGELOG 시드 → `gh repo create` + 초기 푸시. 비어 있지 않은 cwd 는 거부 |
| `/dev:wiring` | 기존 repo 의 하네스 설정을 14축으로 진단 (`FAIL / WARN / ASK / INFO / SKIP / OK`). 존재 검사 위에 효력 검사 4축 (`core.hooksPath`, `@import` 가 `.claude/rules` `paths:` 스코핑을 무력화, MCP 중복 등록, Codex `AGENTS.md` 바이트 예산). `ASK` 답은 `.claude/state/wiring.json` 에 기록해 다음 실행부터 조용하다 |

**Playwright E2E 하네스** — Playwright 공식 AI 에이전트(planner / generator / healer)를 래핑한 자가개선 루프.

| Skill | Description |
|-------|-------------|
| `/dev:e2e-setup` | `npx playwright init-agents --loop=claude` 로 에이전트 생성, 인증 분리 (`storageState` + setup project), `page.route` 모킹 스캐폴드, E2E 운영 SSOT 문서, GitHub Actions CI (트레이스 아티팩트 + PR 코멘트 + 게이팅). 기존 `playwright.config` 는 덮어쓰지 않고 머지 제안 + 백업 |
| `/dev:e2e-author` | critical user flow 선정 → planner 계획서 → 사용자 검토 게이트 → generator 스펙 (semantic `getByRole`) → `--repeat-each` 번인 |
| `/dev:e2e-debug` | 실패한 CI run 의 트레이스 다운로드 → 헤드리스 분석 → healer 수리 (최대 3회 후 skip + 사유 코멘트) → 재실행 |

Codex 는 named agent 를 등록하지 못하므로 세 스킬은 번들 `references/role-contracts.md` 의 역할 계약을 인라인으로 실은 generic subagent 또는 순차 실행으로 같은 게이트를 지킨다. Playwright 미설치 시 graceful degrade.

**Requirements:** `gh` CLI, `git`, `jq`; E2E 는 Node.js + Playwright

</details>

<details>
<summary><strong>docs</strong> - 문서 저작과 내보내기</summary>

**프로젝트 문서 (commands)**

| Command | Description |
|---------|-------------|
| `/docs:readme generate` / `analyze` | 템플릿 (CLI, Library, React Component, MCP Plugin, SaaS, Desktop) 에서 README 생성 또는 기존 README 분석 |
| `/docs:changelog init` | Keep a Changelog 형식 CHANGELOG |
| `/docs:deploy-doc generate` | 배포 / 절차 문서 (요약 + 전제조건 + 번호 단계) |
| `/docs:moc docs/` | 문서 폴더 MOC 인덱스 (경량 / `--strict`) |

네 커맨드는 `doc-guides` 스킬의 참조 카드(README / CHANGELOG / 배포 문서 / MOC)를 필요한 섹션만 로드한다.

**에이전트가 읽는 문서 (skills)**

| Skill | Description |
|-------|-------------|
| `/docs:write-rules` | CLAUDE.md 와 `.claude/rules/*.md` 를 공식 패턴(200줄 root cap, `paths:` 스코핑)에 맞게 생성·재구조화. 상태 스캔 후 `NEW / TIGHTEN / SPLIT / REORGANIZE` 중 하나를 추천 |
| `/docs:interview-methodology` | 요구사항 인터뷰. breadth-first 5-phase, depth-first Socratic, relentless stress-test ("grill me"). 결과가 재사용 프롬프트여야 하면 Google TCREI 구조로 출력 |
| `/docs:skill-forge` | 스킬 작성·개정. 프론트매터 스키마, 작성 레버, 두 런타임 패키징 계약 |
| `/docs:skill-audit` | 단일 스킬 7축 진단 + P0/P1/P2 수정안 |
| `/docs:skill-fleet-review` | 플러그인 트리 전수 검토. 측정 우선 코호트 선정 후 `docs/audit/<date>-fleet.md` + CSV |

**내보내기**

| Skill | Description |
|-------|-------------|
| `/docs:translate-web-article` | 웹 페이지를 한국어 마크다운으로 번역 (Bright Data MCP 페칭, `bdata` CLI 폴백, VLM 이미지 분석, 코드 / 테이블 보존) |
| `/docs:gws-sync` | 로컬 → Google Drive 단방향 제안형 동기화 (`gws` CLI). 업로드 위치는 승인 필수, 삭제는 제안만, 기존 파일은 content 만 갱신해 파일 ID / 공유 링크 보존 |

</details>

<details>
<summary><strong>scout</strong> - 리서치와 검색</summary>

| Skill | Description |
|-------|-------------|
| `/scout:research-orchestrator` | 유일한 리서치 진입점. 쿼리 → mode 감지 (quick / deep) → github / hf / web / docs / paper scout 병렬 fan-out → synthesis-scout 합성 (dedup, trust ranking, 충돌 해소, Markdown 보고서) |
| `/scout:ask` | GitHub 레포에 DeepWiki MCP 로 질문 |
| `/scout:generate-llmstxt` | 레포의 `llms.txt` 생성 |
| `/scout:paper-search` | arXiv, PubMed, bioRxiv, medRxiv, Google Scholar, IACR, Semantic Scholar, CrossRef 논문 검색·다운로드·읽기. 번들 `.mcp.json` 의 `paper-search` MCP 서버 (Docker) |

**Agent team (Claude Code 전용):** `scout:github-scout`, `scout:hf-scout`, `scout:web-scout` (exa → brightdata → insane-search 4-tier fetch), `scout:docs-scout` (Context7 + DeepWiki), `scout:paper-scout`, `scout:synthesis-scout`. Codex 에는 agent 표면이 없으므로 orchestrator 가 generic subagent 또는 순차 실행으로 같은 축을 돌린다. `scout:scout` / `scout:deep-scout` 는 마이그레이션 메시지만 반환하는 stub 이다.

```text
Skill("scout:research-orchestrator", "Research RAG eval frameworks 2026")
Agent(subagent_type="scout:github-scout",
      prompt="query=fastapi production boilerplate\nworkspace_dir=$WORKSPACE\nartifact_id=01_github")
```

정책 / 시장 / 역사 같은 비-code 토픽은 sibling `/deep-research` 를 직접 부른다.

**Requirements:** `gh`, `uvx` (hf), Docker (paper-search MCP), `SEMANTIC_SCHOLAR_API_KEY` (선택)

</details>

<details>
<summary><strong>ml</strong> - ML / CV 개발</summary>

| Skill | Description |
|-------|-------------|
| `/ml:ml-dev-principles` | ML / 멀티모달 개발 작업 규율 (모델·데이터셋 선정, EDA, 학습·파인튜닝, 평가 하네스, FP/FN 오류 분석, GPU 병렬 패턴은 `references/gpu-parallel.md`) |
| `/ml:gradio-cv-app` | Gradio 컴퓨터 비전 데모 앱 (Editorial 디자인) |
| `/ml:cv-notebook` | CV 실험 노트북 저작 + 인터랙티브 ipywidgets 탐색 모드 |
| `/ml:edit-notebook` | `.ipynb` 안전 편집 (NotebookEdit 만 사용, 출력 보존, 셀 순서 검증) |

</details>

<details>
<summary><strong>wiki</strong> - LLM-Wiki 메모리 + mem0 플릿 운영</summary>

중립 `.llmwiki/` 루트의 3-layer: `insight/` (승격된 cross-agent 규칙, `core` 의 prompt-inject 훅이 매 프롬프트 가리킴), `wiki/` (LLM 이 유지하는 lore), `raw/` (immutable evidence). 해석 순서는 `.llmwiki/wiki/` → legacy `.claude/wiki/` → `.codex/wiki/`.

| Skill | Description |
|-------|-------------|
| `/wiki:bootstrap-wiki` | 새 repo 에 3-layer 스캐폴드 (템플릿 번들) |
| `/wiki:ingest-finding` | audit / PR finding 을 wiki 에 반영 (reversible diff-log + 다중 페이지 cross-update) |
| `/wiki:lint-wiki` | 4 wiki-rot 모드 감사 (identity / level / relationship / staleness) |
| `/wiki:plaud-note-taking` | PLAUD 녹음기의 Whisper 전사록을 프로젝트 용어로 정정 → `derived/` corrected + digest → wiki ingest. 원본과 PLAUD 요약은 수정하지 않는다 |
| `/wiki:fleet-scan` | mem0 전 앱 스캔: 앱별 노이즈율, 쓰레기 app_id 후보, user_id 파편화, 설정 자세 (`MEM0_RERANK`, `~/.mem0/settings.json` `auto_save`, 훅 timeout). read-only |
| `/wiki:cleanup` | mem0 백업 → 삭제 (타입 단위 또는 앱 전체). dry-run 기본, `--execute` + 앱별 확인 게이트 |

**Hooks (auto-installed):**

| Hook | Trigger | Behavior |
|------|---------|----------|
| `wiki_stale_check.sh` | UserPromptSubmit | volatility 윈도우 (stable 180d / volatile 30d) 초과 page soft-hint |
| `wiki_post_commit_hint.sh` | PostToolUse(Bash) | 2+ file 또는 50+ line commit 시 ingest 제안 |
| `wiki_session_start_lint_hint.sh` | SessionStart | 마지막 lint 가 3일 초과면 `/wiki:lint-wiki` 권유 |
| `wiki_session_capture.sh` | Stop, SubagentStop | transcript 의 ingest 신호를 `.llmwiki/.staging/pending-<sid>.md` 로 기록 (wiki 무접촉) |
| `wiki_session_start_drain.sh` | SessionStart | 이전 세션의 pending capture 를 `ingest-finding` 지시로 surface |

Cross-ref 는 typed 만 허용한다: `> Refines:` `> Contradicts:` `> Evidence:` `> See-also:` `> Supersedes:` `> Superseded-by:` `> Uses:` `> Depends-on:` `> Caused-by:` `> Fixed-by:`. wiki 없는 repo 에서는 훅이 silent skip.

**Requirements:** `jq`; mem0 스킬은 `MEM0_API_KEY`

</details>

<details>
<summary><strong>council</strong> - 이종 벤더 3인 심의</summary>

`/council:convene` 으로 하나의 질문을 codex (GPT), agy (Gemini), Claude Opus 좌석에 동시에 던지고, 서로의 답을 읽고 반박하게 한 뒤 합의와 끝내 갈린 것을 `.council/<날짜>-<슬러그>/consensus.md` 로 남긴다. Claude 서브에이전트를 여러 개 띄우면 가중치를 공유해 관점이 늘지 않는 문제를 겨냥한다.

- 2라운드: 독립 의견 → 사용자 재질문 관문 → 상호 반박 → 의장 합성
- 좌석 모델은 `~/.claude/council-models.json` 주간 TTL 레지스트리. 만료 시 실제 목록을 근거로 항상 질문, 자동 승급 없음
- 동족 합의 할인: 의장과 Claude 좌석의 동의는 새 논거를 가져왔을 때만 계수
- 결과를 코드에 자동 적용하지 않음. 결석 좌석은 명시
- Claude 전용 (codex 를 의석으로 앉히므로 Codex 에서 돌리면 순환, Claude 좌석은 Agent 도구 필요)

**Requirements:** `codex` / `agy` CLI (없는 좌석은 결석), `jq`

</details>

<details>
<summary><strong>codex-image</strong> - Claude → Codex 이미지 생성 브리지</summary>

`/codex-image` 로 Codex CLI 의 이미지 생성에 위임한다. OpenAI API key 없이 ChatGPT OAuth 만으로 동작한다.

- 명시 요청 또는 작업 사양이 codex-image 를 지정한 경우만 생성, 모호하면 확인
- 기본 출력 `assets/generated/codex-image/`, non-destructive 파일명
- `--size` / `--quality` / `--out` / `-n` / `--edit` / `--ref` 옵션, opt-in `--model` / `--reasoning` / `--sandbox`
- Claude 전용 (Codex 에서 돌리면 순환)

**Requirements:** Codex CLI + ChatGPT OAuth 로그인

</details>

## Configuration

### Codex

Codex 는 같은 `plugins/<name>/` 트리와 `.claude-plugin/` 매니페스트를 네이티브 폴백으로 읽는다 (`.codex-plugin` → `.claude-plugin`, `.agents/plugins/marketplace.json` → `.claude-plugin/marketplace.json`).

```bash
codex plugin marketplace add ~/.claude/plugins/marketplaces/my-claude-plugins
codex plugin add wiki@my-claude-plugins
```

- `council` 과 `codex-image` 는 Codex 에 설치하지 않는다 (순환).
- Codex 는 `commands` / `agents` 를 무시하고 skill 만 노출한다. `docs` 의 4 커맨드와 `scout` 의 agent 팀은 Claude 전용이다.
- Skill `description` 은 1024자 미만이어야 한다. Codex 는 초과 스킬을 조용히 skip 한다.

### 머신 로컬 운영 갱신

marketplace 업데이트가 정본이다. 아래는 리포지토리 상태를 바꾸지 않는 머신 로컬 작업이다.

```bash
rm -rf ~/.claude/plugins/cache/my-claude-plugins/
codex plugin marketplace remove my-claude-plugins
codex plugin marketplace add ~/.claude/plugins/marketplaces/my-claude-plugins
codex plugin add dev@my-claude-plugins
```

**수동 `~/.codex/hooks.json` 등록은 지우지 말고 경로만 고친다.** Codex 훅 (`core` 매 프롬프트 주입, `wiki` stale 체크 등) 의 유일한 실행 경로가 이 수동 등록이다. 2.30.0 이후 캐시 경로가 바뀌므로 항목의 스크립트 경로를 `core-config/<ver>/hooks/...` → `core/1.0.0/hooks/...`, `llm-wiki/<ver>/hooks/...` → `wiki/1.0.0/hooks/...` 로 바꾼 뒤 Codex `/hooks` 에서 trust 를 재승인한다. 승인 전까지 훅은 아무 신호 없이 실행되지 않는다. 각 플러그인의 `hooks/codex-hooks.json` 이 등록할 항목의 문서화된 소스다.

### 기여자 가드

```bash
git config core.hooksPath .githooks   # clone 당 1회
```

`.githooks/pre-commit` 과 `.github/workflows/validate-codex.yml` 이 같은 가드를 돌린다.

### CI 가드가 지키는 것

- `check-doc-consistency.mjs` — README 구조 트리·`## 플러그인 상세` 의 `<summary>` 이름 집합·AGENTS `## Plugins` 표·배지와 카운트 문자열이 `marketplace.json` 과 일치. 트리와 `<details>` 는 같은 문서의 다른 표면이라 둘 다 대조한다.
- `check-shell-portability.mjs` — GNU 전용 셸 구문 (`md5sum`·`sed -i`·`grep -P`·`date -d`·`stat -c`·`timeout`·`${VAR,,}`·`mapfile`·`declare -A` 등) 이 폴백도 capability probe 도 없이 쓰인 경우 차단. `||` 는 우변에 BSD 대응물이 있을 때만 폴백으로 보고, probe 도 대응물과 짝일 때만 인정한다. BSD 대응물이 없는 구문 (`grep -P`·`timeout`·bash 4 문법) 은 `# portability-ok: <사유>` 명시 예외만 받는다 (사유 필수). 판정은 정규식이 아니라 셸 워드 토크나이저로 하므로 GNU 긴 옵션 (`--perl-regexp`·`--date`·`--in-place`) 도 잡고, 인용 문자열과 `command -v` 인자, `case` 패턴은 호출로 세지 않는다. 스캔 대상은 `*.sh`·`*.bash`·`*.md` 의 bash 펜스와 shebang 이 sh/bash 인 확장자 없는 tracked 파일. 회귀 케이스 30건 (`check-shell-portability.test.mjs`) 이 pre-commit + CI 에서 함께 돈다.
- `check-skill-contract.mjs` — 한 런타임에서만 조용히 깨지는 스킬 위반 차단: `description` 1024자 초과, 인용 없는 `: `, resolver 없는 펜스 블록의 bare `${CLAUDE_PLUGIN_ROOT}`, 비-kebab `name`, byte 0 에서 시작하지 않는 frontmatter, `name` 과 디렉터리명 불일치. 스캔 전에 RED/GREEN 픽스처를 먼저 돌린다.
- `windows-codex-hooks.test.mjs` — Windows 에서 `wiki` 의 Codex 훅 `commandWindows` 항목을 실제 PowerShell → Git Bash 경계로 실행. 다른 플랫폼은 skip.
- `check-skill-prose.mjs` — 500줄 초과·깊은 참조 경로 정보성 경고 (비차단).

픽스처 스위트 두 개가 같은 자리에서 돈다: `plugins/dev/skills/cr-fix/tests/run-tests.sh` (1차 경로가 실패한 뒤에만 실행되는 CLI 폴백·CR 상태 경로) 와 `plugins/council/skills/convene/tests/run-tests.sh` (스킬 본문에만 존재하는 codex / agy 호출 계약). macOS CI 레그가 BSD 폴백이 실제로 실행되는 유일한 지점이며 `/bin/bash` 로 bash 3.2 를 강제한다. 가드는 소스를 자동 수정하지 않는다.

## 요구사항

| 도구 | 용도 | 필수 |
|------|------|------|
| [Claude Code](https://docs.anthropic.com/claude-code) | 기본 CLI | Yes |
| `gh` | GitHub 워크플로우 | dev |
| `uv`, `ruff` | Python 포매팅 훅 | core |
| `jq` | 상태 파일, wiki 훅, council | dev, wiki, council |
| Docker | paper-search MCP 서버 | scout (paper-search) |
| Node 18+ | 가드 스크립트 | 기여자 |
| Codex CLI | 네이티브 로드, council 좌석, codex-image | Codex 사용자 |

## 프로젝트 구조

```
.
├── .claude/
│   ├── settings.json         # 플러그인 auto-load
│   └── rules/                # 경로 스코프 규칙 (Claude 전용)
├── .claude-plugin/
│   └── marketplace.json      # 레지스트리 + 버전
├── plugins/
│   ├── core/                 # 훅 전용 (포매팅, 알림, prompt inject)
│   ├── dev/                  # GitHub 워크플로우 + 프로젝트 셋업 + E2E 하네스
│   ├── docs/                 # 문서 저작 + 스킬 저작 + 내보내기
│   ├── scout/                # 리서치 orchestrator + DeepWiki + paper-search MCP
│   ├── ml/                   # ML / CV 개발
│   ├── wiki/                 # LLM-Wiki 3-layer + hooks + mem0 플릿 운영
│   ├── council/              # 이종 벤더 3인 심의 (Claude 전용)
│   └── codex-image/          # Claude → Codex 이미지 생성 (Claude 전용)
├── scripts/                  # 가드 스크립트 (Node 18+, 의존성 없음)
├── .llmwiki/                 # 두 런타임 공유 lore (insight / wiki / raw)
├── AGENTS.md                 # 두 런타임 공통 최상위 지침 (정본)
├── CLAUDE.md                 # @AGENTS.md import
├── CLAUDE.md.global          # 사용자 전역 지침 정본 (~/.claude/CLAUDE.md, ~/.codex/AGENTS.md 로 복사)
├── code_review.md            # Codex cloud reviewer 상세 룰
└── README.md
```

## 참고 자료

- [Claude Code Documentation](https://docs.anthropic.com/claude-code)
- [Claude Code Plugin System](https://docs.anthropic.com/claude-code/plugins)

## License

MIT
