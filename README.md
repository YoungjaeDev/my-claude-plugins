<div align="center">

<img src="assets/banner.png" width="600" alt="my-claude-plugins banner">

<br>

<img src="assets/logo.png" width="100" alt="my-claude-plugins logo">

# my-claude-plugins

Claude Code 를 위한 8개 플러그인 모음. GitHub 워크플로우, 리서치, 문서 저작, ML 개발, 바깥 지식 wiki, 강의 덱 제작을 짧은 이름의 번들로 묶었다. Codex CLI 도 같은 소스 트리와 `.claude-plugin/` 매니페스트를 네이티브로 읽는다.

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

설치 후 `/dev:cr-fix` 처럼 `/plugin:skill` 형태로 호출한다. 플러그인명을 짧게 둔 이유는 호출 길이와 가독성이다. 슬래시 메뉴는 `:`·`-`·`_` 를 무시하고 이름 안의 단어 시작에서도 매칭하므로 `/cr` 만 쳐도 `/dev:cr-fix` 가 하이라이트된다 (Claude Code 2.1.236 이상).

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

### 2.52.0 마이그레이션 (앞단은 Matt, wiki 는 바깥 지식 전용)

- **dev 앞단 스킬 4개 삭제.** 이슈 분해·이슈 해결·버그 진단·spec 상태 추적 스킬이 사라졌다. 아이디어부터 PR 까지는 Matt 스킬(`mattpocock/skills`)의 `/grill-with-docs` → `/to-spec` → `/to-tickets` → `/implement-spec` (또는 `/implement`) 이 맡고, 버그 진단은 `/diagnosing-bugs`, 'grill me' 는 `/grilling` 이 맡는다. dev 는 PR 부터 머지·정리까지(`/dev:cr-fix` → 머지 → `/dev:post-merge`)만 맡는다. 다음에 무엇을 부를지는 `/dev:flow` 가 안내한다.
- **post-merge 는 정리만 한다.** milestone·진행 추적 동기화와 교훈 반영(CLAUDE.md·AGENTS.md·rules·wiki 적재)이 빠졌다. 교훈은 빌드한 세션의 `/retro` 로 옮긴다.
- **docs:interview-methodology** 는 작은 요청의 모호한 점 확인과 TCREI 출력만 하고 파일을 남기지 않는다. 큰 일은 `/grill-with-docs` 로 넘긴다.
- **wiki 는 바깥 지식 전용.** 훅 5종, `insight/` 층, mem0 운영 스킬이 사라졌다. 옛 `ingest-finding`·`lint-wiki` 는 `/wiki:ingest`·`/wiki:lint` 로 이름이 바뀌었고 (옛 이름으로 불러도 잡힌다), `/wiki:query` 가 새로 생겼다. wiki 가 없는 repo 에서는 첫 `/wiki:ingest` 가 뼈대를 만든다. 결정은 `docs/adr/`, 용어는 `GLOSSARY.md` 에 둔다.
- **Codex 사용자**는 `~/.codex/hooks.json` 에서 `wiki/<ver>/hooks/` 를 가리키는 항목 6개(`wiki_stale_check.sh`, `wiki_post_commit_hint.sh`, `wiki_session_start_lint_hint.sh`, `wiki_session_capture.sh` 의 Stop·SubagentStop 두 항목, `wiki_session_start_drain.sh`)를 지운다. 스크립트가 사라져 남겨 두면 매번 실패한다.
- 전역 지침 정본 `CLAUDE.md.global` 의 wiki 포인터 줄이 바뀌었다. 아래 2.31.0 절의 `cp` 두 줄로 설치 사본을 다시 복사한다.
- 위 "플러그인 업데이트" 절차(캐시 삭제 → marketplace update → 재시작)로 새 버전을 받는다.

### 2.31.0 마이그레이션 (core 제거)

`core` 플러그인이 사라졌다. 매 프롬프트 주입 훅(한국어 응답, `.llmwiki/insight/` 선독, surgical diff)은 전역 지침 파일 `CLAUDE.md.global` 로 옮겨졌고, marketplace 업데이트는 이 파일을 설치하지 않으므로 직접 복사한다.

`/plugin marketplace add` 가 저장소를 `~/.claude/plugins/marketplaces/my-claude-plugins/` 에 체크아웃해 두므로, 저장소를 따로 clone 하지 않았다면 그 경로가 원본이다.

