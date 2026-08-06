<div align="center">

<img src="assets/banner.png" width="600" alt="my-claude-plugins banner">

<br>

<img src="assets/logo.png" width="100" alt="my-claude-plugins logo">

# my-claude-plugins

Claude Code를 위한 14개 플러그인 모음 - GitHub 워크플로우부터 AI 이미지 생성까지. Codex 0.135 와 Hermes Agent 도 동일한 소스 트리를 네이티브로 로드합니다 (shared source).

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

### Hermes Agent에서 github-dev만 설치

Hermes Agent는 모노레포의 `plugins/github-dev` 서브디렉터리만 설치할 수 있습니다:

```bash
hermes plugins install YoungjaeDev/my-claude-plugins/plugins/github-dev --enable
hermes gateway restart  # Slack/Telegram 등 gateway 사용 시
```

설치 후 새 Hermes 세션에서 plugin skill을 명시적으로 로드합니다 (`github-dev:<skill>`은 system prompt/skills_list에 자동 노출되지 않는 opt-in 대상입니다):

```text
skill_view("github-dev:resolve-issue")  # 이후 이슈 번호와 함께 실행 요청
skill_view("github-dev:cr-fix")         # 이후 --cr-source auto 등 인자와 함께 실행 요청
skill_view("github-dev:commit-and-push")
```

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
| **GitHub** | `github-dev` | 커밋, PR, 이슈 해결, 코드 리뷰 자동화 |
| **Testing** | `e2e-harness` | Playwright E2E 테스트 하네스 엔지니어링 — 공식 planner/generator/healer AI 에이전트 래핑 (`npx playwright init-agents --loop=claude`). e2e-setup(하네스 온보딩 + 인증 분리 + route 모킹 + CI 트레이스 아티팩트/PR 코멘트/게이팅), e2e-author(planner→generator + `--repeat-each` 번인 플래키 게이트), e2e-debug(헤드리스 trace 분석 + healer 자가수리 루프). Playwright 부재 시 graceful degrade |
| **Research** | `code-scout` | 다축 리서치 하네스 — 5-axis scout 팀 (github/hf/web/docs/paper) + synthesis-scout + research-orchestrator skill. exa MCP + WebSearch + brightdata(tier-3) + insane-search(tier-4, WAF/blocked). paper-scout 가 paper-search-tools 8-source 래핑. 비-code/ML 토픽은 sibling `/deep-research` 직접 호출 (orchestrator 가 위임하지 않음) |
| | `deepwiki` | GitHub 레포 AI 문서화 |
| | `paper-search-tools` | arXiv, PubMed 등 8개 플랫폼 논문 검색 |
| | `brightdata-guide` | Bright Data 웹 데이터 (MCP 툴 + CLI) — 스크래핑(Web Unlocker), SERP, 구조화 web_data_* 추출, 브라우저 자동화. operator 가 BRIGHTDATA_API_KEY 설정 |
| **AI Models** | `codex-image` | Claude->Codex 이미지 생성 브리지 (ChatGPT OAuth, OpenAI API key 불필요) |
| | `council` | 이종 벤더 심의 (`/council:convene`) — codex(GPT) + agy(Gemini) + Claude(Opus) 3인이 독립 의견 → 사용자 재질문 관문 → 상호 반박 → 의장 합성. 좌석 모델은 `~/.claude/council-models.json` 에 주간 TTL 로 고정 |
| **Dev Tools** | `notebook` | Jupyter 노트북 안전 편집 |
| | `ml-toolkit` | ML/멀티모달 개발 원칙, GPU 병렬 처리, Gradio CV 앱 |
| **Content** | `translator` | 웹 아티클 한국어 번역 |
| | `tcrei-prompt` | Google TCREI 구조로 프롬프트 재작성 |
| | `tally-form` | 체크리스트 md → Tally 설문/상담 폼 빌드·게시 (테마 프리셋, 구분선, 문항별 보기·필수·복수선택·단답, matrix/date/time 일정 조율, 이미지·redirect, idempotent) |
| | `voice-prompt` | 한국어 보이스 모드 STT 입력 정규화 — 말버릇·맞춤법·코드스위칭 자동 수정, 식별자는 `git ls-files`·스킬 목록 대조로 해소, 숫자·PR 번호는 손대지 않음. 1줄 에코 후 즉시 실행, 되돌리기 어려운 작업만 확인 |
| **Planning** | `interview` | 구조화된 요구사항 수집 |
| | `project-init` | Day-1 프로젝트 부트스트랩 (.claude/ + CLAUDE.md + AGENTS.md w/ Codex review guidelines + gh repo create) |
| **Docs** | `docs-forge` | README/CHANGELOG 생성 (CRO 최적화) + 배포 문서 템플릿 + MOC 인덱스 |
| | `rules-forge` | CLAUDE.md + .claude/rules/ 자동 모드 감지 생성 (write-rules 스킬) |
| **Memory & Lore** | `llm-wiki` | Karpathy LLM-Wiki 3-layer (insight + wiki + raw; query/ingest/lint/bootstrap/migrate + 5 hooks; post-merge ingest built into `github-dev:post-merge`) |
| **Memory & Lore** | `mem0-ops` | 플릿 레벨 mem0 진단·정리 — fleet-scan(전 앱 노이즈율·파편화) + doctor(설정 자세 점검) + cleanup(백업→삭제, dry-run 기본). upstream mem0 플러그인(프로젝트 내부 품질)과 역할 분리 |
| **Workflow State** | `spec-state` | spec / issue / PR work-pipeline aggregate (`state-tracker` skill, `.claude/state/spec.json`) |
| **Productivity** | `gws-sync` | 로컬 → Google Drive 단방향 제안형 동기화 (gws CLI 기반). 매핑 설정 기억 → Drive 트리 탐색 → 신규·변경 diff 리포트 → 업로드 위치 AskUserQuestion 승인 → 업로드(기존 파일 content update로 ID·공유링크 보존). 삭제는 제안만. gws 미설치 시 설치 안내 후 중단. googleworkspace/cli 스킬 95종 카탈로그(llms.txt) 동봉 |
| **Productivity** | `plaud-note-taking` | PLAUD 음성 녹음 노트(Whisper 전사록 + 별도 LLM 요약) 검토·정정. **요약이 아니라 전사록 기준**으로 STT 오인식(한·영 코드스위칭·고유명사·수치)을 프로젝트 용어 사전에 맞춰 고치고, 애매한 담당자·기한·수치와 "요약이 지어낸 결정"은 `docs-forge:interview-methodology`(grill-me) 위임으로 캐물어 확정. 원본은 동결한 채 `.llmwiki/raw/transcripts/derived/` 에 `*.corrected.md` 생성 → 사용자 확인 게이트 → 읽기용 `*.digest.md` → 재사용될 lore 만 `llm-wiki:ingest-finding` 로 |

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
| `/github-dev:post-merge` | 브랜치 정리, 일회성 산출물 정리(Step 4.5, 휴리스틱 후보 → 확인 → git rm), PR 학습을 설정/Serena/README에 통합 + 필수 wiki lore 적재 (skill) |
| `/github-dev:decompose-issue` | 이슈를 하위 작업으로 분해 |
| `/github-dev:create-issue-label` | 표준화된 이슈 라벨 생성 |
| `/github-dev:update-progress` | 마일스톤/이슈 진행 상황 동기화 |
| `/github-dev:release` | 버전 릴리스 + 자동 CHANGELOG 생성 |

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

