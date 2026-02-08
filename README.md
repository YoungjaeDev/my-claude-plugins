<div align="center">

<img src="assets/banner.png" width="600" alt="my-claude-plugins banner">

<br>

<img src="assets/logo.png" width="100" alt="my-claude-plugins logo">

# my-claude-plugins

Claude Code를 위한 16개 플러그인 모음 - GitHub 워크플로우부터 AI 이미지 생성까지

[![Plugins](https://img.shields.io/badge/plugins-16-blue.svg)](https://github.com/YoungjaeDev/my-claude-plugins)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-purple.svg)](https://docs.anthropic.com/claude-code)

[빠른 시작](#빠른-시작) | [플러그인 목록](#플러그인-목록) | [설치 옵션](#설치-옵션)

</div>

---

## 왜 이 플러그인들인가?

Claude Code의 기본 기능만으로는 부족한 영역들이 있습니다:

- **GitHub 워크플로우** - 이슈 분해, PR 생성, 코드 리뷰 자동화
- **리서치** - 학술 논문 검색, 코드베이스 탐색, 리소스 발견
- **멀티모달** - 이미지 생성, 문서 번역, Notion 연동
- **문서화** - README/CHANGELOG 생성, PRD 작성

이 플러그인들은 실제 개발 워크플로우에서 반복되는 작업들을 자동화합니다.

## 빠른 시작

```bash
# 1. Marketplace 추가
/plugin marketplace add YoungjaeDev/my-claude-plugins

# 2. 원하는 플러그인 설치
/plugin install github-dev@my-claude-plugins
/plugin install code-scout@my-claude-plugins
```

설치 후 `/github-dev:resolve-issue 123` 같은 명령어로 바로 사용 가능합니다.

> **oh-my-claudecode** (멀티 에이전트 오케스트레이션)는 별도 설치:
> ```bash
> /plugin marketplace add Yeachan-Heo/oh-my-claudecode
> /plugin install oh-my-claudecode@omc
> ```

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
| **Core** | `core-config` | 가이드라인 자동 주입, Python 포매팅, 알림 |
| **GitHub** | `github-dev` | 커밋, PR, 이슈 해결, 코드 리뷰 자동화 |
| | `interactive-review` | 브라우저 기반 코드 리뷰 UI |
| **Research** | `code-scout` | GitHub, HuggingFace 등 10+ 플랫폼 리소스 검색 |
| | `deepwiki` | GitHub 레포 AI 문서화 |
| | `paper-search-tools` | arXiv, PubMed 등 8개 플랫폼 논문 검색 |
| **AI Models** | `council` | Claude, Codex, Gemini 멀티모델 심의 |
| | `midjourney` | Midjourney V7 이미지 생성 |
| **Dev Tools** | `notebook` | Jupyter 노트북 안전 편집 |
| | `ml-toolkit` | GPU 병렬 처리, Gradio CV 앱 |
| **Content** | `translator` | 웹 아티클 한국어 번역 |
| | `notion` | Markdown을 Notion으로 업로드 |
| | `humanizer` | AI 글쓰기 패턴 제거 |
| **Planning** | `interview` | 구조화된 요구사항 수집 |
| | `prd-suite` | PRD, Tech Spec, Use Case 생성 |
| **Docs** | `docs-forge` | README/CHANGELOG 생성 (CRO 최적화) |

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

가이드라인 자동 주입 및 워크플로우 훅.

**Hooks:**
| Hook | Trigger | Description |
|------|---------|-------------|
| `inject-guidelines.sh` | UserPromptSubmit | 작업 가이드라인 자동 주입 |
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
| `/github-dev:parallel-resolve` | 여러 이슈 병렬 해결 |
| `/github-dev:code-review` | CodeRabbit 피드백 처리 |

**Flags:** `--worktree`, `--skip-review`, `--strict`

**Requirements:** `gh` CLI

</details>

<details>
<summary><strong>interactive-review</strong> - 웹 UI 코드 리뷰</summary>

브라우저 기반 인터랙티브 코드 리뷰.

- 체크박스 승인 워크플로우
- 실시간 리뷰 인터페이스
- PEP 723 의존성

**Requirements:** `uv`

</details>

### Research & Search

<details>
<summary><strong>code-scout</strong> - 코드 & ML 리소스 탐색</summary>

**Agents:**
| Agent | Model | Platforms |
|-------|-------|-----------|
| `scout` | haiku | GitHub, HuggingFace |
| `deep-scout` | sonnet | 10+ (Reddit, SO, arXiv 등) |

**Usage:**
```
Task(subagent_type="code-scout:scout", prompt="Find FastAPI boilerplate")
```

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
<summary><strong>prd-suite</strong> - PRD & Spec 문서 생성</summary>

**Commands:**
| Command | Description |
|---------|-------------|
| `/prd-suite:prd` | PRD 작성 |
| `/prd-suite:tech-spec` | Tech Spec 작성 |
| `/prd-suite:usecase` | Use Case 작성 |
| `/prd-suite:ia` | IA 작성 |
| `/prd-suite:spec-all` | 전체 순차 실행 |

</details>

### Documentation

<details>
<summary><strong>docs-forge</strong> - README & CHANGELOG 생성</summary>

CRO 베스트 프랙티스로 README/CHANGELOG 생성 및 분석.

**Commands:**
| Command | Description |
|---------|-------------|
| `/docs-forge:readme generate` | 템플릿에서 README 생성 |
| `/docs-forge:readme analyze` | 기존 README 분석 |
| `/docs-forge:changelog init` | CHANGELOG 초기화 |

**Templates:** CLI, Library, React Component, MCP Plugin, SaaS, Desktop

**Based on:** 9개 awesome-readme 프로젝트 분석

</details>

## Configuration

### settings.json

```json
{
  "plugins": {
    "local": [
      "./plugins/core-config",
      "./plugins/github-dev",
      "./plugins/interactive-review",
      "./plugins/code-scout",
      "./plugins/deepwiki",
      "./plugins/paper-search-tools",
      "./plugins/council",
      "./plugins/midjourney",
      "./plugins/notebook",
      "./plugins/ml-toolkit",
      "./plugins/translator",
      "./plugins/notion",
      "./plugins/humanizer",
      "./plugins/interview",
      "./plugins/prd-suite",
      "./plugins/docs-forge"
    ]
  }
}
```

## 요구사항

| 도구 | 용도 | 필수 |
|------|------|------|
| [Claude Code](https://docs.anthropic.com/claude-code) | 기본 CLI | Yes |
| `gh` | GitHub 플러그인 | github-dev |
| `uv` | Python MCP 서버 | core-config, interactive-review |
| `ruff` | Python 포매팅 | core-config |

## 프로젝트 구조

```
.
├── .claude/
│   └── settings.json          # 플러그인 설정
├── plugins/
│   ├── core-config/           # 가이드라인 + 훅
│   ├── github-dev/            # GitHub 워크플로우
│   ├── interactive-review/    # 웹 UI 리뷰
│   ├── code-scout/            # 리소스 탐색
│   ├── deepwiki/              # 레포 문서화
│   ├── paper-search-tools/    # 논문 검색
│   ├── council/               # LLM Council
│   ├── midjourney/            # 이미지 생성
│   ├── notebook/              # Jupyter 편집
│   ├── ml-toolkit/            # ML 개발
│   ├── translator/            # 번역
│   ├── notion/                # Notion 연동
│   ├── humanizer/             # AI 패턴 제거
│   ├── interview/             # 요구사항 수집
│   ├── prd-suite/             # PRD & spec 생성
│   └── docs-forge/            # README/CHANGELOG 생성
├── CLAUDE.md
└── README.md
```

## 참고 자료

- [Claude Code Documentation](https://docs.anthropic.com/claude-code)
- [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode)
- [Claude Code Plugin System](https://docs.anthropic.com/claude-code/plugins)

## License

MIT