```bash
/plugin uninstall core@my-claude-plugins

SRC=~/.claude/plugins/marketplaces/my-claude-plugins/CLAUDE.md.global   # 저장소를 clone 했다면 그쪽 경로
cp "$SRC" ~/.claude/CLAUDE.md      # Claude Code
cp "$SRC" ~/.codex/AGENTS.md       # Codex
```

`~/.codex/hooks.json` 에 `core` 의 `prompt_inject.sh` 항목이 있으면 삭제한다.

### 2.30.0 마이그레이션 (14 → 8 번들)

2.30.0 에서 14개 플러그인을 8개 번들로 통합했다. 옛 이름은 marketplace 에서 사라졌으므로 옛 플러그인을 제거하고 새 번들을 설치한다. 스킬 이름은 그대로이고 네임스페이스만 바뀐다.

| 옛 플러그인 | 새 번들 | 예시 |
|---|---|---|
| `core-config` | `core` | (hooks 전용, 2.31.0 에서 제거 — 아래 절) |
| `github-dev`, `project-init`, `e2e-harness` | `dev` | `/github-dev:cr-fix` → `/dev:cr-fix`, `/project-init:new` → `/dev:new` |
| `docs-forge`, `publish` | `docs` | `/docs-forge:readme` → `/docs:readme`, `/publish:gws-sync` → `/docs:gws-sync` |
| `code-scout`, `deepwiki`, `paper-search-tools` | `scout` | `/deepwiki:ask` → `/scout:ask`, `code-scout:github-scout` → `scout:github-scout` |
| `ml-toolkit` | `ml` | `/ml-toolkit:cv-notebook` → `/ml:cv-notebook` |
| `llm-wiki`, `mem0-ops` | `wiki` | `/llm-wiki:<skill>` → `/wiki:<skill>` (wiki 스킬 이름과 mem0 스킬은 2.52.0 에서 바뀌었다 — 위 절) |
| `council`, `codex-image` | 그대로 | 변경 없음 |

```bash
# 1. 캐시 삭제 (위 절차) 후 marketplace 업데이트
/plugin marketplace update my-claude-plugins

# 2. 옛 플러그인 제거 (설치했던 것만)
/plugin uninstall github-dev@my-claude-plugins
/plugin uninstall llm-wiki@my-claude-plugins
# ... core-config, project-init, e2e-harness, docs-forge, publish, code-scout, deepwiki, paper-search-tools, ml-toolkit, mem0-ops

# 3. 새 번들 설치 후 Claude Code 재시작
/plugin install dev@my-claude-plugins
/plugin install docs@my-claude-plugins
/plugin install scout@my-claude-plugins
/plugin install ml@my-claude-plugins
/plugin install wiki@my-claude-plugins
```

`~/.claude/settings.json` 의 `enabledPlugins` 에 옛 이름 키가 남아 있으면 지운다. Codex 사용자는 아래 "머신 로컬 운영 갱신" 절도 본다.

## 플러그인 목록

| 플러그인 | 분류 | 내용 |
|---------|------|------|
| `dev` | Development | PR 부터 머지·정리까지의 뒷단 4 (commit-and-push, cr-fix, post-merge, release) + 라우터 1 (flow, Matt 앞단 + dev 뒷단) + 세션 인수인계 1 (session-handoff) + 서브에이전트 오케스트레이션 1 (orchestrate, 워커 프리셋 3) + 프로젝트 셋업 2 (new, wiring) + Playwright E2E 하네스 3 (e2e-setup, e2e-author, e2e-debug) |
| `docs` | Documentation | 프로젝트 문서 커맨드 4 (readme, changelog, deploy-doc, moc) + 저작 스킬 (doc-guides, write-rules, interview-methodology, vp, skill-forge, skill-audit, skill-fleet-review) + 내보내기 (translate-web-article, gws-sync) |
| `scout` | Research | research-orchestrator (github / hf / web / docs scout 에이전트 + synthesis), ask / generate-llmstxt (DeepWiki) |
| `ml` | Development | ml-dev-principles, gradio-cv-app, cv-notebook, edit-notebook |
| `wiki` | Outside Knowledge | 바깥 지식 wiki (ingest, query, lint, plaud-note-taking). 훅 없음 |
| `deck` | Documentation | house 형식 HTML 강의 덱 (deck-ask, deck-new, deck-author, deck-assets, deck-check, deck-sync, deck-deploy). 규칙 원본과 도구를 플러그인에 두고 덱 저장소에는 버전 도장 찍은 규칙 사본만 둔다 |
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
<summary><strong>dev</strong> - GitHub 워크플로우 + 프로젝트 셋업 + E2E 하네스</summary>