**Cross-runtime (Claude / Codex):** 세 스킬은 런타임에 따라 두 런타임 계열·세 실행 경로(Path A/B/C)로 갈립니다. **Claude Code** 는 `init-agents --loop=claude` 가 생성한 named agent(planner/generator/healer)를 이름으로 디스패치합니다(**Path A**). **Codex 0.135** 는 그 agent 파일을 named subagent 로 등록하지 못하므로, 번들된 `references/role-contracts.md` 의 역할 계약을 인라인으로 실은 **generic subagent** 로 같은 역할을 실행하거나(**Path B**), 위임이 불가능하면 순차 실행합니다(**Path C**). CUF 선정·계획 검토 게이트·semantic locator·`--repeat-each` 번인·trace-first 진단·healer 3회 상한 등 모든 게이트는 두 경로에서 동일합니다. `--loop=codex` 는 버전 추정이 아니라 feature-detect 로만 사용하고, `.mcp.json` 의 `playwright-test` 항목은 기존 서버를 덮어쓰지 않고 머지합니다. (Hermes 는 forward-compatible — `e2e-harness` 는 아직 `HERMES_ELIGIBLE` 이 아니라 현재 Hermes 에는 로드되지 않으며, generic 경로가 향후 편입 시 `delegate_task` 로 매핑됩니다.)

**Requirements:** Node.js + Playwright (`npm init playwright@latest`), `gh` CLI (e2e-debug 의 CI 트레이스 fetch)

**Loose coupling:** Playwright 미설치 시 graceful degrade. `github-dev` 의 resolve-issue/commit-and-push 는 이 플러그인 없이도 E2E 를 옵트인 감지만 함 (상호 부재에 안전)

</details>

### Research & Search

<details>
<summary><strong>code-scout</strong> - 다축 코드 & ML 리서치 하네스 (v2.2)</summary>

**Skills (entry points):**
| Skill | Purpose |
|-------|---------|
| `research-orchestrator` | 메인 진입점. 쿼리 → mode 감지 (quick/deep) → fan-out → synthesis-scout 합성. |
| `exa-web-search` | web-scout 의 exa MCP + 4-tier fetch (exa → brightdata → insane-search) 사용 가이드. |
| `resource-finder` | github/hf-scout 의 검색 hygiene cheat-sheet. |

**Agent team (6, all `opus`):**
| Agent | Axis |
|-------|------|
| `github-scout` | `gh search repos/code`, awesome-list discovery |
| `hf-scout` | `uvx hf` + HF REST API (models/datasets/spaces) |
| `web-scout` | exa MCP 우선, WebSearch fallback (Reddit/SO/블로그/뉴스). fetch 4-tier: exa → brightdata → **insane-search** (WAF/403/challenge URL, X/Reddit/Coupang 등) |
| `docs-scout` | Context7 (라이브러리 docs) + DeepWiki (repo Q&A) |
| `paper-scout` | paper-search-tools 8-source 래핑 (arXiv/Semantic Scholar/Crossref/PubMed/bioRxiv/medRxiv/IACR/Google Scholar). 도메인별 2-3 source 선택, 학술 신호 감지 시 deep mode 5-axis 에 자동 인입 |
| `synthesis-scout` | dedup (DOI 포함) / trust ranking (peer-reviewed > arxiv high-cite > arxiv recent) / conflict resolution / 최종 보고서 |

**런타임 이식성 (v2.2.0)**: 이 6개 agent 는 **Claude Code 전용** — Codex 0.135 는 skill 은 노출하지만 `agents/*.md` 를 등록하지 못한다 (Hermes 도 `delegate_task` fallback 대상이지만 `code-scout` 는 아직 Hermes-eligible 이 아니라 로드되지 않는다 — forward-compat). 그 런타임에서는 `research-orchestrator` skill 이 named agent 미등록을 감지해 동일 축을 generic 병렬 subagent (Codex `Task` / Hermes `delegate_task`) 로, 위임 불가 시 현재 에이전트 내 순차 실행으로 돌리고 synthesis 를 in-skill 로 수행한다. 세 경로가 공유하는 계약은 `skills/research-orchestrator/references/axis-contracts.md`. Claude named-agent quick / deep 경로 동작은 무변경.

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

