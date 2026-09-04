<div align="center">

<img src="assets/banner.png" width="600" alt="my-claude-plugins banner">

<br>

<img src="assets/logo.png" width="100" alt="my-claude-plugins logo">

# my-claude-plugins

Claude Code를 위한 14개 플러그인 모음 - GitHub 워크플로우부터 AI 이미지 생성까지. Codex 도 동일한 소스 트리와 `.claude-plugin/` 매니페스트를 네이티브로 로드합니다 (shared source, 생성 계층 없음).

[![Plugins](https://img.shields.io/badge/plugins-14-blue.svg)](https://github.com/YoungjaeDev/my-claude-plugins)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-purple.svg)](https://docs.anthropic.com/claude-code)

[빠른 시작](#빠른-시작) | [플러그인 목록](#플러그인-목록) | [설치 옵션](#설치-옵션)

</div>

---

## 왜 이 플러그인들인가?

Claude Code에 빠져 있는 것들을 채웁니다:

- **GitHub 워크플로우** - 이슈 분해, PR, 코드 리뷰, post-merge 정리까지 한 흐름으로
- **리서치** - arXiv/PubMed 논문 검색, GitHub 레포 문서화, 보일러플레이트 탐색
- **멀티모달** - Claude→Codex 이미지 생성 브리지, 웹 페이지 번역
- **문서화** - README/CHANGELOG, CLAUDE.md 모듈화, PRD/Tech Spec 생성
- **시각화** - Mermaid 다이어그램

## 빠른 시작

```bash
# 1. Marketplace 추가
/plugin marketplace add YoungjaeDev/my-claude-plugins

# 2. 원하는 플러그인 설치
/plugin install github-dev@my-claude-plugins
/plugin install code-scout@my-claude-plugins
```

설치 후 `/github-dev:resolve-issue 123` 같은 명령어로 바로 사용 가능합니다.

## 플러그인 업데이트

플러그인 캐시 버그로 인해 업데이트 시 캐시 삭제가 필요합니다 ([#17361](https://github.com/anthropics/claude-code/issues/17361), [#19197](https://github.com/anthropics/claude-code/issues/19197)):

```bash
# 1. 캐시 삭제
#   macOS / Linux:
rm -rf ~/.claude/plugins/cache/my-claude-plugins/
#   Windows (PowerShell):
#   Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\plugins\cache\my-claude-plugins"
#   Windows (cmd):
#   rmdir /s /q "%USERPROFILE%\.claude\plugins\cache\my-claude-plugins"

# 2. Marketplace 업데이트 후 Claude Code 재시작
/plugin marketplace update my-claude-plugins
```

> **Note**: Auto-update 활성화해도 플러그인 파일은 자동 갱신되지 않습니다. 수동 캐시 삭제가 유일한 해결책입니다.

## 플러그인 목록

| 카테고리 | 플러그인 | 설명 |
|---------|---------|------|
| **Core** | `core-config` | Python 포매팅, 알림 + 매 프롬프트 behavioral 주입 훅 (`prompt_inject.sh`, Claude+Codex 공유). 조건부 포인터 2종: cwd 에 knowledge root 가 있으면 `.llmwiki/insight/`, PATH 에 `codex` / `agy` 가 있으면 한 줄짜리 `[council]` 위임 리마인더 (Claude 전용) (work guidelines 는 `~/.claude/CLAUDE.md`) |
| **GitHub** | `github-dev` | 커밋, PR, 이슈 분해(라벨 생성 흡수), 이슈 해결, 코드 리뷰 자동화, post-merge 정리(진행상황 동기화 흡수) + `state-tracker` (spec/issue/PR 파이프라인 집계) |
| **Testing** | `e2e-harness` | Playwright E2E 테스트 하네스 엔지니어링 — 공식 planner/generator/healer AI 에이전트 래핑 (`npx playwright init-agents --loop=claude`). e2e-setup(하네스 온보딩 + 인증 분리 + route 모킹 + CI 트레이스 아티팩트/PR 코멘트/게이팅), e2e-author(planner→generator + `--repeat-each` 번인 플래키 게이트), e2e-debug(헤드리스 trace 분석 + healer 자가수리 루프). Playwright 부재 시 graceful degrade |
| **Research** | `code-scout` | 다축 리서치 하네스 — 5-axis scout 팀 (github/hf/web/docs/paper) + synthesis-scout + research-orchestrator skill(단일 진입점). exa MCP + WebSearch + brightdata(tier-3) + insane-search(tier-4, WAF/blocked). paper-scout 가 paper-search-tools 8-source 래핑. 비-code/ML 토픽은 sibling `/deep-research` 직접 호출 (orchestrator 가 위임하지 않음). `brightdata-guide`/`exa-web-search`/`resource-finder` 는 스킬에서 orchestrator references/ 로 강등 (agent 가 경로로 직접 참조) |
| | `deepwiki` | GitHub 레포 AI 문서화 |
| | `paper-search-tools` | arXiv, PubMed 등 8개 플랫폼 논문 검색 (설치·트러블슈팅 가이드가 스킬 references/ 로 내장, setup 흡수) |
| **AI Models** | `codex-image` | Claude->Codex 이미지 생성 브리지 (ChatGPT OAuth, OpenAI API key 불필요) |
| | `council` | 이종 벤더 심의 (`/council:convene`) — codex(GPT) + agy(Gemini) + Claude(Opus) 3인이 독립 의견 → 사용자 재질문 관문 → 상호 반박 → 의장 합성. 좌석 모델은 `~/.claude/council-models.json` 에 주간 TTL 로 고정 |
| **Dev Tools** | `ml-toolkit` | ML/멀티모달 개발 원칙(GPU 병렬 처리 패턴 references/ 로 흡수), Gradio CV 앱, CV 노트북 저작(인터랙티브 탐색 모드 흡수) + Jupyter 노트북 안전 편집 |
| **Planning** | `project-init` | Day-1 프로젝트 부트스트랩 (.claude/ + CLAUDE.md + AGENTS.md w/ Codex review guidelines + gh repo create) |
| **Docs** | `docs-forge` | 에이전트가 읽는 문서 저작 — `doc-guides` (README/CHANGELOG/배포 문서/MOC 참조 카드 4종 통합, 해당 command 가 결정적 로드) + `write-rules` (CLAUDE.md/.claude/rules) + `interview-methodology` (요구사항 수집·grill-me + TCREI 재작성 템플릿 흡수) + `skill-forge`/`skill-audit`/`skill-fleet-review` (스킬 저작·진단·전수 검토) |
| **Content** | `publish` | 산출물을 다른 표면으로 내보내기 — 웹 아티클 한국어 번역, 로컬 → Google Drive 단방향 제안형 동기화 (gws CLI, 승인 게이트 필수) |
| **Memory & Lore** | `llm-wiki` | Karpathy LLM-Wiki 3-layer (insight + wiki + raw; ingest/lint/bootstrap + 5 hooks; query-wiki/migrate-wiki 폐지 — `index.md` 직접 읽기 / 수동 마이그레이션; post-merge ingest built into `github-dev:post-merge`) + `plaud-note-taking` (PLAUD Whisper 전사록 용어 정정 → `.llmwiki/raw/transcripts/`) |
| **Memory & Lore** | `mem0-ops` | 플릿 레벨 mem0 진단·정리 — fleet-scan(전 앱 노이즈율·파편화 + 설정 자세 점검, doctor 흡수) + cleanup(백업→삭제, dry-run 기본). upstream mem0 플러그인(프로젝트 내부 품질)과 역할 분리 |

## 설치 옵션

### 로컬 개발

```bash
git clone git@github.com:YoungjaeDev/my-claude-plugins.git
cd my-claude-plugins
claude  # .claude/settings.json에서 자동 로드
```

### Marketplace에서 설치

```bash
# User scope (모든 프로젝트) - 기본값
/plugin install core-config@my-claude-plugins

# Project scope (팀 공유, git 추적)
/plugin install core-config@my-claude-plugins --scope project

# Local scope (개인용, 추적 안 함)
/plugin install core-config@my-claude-plugins --scope local
```

## 플러그인 상세

### Core

<details>
<summary><strong>core-config</strong> - 개발 필수 설정</summary>

Python 자동 포매팅 + 크로스 플랫폼 알림 + 매 프롬프트 behavioral 주입 훅 (`prompt_inject.sh` — 한국어 기본 + 핵심 규율 + `.llmwiki/insight/`·wiki 참고 포인터; Claude `UserPromptSubmit` plain stdout / Codex `hookSpecificOutput` JSON 공유). wiki 포인터는 기본적으로 plain 이다 — federation 라벨은 off 가 기본값이고 `CORE_CONFIG_FEDERATE_MEM0=1` 로만 복원한다: 그때 `.llmwiki/` = `[AUTHORITATIVE]` (dated·sourced 우선), mem0 = `[RECALL]` (보조, 라벨일 뿐 mem0 호출 0) 라벨이 붙고 Codex 는 `[RECALL]` 을 생략한다. 작업 가이드라인은 `~/.claude/CLAUDE.md` (SSOT) 가 담당.

**Hooks:**
| Hook | Trigger | Description |
|------|---------|-------------|
| `auto-format-python.py` | Post Write/Edit | ruff로 Python 포매팅 |
| `notify_osc.py` | Stop/Notification | 터미널 알림 |

**Requirements:** `uv`, `ruff`

</details>

### GitHub & Code Review

<details>
<summary><strong>github-dev</strong> - GitHub 워크플로우 자동화</summary>

**Commands:**
| Command | Description |
|---------|-------------|
| `/github-dev:commit-and-push` | 분석, 커밋, 푸시 |
| `/github-dev:resolve-issue` | 이슈 해결 E2E (worktree, 리뷰, 검증) |
| `/github-dev:cr-fix` | CodeRabbit + Codex 통합 파이프라인 (skill, wait + fetch + apply + push 루프, --auto-merge 옵션, resolve-issue 기본 ON). `--cr-source <auto\|pr-bot\|cli\|codex-only>` 로 소스 선택; `auto` 는 PR-bot rate-limit 감지 시 로컬 `coderabbit` CLI 또는 Codex-only 로 silent fallback (1800s spin 해소). |
| `/github-dev:post-merge` | 브랜치 정리, 일회성 산출물 정리(Step 4.5, 휴리스틱 후보 → 확인 → git rm), PR 학습을 설정/Serena/README에 통합 + 필수 wiki lore 적재 (skill). 마일스톤/이슈 진행 상황 동기화도 여기서 수행 (update-progress 흡수, 상세는 `skills/post-merge/references/update-progress.md`) |
| `/github-dev:decompose-issue` | 이슈를 하위 작업으로 분해. 저장소에 라벨 taxonomy 가 없으면 먼저 생성 (create-issue-label 흡수) |
| `/github-dev:release` | 버전 릴리스 + 자동 CHANGELOG 생성 |
| `/github-dev:state-tracker` | `.claude/state/spec.json` 4 ops — `read` / `init` (frontmatter 에서 재생성) / `start <spec>` / `complete <spec>` |

**`state-tracker`** — `.claude/state/spec.json` 한 파일로 "지금 무엇이 in-flight 이고 어떤 spec / issue / PR 에 묶여있나" 를 한 번의 `Read` 로 답하는 aggregate cache. spec frontmatter `status:` 가 SSOT 이고 JSON 은 재생성 가능한 캐시입니다. `post-merge` Step 5.7 이 merge 직후 `complete <spec-path>` 를 자동 호출합니다. hooks 없음 — 순수 on-demand skill.

**Flags:** `--skip-review`, `--strict`

**Requirements:** `gh` CLI

</details>

### Testing

<details>
<summary><strong>e2e-harness</strong> - Playwright E2E 테스트 하네스 엔지니어링</summary>

Playwright 공식 AI 테스트 에이전트(planner/generator/healer)를 래핑해 **planner → generator → healer 자가개선 루프**를 구성합니다. 테스트 코드는 실행하면 센서, 읽으면 명세 — 에이전트의 자기검증 수단.

| 스킬 | 설명 |
|------|------|
| `/e2e-harness:e2e-setup` | 풀 하네스 온보딩 — `npx playwright init-agents --loop=claude` 로 planner/generator/healer 생성, 인증 분리(`auth.setup.ts` + `storageState` + setup-project 의존), `page.route` 모킹 스캐폴드(Next.js BFF/SSR 인지), E2E 운영 SSOT 문서, GitHub Actions CI(트레이스/리포트 아티팩트 업로드 + 실패 시 PR 코멘트 + path/label 게이팅). 기존 `playwright.config` 는 덮어쓰지 않고 머지 제안 + 백업 |
| `/e2e-harness:e2e-author` | CUF(critical user flow) 선정 → planner 계획서 → **사용자 검토 게이트** → generator 스펙 생성(semantic `getByRole` 강제) → `--repeat-each` 번인으로 플래키 차단 |
| `/e2e-harness:e2e-debug` | 실패한 CI run/PR 입력 → 트레이스 아티팩트 다운로드 → 헤드리스 trace 분석 → healer 원인 분석·수리(최대 3회 후 skip + 사유 코멘트) → 재실행 검증 |

**Cross-runtime (Claude / Codex):** 세 스킬은 런타임에 따라 두 런타임 계열·세 실행 경로(Path A/B/C)로 갈립니다. **Claude Code** 는 `init-agents --loop=claude` 가 생성한 named agent(planner/generator/healer)를 이름으로 디스패치합니다(**Path A**). **Codex 0.135** 는 그 agent 파일을 named subagent 로 등록하지 못하므로, 번들된 `references/role-contracts.md` 의 역할 계약을 인라인으로 실은 **generic subagent** 로 같은 역할을 실행하거나(**Path B**), 위임이 불가능하면 순차 실행합니다(**Path C**). CUF 선정·계획 검토 게이트·semantic locator·`--repeat-each` 번인·trace-first 진단·healer 3회 상한 등 모든 게이트는 두 경로에서 동일합니다. `--loop=codex` 는 버전 추정이 아니라 feature-detect 로만 사용하고, `.mcp.json` 의 `playwright-test` 항목은 기존 서버를 덮어쓰지 않고 머지합니다.
**Requirements:** Node.js + Playwright (`npm init playwright@latest`), `gh` CLI (e2e-debug 의 CI 트레이스 fetch)

**Loose coupling:** Playwright 미설치 시 graceful degrade. `github-dev` 의 resolve-issue/commit-and-push 는 이 플러그인 없이도 E2E 를 옵트인 감지만 함 (상호 부재에 안전)

</details>

### Research & Search

<details>
<summary><strong>code-scout</strong> - 다축 코드 & ML 리서치 하네스</summary>

**Skills (entry points):**
| Skill | Purpose |
|-------|---------|
| `research-orchestrator` | 유일한 스킬 진입점. 쿼리 → mode 감지 (quick/deep) → fan-out → synthesis-scout 합성. |

`exa-web-search`(exa MCP + 4-tier fetch 가이드), `resource-finder`(github/hf-scout 검색 hygiene cheat-sheet), `brightdata-guide`(Bright Data MCP 툴 + `bdata` CLI 가이드 — web-scout tier-3 fetch fallback 경로)는 독립 스킬에서 `research-orchestrator/references/*.md` 로 강등되었습니다. scout agent 와 orchestrator 자신만 경로로 직접 읽고, 세션 레벨 스킬로는 더 이상 트리거되지 않습니다.

**Agent team (6, all `opus`):**
| Agent | Axis |
|-------|------|
| `github-scout` | `gh search repos/code`, awesome-list discovery |
| `hf-scout` | `uvx hf` + HF REST API (models/datasets/spaces) |
| `web-scout` | exa MCP 우선, WebSearch fallback (Reddit/SO/블로그/뉴스). fetch 4-tier: exa → brightdata → **insane-search** (WAF/403/challenge URL, X/Reddit/Coupang 등) |
| `docs-scout` | Context7 (라이브러리 docs) + DeepWiki (repo Q&A) |
| `paper-scout` | paper-search-tools 8-source 래핑 (arXiv/Semantic Scholar/Crossref/PubMed/bioRxiv/medRxiv/IACR/Google Scholar). 도메인별 2-3 source 선택, 학술 신호 감지 시 deep mode 5-axis 에 자동 인입 |
| `synthesis-scout` | dedup (DOI 포함) / trust ranking (peer-reviewed > arxiv high-cite > arxiv recent) / conflict resolution / 최종 보고서 |

**런타임 이식성 (v2.2.0)**: 이 6개 agent 는 **Claude Code 전용** — Codex 는 skill 은 노출하지만 `agents/*.md` 를 등록하지 못한다. 그 런타임에서는 `research-orchestrator` skill 이 named agent 미등록을 감지해 동일 축을 generic 병렬 subagent (Codex `Task`) 로, 위임 불가 시 현재 에이전트 내 순차 실행으로 돌리고 synthesis 를 in-skill 로 수행한다. 경로들이 공유하는 계약은 `skills/research-orchestrator/references/axis-contracts.md`. Claude named-agent quick / deep 경로 동작은 무변경.

**경계 — `/deep-research` 와 분리**: code-scout 는 code / ML / docs / papers 도메인 전용. 정책 / 시장 / 역사 / 인물 등 일반 토픽은 sibling `/deep-research` 직접 호출 (7-phase + adversarial verify + state machine). orchestrator 가 위임하지 않음 — 의도된 boundary.

**Usage — Claude Code 호출 (셸 아님, 메인 세션에서 실행):**
```text
# 권장: orchestrator 가 workspace 생성 + 라우팅 + synthesis 까지 모두 처리
Skill("code-scout:research-orchestrator", "Research RAG eval frameworks 2026")

# 단일 axis 직접 호출 (scout 계약상 workspace_dir + artifact_id 필요)
Agent(subagent_type="code-scout:github-scout",
      prompt="query=fastapi production boilerplate\nworkspace_dir=$WORKSPACE\nartifact_id=01_github")

# 학술 단일 axis
Agent(subagent_type="code-scout:paper-scout",
      prompt="query=sparse autoencoder interpretability\nworkspace_dir=$WORKSPACE\nartifact_id=05_paper")
```

> 위 `Agent(subagent_type="code-scout:*-scout")` 직접 호출은 **Claude Code 전용**이다. Codex 에서는 이 named agent 들이 등록되지 않으므로 `Skill("code-scout:research-orchestrator")` 로 진입하면 orchestrator 가 generic subagent / 순차 fallback 으로 같은 축을 실행한다 (위 "런타임 이식성" 참조).

**Workspace 준비 (위 직접 호출 전에 실제 셸에서):**
```bash
PARENT="${TMPDIR:-/tmp}/research"
mkdir -p "$PARENT"
WORKSPACE=$(mktemp -d "$PARENT/run.XXXXXX")
# 결과는 $WORKSPACE/01_github.json 등
```

**Migration:**
- v1.x → v2.0: `Agent(subagent_type="code-scout:scout")` → `Skill("code-scout:research-orchestrator")` (quick mode 자동)
- v2.0 → v2.1: `Agent(subagent_type="code-scout:deep-scout")` 는 v2.0 doc-only stub 그대로 유지 (사용자 관찰 동작 v2.0 과 동일 — 동일 migration 메시지 반환). 영구 제거는 향후 MAJOR 릴리스로 연기. 권장 대안: `Skill("code-scout:research-orchestrator")` 에 "deep / thorough / comprehensive / compare / best practices" 키워드 포함 → deep mode 자동.
- 학술 신호 (paper / arxiv / DOI / SOTA / benchmark / 인용 / venue names) 가 있는 deep 쿼리는 자동으로 5-axis (paper-scout 포함). 기존 4-axis flow 는 무변경.
- WAF / 403 fetch 실패는 web-scout 가 자동으로 insane-search 로 retry. 호출자 변경 없음.

</details>

<details>
<summary><strong>deepwiki</strong> - AI 기반 레포 문서화</summary>

**Commands:**
| Command | Description |
|---------|-------------|
| `/deepwiki:ask` | 레포에 AI로 질문 |
| `/deepwiki:generate-llmstxt` | llms.txt 생성 |

**Usage:**
```bash
/deepwiki:ask facebook/react "reconciliation은 어떻게 동작하나요?"
```

</details>

<details>
<summary><strong>paper-search-tools</strong> - 학술 논문 검색</summary>

8개 플랫폼에서 논문 검색, 다운로드, 읽기. 단일 스킬 `paper-search` — 설치·MCP 등록·핸드셰이크 실패 triage 는 번들 `references/docker-setup.md` 로 흡수 (구 `setup` 스킬).

**Platforms:** arXiv, PubMed, bioRxiv, medRxiv, Google Scholar, IACR, Semantic Scholar, CrossRef

**MCP Tools (23):** `search_arxiv`, `download_arxiv`, `read_arxiv_paper` 등

</details>

### AI Models

<details>
<summary><strong>codex-image</strong> - Claude->Codex 이미지 생성 브리지</summary>

`/codex-image` 호출 또는 에이전트의 스킬 로드 시 Codex CLI 의 이미지 생성 기능에 위임해 이미지를 만들거나 편집합니다. OpenAI REST API 나 API key 없이 ChatGPT OAuth 만으로 동작합니다.

**Features:**
- 모델 호출 허용 + 본문 게이트 (1.2.0) — 명시 요청 또는 작업 사양이 codex-image 를 지정한 경우만 생성, 모호하면 생성 전 확인 (생성 비용/부수효과 때문)
- 기본 출력: `assets/generated/codex-image/`, non-destructive 파일명
- `--size` / `--quality` / `--out` / `-n` / `--edit`(기존 이미지 수정) / `--ref`(새 생성의 스타일·캐릭터 참조, 1.3.0) 옵션, opt-in `--model` / `--reasoning` / `--sandbox` (기본은 Codex 기본 모델 + workspace-write 유지)
- Claude-only 브리지 — Codex sync 에서 제외 (순환 방지)

**Requirements:** Codex CLI 설치 + ChatGPT OAuth 로그인

</details>

<details>
<summary><strong>council</strong> - 이종 벤더 3인 심의</summary>

`/council:convene` 으로 하나의 질문을 서로 다른 회사가 만든 세 모델에게 동시에 던지고, 그 셋이 서로의 답을 읽고 반박하게 한 뒤, 합의된 것과 끝내 갈린 것을 문서로 남깁니다. Claude 서브에이전트를 여러 개 띄우는 것은 가중치를 공유하므로 관점이 늘지 않는다는 문제를 정면으로 겨냥합니다.

**의석 (의장은 의석이 아님):**

| 좌석 | 실행 | 기본 고정값 |
|---|---|---|
| codex | `codex exec` | `gpt-5.6-sol` / effort `xhigh` / tier `fast` |
| agy | `agy --print` | `gemini-3.6-flash-high` |
| claude | `Agent` 도구 model 오버라이드 | `opus` |

**Features:**
- 2라운드 프로토콜 — 독립 의견 → 사용자 재질문 관문 → 상호 반박 → 의장 합성
- 주간 TTL 모델 레지스트리 (`~/.claude/council-models.json`) — 만료 시 `agy models` 와 `~/.codex/models_cache.json` 의 실제 목록을 근거로 제시하며 **항상 질문**, 자동 승급 없음
- 동족 합의 할인 — 의장과 Claude 좌석이 가중치를 공유하므로, 동의 사실만으로는 합의 근거로 세지 않고 새 논거를 가져왔을 때만 계수
- 사전 컨텍스트는 파일로 환원 불가능한 것만 — mem0 기억, Serena 심볼 그래프, code-scout 리서치 (파일은 경로만 전달)
- 산출물은 git 추적되는 `.council/<날짜>-<슬러그>/` — 좌석별 로그 + `consensus.md`
- 좌석은 독립적으로 실패하며 결석은 반드시 명시 (agy 는 1회 재시도 후 결석)
- 합의 결과를 코드에 자동 적용하지 않음 — 결론 제시 후 정지
- Claude-only — Codex sync 에서 제외 (순환 방지 + Agent 도구 부재)

**Requirements:** `codex` / `agy` CLI (없는 좌석은 결석 처리되고 나머지로 진행), `jq`

</details>

### Development Tools

<details>
<summary><strong>ml-toolkit</strong> - ML/AI 개발</summary>

**Skills:**
| Skill | Description |
|-------|-------------|
| `/ml-toolkit:ml-dev-principles` | ML/멀티모달 개발 원칙 (PyTorch 멀티 GPU 병렬 패턴은 `references/gpu-parallel.md` 로 흡수, 구 gpu-parallel-pipeline) |
| `/ml-toolkit:gradio-cv-app` | 컴퓨터 비전 Gradio 앱 |
| `/ml-toolkit:cv-notebook` | CV 실험 노트북 저작 + 인터랙티브 ipywidgets 탐색 모드 (구 cv-explorer 흡수) |
| `/ml-toolkit:edit-notebook` | 안전한 `.ipynb` 조작 — NotebookEdit 도구만 사용, 출력 보존, 셀 순서 검증 |

</details>

### Content & Translation

<details>
<summary><strong>publish</strong> - 산출물을 다른 표면으로 내보내기</summary>

만든 것을 이 저장소 밖으로 내보내는 두 경로를 한 번들에 모았습니다. 둘 다 외부 서비스에 쓰기를 하므로 승인 게이트나 키 부재 시 degrade 규칙을 각자 갖습니다.

| Skill | Description |
|-------|-------------|
| `/publish:translate-web-article` | 웹 페이지를 한국어 마크다운으로 번역 |
| `/publish:gws-sync` | 로컬 → Google Drive 단방향 제안형 동기화 |

**`translate-web-article`** — Bright Data MCP(`scrape_as_markdown`)로 페칭하고 `bdata` CLI 를 터미널 폴백으로 씁니다. VLM 이미지 분석, 코드/테이블 보존.

**`gws-sync`** — gws CLI(공식 googleworkspace/cli) 기반. MCP 가 아니라 CLI 를 부르고, 인증(`gws auth login`)은 전제입니다.
1. 전제 확인 — `gws` 미설치 시 설치 안내(`npm install -g @googleworkspace/cli`) 출력 후 중단(자동 설치 안 함)
2. 매핑 설정(`.gws-sync.json`)으로 로컬↔Drive 폴더 대응 + 파일 ID 캐시 기억
3. Drive 트리 탐색 → 신규·변경 diff 리포트
4. **업로드 위치는 AskUserQuestion 으로 승인 필수** — 승인 없이 업로드 안 함
5. 업로드 — 기존 파일은 `files update --upload` 로 content 만 갱신(파일 ID·공유 링크·버전 히스토리 보존)

하드 룰: 단방향(로컬→Drive)만 · 모든 쓰기는 diff+승인 뒤에만 · 삭제는 제안만(자동 삭제 금지) · Drive→로컬 다운로드는 범위 밖. 번들 `references/gws-skills-llms.txt` 는 googleworkspace/cli 공식 스킬 54종 + 레시피 41종 카탈로그로, 상황에 맞는 미설치 스킬을 `npx skills add` 로 제안하는 인덱스입니다.

</details>

### Memory & Lore

<details>
<summary><strong>llm-wiki</strong> - Karpathy LLM-Wiki 3-layer</summary>

중립 `.llmwiki/` 루트의 3-layer: `.llmwiki/insight/` (승격된 cross-agent 규율 — `.claude/rules/` 가 아니라 여기로 graduate, Codex 가 `.claude/rules/` 를 못 읽기 때문; core-config `prompt_inject.sh` 훅이 매 프롬프트 가리킴) + `.llmwiki/wiki/` (LLM-maintained lore) + `.llmwiki/raw/` (immutable evidence). 어느 repo 든 `/plugin install llm-wiki` 한 번이면 4 skill + 5 hook + bootstrap 템플릿 즉시 사용 가능. wiki 해석 순서: `.llmwiki/wiki/` → legacy `.claude/wiki/` → `.codex/wiki/` (중립 root 라 어떤 mirror 변환도 fork 못 함).

**Skills:**
| Skill | Description |
|-------|-------------|
| `/llm-wiki:ingest-finding` | 새 audit / PR finding 을 wiki 에 반영 (diff-log + multi-page cross-update) |
| `/llm-wiki:lint-wiki` | 4 wiki-rot 모드 감사 (identity/level/relationship/staleness) + 6주 retro 리마인더 |
| `/llm-wiki:bootstrap-wiki` | 새 repo 에 3-layer scaffold (templates 번들) |
| `/llm-wiki:plaud-note-taking` | PLAUD 음성 녹음기 전사록 STT·용어 정정 → `derived/` corrected + digest → wiki ingest |

`query-wiki`(wiki MOC 진입)와 `migrate-wiki`(레거시 `.claude/wiki`/`.codex/wiki` → `.llmwiki/` 이관)는 2026-08 폐지되었습니다 — `index.md` 를 직접 읽고, 마이그레이션은 `bootstrap-wiki` 안내를 참고해 수동으로 수행합니다.

**Hooks (auto-installed):**

| Hook | Trigger | Behavior |
|------|---------|----------|
| `wiki_stale_check.sh` | UserPromptSubmit | volatility 윈도우(stable 180d / volatile 30d) 초과 page soft-hint (rate-limit 1h/cwd) |
| `wiki_post_commit_hint.sh` | PostToolUse(Bash) | 2+ file 또는 50+ line commit 시 ingest 제안 (rate-limit 10min) |
| `wiki_session_start_lint_hint.sh` | SessionStart | 최근 `lint-wiki` 가 3일 초과 경과 시 `/lint-wiki` 권유 (additionalContext, rate-limit 4h) |
| `wiki_session_capture.sh` | Stop | 세션 종료 시 transcript 에서 ingest 신호(merge/디버깅 결론/결정) 스캔 → 세션별 `.staging/pending-<sid>.md` 포인터 기록 (wiki page 무접촉, idempotent) |
| `wiki_session_start_drain.sh` | SessionStart | 이전 세션의 pending capture 를 강한 `ingest-finding` 지시로 surface → LLM turn 이 dedup 후 ingest·소비 |

**Cross-ref grammar** (raw `[[wikilink]]` 금지):
- `> Refines: [[page-id]]` — 세부 추가
- `> Contradicts: [[page-id]]` — 충돌, 해결 필요
- `> Evidence: .llmwiki/raw/<file>` — 원본 인용 (복사 아님; 외부 `docs/...` 도 가능)
- `> See-also: [[page-id]]` — 측면 연관
- `> Supersedes:` / `> Superseded-by:` / `> Uses:` / `> Depends-on:` / `> Caused-by:` / `> Fixed-by:` — v2 typed relations

**`plaud-note-taking` 상세:** PLAUD 는 녹음 하나당 **두 산출물**을 냅니다 — Whisper STT **전사록**과, 그 전사록을 다시 LLM 이 요약한 **별도 요약**. 이 스킬의 철칙은 **요약이 아니라 전사록을 기준으로 정정**하는 것입니다 (요약은 없던 결정을 매끄럽게 지어낼 수 있음). 손으로 `.llmwiki/raw/transcripts/` 에 올린 `<YYYY-MM-DD-slug>.transcript.txt`(+선택 `.note.txt`)를 읽어 하위 `derived/` 에 `corrected.md`(전사 전문 + 4단 태깅)와 `digest.md`(회의 정리본)를 씁니다. **원본은 절대 수정하지 않습니다.**

- **정정 규율(보수적)**: STT 최대 오류원인 한국어+영어 코드스위칭을 `terminology.md` 근거로 정정 / 숫자·날짜·금액·계약 조건은 추측 금지 → `[확인 필요]` / 화자 `Speaker N` 은 추정값 / 태깅 `[확인됨]` `[정정]` `[해석]` `[확인 필요]`
- **corrected 이후 3단계**: 확인 게이트(승인 전 digest·wiki 무접촉) → digest 생성(`[해석]`→"논의만 됨", `[확인 필요]`→"미해결", 어느 쪽도 "결정된 것"에 오르지 못함) → wiki ingest(재사용될 lore 만, 인용은 digest 와 동결된 `.transcript.txt` 를 둘 다)
- 파생본은 `derived_from:`/`ingested:` 프론트매터만 달고 `sha256:` 은 달지 않습니다. `lint-wiki` 는 `sha256:` 선언 파일만 해시 대조하므로 정리본을 손으로 고쳐도 `DRIFT` 로 뜨지 않습니다 — 프론트매터 필드 하나가 "고쳐도 되는 파일 / 안 되는 파일" 스위치입니다.

**Related:** spec / issue / PR work-pipeline state 는 `github-dev:state-tracker` 가 담당합니다.

**Conditional:** wiki 없는 repo 에서는 hook silent skip.

</details>

<details>
<summary><strong>mem0-ops</strong> - 플릿 레벨 mem0 진단·정리</summary>

mem0 Platform store를 app_id **간** 레벨에서 진단·정리합니다. upstream `mem0@mem0-plugins`(health/memory-reviewer/stats/dream — 프로젝트 내부 품질, 200건 캡)와 역할 분리 — 기능 복제 없음. 스크립트는 stdlib + REST 직결(v1 entities/delete, v2 list)이라 upstream 버전 변화와 무관하고, 결정론 구간은 LLM 비용 0.

**Skills:**
| Skill | Description |
|-------|-------------|
| `/mem0-ops:fleet-scan` | 전 앱 스캔 — 앱별 노이즈율, 쓰레기 app_id 후보(`JUNK?`), app/user_id 파편화 쌍(`FRAG`) + 설정 자세 점검(`MEM0_RERANK` env, `~/.mem0/settings.json` `auto_save`(env가 아니라 이 파일이 지배하는 함정), decay, 훅 timeout 예산, 정체성 파편화 — 구 `doctor` 흡수). read-only, 제안만 |
| `/mem0-ops:cleanup` | 백업→삭제 — 타입 단위(`--type session_summary`) 또는 앱 전체(`--all`). dry-run 기본, `--execute` + 스킬 레이어 앱별 사용자 확인(스크립트 단독은 `--execute`만 게이트). 백업은 `~/.mem0/backups/`(런별 타임스탬프), 복원은 `infer=False` 재주입 |

**스코프 규칙:** cleanup은 cwd의 프로젝트 app_id가 기본(upstream과 동일한 해석 체인: env → project_map → git slug → basename). basename fallback 스코프는 거부 — 쓰레기 app_id 생성 경로이기 때문. fleet-scan/doctor는 항상 전역.

**전제:** `MEM0_API_KEY` (없으면 안내 후 중단).

</details>

### Planning

<details>
<summary><strong>project-init</strong> - Day-1 부트스트랩 + 기존 repo 셋업 진단</summary>

빈 디렉토리에서 `/project-init:new` 한 번으로 인터뷰 → 로컬 시드 → gh 레포 생성 → 초기 커밋/푸시까지 완료. 이미 있는 repo 는 `/project-init:wiring` 으로 진단.

**시드 결과:**
- `.claude/{spec,rules}/` + `.llmwiki/{raw,wiki}/` 빈 구조 (`.gitkeep`)
- `CLAUDE.md` — minimal stub + LLM Wiki 사용 안내
- `AGENTS.md` — Codex GitHub cloud reviewer 가 자동으로 읽는 `## Review guidelines` 섹션 포함 (variant: general / ml / web)
- `README.md`, `CHANGELOG.md` — minimal 시드 (각각 6-section, Keep-a-Changelog Unreleased)
- gh repo create + 초기 commit + push

**원칙:**
- Minimal seeding — `bootstrap-wiki` / `write-rules` 는 호출 X, 안내만 (빈 프로젝트에 generic 콘텐츠 만들면 사용자 덮어쓰기 비용 발생)
- Owner gate — personal vs 조직 결정은 `AskUserQuestion` 으로 명시 선택
- Idempotent — 같은 디렉토리 재호출 시 기존 파일 보존

**Next actions** (`/project-init:new` 완료 후):
1. 코드 쌓이면 → `/docs-forge:write-rules`
2. 첫 도메인 lore → `/llm-wiki:bootstrap-wiki`
3. 첫 PR merge 후 → `/github-dev:post-merge` (post-merge 내장 wiki 적재 step)

**`/project-init:wiring`** — `new` 의 역방향. 이미 있는 repo 의 하네스 설정을 14 축으로 진단한다. 판정은 `FAIL / WARN / ASK / INFO / SKIP / OK`.

존재 검사("파일이 있나") 위에 **효력 검사**("그게 실제로 먹나") 4 축이 얹혀 있다 — clone 마다 따로 켜야 하는 `core.hooksPath`, `.claude/rules` 의 `paths:` 스코핑을 `@import` 가 무력화한 경우, 같은 MCP 서버가 두 파일에 등록돼 한쪽 정의가 통째로 버려지는 경우, Codex 의 `AGENTS.md` 바이트 예산. 전부 "설정은 있는데 안 먹는" 실패 모드다.

`ASK` 는 결함이 아니라 **아직 아무도 안 정한 결정**이다 (원격 저장소를 만들지, 산출물을 Drive 에 올릴지). 한 번만 묻고 답을 `.claude/state/wiring.json` 에 적어 다음 실행부터 조용해진다 — 매번 짖는 경고는 사람이 무시하게 되고, 그러면 진짜 `FAIL` 도 같이 묻힌다.

탐지는 `scripts/project_state.sh` 가 전담하는 read-only 단계이고, 결함마다 담당 스킬을 지목한 뒤 모든 수정은 `AskUserQuestion` 게이트 뒤에서만 적용한다. 위키 페이지 건강도는 `/llm-wiki:lint-wiki`, mem0 스토어는 `/mem0-ops:fleet-scan`, 삭제된 플러그인이 남긴 고아 MCP 등록과 미사용 확장은 내장 `/doctor` 가 담당 — 중복하지 않는다.

**Requirements:** `gh` CLI authenticated, `git`, `jq`

</details>

### Documentation

<details>
<summary><strong>docs-forge</strong> - 에이전트가 읽는 문서 저작</summary>

사람과 에이전트가 읽는 문서를 만드는 6개 스킬. 크게 세 갈래입니다 — 프로젝트 문서(README/CHANGELOG/배포문서/MOC, `doc-guides` 참조 카드가 뒷받침), 지침·인터뷰 저작(`write-rules`/`interview-methodology`), 스킬 저작(`skill-forge` 3종).

**프로젝트 문서 — Commands:**
| Command | Description |
|---------|-------------|
| `/docs-forge:readme generate` | 템플릿에서 README 생성 |
| `/docs-forge:readme analyze` | 기존 README 분석 |
| `/docs-forge:changelog init` | CHANGELOG 초기화 |
| `/docs-forge:deploy-doc generate` | 배포 / 절차 문서 생성 (요약 + 전제조건 + 번호 단계) |
| `/docs-forge:moc docs/` | 문서 폴더 MOC 인덱스 생성 (경량 / `--strict`) |

**Templates:** CLI, Library, React Component, MCP Plugin, SaaS, Desktop. 9개 awesome-readme 프로젝트 분석 기반.

**`doc-guides`** — 위 4개 command 가 결정적으로 로드하는 저작 참조 카드 4종(README/CHANGELOG/배포 문서/MOC)을 한 스킬로 통합한 것입니다(구 `readme-guide`/`changelog-guide`/`deploy-doc-guide`/`moc-guide`). 세션 레벨에서 직접 트리거하지 않고 각 command 가 필요한 섹션만 로드합니다.

**지침 저작 — `/docs-forge:write-rules`**

CLAUDE.md 와 `.claude/rules/*.md` 를 Claude Code 2026 공식 패턴(200줄 root cap, `paths:` glob scoping, `.claude/rules/` auto-load)에 맞게 생성·재구조화. 단일 진입점이 프로젝트 상태를 스캔해 4개 모드 중 하나를 추천하고 1회 확인을 받습니다.

| Mode | Trigger | 동작 |
|------|---------|------|
| `NEW` | CLAUDE.md 부재 | 인터뷰 → 초기 root + rules/ 생성 |
| `TIGHTEN` | CLAUDE.md ≤200줄, rules/ 비어있음 | root Do/Don't 로 재구조화 |
| `SPLIT` | CLAUDE.md >200줄, rules/ 비어있음 | 섹션 추출 → 모듈화 |
| `REORGANIZE` | root + rules/ 둘 다 존재 | 중복·누락·드리프트 audit |

**인터뷰 · 프롬프트 저작 — `/docs-forge:interview-methodology`**

모드는 breadth-first(5-phase 전수: Context Gathering → Deep Dive → Edge Case Exploration → Prioritization → Validation), depth-first/Socratic(가장 큰 불확실성 1개씩), relentless/stress-test(기존 계획을 집요하게 압박 — "grill me"). 코드베이스로 답할 수 있는 건 묻지 않고, 이미 구체적인 요청엔 인터뷰를 생략합니다(stress-test 는 예외 — 명시 요청 시 압박). 작은 인터뷰는 lightweight 요약, 큰 건은 `.claude/spec/{date}-{feature}.md`.

인터뷰의 목표가 spec 파일이 아니라 다음 세션에 재사용할 프롬프트일 때는 Google TCREI 구조(Task/Context/References/Evaluate/Iterate)로 결과물을 구조화합니다 — 진단표·출력 템플릿·도메인별 패턴은 `references/tcrei-template.md` (구 `tcrei-prompt` 스킬에서 흡수, 스킬 자체는 폐지).

**스킬 저작 (skill-forge 계열):**
| Skill | Description |
|-------|-------------|
| `/docs-forge:skill-forge` | 스킬 작성·개정 — 프론트매터 스키마, 작성 레버, 구조, 3런타임 패키징 계약 |
| `/docs-forge:skill-audit` | 단일 스킬 진단 — 7축 판정 + P0/P1/P2 수정안 |
| `/docs-forge:skill-fleet-review` | 전수 검토 — 측정 우선 코호트 선정 후 `docs/audit/<date>-fleet.md` + CSV |

자립형입니다. 외부 마켓플레이스 스킬을 읽지 않고, 측정 스크립트(`skills/skill-forge/scripts/measure-skills.mjs`)를 번들 내부에 자체 보유합니다.

</details>

## Configuration

### settings.json

```json
{
  "plugins": {
    "local": [
      "./plugins/core-config",
      "./plugins/github-dev",
      "./plugins/e2e-harness",
      "./plugins/code-scout",
      "./plugins/deepwiki",
      "./plugins/ml-toolkit",
      "./plugins/paper-search-tools",
      "./plugins/docs-forge",
      "./plugins/llm-wiki",
      "./plugins/project-init",
      "./plugins/codex-image",
      "./plugins/publish",
      "./plugins/council",
      "./plugins/mem0-ops"
    ]
  }
}
```

### Codex (native shared source)

Codex 는 동일한 `plugins/<name>/` 트리와 `.claude-plugin/` 매니페스트를 **네이티브 폴백**으로 직접 읽습니다 — 매니페스트 탐색이 `.codex-plugin` → `.claude-plugin` 순, marketplace 카탈로그가 `.agents/plugins/marketplace.json` → `.claude-plugin/marketplace.json` 순으로 폴백하므로 생성 계층이 없습니다:

```bash
# Codex CLI 에서 marketplace 등록 & 설치
codex plugin marketplace add ~/.claude/plugins/marketplaces/my-claude-plugins
codex plugin add llm-wiki@my-claude-plugins
```

`codex-image` 와 `council` 은 Codex 에 설치하지 않는 것을 권장합니다 (`codex-image` 는 Claude->Codex 브리지라 Codex 에서 돌리면 순환, `council` 은 codex 를 의석으로 앉히므로 자기 자신을 소환하는 순환이고 Claude 의석이 Agent 도구를 필요로 함).

Codex 는 매니페스트의 `commands` / `agents` 등 미지원 필드를 무시하고 skill 만 노출합니다 — command-bearing 플러그인(`docs-forge`, `deepwiki` 등)도 Codex 측에는 skill 만 보이고, Claude 측 commands 는 그대로 동작합니다.

skill `description` 은 1024자 미만이어야 합니다 (Codex 는 초과 description 을 가진 skill 을 silent 하게 skip). 이 가드는 `scripts/check-skill-contract.mjs` 가 로컬 pre-commit 훅과 CI 양쪽에서 실행합니다:

```bash
# 클론당 1회: 버전 관리되는 .githooks/pre-commit 활성화
git config core.hooksPath .githooks
```

훅을 건너뛴 기여자도 PR 시 `.github/workflows/validate-codex.yml` 이 동일 명령으로 잡습니다.

### CI 가드가 지키는 것 (curation / security)

4개 가드가 매 PR 과 매 커밋(`.githooks/pre-commit`)에서 함께 검증합니다 — 한 런타임에만 보이는 변경이 조용히 깨진 채로 나가는 것을 막는 것이 목적입니다:

- `check-doc-consistency.mjs` — 플러그인 트리·`## 플러그인 상세` 의 `<summary>` 이름 집합·`## Plugins` 표·카운트(총 14)가 `marketplace.json` 과 일치. 상세 절 검사는 나중에 붙었습니다 — 트리와 `<details>` 는 같은 문서의 다른 표면이라, 플러그인 제거 후 상세 절에 죽은 항목 11개가 남고 살아있는 항목 1개가 빠진 채 이 가드가 통과한 적이 있습니다.
- `check-shell-portability.mjs` — GNU 전용 셸 구문(`md5sum`·`sed -i`·`grep -P`·`date -d`·`stat -c`·`timeout`·`${VAR,,}`·`mapfile`·`declare -A` 등)이 **폴백도 capability probe 도 없이** 쓰인 경우 차단. 정상 폴백 쌍(`stat -c … || stat -f …`)과 probe 분기는 통과하고, 증거는 코드만 인정합니다(대체재를 언급하는 주석은 폴백이 아님). 예외는 `# portability-ok: <사유>`.
- `check-skill-contract.mjs` — 한 런타임에서만 **조용히** 깨지는 스킬 위반 차단: `description` 1024자 초과(Codex silent skip, 여러 줄 scalar 는 접어서 계산), 인용 없는 `: `(YAML frontmatter 붕괴), 펜스 블록별 bare `${CLAUDE_PLUGIN_ROOT}`(그 블록에 resolver 가 없으면 Codex 에서 첫 단계 실패), 비-kebab 또는 64자 초과 `name`, byte 0 에서 시작하지 않는 frontmatter, `name` 과 스킬 디렉터리명 불일치. 스캔 전에 RED/GREEN 픽스처를 먼저 돌려 탐지기 자체의 회귀도 막습니다.
- `check-skill-prose.mjs` — 500줄 초과·깊은 참조 경로에 대한 정보성 경고(비차단, 항상 exit 0).

가드와 별개로 두 개의 픽스처 스위트가 같은 자리에서 돕니다 — `plugins/github-dev/skills/cr-fix/tests/run-tests.sh` (1차 경로가 실패한 뒤에만 실행되는 CLI 폴백·CR 상태 경로)와 `plugins/council/skills/convene/tests/run-tests.sh` (스킬 본문에만 존재해 아무도 실행하지 않는 codex/agy 호출 계약 + 레지스트리 TTL 산술). 후자가 지키는 것은 이식성 가드가 볼 수 없는 종류입니다 — agy 호출에서 `< /dev/null` 이 빠지면 그 의석이 영원히 멈추는데, 그건 GNU 전용 구문이 아니라서 `check-shell-portability` 의 관심사가 아닙니다.

CI 는 여기에 더해 **macOS 레그**(`validate-codex.yml` 의 `macos` job)를 돌립니다. 두 스위트가 품은 BSD 폴백들은 GNU 러너에서 절반만 실행되므로, macOS 레그가 그 나머지 절반이 실제로 도는 유일한 지점입니다. `env -i PATH=/usr/bin:/bin` 는 쓰지 않습니다 — macOS 에서 `jq` 가 Homebrew 경로에 있어 스위트가 도구 부재로 죽습니다. 대신 `sed`/`date`/`stat` 이 BSD 빌드인지 assert 하고(Homebrew coreutils 가 시스템 도구를 가리면 실패), 스위트는 `/bin/bash` 로 돌려 bash 3.2 를 강제합니다.

길이·shape·이식성 위반은 **차단**(exit 1)이고, prose 경고는 측정치일 뿐 커밋을 막지 않습니다. 어느 가드도 소스를 자동 수정하지 않습니다 — 위반을 보고할 뿐이니, 소스를 고친 뒤 다시 커밋하세요.

### 머신 로컬 운영 갱신 (PR 밖 오퍼레이터 체크리스트)

marketplace 업데이트가 정본입니다. 예전에 스킬 단위로 손으로 깐 복사본(`~/.agents/skills/<...>`)을 쓰던 머신은 그 복사본이 stale 해질 수 있습니다. 아래는 리포지토리 상태를 바꾸지 않는 **머신 로컬 작업**이라 PR 에 포함되지 않으며, marketplace 업데이트 후 한 번 실행합니다:

```bash
# 1) marketplace 캐시 갱신 (위 "플러그인 업데이트" 절차)
rm -rf ~/.claude/plugins/cache/my-claude-plugins/

# 2) Codex: 네이티브 marketplace 로 재설치
codex plugin marketplace add ~/.claude/plugins/marketplaces/my-claude-plugins
codex plugin add github-dev@my-claude-plugins
```

**수동 `~/.codex/hooks.json` 등록은 지우지 마세요** — 생성 매니페스트 계층이 제거된 뒤로 Codex 훅(core-config 매 프롬프트 주입, llm-wiki stale 체크)의 유일한 실행 경로는 이 수동 등록입니다. 항목이 가리키는 스크립트 경로가 재설치 후에도 유효한지(설치된 플러그인의 `hooks/prompt_inject.sh` 등)만 확인하고, 바뀌었으면 경로를 갱신한 뒤 Codex `/hooks` 에서 trust 를 재승인합니다.

## 요구사항

| 도구 | 용도 | 필수 |
|------|------|------|
| [Claude Code](https://docs.anthropic.com/claude-code) | 기본 CLI | Yes |
| `gh` | GitHub 플러그인 | github-dev |
| `uv` | Python MCP 서버 | core-config |
| `ruff` | Python 포매팅 | core-config |
| Node 18+ | 저장소 가드 스크립트 런타임 | 기여자 (`scripts/check-*.mjs`) |
| Codex CLI | shared-source 네이티브 로드 (`.claude-plugin/` 매니페스트 폴백) | Codex 사용자 |

## 프로젝트 구조

```
.
├── .claude/
│   └── settings.json          # 플러그인 설정
├── plugins/
│   ├── core-config/           # 가이드라인 + 훅
│   ├── github-dev/            # GitHub 워크플로우
│   ├── e2e-harness/           # Playwright E2E 테스트 하네스 (setup/author/debug)
│   ├── code-scout/            # 리소스 탐색
│   ├── deepwiki/              # 레포 문서화
│   ├── paper-search-tools/    # 논문 검색
│   ├── ml-toolkit/            # ML 개발 + Jupyter 편집
│   ├── codex-image/           # Claude->Codex 이미지 생성 브리지
│   ├── council/               # 이종 벤더 3인 심의 (codex + agy + Opus)
│   ├── docs-forge/            # 에이전트가 읽는 문서 저작 (README/CHANGELOG/MOC + 규칙 + 인터뷰 + 프롬프트 + 스킬 저작)
│   ├── llm-wiki/              # LLM-Wiki 3-layer (wiki lore) + PLAUD 전사록 정정
│   ├── publish/               # 산출물 내보내기 (번역 / Tally 폼 / Google Drive 동기화)
│   ├── project-init/          # Day-1 프로젝트 부트스트랩 (인터뷰 + .claude/ + AGENTS.md + gh repo)
│   └── mem0-ops/              # 플릿 레벨 mem0 진단·정리 (fleet-scan/doctor/cleanup)
├── AGENTS.md                 # 두 런타임 공통 최상위 지침 (정본)
├── CLAUDE.md                 # @AGENTS.md import
└── README.md
```

## 참고 자료

- [Claude Code Documentation](https://docs.anthropic.com/claude-code)
- [Claude Code Plugin System](https://docs.anthropic.com/claude-code/plugins)

## License

MIT