dev 는 뒷단만 맡는다: PR 부터 리뷰 루프, 머지, 정리까지. 아이디어부터 PR 까지의 앞단은 Matt 스킬(`mattpocock/skills`: `/grill-with-docs` → `/to-spec` → `/to-tickets` → `/implement-spec` 또는 `/implement`)이 맡고, 버그 진단은 `/diagnosing-bugs`, 교훈은 빌드한 세션의 `/retro` 가 맡는다.

**GitHub 워크플로우**

| Skill | Description |
|-------|-------------|
| `/dev:commit-and-push` | 변경 분석, Conventional Commits 메시지, 커밋, 푸시 |
| `/dev:cr-fix` | CodeRabbit + Codex 리뷰를 pre-flight 로 감지해 finding 별로 apply / defer / skip 을 사용자에게 묻지 않고 판단하고, 수렴·low-severity 바닥·churn 중 하나에서 정지하며 남은 지적은 후속 이슈 1건으로 넘긴다. 켜진 리뷰어 전원이 HEAD 에 판정을 낸 뒤에만 다음 라운드를 push 하거나 끝내거나 머지하고, Codex 가 Failed 를 내면 `codex_failed` 로 멈춘다. PR 댓글은 `@coderabbitai rate limit` 질의와 HEAD 당 1회의 `@coderabbitai review` 요청(non-default base, 자동 리뷰 일시정지)뿐이다. `--auto-merge`, `--cr-source <auto\|pr-bot\|cli\|codex-only>` (rate-limit 시 로컬 CLI 또는 Codex-only 폴백) |
| `/dev:post-merge` | 머지 후 정리만 한다: 남은 리뷰 지적 표시, base 전환, 머지된 브랜치 삭제, 남은 이슈 close, GitHub Project 상태 동기화, repo About(description) 불일치 점검, 커밋. README·CHANGELOG 는 `docs:readme`·`docs:changelog` 를 가리키기만 하고 교훈은 기록하지 않는다 (`/retro` 몫) |
| `/dev:release` | 버전 태그 + GitHub Release (릴리스 노트 자동 생성) |
| `/dev:session-handoff` | 컨텍스트를 비우기 전 세션 인수인계 요약 (결정, 변경, 핵심 파일, 실행 중 상태, 검증 명령, 보류·미해결 질문). 채팅 출력 전용, 파일·메모리 미기록 |
| `/dev:orchestrate` | 메인 에이전트를 오케스트레이터로 운용. 슬라이스별 job card (목표·범위·절대 경로·입력·출력 형식·완료 기준·프리셋), 모델 x effort 워커 프리셋 `dev:worker-standard/deep/max`, 경로당 writer 하나, 품질 게이트 (같은 에이전트 재질의 2회 → 상위 프리셋 1회 → 사용자 질문), 오케스트레이터가 직접 검증 후 에이전트별 ledger 보고. `Workflow` 는 수동 호출 시에만. 쓰는 슬라이스는 전부 worktree 격리 — 워커 브랜치 diff 를 카드의 owned Paths 와 대조해 범위를 벗어난 브랜치는 merge 하지 않는다 (복원하지 않는다). Codex 에는 `Agent` 도구가 없어 인라인으로 돌고, 수동 `git worktree add` 를 택하지 않으면 브랜치 게이트 대신 카드 Paths + 쓴 경로 자기보고가 완료 조건이다. `git worktree list` 베이스라인 대조 cleanup 필수 |
| `/dev:flow` | 다음에 무엇을 부를지 안내하는 짧은 라우터. Matt 앞단(`/grill-with-docs` → `/to-spec` → `/to-tickets` → `/implement-spec`, 세부는 `/ask-matt`) 과 dev 뒷단(`/dev:cr-fix` → 머지 → `/dev:post-merge` → `/retro`) 을 한 흐름으로 보이고, 버그·PR 없음·즉석 병렬(`/dev:orchestrate`)·wiki·worktree·non-default base·E2E 갈래와 제품 repo 준비를 안내한다. 직접 뭔가를 실행하지 않는다. `mattpocock/skills` `ask-matt` 형식을 각색 |

**제품 repo 준비 (repo 당 1회)** — Matt 스킬을 설치한 뒤 `/setup-matt-pocock-skills` 로 이슈 트래커·triage 라벨·도메인 문서 안내를 repo 에 연결하고, triage 라벨 5개를 만든다. 라벨이 없으면 첫 `/to-spec` 이 실패한다. 없는 라벨만 만들므로 다시 돌려도 기존 라벨의 색상·설명은 그대로다 (`--force` 는 덮어쓴다).