> 위 `Agent(subagent_type="code-scout:*-scout")` 직접 호출은 **Claude Code 전용**이다. Codex 에서는 이 named agent 들이 등록되지 않으므로 `Skill("code-scout:research-orchestrator")` 로 진입하면 orchestrator 가 generic subagent / 순차 fallback 으로 같은 축을 실행한다 (Hermes 는 `code-scout` 가 아직 Hermes-eligible 이 아니라 미로드 — 위 "런타임 이식성" 참조).

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

8개 플랫폼에서 논문 검색, 다운로드, 읽기.

**Platforms:** arXiv, PubMed, bioRxiv, medRxiv, Google Scholar, IACR, Semantic Scholar, CrossRef

**MCP Tools (23):** `search_arxiv`, `download_arxiv`, `read_arxiv_paper` 등

</details>

<details>
<summary><strong>brightdata-guide</strong> - Bright Data 웹 데이터 접근 (MCP + CLI)</summary>

Bright Data 플랫폼으로 웹 데이터 작업을 수행하는 가이드 스킬. 두 경로가 같은 플랫폼 + 무료 5,000 req/월 을 공유합니다.

- **MCP 툴**: `search_engine` (SERP), `scrape_as_markdown`/`scrape_batch` (Web Unlocker — JS/CAPTCHA/봇 탐지 우회), `extract` (AI 구조화 JSON), 40+ `web_data_*` 구조화 추출기 (Amazon/LinkedIn/Instagram/TikTok/YouTube/X/Reddit 등), `scraping_browser_*` 브라우저 자동화
- **CLI (`bdata`/`brightdata`)**: MCP 툴을 못 받는 `delegate_task` 서브에이전트용 fallback (터미널은 상속하지만 부모의 MCP 툴셋은 상속 안 함)

**Runtime:** Claude / Codex / Hermes 공용 (MCP 툴명 동일; `terminal` ↔ Bash / execute_command)

**Requirements:** Bright Data 계정 + `BRIGHTDATA_API_KEY` (또는 `bdata login`). 스킬은 guide 라 설치/키 하드코딩 안 함 — operator 가 out-of-band 로 연결.

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
<summary><strong>notebook</strong> - Jupyter 노트북 편집</summary>

안전한 .ipynb 파일 조작.

**Rules:**
- NotebookEdit 도구만 사용
- 출력 보존
- 셀 순서 검증

</details>

<details>
<summary><strong>ml-toolkit</strong> - ML/AI 개발</summary>

**Skills:**
| Skill | Description |
|-------|-------------|
| `gpu-parallel-pipeline` | PyTorch 멀티 GPU 처리 |
| `gradio-cv-app` | 컴퓨터 비전 Gradio 앱 |

</details>

### Content & Translation

<details>
<summary><strong>translator</strong> - 웹 아티클 번역</summary>

웹 페이지를 한국어 마크다운으로 번역.

**Features:**
- Bright Data MCP(`scrape_as_markdown`)로 페칭, `bdata` CLI 는 터미널 폴백
- VLM 이미지 분석
- 코드/테이블 보존

</details>

<details>
<summary><strong>tcrei-prompt</strong> - TCREI 프롬프트 구조화</summary>

Google TCREI 구조(Task, Context, References, Evaluate, Iterate)로 프롬프트 재작성.

**Workflow:**
1. 원본 프롬프트에서 T/C/R/E/I 요소 진단
2. 빠진 요소를 인터뷰로 수집
3. 구조화된 프롬프트 생성
4. OMC verifier로 자체 검증
5. `.claude/prompts/{date}-{name}.md`에 저장

**Triggers:** "TCREI", "structure this prompt", "prompt enhance"

**5개 도메인 패턴:** 개발, 마케팅, 문서, 교육, 번역

</details>

<details>
<summary><strong>tally-form</strong> - 체크리스트 md → Tally 폼</summary>

체크리스트 markdown 을 Tally 설문/상담 폼으로 빌드해 생성·게시. 결정적·무의존성(stdlib urllib) idempotent 빌더.

**Features:**
- 테마 프리셋 (neutral 기본 / hermes) + 섹션 구분선 + 문단 분리 인트로
- 문항별 보기 객관식 (필수 / 복수선택 체크박스) + 단답 입력 (text/number/email/phone/link)
- 네이티브 일정 조율 (matrix 그리드 / date / time)
- 폼 이미지 (logo/cover/본문 IMAGE, URL 호스팅 + GitHub raw 숏핸드) + 제출 후 redirect
- humanize-korean 카피 윤문 라우팅 (미설치 시 graceful degrade)
- dev-survey / lecture-consultation 프리셋 + 빌드 가능한 예시 fixture 번들

**Triggers:** "설문 폼 만들어", "Tally 폼 만들어", "상담 신청 폼", "일정 조율 설문"

**Requirements:** `TALLY_API_KEY` (없으면 payload-only)

</details>

### Memory & Lore

<details>
<summary><strong>llm-wiki</strong> - Karpathy LLM-Wiki 3-layer</summary>

중립 `.llmwiki/` 루트의 3-layer: `.llmwiki/insight/` (승격된 cross-agent 규율 — `.claude/rules/` 가 아니라 여기로 graduate, Codex 가 `.claude/rules/` 를 못 읽기 때문; core-config `prompt_inject.sh` 훅이 매 프롬프트 가리킴) + `.llmwiki/wiki/` (LLM-maintained lore) + `.llmwiki/raw/` (immutable evidence). 어느 repo 든 `/plugin install llm-wiki` 한 번이면 5 skill + 5 hook + bootstrap 템플릿 즉시 사용 가능. wiki 해석 순서: `.llmwiki/wiki/` → legacy `.claude/wiki/` → `.codex/wiki/` (중립 root 라 어떤 mirror 변환도 fork 못 함).

