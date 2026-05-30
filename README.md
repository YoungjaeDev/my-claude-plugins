<div align="center">

<img src="assets/banner.png" width="600" alt="my-claude-plugins banner">

<br>

<img src="assets/logo.png" width="100" alt="my-claude-plugins logo">

# my-claude-plugins

Claude Code를 위한 21개 플러그인 모음 - GitHub 워크플로우부터 AI 이미지 생성까지

[![Plugins](https://img.shields.io/badge/plugins-21-blue.svg)](https://github.com/YoungjaeDev/my-claude-plugins)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-purple.svg)](https://docs.anthropic.com/claude-code)

[빠른 시작](#빠른-시작) | [플러그인 목록](#플러그인-목록) | [설치 옵션](#설치-옵션)

</div>

---

## 왜 이 플러그인들인가?

Claude Code에 빠져 있는 것들을 채웁니다:

- **GitHub 워크플로우** - 이슈 분해, PR, 코드 리뷰, post-merge 정리까지 한 흐름으로
- **리서치** - arXiv/PubMed 논문 검색, GitHub 레포 문서화, 보일러플레이트 탐색
- **멀티모달** - Midjourney 이미지 생성, 웹 페이지 번역, Notion 업로드
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

## 플러그인 업데이트

플러그인 캐시 버그로 인해 업데이트 시 캐시 삭제가 필요합니다 ([#17361](https://github.com/anthropics/claude-code/issues/17361), [#19197](https://github.com/anthropics/claude-code/issues/19197)):

```bash
# 1. 캐시 삭제
rm -rf ~/.claude/plugins/cache/my-claude-plugins/

# 2. Marketplace 업데이트 후 Claude Code 재시작
/plugin marketplace update my-claude-plugins
```

> **Note**: Auto-update 활성화해도 플러그인 파일은 자동 갱신되지 않습니다. 수동 캐시 삭제가 유일한 해결책입니다.

## 플러그인 목록

| 카테고리 | 플러그인 | 설명 |
|---------|---------|------|
| **Core** | `core-config` | Python 포매팅, 알림 (work guidelines 는 `~/.claude/CLAUDE.md`) |
| **GitHub** | `github-dev` | 커밋, PR, 이슈 해결, 코드 리뷰 자동화 |
| **Research** | `code-scout` | 다축 리서치 하네스 — 5-axis scout 팀 (github/hf/web/docs/paper) + synthesis-scout + research-orchestrator skill. exa MCP + WebSearch + firecrawl(tier-3) + insane-search(tier-4, WAF/blocked). paper-scout 가 paper-search-tools 8-source 래핑. 비-code/ML 토픽은 sibling `/deep-research` 직접 호출 (orchestrator 가 위임하지 않음) |
| | `deepwiki` | GitHub 레포 AI 문서화 |
| | `paper-search-tools` | arXiv, PubMed 등 8개 플랫폼 논문 검색 |
| **AI Models** | `council` | Claude, Codex, Gemini 멀티모델 심의 |
| | `midjourney` | Midjourney V7 이미지 생성 |
| **Dev Tools** | `notebook` | Jupyter 노트북 안전 편집 |
| | `ml-toolkit` | GPU 병렬 처리, Gradio CV 앱 |
| **Content** | `translator` | 웹 아티클 한국어 번역 |
| | `notion` | Markdown을 Notion으로 업로드 |
| | `humanizer` | AI 글쓰기 패턴 제거 |
| | `tcrei-prompt` | Google TCREI 구조로 프롬프트 재작성 |
| **Presentation** | `slidev` | Slidev 마크다운 프레젠테이션 생성 (인터뷰 워크플로우) |
| **Planning** | `interview` | 구조화된 요구사항 수집 |
| | `project-init` | Day-1 프로젝트 부트스트랩 (.claude/ + CLAUDE.md + AGENTS.md w/ Codex review guidelines + gh repo create) |
| **Docs** | `docs-forge` | README/CHANGELOG 생성 (CRO 최적화) |
| | `rules-forge` | CLAUDE.md + .claude/rules/ 자동 모드 감지 생성 (write-rules 스킬) |
| **Visualization** | `workflow-viz` | 시스템 워크플로우 Mermaid 다이어그램, ASCII 진행 추적 |
| **Memory & Lore** | `llm-wiki` | Karpathy LLM-Wiki 3-layer (query/ingest/lint/bootstrap/migrate/post-merge-wiki + 3 hooks) |
| **Workflow State** | `spec-state` | spec / issue / PR work-pipeline aggregate (`state-tracker` skill, `.claude/state/spec.json`) |

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

Python 자동 포매팅 + 크로스 플랫폼 알림. 작업 가이드라인은 `~/.claude/CLAUDE.md` (SSOT) 가 담당.

**Hooks:**
| Hook | Trigger | Description |
|------|---------|-------------|
| `auto-format-python.py` | Post Write/Edit | ruff로 Python 포매팅 |
| `notify_osc.sh` | Stop/Notification | 터미널 알림 |

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
| `/github-dev:post-merge` | 브랜치 정리, PR 학습 내용을 설정 파일/Serena/README에 통합 |
| `/github-dev:merge-worktree` | worktree에서 base 브랜치로 squash merge + 학습 반영 |
| `/github-dev:decompose-issue` | 이슈를 하위 작업으로 분해 |
| `create-issue-labels` (skill) | 표준화된 이슈 라벨 생성 (자동 트리거 skill, Codex `$create-issue-labels`) |
| `/github-dev:update-progress` | 마일스톤/이슈 진행 상황 동기화 |
| `/github-dev:release` | 버전 릴리스 + 자동 CHANGELOG 생성 |

**Flags:** `--skip-review`, `--strict`

**Requirements:** `gh` CLI

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

**Skills:** (자동 트리거 — slash command 아님, Codex `$ask` / `$generate-llmstxt`)
| Skill | Description |
|-------|-------------|
| `ask` | 레포에 AI로 질문 |
| `generate-llmstxt` | llms.txt 생성 |

**Usage:**
```text
facebook/react에서 reconciliation은 어떻게 동작하나요?
```

</details>

<details>
<summary><strong>paper-search-tools</strong> - 학술 논문 검색</summary>

8개 플랫폼에서 논문 검색, 다운로드, 읽기.

**Platforms:** arXiv, PubMed, bioRxiv, medRxiv, Google Scholar, IACR, Semantic Scholar, CrossRef

**MCP Tools (23):** `search_arxiv`, `download_arxiv`, `read_arxiv_paper` 등

</details>

### AI Models

<details>
<summary><strong>council</strong> - LLM Council</summary>

여러 AI 모델에 질문하고 집단 지혜 합성.

**Commands:**
| Command | Description |
|---------|-------------|
| `/council` | 멀티모델 심의 |
| `/council --quick` | 퀵 모드 (1라운드) |
| `/council:ask-codex` | Codex 직접 질문 |
| `/council:ask-gemini` | Gemini 직접 질문 |

**Models:** Claude Opus, Sonnet, Codex, Gemini

</details>

<details>
<summary><strong>midjourney</strong> - 이미지 생성</summary>

Midjourney V7 프롬프트 최적화 및 생성.

**Features:**
- 5레이어 프롬프트 구조
- 스타일/분위기 명확화
- 다양한 프롬프트 변형

**Requirements:** midjourney MCP 설정

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
<summary><strong>notion</strong> - Notion 연동</summary>

Markdown을 Notion에 포매팅하여 업로드.

**Features:**
- 전체 Markdown 지원
- 이미지 자동 업로드
- Dry run 미리보기

**Requirements:** Notion API key

</details>

<details>
<summary><strong>humanizer</strong> - AI 글쓰기 패턴 제거</summary>

AI 생성 글의 패턴 제거.

**Triggers:** "humanize this", "make it sound human"

**24가지 패턴 감지:** 중요성 과장, 홍보적 언어, AI 어휘, 대시 남용 등

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

### Codex (shared-source)

<details>
<summary><strong>Codex 네이티브 설치</strong> - 같은 repo, 한 줄 설치</summary>

이 repo 는 Claude 마켓플레이스(`.claude-plugin/marketplace.json`)와 Codex 마켓플레이스(`.agents/plugins/marketplace.json`)를 **한 트리에 공존**시킨다. Codex 는 Claude 와 **동일한** `plugins/<name>/skills/` 를 그대로 로드한다 — 변환·복제 없음(shared-source).

```bash
# 원격 1줄 설치
codex plugin marketplace add YoungjaeDev/my-claude-plugins
codex plugin add <plugin>@my-claude-plugins
codex plugin marketplace upgrade   # git pull 로 업데이트
```

- Codex 전용 산출물은 작은 커밋 매니페스트 둘뿐: 플러그인별 `.codex-plugin/plugin.json` + 루트 `.agents/plugins/marketplace.json`.
- 둘 다 `node scripts/sync-codex-manifests.mjs` 가 Claude `.claude-plugin/` 소스에서 생성한다(`--check` 로 drift 검출).
- skill 1개 이상인 plugin 만 Codex 카탈로그에 포함(command-only plugin·`midjourney` 제외 — Claude 전용). Codex 는 plugin.json 에 `commands`/`agents` 필드가 없어 command/subagent 를 로드하지 않는다.

**Requirements:** Node 18+, Codex CLI 0.120.0+

</details>

### Memory & Lore

<details>
<summary><strong>llm-wiki</strong> - Karpathy LLM-Wiki 3-layer</summary>

`.claude/rules/` (invariants) + 중립 `.llmwiki/wiki/` (LLM-maintained lore) + `.llmwiki/raw/` (immutable evidence) 패키지. 어느 repo 든 `/plugin install llm-wiki` 한 번이면 6 skill + 3 hook + bootstrap 템플릿 즉시 사용 가능. wiki 해석 순서: `.llmwiki/wiki/` → legacy `.claude/wiki/` → `.codex/wiki/` (중립 root 라 codex-bridge `.claude/`→`.codex/` 변환이 fork 못 함).

**Skills:**
| Skill | Description |
|-------|-------------|
| `/llm-wiki:query-wiki` | wiki MOC (`index.md`) 진입 + typed cross-ref 따라가기 |
| `/llm-wiki:ingest-finding` | 새 audit / PR finding 을 wiki 에 반영 (diff-log + multi-page cross-update) |
| `/llm-wiki:lint-wiki` | 4 wiki-rot 모드 감사 (identity/level/relationship/staleness) + 6주 retro 리마인더 |
| `/llm-wiki:bootstrap-wiki` | 새 repo 에 3-layer scaffold (templates 번들) |
| `/llm-wiki:post-merge-wiki` | merge 후 `git show --name-only` 기반 ingest 후보 도출 → `ingest-finding` 체인 |
| `/llm-wiki:migrate-wiki` | 기존 `.claude/wiki`/`.codex/wiki` 를 중립 `.llmwiki/` 로 마이그레이트 + v2 frontmatter(status/volatility/sources) 추가 (idempotent, diff-log) |

**Hooks (auto-installed):**

| Hook | Trigger | Behavior |
|------|---------|----------|
| `wiki_stale_check.sh` | UserPromptSubmit | volatility 윈도우(stable 180d / volatile 30d) 초과 page soft-hint (rate-limit 1h/cwd) |
| `wiki_post_commit_hint.sh` | PostToolUse(Bash) | 2+ file 또는 50+ line commit 시 ingest 제안 (rate-limit 10min) |
| `wiki_session_start_lint_hint.sh` | SessionStart | 최근 `lint-wiki` 가 3일 초과 경과 시 `/lint-wiki` 권유 (additionalContext, rate-limit 4h) |

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

**Phases:**
1. Context Gathering
2. Deep Dive
3. Edge Case Exploration
4. Prioritization
5. Validation

**Output:** `.claude/spec/{date}-{feature}.md`

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
3. 첫 PR merge 후 → `/github-dev:post-merge` (자동 `/llm-wiki:post-merge-wiki` 체이닝)

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
<summary><strong>docs-forge</strong> - README & CHANGELOG 생성</summary>

CRO 분석 기반 README/CHANGELOG 생성.

**Commands:**
| Command | Description |
|---------|-------------|
| `/docs-forge:readme generate` | 템플릿에서 README 생성 |
| `/docs-forge:readme analyze` | 기존 README 분석 |
| `/docs-forge:changelog init` | CHANGELOG 초기화 |

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

### Visualization

<details>
<summary><strong>workflow-viz</strong> - 워크플로우 시각화</summary>

시스템 아키텍처 다이어그램 및 작업 진행 추적.

**Features:**
- C4 Container 다이어그램
- 플러그인별 Flowchart
- ASCII 진행 상황 표시

**Usage:** `/workflow-viz:show-progress`

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
      "./plugins/council",
      "./plugins/deepwiki",
      "./plugins/paper-search-tools",
      "./plugins/notebook",
      "./plugins/ml-toolkit",
      "./plugins/translator",
      "./plugins/midjourney",
      "./plugins/interview",
      "./plugins/notion",
      "./plugins/humanizer",
      "./plugins/slidev",
      "./plugins/docs-forge",
      "./plugins/rules-forge",
      "./plugins/workflow-viz",
      "./plugins/tcrei-prompt",
      "./plugins/llm-wiki",
      "./plugins/spec-state"
    ]
  }
}
```

## 요구사항

| 도구 | 용도 | 필수 |
|------|------|------|
| [Claude Code](https://docs.anthropic.com/claude-code) | 기본 CLI | Yes |
| `gh` | GitHub 플러그인 | github-dev |
| `uv` | Python MCP 서버 | core-config |
| `ruff` | Python 포매팅 | core-config |
| Node 18+ | Codex 매니페스트 동기화 스크립트 | `scripts/sync-codex-manifests.mjs` |
| Codex CLI 0.120.0+ | Codex 네이티브 설치 (shared-source) | Codex 사용 시 |

## 프로젝트 구조

```
.
├── .claude/
│   └── settings.json          # 플러그인 설정
├── plugins/
│   ├── core-config/           # 가이드라인 + 훅
│   ├── github-dev/            # GitHub 워크플로우
│   ├── code-scout/            # 리소스 탐색
│   ├── council/               # LLM Council
│   ├── deepwiki/              # 레포 문서화
│   ├── paper-search-tools/    # 논문 검색
│   ├── notebook/              # Jupyter 편집
│   ├── ml-toolkit/            # ML 개발
│   ├── translator/            # 번역
│   ├── midjourney/            # 이미지 생성
│   ├── interview/             # 요구사항 수집
│   ├── notion/                # Notion 연동
│   ├── humanizer/             # AI 패턴 제거
│   ├── slidev/                # 프레젠테이션 생성
│   ├── docs-forge/            # README/CHANGELOG 생성
│   ├── rules-forge/           # write-rules 스킬 (자동 모드 감지)
│   ├── workflow-viz/          # 워크플로우 시각화
│   ├── tcrei-prompt/          # TCREI 프롬프트 구조화
│   ├── llm-wiki/              # LLM-Wiki 3-layer (wiki lore)
│   ├── spec-state/            # spec/issue/PR work-pipeline aggregate
│   └── project-init/          # Day-1 프로젝트 부트스트랩 (인터뷰 + .claude/ + AGENTS.md + gh repo)
├── CLAUDE.md
└── README.md
```

## 참고 자료

- [Claude Code Documentation](https://docs.anthropic.com/claude-code)
- [Claude Code Plugin System](https://docs.anthropic.com/claude-code/plugins)

## License

MIT