```bash
( have=$(gh label list --limit 1000 --json name --jq '.[].name') || exit 1
  for l in needs-triage needs-info ready-for-agent ready-for-human wontfix; do
    printf '%s\n' "$have" | grep -qxF "$l" || gh label create "$l" || exit 1
  done )
```

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
| `/docs:readme generate` / `analyze` | 템플릿 (CLI, Library, React Component, MCP Plugin, SaaS, Desktop, Internal) 에서 README 생성 또는 기존 README 분석 |
| `/docs:changelog init` | Keep a Changelog 형식 CHANGELOG |
| `/docs:deploy-doc generate` | 배포 / 절차 문서 (요약 + 전제조건 + 번호 단계) |
| `/docs:moc docs/` | 문서 폴더 MOC 인덱스 (경량 / `--strict`) |

네 커맨드는 `doc-guides` 스킬의 참조 카드(README / CHANGELOG / 배포 문서 / MOC)를 필요한 섹션만 로드한다.

**에이전트가 읽는 문서 (skills)**

| Skill | Description |
|-------|-------------|
| `/docs:write-rules` | CLAUDE.md 와 `.claude/rules/*.md` 를 공식 패턴(200줄 root cap, `paths:` 스코핑)에 맞게 생성·재구조화. 상태 스캔 후 `NEW / TIGHTEN / SPLIT / REORGANIZE` 중 하나를 추천 |
| `/docs:interview-methodology` | 작은 요청의 모호한 점 확인 (breadth-first). 결과는 대화 안 요약으로 끝내고 파일을 남기지 않는다. 재사용 프롬프트가 필요하면 Google TCREI 구조로 출력. 일이 커 보이면 `/grill-with-docs`, 계획을 몰아붙이는 인터뷰('grill me')는 Matt `/grilling` 으로 넘긴다 |
| `/docs:vp` | 음성 전사 프롬프트 게이트. 프롬프트 앞·뒤·중간 어디에 넣어도 됨. `.agents/voice-terms.md` 사전으로 오인식 교정 후, 명확하면 한 줄 요약하고 진행, 모호하면 핵심 질문 2-3개. 사전 행은 승인 후에만 추가 (Claude·Codex 공용) |
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
| `/scout:research-orchestrator` | 유일한 리서치 진입점. 쿼리 → mode 감지 (quick / deep) → github / hf / web / docs scout 병렬 fan-out → synthesis-scout 합성 (dedup, trust ranking, 충돌 해소, Markdown 보고서) |
| `/scout:ask` | GitHub 레포에 DeepWiki MCP 로 질문 |
| `/scout:generate-llmstxt` | 레포의 `llms.txt` 생성 |

**Agent team (Claude Code 전용):** `scout:github-scout`, `scout:hf-scout`, `scout:web-scout` (exa → brightdata → insane-search 4-tier fetch), `scout:docs-scout` (Context7 + DeepWiki), `scout:synthesis-scout`. Codex 에는 agent 표면이 없으므로 orchestrator 가 generic subagent 또는 순차 실행으로 같은 축을 돌린다.

```text
Skill("scout:research-orchestrator", "Research RAG eval frameworks 2026")
Agent(subagent_type="scout:github-scout",
      prompt="query=fastapi production boilerplate\nworkspace_dir=$WORKSPACE\nartifact_id=01_github")
```

정책 / 시장 / 역사 같은 비-code 토픽은 sibling `/deep-research` 를 직접 부른다.

**Requirements:** `gh`, `uvx` (hf)

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
<summary><strong>wiki</strong> - 바깥 지식 wiki</summary>

저장소가 통제하지 못하는 것(플랫폼, 벤더, 고객, 도메인)에 대한 지식만 받는다. 문서로 들어왔든 작업 중에 알게 됐든 같다. 결정은 `docs/adr/`, 용어는 `GLOSSARY.md`, 반복 실수는 `/retro` 가 만드는 자동 검사로 가고 wiki 는 받지 않는다. 구조는 `.llmwiki/raw/` (손대지 않는 원본) + `.llmwiki/wiki/` (`index.md` 한 줄씩, `log.md` 작업 기록, `<주제>/<개념>.md` 개념 페이지와 `## Sources`).