**Skills:**
| Skill | Description |
|-------|-------------|
| `/llm-wiki:query-wiki` | wiki MOC (`index.md`) 진입 + typed cross-ref 따라가기 |
| `/llm-wiki:ingest-finding` | 새 audit / PR finding 을 wiki 에 반영 (diff-log + multi-page cross-update) |
| `/llm-wiki:lint-wiki` | 4 wiki-rot 모드 감사 (identity/level/relationship/staleness) + 6주 retro 리마인더 |
| `/llm-wiki:bootstrap-wiki` | 새 repo 에 3-layer scaffold (templates 번들) |
| `/llm-wiki:migrate-wiki` | 기존 `.claude/wiki`/`.codex/wiki` 를 중립 `.llmwiki/` 로 마이그레이트 + v2 frontmatter(status/volatility/sources) 추가 (idempotent, diff-log) |

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

**Related:** spec / issue / PR work-pipeline state 는 `spec-state` plugin 으로 분리.

**Conditional:** wiki 없는 repo 에서는 hook silent skip.

</details>

<details>
<summary><strong>mem0-ops</strong> - 플릿 레벨 mem0 진단·정리</summary>

mem0 Platform store를 app_id **간** 레벨에서 진단·정리합니다. upstream `mem0@mem0-plugins`(health/memory-reviewer/stats/dream — 프로젝트 내부 품질, 200건 캡)와 역할 분리 — 기능 복제 없음. 스크립트는 stdlib + REST 직결(v1 entities/delete, v2 list)이라 upstream 버전 변화와 무관하고, 결정론 구간은 LLM 비용 0.

**Skills:**
| Skill | Description |
|-------|-------------|
| `/mem0-ops:fleet-scan` | 전 앱 스캔 — 앱별 노이즈율, 쓰레기 app_id 후보(`JUNK?`), app/user_id 파편화 쌍(`FRAG`). read-only |
| `/mem0-ops:doctor` | 설정 자세 점검 — `MEM0_RERANK` env, `~/.mem0/settings.json` `auto_save`(env가 아니라 이 파일이 지배하는 함정), decay, 훅 timeout 예산, 정체성 파편화. 제안만 |
| `/mem0-ops:cleanup` | 백업→삭제 — 타입 단위(`--type session_summary`) 또는 앱 전체(`--all`). dry-run 기본, `--execute` + 스킬 레이어 앱별 사용자 확인(스크립트 단독은 `--execute`만 게이트). 백업은 `~/.mem0/backups/`(런별 타임스탬프), 복원은 `infer=False` 재주입 |

**스코프 규칙:** cleanup은 cwd의 프로젝트 app_id가 기본(upstream과 동일한 해석 체인: env → project_map → git slug → basename). basename fallback 스코프는 거부 — 쓰레기 app_id 생성 경로이기 때문. fleet-scan/doctor는 항상 전역.

**전제:** `MEM0_API_KEY` (없으면 안내 후 중단).

</details>

### Workflow State

<details>
<summary><strong>spec-state</strong> - spec / issue / PR work-pipeline aggregate</summary>

`.claude/state/spec.json` 한 파일로 "지금 무엇이 in-flight 이고 어떤 spec / issue / PR 에 묶여있나" 를 한 번의 `Read` 로 답하기 위한 aggregate cache. spec frontmatter `status:` 가 SSOT, JSON 은 regeneratable cache.

**Skill:**
| Skill | Description |
|-------|-------------|
| `/github-dev:state-tracker` | `.claude/state/spec.json` 4 ops — `read` / `init` (regenerate from frontmatter) / `start <spec>` / `complete <spec>` |

`github-dev:post-merge` Step 5.7 이 merge 직후 `complete <spec-path>` 를 자동 호출. hooks 없음 — 순수 on-demand skill.

</details>

### Planning & Methodology

<details>
<summary><strong>interview</strong> - 요구사항 수집</summary>

스펙 기반 개발을 위한 구조화된 인터뷰.

**Modes:** breadth-first (5-phase 전수) + depth-first / Socratic (가장 큰 불확실성 1개씩 focused) + relentless / stress-test (기존 계획을 집요하게 압박 — "grill me"). 코드베이스로 답할 수 있는 건 묻지 않고, 이미 구체적인 요청엔 인터뷰 생략(단 stress-test 모드는 예외 — 명시 요청 시 압박).

**Phases (breadth-first):**
1. Context Gathering
2. Deep Dive
3. Edge Case Exploration
4. Prioritization
5. Validation

**Output:** 작은 인터뷰는 lightweight 요약 (결정 + 열린 질문), 큰 건은 full spec `.claude/spec/{date}-{feature}.md`

</details>

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

탐지는 `scripts/project_state.sh` 가 전담하는 read-only 단계이고, 결함마다 담당 스킬을 지목한 뒤 모든 수정은 `AskUserQuestion` 게이트 뒤에서만 적용한다. 위키 페이지 건강도는 `/llm-wiki:lint-wiki`, mem0 스토어는 `/mem0-ops:doctor`, 삭제된 플러그인이 남긴 고아 MCP 등록과 미사용 확장은 내장 `/doctor` 가 담당 — 중복하지 않는다.

**Requirements:** `gh` CLI authenticated, `git`, `jq`

</details>

### Documentation & Rules

<details>
<summary><strong>docs-forge</strong> - README & CHANGELOG & 배포 문서 & MOC 생성</summary>

CRO 분석 기반 README/CHANGELOG 생성, 배포 / 절차 문서 템플릿, 임의 폴더 MOC 인덱스 생성.

**Commands:**
| Command | Description |
|---------|-------------|
| `/docs-forge:readme generate` | 템플릿에서 README 생성 |
| `/docs-forge:readme analyze` | 기존 README 분석 |
| `/docs-forge:changelog init` | CHANGELOG 초기화 |
| `/docs-forge:deploy-doc generate` | 배포 / 절차 문서 생성 (요약 + 전제조건 + 번호 단계) |
| `/docs-forge:moc docs/` | 문서 폴더 MOC 인덱스 생성 (경량 / `--strict`) |

**Templates:** CLI, Library, React Component, MCP Plugin, SaaS, Desktop

9개 awesome-readme 프로젝트 분석 기반.

</details>

