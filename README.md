<div align="center">

<img src="assets/banner.png" width="800" height="267" alt="한 소스, 두 런타임, 여덟 플러그인">

# my-claude-plugins

PR 리뷰 루프부터 리서치·문서·강의 덱까지, Claude Code 와 Codex CLI 가 같은 소스를 읽는 8개 플러그인 모음.

[![Plugins](https://img.shields.io/badge/plugins-8-blue.svg)](#플러그인-목록)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-purple.svg)](https://docs.anthropic.com/claude-code)
[![Codex CLI](https://img.shields.io/badge/Codex%20CLI-native-black.svg)](#codex-cli)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

[빠른 시작](#빠른-시작) | [플러그인 목록](#플러그인-목록) | [업데이트](#업데이트) | [플러그인 상세](#플러그인-상세)

</div>

---

GitHub PR 로 일하는 Claude Code 사용자를 위한 번들이다.

- **리뷰를 사람 대신 돌린다.** `/dev:review-loop` 가 CodeRabbit·Codex 지적을 판정해 고치고 push 하기를 리뷰어가 새 지적을 멈출 때까지 반복하고, 남은 것은 후속 이슈 1건으로 넘긴다.
- **다음에 무엇을 부를지 묻지 않아도 된다.** `/dev:flow` 가 아이디어부터 머지·정리까지 지금 단계의 스킬을 알려 준다.
- **한 소스, 두 런타임.** Codex CLI 가 같은 `plugins/` 트리와 `.claude-plugin/` 매니페스트를 직접 읽으므로 생성 단계도, 따로 맞출 사본도 없다.
- **짧은 이름.** 스킬은 `/dev:review-loop` 처럼 `/plugin:skill` 로 부르고, 슬래시 메뉴에서 `/rev` 만 쳐도 잡힌다 (Claude Code 2.1.236 이상).

## 빠른 시작

```bash
# 1. Marketplace 추가
/plugin marketplace add YoungjaeDev/my-claude-plugins

# 2. 필요한 플러그인 설치
/plugin install dev@my-claude-plugins

# 3. 다음에 할 일 묻기
/dev:flow
```

**You should see:** 슬래시 메뉴에 `/dev:` 로 시작하는 스킬이 뜨고, `/dev:flow` 가 지금 단계에 맞는 다음 스킬을 알려 준다. 메뉴에 없으면 Claude Code 를 재시작한다.

## 플러그인 목록

| 플러그인 | 얻는 것 | 대표 명령 |
|---------|--------|-----------|
| `dev` | PR 부터 리뷰 루프·머지·정리까지 자동화, 프로젝트 셋업, Playwright E2E | `/dev:review-loop` |
| `docs` | README·CHANGELOG·배포 문서, 에이전트 지침과 스킬 저작, Drive 내보내기 | `/docs:readme` |
| `scout` | GitHub·HF·웹·공식 문서를 병렬로 훑어 하나의 보고서로 | `/scout:research-orchestrator` |
| `ml` | ML·CV 작업 규율, Gradio 데모, 노트북 저작·안전 편집 | `/ml:cv-notebook` |
| `wiki` | 저장소 밖 지식(플랫폼·벤더·고객·도메인)을 출처 달린 wiki 로 | `/wiki:ingest` |
| `deck` | house 형식 HTML 강의 덱 조립·검사·배포 | `/deck:deck-ask` |
| `council` | GPT·Gemini·Claude 세 좌석의 교차 심의 (Claude 전용) | `/council:convene` |
| `codex-image` | API key 없이 Codex 로 이미지 생성 (Claude 전용) | `/codex-image:codex-image` |

## 업데이트

플러그인 캐시 버그([#17361](https://github.com/anthropics/claude-code/issues/17361), [#19197](https://github.com/anthropics/claude-code/issues/19197)) 때문에 **Auto-update 를 켜도 플러그인 파일은 갱신되지 않는다.** 새 버전은 캐시를 지운 뒤 받는다.

```bash
# 1. 캐시 삭제
#   macOS / Linux:
rm -rf ~/.claude/plugins/cache/my-claude-plugins/
#   Windows (PowerShell):
#   Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\plugins\cache\my-claude-plugins"

# 2. Marketplace 업데이트 후 Claude Code 재시작
/plugin marketplace update my-claude-plugins
```

옛 버전(2.54.0 이전)에서 올라온다면 [옛 버전에서 옮겨 오기](#옛-버전에서-옮겨-오기)도 본다.

## 플러그인 상세

<details>
<summary><strong>dev</strong> - PR 부터 머지·정리까지, 프로젝트 셋업, E2E 하네스</summary>

dev 는 뒷단만 맡는다: PR 부터 리뷰 루프, 머지, 정리까지. 아이디어부터 PR 까지의 앞단은 Matt 스킬(`mattpocock/skills`: `/grill-with-docs` → `/to-spec` → `/to-tickets` → `/implement-spec` 또는 `/implement`)이, 버그 진단은 `/diagnosing-bugs` 가, 교훈은 빌드한 세션의 `/retro` 가 맡는다.

**GitHub 워크플로우**

| Skill | 하는 일 |
|-------|---------|
| `/dev:flow` | 다음에 부를 스킬을 알려 주는 라우터 (Matt 앞단 + dev 뒷단, 버그·E2E·worktree 갈래, 제품 repo 준비). 직접 실행하지 않는다 |
| `/dev:commit-and-push` | 변경을 분석해 Conventional Commits 메시지로 커밋하고 푸시 |
| `/dev:review-loop` | CodeRabbit + Codex 지적을 묻지 않고 판정(apply / defer / skip)해 고치고, 수렴·저심각도 바닥·churn 중 하나에서 멈춘다. 남은 지적은 후속 이슈 1건. 켜진 리뷰어 전원이 HEAD 에 판정을 낸 뒤에만 push·종료·머지한다. PR 댓글은 `@coderabbitai rate limit` 질의와 HEAD 당 1회의 `@coderabbitai review` 요청뿐. `--auto-merge`, `--cr-source <auto\|pr-bot\|cli\|codex-only>` (rate limit 시 로컬 CLI 또는 Codex-only 폴백) |
| `/dev:post-merge` | 머지 후 정리만: 남은 리뷰 지적 표시, base 전환, 브랜치 삭제, 남은 이슈 close, Project 상태 동기화, About 줄 점검, 커밋 |
| `/dev:release` | 버전 태그 + GitHub Release (릴리스 노트 자동 생성) |
| `/dev:session-handoff` | 컨텍스트를 비우기 전, 새 에이전트가 이어받을 인수인계 요약. 채팅 출력만 |
| `/dev:orchestrate` | 메인 에이전트를 오케스트레이터로: 슬라이스별 job card, 워커 프리셋 `dev:worker-standard/deep/max`, 경로당 writer 하나, 오케스트레이터가 직접 검증. 쓰는 슬라이스는 worktree 격리. Codex 에는 `Agent` 도구가 없어 인라인으로 돈다 |

**프로젝트 셋업**

| Skill | 하는 일 |
|-------|---------|
| `/dev:new` | 빈 디렉터리에서 인터뷰 → `.claude/` 스캐폴드 → CLAUDE.md + AGENTS.md (general / ml / web) + README·CHANGELOG 시드 → `gh repo create` + 초기 푸시. 비어 있지 않은 디렉터리는 거부 |
| `/dev:wiring` | 기존 repo 의 하네스 배선을 14축으로 진단 (`core.hooksPath`, `.claude/rules` 스코핑을 무력화하는 `@import`, MCP 중복 등록, Codex `AGENTS.md` 바이트 예산 등). 승인 전까지 read-only |

**제품 repo 준비 (repo 당 1회)**: Matt 스킬을 설치한 뒤 `/setup-matt-pocock-skills` 로 이슈 트래커·triage 라벨·도메인 문서를 연결하고 triage 라벨 5개를 만든다. 라벨이 없으면 첫 `/to-spec` 이 실패한다. 아래는 없는 라벨만 만들므로 다시 돌려도 기존 라벨은 그대로다.

```bash
( have=$(gh label list --limit 1000 --json name --jq '.[].name') || exit 1
  for l in needs-triage needs-info ready-for-agent ready-for-human wontfix; do
    printf '%s\n' "$have" | grep -qxF "$l" || gh label create "$l" || exit 1
  done )
```

**Playwright E2E 하네스**: Playwright 공식 AI 에이전트(planner / generator / healer)를 감싼 자가개선 루프.

| Skill | 하는 일 |
|-------|---------|
| `/dev:e2e-setup` | 에이전트 생성, 인증 분리, `page.route` 모킹 스캐폴드, CI 워크플로우. 기존 `playwright.config` 는 덮어쓰지 않고 머지 제안 + 백업 |
| `/dev:e2e-author` | critical flow 선정 → 계획서 → 사용자 검토 → 스펙 생성 → `--repeat-each` 번인 |
| `/dev:e2e-debug` | 실패한 CI run 의 트레이스 분석 → healer 수리 (최대 3회) → 재실행 |

Playwright 가 없으면 graceful degrade. Codex 에서는 역할 계약(`references/role-contracts.md`)을 generic subagent 나 순차 실행으로 지킨다.

**Requirements:** `gh`, `git`, `jq`; E2E 는 Node.js + Playwright

</details>

<details>
<summary><strong>docs</strong> - 문서 저작과 내보내기</summary>

**프로젝트 문서 (commands, Claude 전용)**: `doc-guides` 스킬의 참조 카드에서 필요한 섹션만 로드한다.

| Command | 하는 일 |
|---------|---------|
| `/docs:readme generate` / `analyze` | 템플릿(CLI, Library, React Component, MCP Plugin, SaaS, Desktop, Internal)으로 README 생성, 또는 기존 README 분석 |
| `/docs:changelog init` | Keep a Changelog 형식 CHANGELOG |
| `/docs:deploy-doc generate` | 배포·절차 문서 (요약 + 전제조건 + 번호 단계) |
| `/docs:moc docs/` | 문서 폴더 MOC 인덱스 (경량 / `--strict`) |

**에이전트가 읽는 문서**

| Skill | 하는 일 |
|-------|---------|
| `/docs:write-rules` | CLAUDE.md 와 `.claude/rules/*.md` 를 공식 패턴(200줄 root cap, `paths:` 스코핑)으로 생성·재구조화 |
| `/docs:interview-methodology` | 작은 요청의 모호한 점을 확인하고 대화 안 요약으로 끝낸다 (재사용 프롬프트는 TCREI 형식). 큰 일은 `/grill-with-docs` 로 |
| `/docs:vp` | 음성 전사 프롬프트 게이트. `.agents/voice-terms.md` 사전으로 오인식을 고치고, 명확하면 진행, 모호하면 질문 2-3개 |
| `/docs:skill-forge` | 두 런타임에서 살아남는 스킬 작성·개정 (프론트매터, 작성 레버, 패키징 계약) |
| `/docs:skill-audit` | 단일 스킬 7축 진단 + P0/P1/P2 수정안 |
| `/docs:skill-fleet-review` | 플러그인 트리 전수 검토 → `docs/audit/<date>-fleet.md` + CSV |

**내보내기**

| Skill | 하는 일 |
|-------|---------|
| `/docs:translate-web-article` | 웹 페이지를 한국어 마크다운으로 번역 (이미지 분석, 코드·테이블 보존) |
| `/docs:gws-sync` | 로컬 → Google Drive 단방향 동기화 (`gws` CLI). 업로드 위치는 승인 필수, 삭제는 제안만, 파일 ID·공유 링크 보존 |

</details>

<details>
<summary><strong>scout</strong> - 리서치와 검색</summary>

| Skill | 하는 일 |
|-------|---------|
| `/scout:research-orchestrator` | 리서치 진입점. quick / deep 모드를 고르고 github / hf / web / docs scout 를 병렬로 돌린 뒤 synthesis-scout 가 중복 제거·신뢰도 순위·충돌 해소를 거쳐 Markdown 보고서로 합친다 |
| `/scout:ask` | GitHub 레포에 DeepWiki MCP 로 질문 |
| `/scout:generate-llmstxt` | 레포의 `llms.txt` 생성 |

**Agent team (Claude Code 전용):** `scout:github-scout`, `scout:hf-scout`, `scout:web-scout` (exa → brightdata → insane-search 4-tier fetch), `scout:docs-scout` (Context7 + DeepWiki), `scout:synthesis-scout`. Codex 에서는 orchestrator 가 generic subagent 나 순차 실행으로 같은 축을 돌린다. 정책·시장·역사 같은 비코드 토픽은 `/deep-research` 를 직접 부른다.

**Requirements:** `gh`, `uvx` (hf)

</details>

<details>
<summary><strong>ml</strong> - ML / CV 개발</summary>

| Skill | 하는 일 |
|-------|---------|
| `/ml:ml-dev-principles` | ML·멀티모달 작업 규율: 모델·데이터 선정, EDA, 학습, 평가 하네스, FP/FN 오류 분석, GPU 병렬 패턴 |
| `/ml:gradio-cv-app` | Gradio 컴퓨터 비전 데모 앱 |
| `/ml:cv-notebook` | CV 실험 노트북 저작 + ipywidgets 탐색 모드 |
| `/ml:edit-notebook` | `.ipynb` 안전 편집 (NotebookEdit 만 사용, 출력 보존, 셀 순서 검증) |

</details>

<details>
<summary><strong>wiki</strong> - 바깥 지식 wiki</summary>

저장소가 통제하지 못하는 것(플랫폼, 벤더, 고객, 도메인)에 대한 지식만 받는다. 결정은 `docs/adr/`, 용어는 `GLOSSARY.md`, 반복 실수는 `/retro` 가 만드는 자동 검사로 간다. 구조는 `.llmwiki/raw/` (손대지 않는 원본) + `.llmwiki/wiki/` (`index.md`, `log.md`, `## Sources` 가 달린 개념 페이지).

| Skill | 하는 일 |
|-------|---------|
| `/wiki:ingest` | 원본 문서나 작업 중 알게 된 사실을 개념 페이지로 만들고 index·log 갱신. wiki 가 없으면 뼈대를 만든다 |
| `/wiki:query` | index → 개념 페이지 → raw 순으로 읽고 인용을 달아 답한다. 새 답은 승인 뒤에만 저장 |
| `/wiki:lint` | 오래된 페이지, 깨진 링크·Sources, 고아 페이지, index 불일치 점검 (read-only) |
| `/wiki:plaud-note-taking` | PLAUD 녹음기 전사록을 프로젝트 용어로 정정 → corrected + digest → `/wiki:ingest`. 원본은 수정하지 않는다 |

훅과 스크립트가 없어 Claude Code 와 Codex 에서 같은 산문으로 돈다.

</details>

<details>
<summary><strong>deck</strong> - house 형식 HTML 강의 덱</summary>

`deck/shell.html` + `deck/sections/*.html` 을 GSAP 모션과 함께 1920×1080 덱으로 조립한다. 규칙 원본과 도구는 플러그인에 두고, 덱 저장소에는 버전 도장이 찍힌 규칙 사본(`.claude/rules/`)과 덱 내용만 남긴다.

| Skill | 하는 일 |
|-------|---------|
| `/deck:deck-ask` | 지금 상황에 맞는 다음 덱 스킬 제안 (실행하지 않는다) |
| `/deck:deck-new` | 빈 저장소에 `deck/` 스캐폴드와 규칙 사본. `deck/` 가 있으면 거부 |
| `/deck:deck-author` | 섹션 HTML 형식, 클래스 어휘, 패널·모션 계약 |
| `/deck:deck-assets` | 공식 로고 수집, 아이콘 시트, 마스코트 컷 |
| `/deck:deck-check` | 빌드, 문구 검사, 규칙 사본 어긋남, PNG·PDF 렌더와 상호작용 검사 |
| `/deck:deck-sync` | 규칙 사본과 `vendor/` 갱신. `shell.html` 은 차이만 보여 준다 |
| `/deck:deck-deploy` | 명시 요청 때만 Vercel 배포 (noindex) |

덱별 예외는 `.claude/rules/deck-local.md` 에 두며 동기화가 건드리지 않는다. Codex 는 `.claude/rules/` 를 읽지 못해 규칙 사본은 Claude 에만 걸리고, 도구와 스킬은 두 런타임에서 돈다. 일반 발표 자료와 PPTX 변환은 `frontend-slides` 몫이다.

**Requirements:** Python 3, Node 20+, Chrome, `pdfinfo`, 배포 시 Vercel 계정

</details>

<details>
<summary><strong>council</strong> - 이종 벤더 3인 심의</summary>

`/council:convene` 이 한 질문을 codex (GPT), agy (Gemini), Claude Opus 좌석에 동시에 던지고, 서로 반박하게 한 뒤 합의와 끝내 갈린 것을 `.council/<날짜>-<슬러그>/consensus.md` 로 남긴다. Claude 서브에이전트를 여러 개 띄워도 가중치를 공유해 관점이 늘지 않는 문제를 겨냥한다.

- 독립 의견 → 사용자 재질문 → 상호 반박 → 의장 합성
- 좌석 모델은 `~/.claude/council-models.json` 주간 TTL 레지스트리. 만료되면 실제 목록을 근거로 묻고, 자동 승급하지 않는다
- 결과를 코드에 자동 적용하지 않는다. 결석 좌석은 명시한다
- Claude 전용 (Codex 를 좌석으로 앉히므로 Codex 에서 돌리면 순환)

**Requirements:** `codex` / `agy` CLI (없는 좌석은 결석), `jq`

</details>

<details>
<summary><strong>codex-image</strong> - Claude → Codex 이미지 생성 브리지</summary>

`/codex-image:codex-image` 가 Codex CLI 의 이미지 생성에 위임한다. OpenAI API key 없이 ChatGPT OAuth 로 동작한다.

- 명시 요청이나 작업 사양이 지정한 경우에만 생성하고, 모호하면 먼저 확인한다
- 기본 출력 `assets/generated/codex-image/`, 기존 파일을 덮지 않는 파일명
- `--size` / `--quality` / `--out` / `-n` / `--variants` (서로 다른 시안 최대 4장) / `--verbatim` / `--edit` / `--ref`, opt-in `--model` / `--reasoning` / `--sandbox`
- Claude 전용 (Codex 에서 돌리면 순환)

**Requirements:** Codex CLI + ChatGPT OAuth 로그인

</details>

## Codex CLI

Codex 는 같은 `plugins/<name>/` 트리와 `.claude-plugin/` 매니페스트를 네이티브 폴백으로 읽는다 (`.codex-plugin` → `.claude-plugin`, `.agents/plugins/marketplace.json` → `.claude-plugin/marketplace.json`). Claude Code 의 marketplace 체크아웃을 그대로 등록한다.

```bash
codex plugin marketplace add ~/.claude/plugins/marketplaces/my-claude-plugins
codex plugin add dev@my-claude-plugins
```

업데이트할 때는 위 [업데이트](#업데이트) 절차 뒤에 Codex 등록을 다시 한다.

```bash
codex plugin marketplace remove my-claude-plugins
codex plugin marketplace add ~/.claude/plugins/marketplaces/my-claude-plugins
codex plugin add dev@my-claude-plugins
```

- **`council` 과 `codex-image` 는 Codex 에 설치하지 않는다** (순환).
- Codex 는 `commands` / `agents` 를 무시하고 skill 만 노출한다. `docs` 의 4 커맨드와 `scout` 의 agent 팀은 Claude 전용이다.
- 지금 이 marketplace 의 어떤 플러그인도 Codex 훅을 싣지 않는다.

## 설치 옵션

```bash
# Marketplace 설치 scope
/plugin install dev@my-claude-plugins                  # user (기본)
/plugin install dev@my-claude-plugins --scope project  # 팀 공유, git 추적
/plugin install dev@my-claude-plugins --scope local    # 개인용, 추적 안 함

# 로컬 개발: 클론 후 실행하면 .claude/settings.json 이 전부 auto-load
git clone git@github.com:YoungjaeDev/my-claude-plugins.git && cd my-claude-plugins && claude
```

**전역 지침 (선택).** `CLAUDE.md.global` 은 한국어 응답, 검증한 것과 추측한 것의 구분 같은 전역 지침의 정본이다 (Claude 와 Codex 공통). marketplace 업데이트는 이 파일을 설치하지 않으므로 직접 복사한다. `/plugin marketplace add` 가 저장소를 `~/.claude/plugins/marketplaces/my-claude-plugins/` 에 체크아웃해 두므로, 따로 clone 하지 않았다면 그 경로가 원본이다.

```bash
SRC=~/.claude/plugins/marketplaces/my-claude-plugins/CLAUDE.md.global   # 저장소를 clone 했다면 그쪽 경로
cp "$SRC" ~/.claude/CLAUDE.md      # Claude Code
cp "$SRC" ~/.codex/AGENTS.md       # Codex
```

## 요구사항

| 도구 | 용도 | 필요한 경우 |
|------|------|------|
| [Claude Code](https://docs.anthropic.com/claude-code) | 기본 CLI | 항상 |
| `gh` | GitHub 워크플로우 | dev |
| `jq` | 상태 파일, council | dev, council |
| Codex CLI | 네이티브 로드, council 좌석, codex-image | Codex 사용자, council, codex-image |
| Node 18+ | 가드 스크립트 | 기여자 |

## 옛 버전에서 옮겨 오기

모든 경우 먼저 [업데이트](#업데이트) 절차(캐시 삭제 → marketplace update → 재시작)로 새 버전을 받는다. 건너뛴 버전이 여럿이면 오래된 것부터 차례로 적용한다.

<details>
<summary>2.54.0: <code>cr-fix</code> → <code>/dev:review-loop</code></summary>

- 리뷰 루프 스킬 이름이 `/dev:review-loop` 로 바뀌었다 (dev 5.0.0). 옛 이름 "cr-fix" 나 '리뷰 반영' 으로 불러도 잡히고, 플래그와 동작은 그대로다.
- 상태 파일은 `.claude/state/review-loop-<PR>.json` 이다. `/dev:post-merge` 와 worktree 상태 복사는 옛 `cr-fix-<PR>.json` 도 읽고, 이름 변경 전에 루프를 돌린 PR 에서 `/dev:review-loop` 를 다시 돌리면 옛 상태의 처리 목록과 follow-up 이슈를 이어받는다.

</details>

<details>
<summary>2.52.0: 앞단은 Matt, wiki 는 바깥 지식 전용</summary>

- **dev 앞단 스킬 4개 삭제.** 아이디어부터 PR 까지는 Matt 스킬(`mattpocock/skills`)의 `/grill-with-docs` → `/to-spec` → `/to-tickets` → `/implement-spec` (또는 `/implement`), 버그 진단은 `/diagnosing-bugs`, 'grill me' 는 `/grilling` 이 맡는다.
- **post-merge 는 정리만 한다.** 교훈 반영은 빌드한 세션의 `/retro` 로 옮겼다.
- **docs:interview-methodology** 는 파일을 남기지 않는다. 큰 일은 `/grill-with-docs` 로.
- **wiki 는 바깥 지식 전용.** 훅, `insight/` 층, mem0 운영 스킬이 사라졌다. 옛 `ingest-finding`·`lint-wiki` 는 `/wiki:ingest`·`/wiki:lint` 로 바뀌었고 (옛 이름도 잡힌다), `/wiki:query` 가 새로 생겼다.
- **Codex 사용자는 `~/.codex/hooks.json` 에서 `wiki/<ver>/hooks/` 를 가리키는 항목 6개를 지운다** (`wiki_stale_check.sh`, `wiki_post_commit_hint.sh`, `wiki_session_start_lint_hint.sh`, `wiki_session_capture.sh` 의 Stop·SubagentStop 두 항목, `wiki_session_start_drain.sh`). 스크립트가 사라져 남겨 두면 매번 실패한다.
- `CLAUDE.md.global` 의 wiki 포인터 줄이 바뀌었다. 썼다면 [전역 지침](#설치-옵션) 의 `cp` 두 줄로 다시 복사한다.

</details>

<details>
<summary>2.31.0: <code>core</code> 제거</summary>

`core` 의 매 프롬프트 주입 훅(한국어 응답 등)은 `CLAUDE.md.global` 로 옮겨졌다. 플러그인을 지우고 [전역 지침](#설치-옵션)을 복사한다.

```bash
/plugin uninstall core@my-claude-plugins
```

`~/.codex/hooks.json` 에 `core` 나 `core-config` 의 `prompt_inject.sh` 항목이 있으면 삭제한다.

</details>

<details>
<summary>2.30.0: 14개 플러그인 → 8개 번들</summary>

옛 이름은 marketplace 에서 사라졌다. 옛 플러그인을 제거하고 새 번들을 설치한다. 스킬 이름은 그대로이고 네임스페이스만 바뀐다.

| 옛 플러그인 | 새 번들 | 예시 |
|---|---|---|
| `core-config` | `core` | (hooks 전용, 2.31.0 에서 제거) |
| `github-dev`, `project-init`, `e2e-harness` | `dev` | `/github-dev:commit-and-push` → `/dev:commit-and-push`, `/project-init:new` → `/dev:new` |
| `docs-forge`, `publish` | `docs` | `/docs-forge:readme` → `/docs:readme`, `/publish:gws-sync` → `/docs:gws-sync` |
| `code-scout`, `deepwiki`, `paper-search-tools` | `scout` | `/deepwiki:ask` → `/scout:ask`, `code-scout:github-scout` → `scout:github-scout` |
| `ml-toolkit` | `ml` | `/ml-toolkit:cv-notebook` → `/ml:cv-notebook` |
| `llm-wiki`, `mem0-ops` | `wiki` | `/llm-wiki:<skill>` → `/wiki:<skill>` (wiki 스킬 이름은 2.52.0 에서 다시 바뀌었다) |
| `council`, `codex-image` | 그대로 | 변경 없음 |

```bash
# 옛 플러그인 제거 (설치했던 것만)
/plugin uninstall github-dev@my-claude-plugins
/plugin uninstall llm-wiki@my-claude-plugins
# ... core-config, project-init, e2e-harness, docs-forge, publish, code-scout, deepwiki, paper-search-tools, ml-toolkit, mem0-ops

# 새 번들 설치 후 Claude Code 재시작
/plugin install dev@my-claude-plugins
/plugin install docs@my-claude-plugins
/plugin install scout@my-claude-plugins
/plugin install ml@my-claude-plugins
/plugin install wiki@my-claude-plugins
```

`~/.claude/settings.json` 의 `enabledPlugins` 에 옛 이름 키가 남아 있으면 지운다. Codex 사용자는 [Codex CLI](#codex-cli) 의 재등록 절차를 따른다.

</details>

## 기여하기

```bash
git config core.hooksPath .githooks   # clone 당 1회
```

`.githooks/pre-commit` 이 커밋마다 아래 가드를 돌린다. 훅은 Node 가 없으면 커밋을 거부한다 (`--no-verify` 로 우회하면 가드가 돌지 않은 것이다). CI(`.github/workflows/validate-codex.yml`)는 **릴리스 태그(`vX.Y.Z`, `/dev:release` 가 push 한다) push 와 Actions 탭의 수동 실행에서만** 돈다. CI 는 릴리스를 막지 않으므로 릴리스 뒤 Actions 탭에서 결과를 확인한다. 한 줄 검증 명령은 `AGENTS.md` 의 `## 검증` 에 있다.

이 저장소를 clone 해 열면 SessionStart 훅(`scripts/check-plugin-cache.mjs`)이 설치 캐시가 소스 버전보다 뒤처졌을 때 경고한다.

### CI 가드가 지키는 것

- `check-doc-consistency.mjs`: README 구조 트리·`## 플러그인 상세` 의 `<summary>` 이름 집합·AGENTS `## Plugins` 표·배지와 카운트 문자열이 `marketplace.json` 과 일치. 트리와 `<details>` 는 같은 문서의 다른 표면이라 둘 다 대조한다.
- `check-shell-portability.mjs`: GNU 전용 셸 구문 (`md5sum`·`sed -i`·`grep -P`·`date -d`·`stat -c`·`timeout`·`${VAR,,}`·`mapfile`·`declare -A` 등) 이 폴백도 capability probe 도 없이 쓰인 경우 차단. `||` 는 우변에 BSD 대응물이 있을 때만 폴백으로 보고, probe 도 대응물과 짝일 때만 인정한다. BSD 대응물이 없는 구문 (`grep -P`·`timeout`·bash 4 문법) 은 `# portability-ok: <사유>` 명시 예외만 받는다 (사유 필수). 판정은 정규식이 아니라 셸 워드 토크나이저로 하므로 GNU 긴 옵션 (`--perl-regexp`·`--date`·`--in-place`) 도 잡고, 인용 문자열과 `command -v` 인자, `case` 패턴은 호출로 세지 않는다. 스캔 대상은 `*.sh`·`*.bash`·`*.md` 의 bash 펜스와 shebang 이 sh/bash 인 확장자 없는 tracked 파일. 회귀 케이스 30건 (`check-shell-portability.test.mjs`) 이 함께 돈다.
- `check-skill-contract.mjs`: 한 런타임에서만 조용히 깨지는 스킬 위반 차단: `description` 1024자 초과, 인용 없는 `: `, resolver 없는 펜스 블록의 bare `${CLAUDE_PLUGIN_ROOT}`, 비-kebab `name`, byte 0 에서 시작하지 않는 frontmatter, `name` 과 디렉터리명 불일치. 여기에 stale 스킬 참조 가드: git 이 추적하는 live 파일에서 이 marketplace 플러그인 이름으로 시작하는 `<plugin>:<skill>` 참조(슬래시 형태 포함)가 없는 스킬을 가리키면 실패한다. 과거 기록 폴더(`docs/audit`·`docs/prd`·`docs/superpowers`·`.claude/spec`)와 `.llmwiki` 는 검사하지 않는다. 그 밖의 파일은 change log 안이라도 지운 스킬을 `<plugin>:<skill>` 형태가 아니라 산문으로 적는다 (예외는 ml 참조 문서 머리의 `Migrated from` 출처 줄 하나). 외부 플러그인(Matt 등) 이름은 대상이 아니다. 스캔 전에 RED/GREEN 픽스처를 먼저 돌린다.
- `check-skill-prose.mjs`: 500줄 초과·깊은 참조 경로 정보성 경고 (비차단).

픽스처 스위트 두 개가 같은 자리에서 돈다: `plugins/dev/skills/review-loop/tests/run-tests.sh` (1차 경로가 실패한 뒤에만 실행되는 CLI 폴백·CR 상태 경로) 와 `plugins/council/skills/convene/tests/run-tests.sh` (스킬 본문에만 존재하는 codex / agy 호출 계약). macOS CI 레그가 BSD 폴백이 실제로 실행되는 유일한 지점이며 `/bin/bash` 로 bash 3.2 를 강제한다. 가드는 소스를 자동 수정하지 않는다.

### 프로젝트 구조

```
.
├── .claude/
│   ├── settings.json         # 플러그인 auto-load + 캐시 지연 경고 훅
│   └── rules/                # 경로 스코프 규칙 (Claude 전용)
├── .claude-plugin/
│   └── marketplace.json      # 레지스트리 + 버전
├── plugins/
│   ├── dev/                  # PR 리뷰 루프·머지·정리 + 프로젝트 셋업 + E2E 하네스
│   ├── docs/                 # 문서 저작 + 스킬 저작 + 내보내기
│   ├── scout/                # 리서치 orchestrator + DeepWiki
│   ├── ml/                   # ML / CV 개발
│   ├── wiki/                 # 바깥 지식 wiki (ingest / query / lint / plaud)
│   ├── deck/                 # house 형식 HTML 강의 덱 (규칙 원본 + 도구 + 템플릿)
│   ├── council/              # 이종 벤더 3인 심의 (Claude 전용)
│   └── codex-image/          # Claude → Codex 이미지 생성 (Claude 전용)
├── scripts/                  # 가드 스크립트 (Node 18+, 의존성 없음)
├── docs/adr/                 # 결정 기록 (ADR)
├── GLOSSARY.md               # 용어집
├── AGENTS.md                 # 두 런타임 공통 최상위 지침 (정본)
├── CLAUDE.md                 # @AGENTS.md import
├── CLAUDE.md.global          # 사용자 전역 지침 정본 (~/.claude/CLAUDE.md, ~/.codex/AGENTS.md 로 복사)
├── code_review.md            # Codex cloud reviewer 상세 룰
└── README.md
```

## License

MIT