| Skill | Description |
|-------|-------------|
| `/wiki:ingest` | 원본(회의록·리서치·고객·벤더 문서)이나 작업 중 알게 된 사실을 개념 페이지로 만들거나 고치고 index·log 를 갱신. wiki 가 없으면 뼈대를 만든다. 옛 이름 `ingest-finding` 도 잡힌다 |
| `/wiki:query` | index → 개념 페이지 → 필요하면 raw 순으로 읽고 인용을 달아 답한다. 새로 정리한 답은 승인 뒤에만 페이지로 저장. 다루는 페이지가 없으면 넣을 원본을 알려 준다 |
| `/wiki:lint` | 오래된 페이지, 깨진 링크·Sources, 고아 페이지, index 불일치 점검 (read-only). 옛 형식 페이지는 개수 한 줄로만 알린다. 옛 이름 `lint-wiki` 도 잡힌다 |
| `/wiki:plaud-note-taking` | PLAUD 녹음기의 Whisper 전사록을 프로젝트 용어로 정정 → `derived/` corrected + digest → `/wiki:ingest`. 원본과 PLAUD 요약은 수정하지 않는다 |

훅과 스크립트가 없다. 네 스킬 모두 Claude Code 와 Codex 에서 같은 산문으로 돈다.

</details>

<details>
<summary><strong>deck</strong> - house 형식 HTML 강의 덱</summary>

`deck/shell.html` + `deck/sections/*.html` 을 GSAP 모션과 함께 1920×1080 덱으로 조립한다. 규칙 원본(korean-style, deck-copy, deck-authoring)과 도구는 플러그인 한 곳에 두고, 덱 저장소에는 버전 도장이 찍힌 규칙 사본과 그 덱의 내용만 남긴다.

| Skill | Description |
|-------|-------------|
| `/deck:deck-ask` | 지금 상황에 맞는 다음 덱 스킬을 제안한다. 실행하지 않고 알려 주기만 한다 |
| `/deck:deck-new` | 빈 저장소에 `deck/` 스캐폴드와 규칙 사본을 만든다. `deck/` 가 있으면 거부 |
| `/deck:deck-author` | 섹션 HTML 형식, 클래스 어휘, 패널·모션 계약 |
| `/deck:deck-assets` | 공식 로고 수집, 아이콘 시트, 마스코트 컷 |
| `/deck:deck-check` | 빌드, 문구 검사(`deck-copy.md` 금지 표기 표), 규칙 사본 어긋남, PNG·PDF 렌더와 상호작용 검사 |
| `/deck:deck-sync` | 규칙 사본과 `vendor/` 갱신, `shell.html` 은 차이만 보여 준다 |
| `/deck:deck-deploy` | 명시 요청 때만 Vercel 배포 (noindex 헤더 + robots.txt) |

- 도구(`build.py`, `dev.py`, `check_copy.py`, `kit.py`, `render-deck.cjs`, `check-deck-interaction.cjs`, `deploy.sh`)는 덱에 복사하지 않고 플러그인에서 실행한다
- 덱별 예외는 `.claude/rules/deck-local.md` 에 둔다. 동기화가 건드리지 않는다
- 일반 발표 자료와 PPTX 변환은 `frontend-slides` 몫이다. 설치 여부는 경고로만 알린다
- Codex 는 `.claude/rules/` 를 읽지 못하므로 규칙 사본은 Claude 에만 걸린다. 도구와 스킬은 두 런타임에서 돈다

**Requirements:** Python 3, Node 20+, Chrome, `pdfinfo` (렌더 PDF 검사), 배포 시 Vercel 계정

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
- `--size` / `--quality` / `--out` / `-n` (같은 프롬프트 N장) / `--variants` (서로 다른 시안 N장, 최대 4, 전부 보여주고 고른다) / `--verbatim` / `--edit` / `--ref` 옵션, opt-in `--model` / `--reasoning` / `--sandbox`
- Codex 는 이미지를 `$CODEX_HOME/generated_images/` 에 먼저 쓰므로, 출력 디렉터리에 없으면 세션 폴더에서 회수한다 (전 플랫폼 공통)
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

**`~/.codex/hooks.json` 의 `wiki` 항목은 지운다.** 2.52.0 부터 `wiki` 는 훅을 싣지 않으므로 `wiki/<ver>/hooks/...` 를 가리키는 항목 6개가 남아 있으면 없는 스크립트를 부른다. `core-config` / `core` 의 `prompt_inject.sh` 항목도 플러그인이 사라졌으므로 삭제한다 (전역 지침 `CLAUDE.md.global` 이 같은 역할을 한다). 지금 이 marketplace 의 어떤 플러그인도 Codex 훅을 싣지 않는다.