<details>
<summary><strong>rules-forge</strong> - CLAUDE.md 생성 및 모듈화 (자동 모드 감지)</summary>

CLAUDE.md 와 `.claude/rules/*.md` 를 Claude Code 2026 공식 패턴
(200줄 root cap, `paths:` glob scoping, `.claude/rules/` auto-load)
에 맞게 생성·재구조화. 단일 스킬 `write-rules` 이 프로젝트 상태를
스캔해 4개 모드 중 하나를 추천:

| Mode | Trigger | 동작 |
|------|---------|------|
| `NEW` | CLAUDE.md 부재 | 인터뷰 → 초기 root + rules/ 생성 |
| `TIGHTEN` | CLAUDE.md ≤200줄, rules/ 비어있음 | root Do/Don't 로 재구조화 |
| `SPLIT` | CLAUDE.md >200줄, rules/ 비어있음 | 섹션 추출 → 모듈화 |
| `REORGANIZE` | root + rules/ 둘 다 존재 | 중복·누락·드리프트 audit |

**Skill:**
| Skill | Description |
|-------|-------------|
| `/docs-forge:write-rules` | 단일 진입점, 자동 모드 감지 + 1회 확인 |

**Auto-triggers:** "rules 작성", "write rules", "generate claude.md",
"restructure claude.md", "split claude.md", "modularize instructions",
"organize project rules", "rules 분리"

</details>

### Productivity

<details>
<summary><strong>gws-sync</strong> - 로컬 → Google Drive 단방향 제안형 동기화</summary>

로컬 폴더의 산출물을 Google Drive에 **제안형으로** 올립니다. gws CLI(공식 googleworkspace/cli) 기반 — MCP가 아니라 CLI를 부르고, 인증(`gws auth login`)은 전제입니다.

**동작:**
1. 전제 확인 — `gws` 미설치 시 설치 안내(`npm install -g @googleworkspace/cli`) 출력 후 중단(자동 설치 안 함)
2. 매핑 설정(`.gws-sync.json`)으로 로컬↔Drive 폴더 대응 + 파일 ID 캐시 기억
3. Drive 트리 탐색 → 신규·변경 diff 리포트
4. **업로드 위치는 AskUserQuestion으로 승인 필수** — 승인 없이 업로드 안 함
5. 업로드 — 기존 파일은 `files update --upload`로 content만 갱신(파일 ID·공유 링크·버전 히스토리 보존)

**하드 룰:** 단방향(로컬→Drive)만 · 모든 쓰기는 diff+승인 뒤에만 · 삭제는 제안만(자동 삭제 금지) · Drive→로컬 다운로드는 범위 밖.

**동봉:** `references/gws-skills-llms.txt` — googleworkspace/cli 공식 스킬 54종 + 레시피 41종 카탈로그. 상황에 맞는 미설치 스킬을 `npx skills add`로 제안하는 인덱스.

</details>

<details>
<summary><strong>plaud-note-taking</strong> - PLAUD 노트(전사록+요약) STT·용어 정정</summary>

PLAUD 음성 녹음기가 만든 노트를 검토·정정합니다. PLAUD는 녹음 하나당 **두 산출물**을 냅니다 — Whisper STT **전사록**과, 그 전사록을 다시 LLM이 요약한 **별도 요약**. 이 스킬의 철칙은 **요약이 아니라 전사록을 기준으로 정정**하는 것입니다 (요약은 없던 결정을 매끄럽게 지어낼 수 있음).

**입력/출력:** 손으로 `.llmwiki/raw/transcripts/`에 올린 `<YYYY-MM-DD-slug>.transcript.txt`(+선택 `.note.txt`)를 읽어, 하위 `derived/` 폴더에 산출물 두 개를 씁니다. **원본은 절대 수정하지 않습니다.**

```text
.llmwiki/raw/transcripts/
├── <YYYY-MM-DD-slug>.transcript.txt   원본 (동결)
├── <YYYY-MM-DD-slug>.note.txt         원본 (동결)
└── derived/
    ├── <YYYY-MM-DD-slug>.corrected.md   충실성 산출물 (전사 전문 + 4단 태깅)
    └── <YYYY-MM-DD-slug>.digest.md      회의 정리본 (읽기용)
```

파생본은 `derived_from:` / `ingested:` 프론트매터만 달고 `sha256:` 은 달지 않습니다. `llm-wiki:lint-wiki` 는 `sha256:` 이 선언된 파일만 해시 대조하므로, 정리본을 손으로 고쳐도 `DRIFT` 로 뜨지 않습니다 (`sha256:` 을 선언한 원본을 고치면 여전히 뜹니다). 프론트매터 필드 하나가 "고쳐도 되는 파일 / 안 되는 파일" 스위치입니다.

**정정 규율(보수적):**
- STT 최대 오류원인 **한국어+영어 코드스위칭**(기술용어·고유명사)을 `terminology.md` 프로젝트 용어 사전 근거로 정정
- 숫자·날짜·금액·계약 조건은 추측 금지 → `[확인 필요]`
- 화자 `Speaker N`은 추정값 — 실명·담당자로 확정하지 않음
- 태깅: `[확인됨]` / `[정정]` / `[해석]` / `[확인 필요]`

**Open question → grill me:** 애매한 담당자·기한·수치·화자 귀속과 "요약이 지어낸 결정"은 `docs-forge:interview-methodology` relentless 위임으로 하나씩 집요하게 캐물어 확정하고, 남으면 `[확인 필요]`로 둡니다.

**corrected 이후 3단계 (0.2.0):**

