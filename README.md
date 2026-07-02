<div align="center">

<img src="assets/banner.png" width="600" alt="my-claude-plugins banner">

<br>

<img src="assets/logo.png" width="100" alt="my-claude-plugins logo">

# my-claude-plugins

Claude Code를 위한 22개 플러그인 모음 - GitHub 워크플로우부터 AI 이미지 생성까지. Codex 0.135 와 Hermes Agent 도 동일한 소스 트리를 네이티브로 로드합니다 (shared source).

[![Plugins](https://img.shields.io/badge/plugins-22-blue.svg)](https://github.com/YoungjaeDev/my-claude-plugins)
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
- **시각화** - Mermaid 다이어그램, Slidev 프레젠테이션

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
| **Core** | `core-config` | Python 포매팅, 알림 + 매 프롬프트 behavioral 주입 훅 (`prompt_inject.sh`, Claude+Codex 공유, `.llmwiki/insight/` 포인터) (work guidelines 는 `~/.claude/CLAUDE.md`) |
| **GitHub** | `github-dev` | 커밋, PR, 이슈 해결, 코드 리뷰 자동화 |
| **Testing** | `e2e-harness` | Playwright E2E 테스트 하네스 엔지니어링 — 공식 planner/generator/healer AI 에이전트 래핑 (`npx playwright init-agents --loop=claude`). e2e-setup(하네스 온보딩 + 인증 분리 + route 모킹 + CI 트레이스 아티팩트/PR 코멘트/게이팅), e2e-author(planner→generator + `--repeat-each` 번인 플래키 게이트), e2e-debug(헤드리스 trace 분석 + healer 자가수리 루프). Playwright 부재 시 graceful degrade |
| **Research** | `code-scout` | 다축 리서치 하네스 — 5-axis scout 팀 (github/hf/web/docs/paper) + synthesis-scout + research-orchestrator skill. exa MCP + WebSearch + firecrawl(tier-3) + insane-search(tier-4, WAF/blocked). paper-scout 가 paper-search-tools 8-source 래핑. 비-code/ML 토픽은 sibling `/deep-research` 직접 호출 (orchestrator 가 위임하지 않음) |
| | `deepwiki` | GitHub 레포 AI 문서화 |
| | `paper-search-tools` | arXiv, PubMed 등 8개 플랫폼 논문 검색 |
| | `brightdata-guide` | Bright Data 웹 데이터 (MCP 툴 + CLI) — 스크래핑(Web Unlocker), SERP, 구조화 web_data_* 추출, 브라우저 자동화. operator 가 BRIGHTDATA_API_KEY 설정 |
| **AI Models** | `codex-image` | Claude->Codex 이미지 생성 브리지 (ChatGPT OAuth, OpenAI API key 불필요) |
| **Dev Tools** | `notebook` | Jupyter 노트북 안전 편집 |
| | `ml-toolkit` | ML/멀티모달 개발 원칙, GPU 병렬 처리, Gradio CV 앱 |
| **Content** | `translator` | 웹 아티클 한국어 번역 |
| | `tcrei-prompt` | Google TCREI 구조로 프롬프트 재작성 |
| | `tally-form` | 체크리스트 md → Tally 설문/상담 폼 빌드·게시 (테마 프리셋, 구분선, 문항별 보기·필수·복수선택·단답, matrix/date/time 일정 조율, 이미지·redirect, idempotent) |
| **Presentation** | `slidev` | Slidev 마크다운 프레젠테이션 생성 (인터뷰 워크플로우) |
| **Planning** | `interview` | 구조화된 요구사항 수집 |
| | `project-init` | Day-1 프로젝트 부트스트랩 (.claude/ + CLAUDE.md + AGENTS.md w/ Codex review guidelines + gh repo create) |
| **Docs** | `docs-forge` | README/CHANGELOG 생성 (CRO 최적화) + 배포 문서 템플릿 + MOC 인덱스 |
| | `rules-forge` | CLAUDE.md + .claude/rules/ 자동 모드 감지 생성 (write-rules 스킬) |
| **Memory & Lore** | `llm-wiki` | Karpathy LLM-Wiki 3-layer (insight + wiki + raw; query/ingest/lint/bootstrap/migrate + 5 hooks; post-merge ingest built into `github-dev:post-merge`) |
| **Workflow State** | `spec-state` | spec / issue / PR work-pipeline aggregate (`state-tracker` skill, `.claude/state/spec.json`) |
| **Design** | `anti-slop-design` | 웹/SaaS 랜딩, 덱(PPT), 대시보드, 카피 anti-AI-slop 가드. clarify→context→plan→run→audit→revise + 2단계 audit gate; 한국어 카피는 `humanize-korean` 위임. 6개 OSS repo 기반 |
| | `ppt-yeong-style` | yeong 스타일 강의·제안 덱 작성 규약. `ppt-master` 엔진 위 작성 레이어 — 덱 유형·md 규약·작성 원칙 15종·밀도 리듬·역할 기반 색·codex vs SVG 경계·앱 UI 실물 강제·ppt-master 레버 조합 차별화·빌드 후 스토리 review·공식 로고 fetch·윤문·렌더 QA. 진입점 SKILL.md + references/ 6종 + 주입 프롬프트 |

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
| `/github-dev:code-review` | (1.10 deprecated) CodeRabbit 피드백 자동 fetch + 수동 paste fallback |
| `/github-dev:cr-wait` | (1.10 deprecated) CodeRabbit commit status 백그라운드 폴링 |
| `/github-dev:post-merge` | 브랜치 정리, 일회성 산출물 정리(Step 4.5, 휴리스틱 후보 → 확인 → git rm), PR 학습을 설정/Serena/README에 통합 + 필수 wiki lore 적재 (skill) |
| `/github-dev:merge-worktree` | worktree에서 base 브랜치로 squash merge + 학습 반영 |
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

**Requirements:** Node.js + Playwright (`npm init playwright@latest`), `gh` CLI (e2e-debug 의 CI 트레이스 fetch)

**Loose coupling:** Playwright 미설치 시 graceful degrade. `github-dev` 의 resolve-issue/commit-and-push 는 이 플러그인 없이도 E2E 를 옵트인 감지만 함 (상호 부재에 안전)

</details>

### Research & Search

<details>
<summary><strong>code-scout</strong> - 다축 코드 & ML 리서치 하네스 (v2.1)</summary>

**Skills (entry points):**
| Skill | Purpose |
|-------|---------|
| `research-orchestrator` | 메인 진입점. 쿼리 → mode 감지 (quick/deep) → fan-out → synthesis-scout 합성. |
| `exa-web-search` | web-scout 의 exa MCP + 4-tier fetch (exa → firecrawl → insane-search) 사용 가이드. |
| `resource-finder` | github/hf-scout 의 검색 hygiene cheat-sheet. |

**Agent team (6, all `opus`):**
| Agent | Axis |
|-------|------|
| `github-scout` | `gh search repos/code`, awesome-list discovery |
| `hf-scout` | `uvx hf` + HF REST API (models/datasets/spaces) |
| `web-scout` | exa MCP 우선, WebSearch fallback (Reddit/SO/블로그/뉴스). fetch 4-tier: exa → firecrawl → **insane-search** (WAF/403/challenge URL, X/Reddit/Coupang 등) |
| `docs-scout` | Context7 (라이브러리 docs) + DeepWiki (repo Q&A) |
| `paper-scout` | paper-search-tools 8-source 래핑 (arXiv/Semantic Scholar/Crossref/PubMed/bioRxiv/medRxiv/IACR/Google Scholar). 도메인별 2-3 source 선택, 학술 신호 감지 시 deep mode 5-axis 에 자동 인입 |
| `synthesis-scout` | dedup (DOI 포함) / trust ranking (peer-reviewed > arxiv high-cite > arxiv recent) / conflict resolution / 최종 보고서 |

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
- `--size` / `--quality` / `--out` / `-n` / `--edit` 옵션, opt-in `--model` / `--reasoning` / `--sandbox` (기본은 Codex 기본 모델 + workspace-write 유지)
- Claude-only 브리지 — Codex sync 에서 제외 (순환 방지)

**Requirements:** Codex CLI 설치 + ChatGPT OAuth 로그인

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
- firecrawl MCP로 페칭
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

### Workflow State

<details>
<summary><strong>spec-state</strong> - spec / issue / PR work-pipeline aggregate</summary>

`.claude/state/spec.json` 한 파일로 "지금 무엇이 in-flight 이고 어떤 spec / issue / PR 에 묶여있나" 를 한 번의 `Read` 로 답하기 위한 aggregate cache. spec frontmatter `status:` 가 SSOT, JSON 은 regeneratable cache.

**Skill:**
| Skill | Description |
|-------|-------------|
| `/spec-state:state-tracker` | `.claude/state/spec.json` 4 ops — `read` / `init` (regenerate from frontmatter) / `start <spec>` / `complete <spec>` |

`github-dev:post-merge` Step 5.7 이 merge 직후 `complete <spec-path>` 를 자동 호출. hooks 없음 — 순수 on-demand skill.

</details>

### Planning & Methodology

<details>
<summary><strong>interview</strong> - 요구사항 수집</summary>

스펙 기반 개발을 위한 구조화된 인터뷰.

**Modes:** breadth-first (5-phase 전수) + depth-first / Socratic (가장 큰 불확실성 1개씩 focused). 코드베이스로 답할 수 있는 건 묻지 않고, 이미 구체적인 요청엔 인터뷰 생략.

**Phases (breadth-first):**
1. Context Gathering
2. Deep Dive
3. Edge Case Exploration
4. Prioritization
5. Validation

**Output:** 작은 인터뷰는 lightweight 요약 (결정 + 열린 질문), 큰 건은 full spec `.claude/spec/{date}-{feature}.md`

</details>

<details>
<summary><strong>project-init</strong> - Day-1 프로젝트 부트스트랩</summary>

새 디렉토리에서 단일 `/project-init:new` 한 번으로 인터뷰 → 로컬 시드 → gh 레포 생성 → 초기 커밋/푸시까지 완료.

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
1. 코드 쌓이면 → `/rules-forge:write-rules`
2. 첫 도메인 lore → `/llm-wiki:bootstrap-wiki`
3. 첫 PR merge 후 → `/github-dev:post-merge` (post-merge 내장 wiki 적재 step)

**Requirements:** `gh` CLI authenticated, `git`, `jq`

</details>

### Presentation

<details>
<summary><strong>slidev</strong> - Slidev 프레젠테이션 생성</summary>

인터뷰 기반 워크플로우로 Slidev 마크다운 프레젠테이션 생성.

**Workflow:**
1. Auto-detect: Slidev 프로젝트 존재 여부 확인
2. Setup: `npm init slidev@latest` (필요 시)
3. Interview: 주제, 대상, 시간, 구조, 테마 수집
4. Generate: slides.md 생성
5. Review: 슬라이드 구조 요약 + 실행 커맨드

**Themes:** apple-basic, seriph, geist, purplin, academic, bricks

**Triggers:** "PT 만들어줘", "create a slide", "make a presentation"

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
| `/rules-forge:write-rules` | 단일 진입점, 자동 모드 감지 + 1회 확인 |

**Auto-triggers:** "rules 작성", "write rules", "generate claude.md",
"restructure claude.md", "split claude.md", "modularize instructions",
"organize project rules", "rules 분리"

</details>

### Design

<details>
<summary><strong>anti-slop-design</strong> - anti-AI-slop 디자인 가드</summary>

웹/SaaS 랜딩, 발표 덱(PPT), 대시보드/admin UI, 마케팅·UI 카피의 "AI가 만든 티(slop)"를 생성 전 차단하고 생성 후 감사합니다. 핵심 명제: slop = 브리프와 무관한 default-not-choice.

**Flow:** clarify → context → plan → run → audit → revise

**Audit gate (2단계):**
- Phase A — 생성 전 self-similarity probe + 6축 self-critique (Philosophy/Hierarchy/Specificity/Restraint/Variety/Honesty)
- Phase B — 납품 전 12항목 binary 체크리스트 + numeric floor sweep

**카피:** 영문 탐지·스코어링은 자체, 한국어 재작성은 `humanize-korean` 위임.

**근거:** 6개 OSS anti-slop repo (impeccable 44-rule / hallmark 58-gate / frontend-design / huashu / stop-slop / frontend-slides) source-grounded 합성.

</details>

<details>
<summary><strong>ppt-yeong-style</strong> - yeong 스타일 강의·제안 덱 작성 규약</summary>

강의/실습/제안/학술 덱을 yeong 스타일로 만들 때 적용하는 작성 규약. `ppt-master`(빌드 엔진) 위에 얹는 **작성 레이어** — 엔진은 손대지 않고 "무엇을·어떻게 쓸지"를 어느 repo·세션에서든 일관 적용합니다.

**엔진·의존:** `ppt-master`(빌드 엔진, bare name 참조) 위 레이어. `codex-image`·`interview`·`anti-slop-design`·`humanize-korean`·`design-shotgun` 은 있으면 사용, 없으면 graceful degrade.

**규약 핵심:**
- 덱 유형(제안/실습)·파이프라인(인터뷰→색 락→md→빌드→audit→윤문→QA)
- md 소스 규약(단일 md, `[ ]` 키 메시지, 담백한 명사구 제목)
- 작성 원칙 15종 + 밀도 리듬(anchor/breathing/dense, **중간 강화 기본** + 본문 바닥 20pt)
- 역할·면적 기반 색(중립 2 + 주색 1~2 + 액센트 ≤10%), 폰트 폴백 Pretendard→Noto→Malgun
- codex-image vs SVG 경계, fade·pop은 표지/전환 한정, 실물 스크린샷 우선
- 공식 SVG 로고 fetch→인라인→근접성

**구조:** 진입점 `SKILL.md` + `references/` 6종(design-language / color-typography / images-and-pop / icons-logos / ppt-master-and-qa / ppt-master-craft) + `assets/injection-prompt.md`(다른 세션 주입용 압축 페이로드).

> 그냥 "PPT 만들어줘"는 `ppt-master`, "slidev 슬라이드"는 `slidev` — 이 스킬은 yeong 규약이 필요할 때만 트리거됩니다.

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
      "./plugins/slidev",
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

Codex 에서 제외되는 플러그인: `core-config` (Claude-only hooks — Codex 에 대응 surface 없음), `codex-image` (Claude->Codex 브리지 — Codex 로 sync 하면 순환). 즉 20 / 22 플러그인이 양쪽에서 skill 단위로 동작. `deepwiki` 와 `project-init` 은 1.41.0 부터 dual-surface (command + skill) 로 양쪽 런타임에서 사용 가능.

Codex 0.135 manifest top-level은 `skills` / `hooks` / `mcpServers` / `apps` 만 지원하므로, command-bearing 플러그인(`paper-search-tools`, `docs-forge` 등)도 Codex 측에는 skill만 노출됩니다 — Claude 측 commands 는 그대로 동작합니다. `github-dev` 는 모든 워크플로가 skill 로 전환돼 command surface 가 없으므로 Claude·Codex 양쪽에서 동일하게 동작합니다.

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

어댑터 필드는 marketplace 엔트리에서 파생되고(`plugin.yaml` name/version/description, `__init__.py` 는 SKILL.md 를 `<plugin>:<skill>` 로 등록하는 제네릭 엔트리포인트 — 플러그인별 로직 없음), 대상은 `HERMES_ELIGIBLE` allowlist (이번 라운드 7개: `github-dev`, `interview`, `anti-slop-design`, `tcrei-prompt`, `ppt-yeong-style`, `ml-toolkit`, `brightdata-guide`) 입니다. allowlist 에 이름을 추가하면 커버리지가 확장됩니다. `--check` 가 어댑터 drift + orphan 어댑터를 잡습니다. 공유 skill 본문은 Claude/Codex 도구 용어를 Hermes 도구로 매핑하는 호환 표를 포함합니다.

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
│   ├── code-scout/            # 리소스 탐색
│   ├── deepwiki/              # 레포 문서화
│   ├── paper-search-tools/    # 논문 검색
│   ├── brightdata-guide/      # Bright Data 웹데이터 guide (MCP + CLI)
│   ├── notebook/              # Jupyter 편집
│   ├── ml-toolkit/            # ML 개발
│   ├── translator/            # 번역
│   ├── codex-image/           # Claude->Codex 이미지 생성 브리지
│   ├── interview/             # 요구사항 수집
│   ├── slidev/                # 프레젠테이션 생성
│   ├── docs-forge/            # README/CHANGELOG + 배포 문서 + MOC 생성
│   ├── rules-forge/           # write-rules 스킬 (자동 모드 감지)
│   ├── tcrei-prompt/          # TCREI 프롬프트 구조화
│   ├── llm-wiki/              # LLM-Wiki 3-layer (wiki lore)
│   ├── spec-state/            # spec/issue/PR work-pipeline aggregate
│   ├── anti-slop-design/      # anti-AI-slop 디자인 가드 (web/ppt/dashboard/copy)
│   ├── ppt-yeong-style/       # yeong 스타일 강의·제안 덱 작성 레이어 (ppt-master 위)
│   └── project-init/          # Day-1 프로젝트 부트스트랩 (인터뷰 + .claude/ + AGENTS.md + gh repo)
├── CLAUDE.md
└── README.md
```

## 참고 자료

- [Claude Code Documentation](https://docs.anthropic.com/claude-code)
- [Claude Code Plugin System](https://docs.anthropic.com/claude-code/plugins)

## License

MIT