### 기여자 가드

```bash
git config core.hooksPath .githooks   # clone 당 1회
```

`.githooks/pre-commit` 과 `.github/workflows/validate-codex.yml` 이 같은 가드를 돌린다.

### CI 가드가 지키는 것

- `check-doc-consistency.mjs` — README 구조 트리·`## 플러그인 상세` 의 `<summary>` 이름 집합·AGENTS `## Plugins` 표·배지와 카운트 문자열이 `marketplace.json` 과 일치. 트리와 `<details>` 는 같은 문서의 다른 표면이라 둘 다 대조한다.
- `check-shell-portability.mjs` — GNU 전용 셸 구문 (`md5sum`·`sed -i`·`grep -P`·`date -d`·`stat -c`·`timeout`·`${VAR,,}`·`mapfile`·`declare -A` 등) 이 폴백도 capability probe 도 없이 쓰인 경우 차단. `||` 는 우변에 BSD 대응물이 있을 때만 폴백으로 보고, probe 도 대응물과 짝일 때만 인정한다. BSD 대응물이 없는 구문 (`grep -P`·`timeout`·bash 4 문법) 은 `# portability-ok: <사유>` 명시 예외만 받는다 (사유 필수). 판정은 정규식이 아니라 셸 워드 토크나이저로 하므로 GNU 긴 옵션 (`--perl-regexp`·`--date`·`--in-place`) 도 잡고, 인용 문자열과 `command -v` 인자, `case` 패턴은 호출로 세지 않는다. 스캔 대상은 `*.sh`·`*.bash`·`*.md` 의 bash 펜스와 shebang 이 sh/bash 인 확장자 없는 tracked 파일. 회귀 케이스 30건 (`check-shell-portability.test.mjs`) 이 pre-commit + CI 에서 함께 돈다.
- `check-skill-contract.mjs` — 한 런타임에서만 조용히 깨지는 스킬 위반 차단: `description` 1024자 초과, 인용 없는 `: `, resolver 없는 펜스 블록의 bare `${CLAUDE_PLUGIN_ROOT}`, 비-kebab `name`, byte 0 에서 시작하지 않는 frontmatter, `name` 과 디렉터리명 불일치. 여기에 stale 스킬 참조 가드: git 이 추적하는 live 파일에서 이 marketplace 플러그인 이름으로 시작하는 `<plugin>:<skill>` 참조(슬래시 형태 포함)가 없는 스킬을 가리키면 실패한다. 과거 기록 폴더(`docs/audit`·`docs/prd`·`docs/superpowers`·`.claude/spec`)와 `.llmwiki` 는 검사하지 않는다. 그 밖의 파일은 change log 안이라도 지운 스킬을 `<plugin>:<skill>` 형태가 아니라 산문으로 적는다 (예외는 ml 참조 문서 머리의 `Migrated from` 출처 줄 하나). 외부 플러그인(Matt 등) 이름은 대상이 아니다. 스캔 전에 RED/GREEN 픽스처를 먼저 돌린다.
- `check-skill-prose.mjs` — 500줄 초과·깊은 참조 경로 정보성 경고 (비차단).

픽스처 스위트 두 개가 같은 자리에서 돈다: `plugins/dev/skills/cr-fix/tests/run-tests.sh` (1차 경로가 실패한 뒤에만 실행되는 CLI 폴백·CR 상태 경로) 와 `plugins/council/skills/convene/tests/run-tests.sh` (스킬 본문에만 존재하는 codex / agy 호출 계약). macOS CI 레그가 BSD 폴백이 실제로 실행되는 유일한 지점이며 `/bin/bash` 로 bash 3.2 를 강제한다. 가드는 소스를 자동 수정하지 않는다.

## 요구사항

| 도구 | 용도 | 필수 |
|------|------|------|
| [Claude Code](https://docs.anthropic.com/claude-code) | 기본 CLI | Yes |
| `gh` | GitHub 워크플로우 | dev |
| `jq` | 상태 파일, council | dev, council |
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
│   ├── dev/                  # GitHub 워크플로우 + 프로젝트 셋업 + E2E 하네스
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

## 참고 자료

- [Claude Code Documentation](https://docs.anthropic.com/claude-code)
- [Claude Code Plugin System](https://docs.anthropic.com/claude-code/plugins)

## License

MIT