1. **확인 게이트** — corrected 요지·`[정정]` 목록과 근거·잔여 open question 을 제시하고 승인을 기다립니다. 승인 전에는 digest 도 wiki 도 건드리지 않습니다. corrected 는 모든 주장이 아직 근거 태그를 달고 있는 마지막 지점이라, 여기서 고치면 편집 한 번이고 두 단계 뒤에 고치면 wiki 정리가 됩니다.
2. **digest 생성** — `derived/<slug>.digest.md` 에 한 줄 요약 / 결정된 것 / 액션 / 논의만 됨 / 미해결 로 정리합니다. **승격은 한 방향으로 막혀 있습니다**: corrected 의 `[해석]` 은 "논의만 됨" 으로, `[확인 필요]` 는 "미해결" 로 가고 어느 쪽도 "결정된 것" 에 오르지 못합니다. digest 는 압축만 할 뿐 새 사실을 만들지 않습니다.
3. **wiki ingest** — 재사용될 lore(결정의 근거, 제약조건, 도메인 사실, 반복될 판단 기준)만 추려 `llm-wiki:ingest-finding` 에 넘깁니다. 회의록 통째로는 넘기지 않습니다. 단발 액션아이템·일정은 digest 에만 남습니다. digest 가 태그를 떼어냈어도 태그 규율은 그대로라, "논의만 됨"·"미해결" 에 있던 주장은 넘어가지 않습니다. 인용은 digest 와 동결된 `.transcript.txt` 를 **둘 다** 답니다 (digest 는 나중에 손으로 고칠 수 있는 계층이므로 단독 인용은 근거가 흔들립니다). wiki 루트나 `ingest-finding` 이 없으면 사유 한 줄을 남기고 skip 하며, 스킬을 실패시키지 않습니다.

</details>

<details>
<summary><strong>voice-prompt</strong> - 보이스 모드 STT 입력 정규화</summary>

한국어 보이스 모드가 넘겨준 음성 인식 결과를 실행 **전에** 명령으로 되돌립니다. `/docs-forge:voice-prompt` 를 한 번 타이핑하면 해제할 때까지 모든 입력에 적용됩니다 (자동 감지 없음). 활성화 시 `.claude/voice-prompt/speech-profile.md` 를 읽어 이전 세션에서 확정한 항목을 되살립니다.

**이건 텍스트 청소기가 아닙니다.** 말버릇 제거는 모델이 이미 잘 하는 일이라 값이 낮습니다. 실제 값은 **모델이 추측으로 넘어가던 자리에 확인 절차를 끼워넣는 것**입니다 — "로더 파일"을 들으면 모델은 파일명을 지어내는데, `loader.py` 가 실재하는지 찾아보지 않으면 알 수 없습니다. 독해 실패가 아니라 행동 누락입니다.

**3단 분류:**
- **자동 수정** — 말버릇 부류, 맞춤법, 저장소 단일 후보, 스킬 목록 단일 후보, 발화 내 자기수정
- **질문** — 후보 0건 또는 다건, 두 해석이 서로 다른 행동을 유발, 되돌리기 어려운 작업 대상 (한 라운드로 묶어서)
- **손대지 않음** — 숫자·날짜·버전·PR/이슈 번호·금액·경로 리터럴. `PR 189` 가 `PR 180` 으로 들리면 조용히 잘못된 PR 을 건드리므로, 문맥이 아무리 그럴듯해도 추측 금지

**말버릇은 목록이 아니라 기능 검사로 지웁니다.** "그냥 지워"의 "그냥"은 "다른 건 하지 말고"이고 "일단 커밋해"의 "일단"은 순서 지시입니다. 그 단어를 지웠을 때 행동이 달라지면 말버릇이 아니고, 애매하면 보존합니다. 자기수정 표지("아 아니")는 삭제 대상이 아니라 정정 근거로, 그 뒤의 발화가 이깁니다.

**에코 → 실행:** `→ src/loader.py 초기화 부분 고쳐 (로더 파일→loader.py, 필러 3어 삭제)` 처럼 한 줄 보고 후 즉시 진행. 푸시·머지·삭제 등 되돌리기 어려운 작업만 대상을 명시해 확인받습니다.

**개인화:** 일반 한국어 말버릇은 번들 레퍼런스에, 개인 발음 습관과 도메인 용어는 `.claude/voice-prompt/speech-profile.md` 에 분리합니다. 사용자 확인 없이 프로필에 쓰지 않습니다.

**한계:** 스킬은 입력을 가로채지 않습니다 — 지침 준수 기반이라 긴 세션에서 흐려질 수 있고, 에코가 사라지면 재호출하라는 신호입니다.

</details>

## Configuration

### settings.json

```json
{
  "plugins": {
    "local": [
      "./plugins/core-config",
      "./plugins/github-dev",
      "./plugins/code-scout",
      "./plugins/deepwiki",
      "./plugins/paper-search-tools",
      "./plugins/notebook",
      "./plugins/ml-toolkit",
      "./plugins/translator",
      "./plugins/interview",
      "./plugins/docs-forge",
      "./plugins/rules-forge",
      "./plugins/tcrei-prompt",
      "./plugins/llm-wiki",
      "./plugins/spec-state"
    ]
  }
}
```

### Codex 0.135 (shared source)

Codex 도 동일한 `plugins/<name>/` 트리를 네이티브로 읽습니다. 매니페스트는 `scripts/sync-codex-manifests.mjs` 가 `.claude-plugin/marketplace.json` 으로부터 생성:

```bash
# 매니페스트 생성 / 재생성 (플러그인 추가·삭제 / version·description 변경 시)
node scripts/sync-codex-manifests.mjs

# PR drift 가드 — CI 에서 실행
node scripts/sync-codex-manifests.mjs --check

# Codex CLI 에서 marketplace 등록 & 설치
codex plugin marketplace add ~/.claude/plugins/marketplaces/my-claude-plugins
codex plugin add llm-wiki@my-claude-plugins
```

Codex 에서 제외되는 플러그인은 `codex-image` 와 `council` 둘입니다 (`codex-image` 는 Claude->Codex 브리지라 Codex 로 sync 하면 순환, `council` 은 codex 를 의석으로 앉히므로 Codex 에서 돌리면 자기 자신을 소환하는 순환이고 Claude 의석이 Agent 도구를 필요로 함). `core-config` 는 skill 이 없지만 번들 Codex hooks (`hooks/codex-hooks.json`) 를 실어 hooks-only 매니페스트로 Codex 에 sync 됩니다 (native `UserPromptSubmit` 훅). 즉 12 / 14 플러그인이 Codex 로 sync 되며 (core-config 는 hooks-only, 나머지는 skill 단위), `deepwiki` 와 `project-init` 은 1.41.0 부터 Claude 에서는 command + skill 양쪽으로, Codex 에서는 skill 로만 동작합니다 (Codex 는 command surface 를 로드하지 않음).

Codex 0.135 manifest top-level은 `skills` / `hooks` / `mcpServers` / `apps` 만 지원하므로, command-bearing 플러그인(`docs-forge`, `deepwiki` 등)도 Codex 측에는 skill만 노출됩니다 — Claude 측 commands 는 그대로 동작합니다. `github-dev` 는 모든 워크플로가 skill 로 전환돼 command surface 가 없으므로 Claude·Codex 양쪽에서 동일하게 동작합니다.

`--check` 는 manifest drift 외에 **skill `description` 길이**도 검증합니다 (Codex 0.135 는 1024자 초과 description 을 가진 skill 을 silent 하게 skip). 이 가드는 로컬 pre-commit 훅과 CI 양쪽에서 동일하게 실행됩니다:

```bash
# 클론당 1회: 버전 관리되는 .githooks/pre-commit 활성화
git config core.hooksPath .githooks
```

활성화하면 매 커밋 전에 `node scripts/sync-codex-manifests.mjs --check` 가 돌아 drift / 길이 위반을 차단합니다. 훅을 건너뛴 기여자도 PR 시 `.github/workflows/validate-codex.yml` 이 동일 명령으로 잡습니다.

### Hermes Agent (shared source)

Hermes Agent 도 동일한 `plugins/<name>/` 트리를 네이티브로 읽습니다. 어댑터(`plugin.yaml` + `__init__.py`)는 `scripts/sync-hermes-manifests.mjs` 가 `.claude-plugin/marketplace.json` 으로부터 생성:

```bash
# 어댑터 생성 / 재생성 (eligible 플러그인의 version·description 변경 시)
node scripts/sync-hermes-manifests.mjs

# PR drift 가드 — CI(validate-codex.yml) + .githooks/pre-commit 에서 실행
node scripts/sync-hermes-manifests.mjs --check

# Hermes 에 플러그인 단위 설치 (plugin.yaml 어댑터 필요)
hermes plugins install YoungjaeDev/my-claude-plugins/plugins/github-dev --enable
hermes gateway restart  # 메시징 게이트웨이 사용 시
```

어댑터 필드는 marketplace 엔트리에서 파생되고(`plugin.yaml` name/version/description, `__init__.py` 는 SKILL.md 를 `<plugin>:<skill>` 로 등록하는 제네릭 엔트리포인트 — 플러그인별 로직 없음), 대상은 `HERMES_ELIGIBLE` allowlist (이번 라운드 4개: `github-dev`, `docs-forge`, `code-scout`, `ml-toolkit`) 입니다. allowlist 에 이름을 추가하면 커버리지가 확장됩니다. `--check` 가 어댑터 drift + orphan 어댑터를 잡습니다. 공유 skill 본문은 Claude/Codex 도구 용어를 Hermes 도구로 매핑하는 호환 표를 포함합니다.

플러그인 스킬은 opt-in 이라 enable 후 `skill_view("<plugin>:<skill>")` 로 명시 로드합니다 (`--enable` 후 새 Hermes 세션 시작).

**설치 두 경로:**
- **플러그인 단위** (`hermes plugins install .../plugins/<name>` — 위 `plugin.yaml` 어댑터 필요, 이번 PR 이 5개 추가). 플러그인 전체를 Hermes 에 등록.
- **스킬 단위** (`node scripts/install-skills.mjs` → `npx skills` — 어댑터와 무관, 어댑터 없는 플러그인도 가능). 개별 skill 만 설치.

### 스킬을 Hermes / Codex 에 설치 (스킬 단위)

이 마켓플레이스의 skill 을 **스킬 단위**로 Hermes Agent 와 Codex 에 설치하는 대화형 도구 (위 `plugin.yaml` 어댑터와 무관 — 어댑터 없는 플러그인도 설치 가능). `npx skills`(vercel-labs/skills) 를 래핑하며 Node builtin 만 사용(zero-dep):

```bash
node scripts/install-skills.mjs
```

플러그인 그룹 단위로 skill 을 고른 뒤 타겟(`hermes-agent` / `codex`)·scope(global `~/` / project `./`)·Hermes profile 을 선택하면 `npx skills add` 로 설치합니다. 설치 메커니즘(symlink/copy)·충돌·lockfile 은 `npx skills` 에 위임하고, Hermes profile 은 `HERMES_HOME` env 로 타겟팅합니다.

### CI 가드가 지키는 것 (curation / security)

shared-source 배선은 6개 가드가 매 PR 과 매 커밋(`.githooks/pre-commit`)에서 함께 검증합니다 — 한 런타임에만 보이는 변경이 다른 도구체인에 조용히 깨진 채로 나가는 것을 막는 것이 목적입니다:

- `sync-codex-manifests.mjs --check` — Codex 매니페스트 drift + skill `description` 1024자 초과(Codex silent skip) + 번들 hook 디스크립터 shape·참조 스크립트 존재·orphan.
- `sync-hermes-manifests.mjs --check` — Hermes 어댑터 drift + orphan.
- `check-doc-consistency.mjs` — 플러그인 트리·표·카운트(총 24 / Codex-eligible 22 / Hermes 5)가 `manifest-eligibility.mjs` SoT 와 일치.
- `check-skill-tool-portability.mjs --check` — 공유 스킬 본문의 `AskUserQuestion` 사용이 파일럿 표준 매핑 또는 baseline 에 등록됐는지(미등록 크로스런타임 상호작용 경로 차단).
- `check-shell-portability.mjs` — GNU 전용 셸 구문(`md5sum`·`sed -i`·`grep -P`·`date -d`·`stat -c`·`timeout`·`${VAR,,}`·`mapfile`·`declare -A` 등)이 **폴백도 capability probe 도 없이** 쓰인 경우 차단. 정상 폴백 쌍(`stat -c … || stat -f …`)과 probe 분기는 통과하고, 증거는 코드만 인정합니다(대체재를 언급하는 주석은 폴백이 아님). 예외는 `# portability-ok: <사유>`.
- `check-skill-prose.mjs` — 500줄 초과·깊은 참조 경로에 대한 정보성 경고(비차단, 항상 exit 0).

가드와 별개로 두 개의 픽스처 스위트가 같은 자리에서 돕니다 — `plugins/github-dev/skills/cr-fix/tests/run-tests.sh` (1차 경로가 실패한 뒤에만 실행되는 CLI 폴백·CR 상태 경로)와 `plugins/council/skills/convene/tests/run-tests.sh` (스킬 본문에만 존재해 아무도 실행하지 않는 codex/agy 호출 계약 + 레지스트리 TTL 산술). 후자가 지키는 것은 이식성 가드가 볼 수 없는 종류입니다 — agy 호출에서 `< /dev/null` 이 빠지면 그 의석이 영원히 멈추는데, 그건 GNU 전용 구문이 아니라서 `check-shell-portability` 의 관심사가 아닙니다.

CI 는 여기에 더해 **macOS 레그**(`validate-codex.yml` 의 `macos` job)를 돌립니다. 두 스위트가 품은 BSD 폴백들은 GNU 러너에서 절반만 실행되므로, macOS 레그가 그 나머지 절반이 실제로 도는 유일한 지점입니다. `env -i PATH=/usr/bin:/bin` 는 쓰지 않습니다 — macOS 에서 `jq` 가 Homebrew 경로에 있어 스위트가 도구 부재로 죽습니다. 대신 `sed`/`date`/`stat` 이 BSD 빌드인지 assert 하고(Homebrew coreutils 가 시스템 도구를 가리면 실패), 스위트는 `/bin/bash` 로 돌려 bash 3.2 를 강제합니다.

drift·길이·shape·이식성 위반은 **차단**(exit 1)이고, prose 경고는 측정치일 뿐 커밋을 막지 않습니다. 어느 가드도 소스를 자동 수정하지 않습니다 — 위반을 보고할 뿐이니, 로컬에서 generator 를 재실행해 파생물을 맞춘 뒤 다시 커밋하세요.

### 머신 로컬 운영 갱신 (PR 밖 오퍼레이터 체크리스트)

Codex 의 UserPromptSubmit 훅과 Hermes 스킬은 이제 **번들 디스크립터/어댑터**로 배포되므로 marketplace 업데이트가 정본입니다. 다만 예전에 손으로 설치한 복사본(수동 `~/.codex/hooks/prompt_inject.sh`, 스킬 단위로 깐 `~/.agents/skills/<...>`)을 쓰던 머신은 그 복사본이 stale 해질 수 있습니다. 아래는 리포지토리 상태를 바꾸지 않는 **머신 로컬 작업**이라 PR 에 포함되지 않으며, marketplace 업데이트 후 한 번 실행합니다:

```bash
# 1) marketplace 캐시 갱신 (위 "플러그인 업데이트" 절차)
rm -rf ~/.claude/plugins/cache/my-claude-plugins/

# 2) Codex: 번들 디스크립터로 재설치 (수동 ~/.codex/hooks.json 항목을 쓰던 경우 먼저 제거)
codex plugin marketplace add ~/.claude/plugins/marketplaces/my-claude-plugins
codex plugin add core-config@my-claude-plugins   # 이후 /hooks 로 trust 재승인

# 3) Hermes: 스킬 단위 설치본 갱신
node scripts/install-skills.mjs                  # 또는 hermes plugins install ... --enable
```

번들 디스크립터/어댑터를 쓰는 신규 설치는 marketplace 업데이트만으로 최신이 됩니다 — 이 체크리스트는 레거시 수동 복사본을 쓰는 머신에만 필요합니다.

## 요구사항

| 도구 | 용도 | 필수 |
|------|------|------|
| [Claude Code](https://docs.anthropic.com/claude-code) | 기본 CLI | Yes |
| `gh` | GitHub 플러그인 | github-dev |
| `uv` | Python MCP 서버 | core-config |
| `ruff` | Python 포매팅 | core-config |
| Node 18+ | Codex/Hermes 매니페스트 생성기 런타임 | `scripts/sync-{codex,hermes}-manifests.mjs` |
| Codex CLI 0.135+ | shared-source 네이티브 로드 (`.codex-plugin/plugin.json`) | Codex 사용자 |
| Hermes Agent | shared-source 네이티브 로드 (`plugin.yaml` + `__init__.py`) | Hermes 사용자 |

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
│   ├── docs-forge/            # 에이전트가 읽는 문서 저작 (README/CHANGELOG/MOC + 규칙 + 인터뷰 + 프롬프트)
│   ├── llm-wiki/              # LLM-Wiki 3-layer (wiki lore) + PLAUD 전사록 정정
│   ├── publish/               # 산출물 내보내기 (번역 / Tally 폼 / Google Drive 동기화)
│   ├── project-init/          # Day-1 프로젝트 부트스트랩 (인터뷰 + .claude/ + AGENTS.md + gh repo)
│   └── mem0-ops/              # 플릿 레벨 mem0 진단·정리 (fleet-scan/doctor/cleanup)
├── AGENTS.md                 # 세 런타임 공통 최상위 지침 (정본)
├── CLAUDE.md                 # @AGENTS.md import
└── README.md
```

## 참고 자료

- [Claude Code Documentation](https://docs.anthropic.com/claude-code)
- [Claude Code Plugin System](https://docs.anthropic.com/claude-code/plugins)

## License

MIT
