# AGENTS.md

> **이 파일이 정본이고, 루트 `CLAUDE.md` 는 이 파일을 `@AGENTS.md` 로 import 하는 한 줄짜리 포인터다.** 세 런타임이 서로 다른 파일명을 찾기 때문이다 — Claude Code 는 `CLAUDE.md` 만 읽고 그 안의 `@AGENTS.md` import 로 이 파일을 끌어오며, Codex 와 Hermes 는 `AGENTS.md` 를 그대로 읽는다. 내용을 이 파일 한 곳에만 두어 미러 유지 부담을 없앴다.
>
> `CLAUDE.md` 를 따로 편집하지 마라 — `@AGENTS.md` 한 줄 import 일 뿐이다. 편집은 항상 `AGENTS.md` 에 한다.

## 기본 원칙

- 이 저장소는 Claude Code 플러그인 marketplace 저장소입니다. 변경 전에는 이 문서, `README.md`, 관련 플러그인의 `plugins/<name>/CLAUDE.md`를 먼저 확인하세요.
- 사용자가 한국어로 요청하면 한국어로 응답하세요.
- 변경은 요청 범위에만 한정하고, 관련 없는 파일이나 기존 사용자 변경 사항은 되돌리지 마세요.
- 파일 탐색과 검색은 우선 `rg`, `rg --files`를 사용하세요.
- 문서와 매니페스트가 함께 움직이는 저장소이므로 코드 변경뿐 아니라 `README.md`, 이 문서, marketplace manifest의 동기화 필요성을 항상 확인하세요.

플러그인 트리 하나를 Claude Code, Codex 0.135(`scripts/sync-codex-manifests.mjs`), Hermes Agent(`scripts/sync-hermes-manifests.mjs`)가 함께 읽습니다 — one source, three runtimes.

## Plugins (24)

### Core
| Plugin | Description |
|--------|-------------|
| `core-config` | Python auto-format + cross-platform notifications + per-prompt behavioral block (`prompt_inject.sh`, shared Claude + Codex). Two conditional pointers: `.llmwiki/insight/` when a knowledge root resolves in cwd, and a one-line `[council]` delegation reminder when `codex` / `agy` is on PATH (Claude-only — Codex is itself a council member). Work guidelines live in `~/.claude/CLAUDE.md` |

### GitHub
| Plugin | Description |
|--------|-------------|
| `github-dev` | GitHub workflow (commit, PR, issue, unified cr-fix CodeRabbit + Codex skill with PR-bot → CLI → codex-only auto-fallback on rate-limit) |

### Testing
| Plugin | Description |
|--------|-------------|
| `e2e-harness` | Playwright E2E test-harness engineering — wraps Playwright's official planner/generator/healer AI agents (`npx playwright init-agents --loop=claude`). 3 skills: `e2e-setup` (full harness onboarding — agents, auth via storageState, route mocking, CI with trace artifacts + PR comment + path/label gating), `e2e-author` (planner→generator orchestration, semantic `getByRole` locators, `--repeat-each` burn-in flake gate), `e2e-debug` (headless trace analysis + healer self-healing loop, skip-after-3). Loose coupling — degrades gracefully when Playwright is absent. |

### Research & Search
| Plugin | Description |
|--------|-------------|
| `code-scout` | Multi-axis research harness — 5-axis scout team (github/hf/web/docs/paper) + synthesis-scout + research-orchestrator skill. exa MCP + WebSearch + firecrawl tier-3 + insane-search tier-4 for WAF/blocked URLs. paper-scout wraps paper-search-tools 8-source family. /deep-research is the sibling for non-code/ML topics. |
| `deepwiki` | AI-powered GitHub repo documentation |
| `paper-search-tools` | Academic paper search (arXiv, PubMed, Semantic Scholar, etc.) |
| `brightdata-guide` | Bright Data web data access via MCP tools + CLI — scraping (Web Unlocker), SERP, structured web_data_* extractors, browser automation. Operator sets BRIGHTDATA_API_KEY; delegate subagents fall back to the bdata CLI |

### AI Models
| Plugin | Description |
|--------|-------------|
| `codex-image` | Claude->Codex image generation bridge (delegates to Codex CLI image gen via ChatGPT OAuth, no OpenAI API key). Claude-only — excluded from Codex sync |

### Development Tools
| Plugin | Description |
|--------|-------------|
| `notebook` | Safe Jupyter notebook editing |
| `ml-toolkit` | ML/multimodal dev principles, GPU parallel processing, Gradio CV apps, CV notebooks, dataset exploration |

### Content & Translation
| Plugin | Description |
|--------|-------------|
| `translator` | Web article translation to Korean |
| `tcrei-prompt` | Rewrite prompts using Google's TCREI structure for next-session reuse |
| `tally-form` | Checklist markdown to Tally questionnaire/survey form — deterministic urllib builder, theme presets, section dividers, per-question choices (required/checkbox) + short-answer inputs (text/number/email/phone/link), native scheduling (matrix/date/time), form images (logo/cover/IMAGE) + redirect, idempotent publish, humanize routing. Dev-survey + lecture-consultation presets |

### Planning
| Plugin | Description |
|--------|-------------|
| `interview` | Structured requirements gathering |
| `project-init` | Agent-harness project lifecycle. `new` — first-day bootstrap (.claude/ + CLAUDE.md + AGENTS.md w/ Codex review guidelines + README/CHANGELOG + gh repo create), preflight-guarded to empty dirs. `wiring` — read-only 14-axis setup diagnostic for existing repos, verdicts `FAIL/WARN/ASK/INFO/SKIP/OK`. Four axes ask whether config takes *effect*, not just exists: `core.hooksPath`, an `@import` that defeats `.claude/rules` `paths:` scoping, MCP servers registered twice (one copy silently discarded), Codex `AGENTS.md` byte budget. `ASK` = a decision nobody made yet — asked once, persisted to `.claude/state/wiring.json`. Shared detector `scripts/project_state.sh` |

### Presentation
| Plugin | Description |
|--------|-------------|
| `slidev` | Slidev markdown presentation generator with interview workflow |

### Documentation
| Plugin | Description |
|--------|-------------|
| `docs-forge` | README/CHANGELOG generation with CRO best practices, plus deployment-doc templates (`/docs-forge:deploy-doc`) and MOC index generation (`/docs-forge:moc`) |
| `rules-forge` | CLAUDE.md + .claude/rules/ generation with auto mode detection (single write-rules skill) |

### Design
| Plugin | Description |
|--------|-------------|
| `anti-slop-design` | Anti-AI-slop design guard for web/SaaS landing, decks (PPT), dashboards, and copy. clarify→context→plan→run→audit→revise flow + two-phase audit gate (pre-emit self-critique + binary slop checklist); Korean copy handed to `humanize-korean`. Source-grounded in 6 OSS anti-slop repos (impeccable/hallmark/frontend-design/huashu/stop-slop/frontend-slides) |
| `ppt-yeong-style` | yeong 스타일 강의·제안 덱 작성 규약 — `ppt-master` 엔진 위에 얹는 작성 레이어. 덱 유형·md 소스 규약·작성 원칙 16종·밀도 리듬(중간 강화)·역할 기반 색·codex vs SVG 경계·앱 UI 실물 강제·ppt-master 레버 조합 차별화·빌드 후 스토리 review·공식 로고 fetch·윤문·렌더 QA. 진입점 SKILL.md + references/ 6종 + assets/injection-prompt.md |

### Productivity
| Plugin | Description |
|--------|-------------|
| `gws-sync` | 로컬 → Google Drive 단방향 제안형 동기화 (gws CLI 기반). 매핑 설정(`.gws-sync.json`) → Drive 트리 탐색 → 신규·변경 diff 리포트 → 업로드 위치 AskUserQuestion 승인 → 업로드(기존 파일 content update로 ID·공유링크 보존). 삭제는 제안만. gws 미설치 시 설치 안내 후 중단. googleworkspace/cli 스킬 95종 카탈로그 동봉 |

### Memory & Lore
| Plugin | Description |
|--------|-------------|
| `mem0-ops` | 플릿 레벨 mem0 진단·정리 — upstream mem0 플러그인(프로젝트 내부 품질)과 역할 분리. fleet-scan(전 앱 노이즈율·쓰레기 app_id 후보·app/user_id 파편화 리포트) + doctor(rerank env·auto_save 파일 우선순위 함정·decay·훅 timeout·정체성 파편화 점검, 제안만) + cleanup(백업→타입/앱 단위 삭제, dry-run 기본 + 스킬 레이어 앱별 확인 게이트). stdlib REST 스크립트라 결정론 구간 LLM 비용 0 |
| `llm-wiki` | Karpathy LLM-Wiki 3-layer (insight + wiki + raw under neutral `.llmwiki/`): 5 skills + 5 hooks (incl. Stop-capture + SessionStart-drain auto-ingest) + bootstrap templates. Post-merge wiki ingest is a mandatory step inside `github-dev:post-merge` (post-merge-wiki absorbed). Promoted cross-agent rules graduate to `.llmwiki/insight/` (surfaced via core-config prompt-inject hook), not `.claude/rules/` |

### Workflow State
| Plugin | Description |
|--------|-------------|
| `spec-state` | Spec / issue / PR work-pipeline aggregate (`state-tracker` skill, `.claude/state/spec.json`) |

플러그인은 `.claude/settings.json` 에서 auto-load 됩니다. 사용법 상세는 `README.md`.

## 저장소 구조

```
.
├── .claude/
│   └── settings.json       # Plugin configuration
├── plugins/
│   ├── core-config/        # Guidelines + hooks
│   ├── github-dev/         # GitHub workflow
│   ├── e2e-harness/        # Playwright E2E test-harness (setup/author/debug)
│   ├── code-scout/         # Resource discovery
│   ├── deepwiki/           # Repo docs
│   ├── paper-search-tools/ # Academic papers
│   ├── brightdata-guide/   # Bright Data web-data guide (MCP + CLI)
│   ├── notebook/           # Jupyter
│   ├── ml-toolkit/         # ML tools
│   ├── translator/         # Translation
│   ├── codex-image/        # Claude->Codex image gen bridge
│   ├── interview/          # Requirements
│   ├── docs-forge/         # README/CHANGELOG + deploy-doc + MOC
│   ├── rules-forge/        # write-rules skill (auto mode detection)
│   ├── slidev/             # Presentation generator
│   ├── tcrei-prompt/       # TCREI prompt structuring
│   ├── llm-wiki/           # LLM-Wiki 3-layer (wiki lore)
│   ├── mem0-ops/           # Fleet-level mem0 diagnostics/cleanup (fleet-scan/doctor/cleanup)
│   ├── spec-state/         # spec/issue/PR work-pipeline aggregate
│   ├── anti-slop-design/   # Anti-AI-slop design guard (web/ppt/dashboard/copy)
│   ├── ppt-yeong-style/    # yeong-style lecture/proposal deck writing layer (on ppt-master)
│   ├── tally-form/         # Checklist md -> Tally questionnaire/survey form builder
│   └── project-init/       # Day-1 bootstrap (new) + existing-repo setup diagnostic (wiring)
├── AGENTS.md               # This file — 정본
├── CLAUDE.md               # @AGENTS.md import (한 줄)
└── README.md               # Full documentation
```

- `AGENTS.md`: 이 문서. 세 런타임 공통 최상위 지침 + 플러그인 목록 + 구조 요약.
- `CLAUDE.md`: `@AGENTS.md` 를 import 하는 한 줄 파일. Claude Code 진입점일 뿐, 별도 내용이 없습니다.
- `README.md`: 사용자용 설치 및 플러그인 문서.
- `.claude/settings.json`: 로컬 플러그인 로드 설정.
- `.claude-plugin/marketplace.json`: marketplace 레지스트리와 플러그인 버전 목록.
- `.claude/rules/`: 특정 경로에 적용되는 상세 규칙 (Claude 전용 — Codex/Hermes 는 읽지 못함).
- `plugins/<name>/`: 각 플러그인의 원본 디렉터리.
- `plugins/<name>/.claude-plugin/plugin.json`: 플러그인별 매니페스트와 버전.
- `plugins/<name>/.codex-plugin/plugin.json`: Codex 0.135 용 매니페스트 (generated, do not edit by hand).
- `plugins/<name>/plugin.yaml` + `plugins/<name>/__init__.py`: Hermes Agent 어댑터 (HERMES_ELIGIBLE 플러그인만, generated, do not edit by hand).
- `.agents/plugins/marketplace.json`: Codex marketplace 카탈로그 (generated).
- `scripts/sync-codex-manifests.mjs`: Codex 매니페스트 생성기. `--check` 로 drift 가드, `--dry-run` 으로 출력 미리보기.
- `scripts/sync-hermes-manifests.mjs`: Hermes 어댑터 생성기. `--check` drift + orphan 가드, `--dry-run` 미리보기.

## 멀티런타임 통합 (Claude Code ↔ Codex ↔ Hermes Agent)

이 저장소는 Claude Code, Codex CLI, Hermes Agent 세 런타임으로 구동된다. 지침/hook/lore 를 한쪽 표면에만 두면 다른 도구체인에는 안 보인다. 동작에 영향을 주는 변경은 짝 표면을 같은 변경에서 점검한다. (Claude 쪽 SSOT: `.claude/rules/dual-integration.md` — Codex/Hermes 는 `.claude/rules/` 를 `@import` 못 하므로 이 블록이 미러다.)

| 관심사 | Claude Code 표면 | Codex 표면 | Hermes 표면 |
|---|---|---|---|
| 최상위 지침 | `CLAUDE.md` (`@AGENTS.md` import), `.claude/rules/*.md` (auto-load) | `AGENTS.md` (verbatim 로드 — `@import` 메커니즘 자체가 없음) | `AGENTS.md` (verbatim) |
| 프롬프트 주입 hook | 플러그인 `UserPromptSubmit` (`plugin.json` → `hooks/*.sh`) | `~/.codex/hooks.json` → 같은 스크립트, `codex` 포맷 인자 | (별도 hook surface — 현재 미사용) |
| skill | `plugins/*/skills` (native) | 같은 트리 in-place + generated `.codex-plugin/plugin.json` (아래 "Codex 통합") | 같은 트리 in-place + generated `plugin.yaml` + `__init__.py` (아래 "Hermes 통합") |
| command / subagent | `plugins/*/{commands,agents}` (native) | Codex 0.135 미지원 (Claude-only) | Hermes 미지원 (skill 만) |
| skill 본문 도구명 | Claude 도구명 (`Bash`, `Read`, ...) | Claude 와 동일 (본문 그대로 읽음) | 본문의 호환 표로 Hermes 도구명 매핑 (`Bash`→`terminal`, `AskUserQuestion`→`clarify`, ...) |
| 공유 중립 lore | `.llmwiki/` (세 에이전트 동일 루트, fork 금지) | `.llmwiki/` | `.llmwiki/` |

- 최상위 지침은 이 파일 한 곳에만 쓴다. `CLAUDE.md` 는 `@AGENTS.md` 한 줄 import 라 편집할 내용이 없다.
- Claude hook 을 추가/변경하면 Codex `~/.codex/hooks.json` 대응을 점검한다 (Codex hook 은 별도 `/hooks` trust 필요, 자동 등록 안 됨).
- skill / 버전 / description 을 바꾸면 Codex 매니페스트 재생성(`node scripts/sync-codex-manifests.mjs`) + (Hermes-eligible 이면) Hermes 어댑터 재생성(`node scripts/sync-hermes-manifests.mjs`)이 필요한지 점검한다 ("Codex 통합" / "Hermes 통합" 섹션 + `plugin-versioning.md`).
- skill 본문을 추가/변경할 때 Hermes 호환 표(Claude/Codex 도구 용어 → Hermes 도구)를 점검한다 — 3런타임 포터블.
- subagent 위임은 Claude 전용 가속일 뿐이다 — skill 단계의 인라인 크로스런타임 경로가 primary 로 남아야 하고, skill 로직을 agent 정의로 옮기지 않는다 (Codex 0.135 / Hermes 는 agents surface 가 없어 옮긴 로직이 조용히 사라진다).
- wiki lore 는 `.claude/rules/` 로 승격하지 않는다 — Codex/Hermes 가 못 읽는다. cross-agent insight 는 `.llmwiki/insight/` 로 graduate 후 공유 주입 hook 으로 노출한다.
- `.llmwiki/` 를 per-agent 로 fork 하지 않는다.
- **`AGENTS.md` 를 `CLAUDE.md` 로의 포인터로 축약하지 않는다.** Codex/Hermes 는 `@` 를 확장하지 않아 `@CLAUDE.md` 는 죽은 텍스트이고, "CLAUDE.md 를 먼저 읽어라" 식 산문 redirect 는 Codex GitHub cloud reviewer 에 닿지 않는다 (이 리뷰어는 `## Review guidelines` 섹션을 시스템 프롬프트에 직접 로드한다 — 임의 산문 redirect 는 따라가지 않고, `AGENTS.md` 가 명시적으로 참조하는 `code_review.md` 만 예외적으로 따라갈 수 있다[소프트 개런티, best-practices 문서]). 실패는 조용하다 — 에러 없이 지침만 사라진다. 이 저장소는 반대 방향을 택했다: `AGENTS.md` 가 SSOT 이고 `CLAUDE.md` 는 `@AGENTS.md` 한 줄을 import 한다 (`@import` 는 Claude 전용이라 `CLAUDE.md` 쪽에만 두면 되고, Codex/Hermes 는 `AGENTS.md` 를 직접 읽는다). 심볼릭 링크도 같은 효과를 내지만 Windows 체크아웃에서 `core.symlinks` 가 꺼져 있으면 `CLAUDE.md` 가 링크 대상 문자열 그대로 풀려 깨지므로, 포터블한 `@import` 를 택했다.

## 플러그인 변경 규칙

- 플러그인 버전을 올릴 때는 `plugins/<name>/.claude-plugin/plugin.json`과 `.claude-plugin/marketplace.json`의 해당 항목을 같은 변경에 포함하세요.
- `plugins/<name>/` 아래 **어떤 파일이든** 바뀌면 버전 범프 대상입니다 — 코드/스킬뿐 아니라 번들 `references/`·`docs`·asset 편집도 포함. 캐시로 게이트된 사용자는 버전 범프가 있어야 새 내용을 받으므로, 문서만 고쳐도 해당 플러그인 PATCH + `metadata.version`을 올립니다 (Codex-eligible 이면 매니페스트 재생성). 반면 루트 문서(`AGENTS.md`, `README.md`, `code_review.md`, `.claude/rules/*`)는 플러그인 콘텐츠가 아니라 어떤 플러그인도 범프하지 않습니다.
- Hermes-eligible 플러그인: `plugins/<name>/plugin.yaml`(Hermes 어댑터)의 `version`은 `sync-hermes-manifests.mjs` 가 marketplace 에서 파생해 생성하므로, 버전 범프 후 `node scripts/sync-hermes-manifests.mjs` 재실행으로 갱신하세요. `sync-hermes-manifests.mjs --check` 가 drift 를 가드하므로 수동 동기화는 불필요합니다 (단 Codex `--check` 는 Codex 매니페스트만 봅니다).
- 어떤 플러그인 버전이든 변경하면 `.claude-plugin/marketplace.json`의 `metadata.version`도 marketplace release 버전으로 올리세요.
- 플러그인을 추가하거나 제거하면 이 문서의 `## Plugins (N)` 수와 구조 트리, `README.md`의 플러그인 수와 목록도 갱신하세요. 이 문서의 미러 카운트(Hermes allowlist `현재 N개`, Codex 검증 주석 `# N entries`)도 같은 변경에서 함께 갱신하세요 — `--check` 가 못 잡습니다.
- 버전은 semver를 따릅니다. 버그 수정은 PATCH, 하위 호환 기능은 MINOR, 깨지는 변경은 MAJOR입니다.
- Claude Code 플러그인 캐시 이슈 때문에 사용자 문서나 릴리스 안내에는 필요 시 `rm -rf ~/.claude/plugins/cache/my-claude-plugins/` 후 marketplace update 및 Claude Code 재시작 절차를 유지하세요.

## Modular Rules

`.claude/rules/*.md` is auto-loaded by Claude Code — no `@import` required, and Codex/Hermes cannot read the directory at all (their mirror is the "멀티런타임 통합" section above). A rule carrying `paths:` frontmatter loads only when Claude touches a matching file; `@import`ing that same rule expands it unconditionally at launch and kills the scoping, so the first pointer below is deliberately plain (backticks, not `@`).

- `.claude/rules/plugin-versioning.md` — plugin version bump contract and cache-refresh workflow. Scoped via `paths:` to the manifest files, so it loads only when you touch them.
- See @.claude/rules/dual-integration.md for keeping the Claude Code, Codex, and Hermes surfaces in sync when editing guidance, hooks, or derived artifacts (unscoped, always loaded; its cross-runtime content is mirrored in the "멀티런타임 통합" section above, which is what Codex and Hermes actually read).

## Setup answers

`/project-init:wiring` records decisions the filesystem cannot infer — whether this project wants a git remote, whether its deliverables go to Drive — in `.claude/state/wiring.json` (gitignored; values are machine-local). Read that file before re-asking.

## Known limitation — cr-fix portability

`plugins/github-dev/skills/cr-fix/SKILL.md` 의 36여 path 가 marketplace-repo-relative (`plugins/github-dev/skills/cr-fix/scripts/...`) 로 하드코딩되어 있어, marketplace repo 가 cwd 일 때 (dogfood) 만 동작합니다. 일반 user repo / Codex 양쪽에서 깨집니다 — 이건 shared-source bridge 이전부터 있던 cr-fix 자체의 구조적 결함이고, 별도 follow-up 으로 portable 화 예정 (`${CLAUDE_PLUGIN_ROOT}` 또는 동등한 env-var 사용으로 일관화).

## Codex 통합 (shared-source)

```bash
node scripts/sync-codex-manifests.mjs           # write manifests
node scripts/sync-codex-manifests.mjs --check   # CI drift guard
```

- Claude 와 Codex 0.135 가 **동일한** `plugins/<name>/` 트리를 직접 읽습니다. 별도 mirror / body transform 없음 (구 `codex-bridge` 플러그인은 1.40.0 에서 제거). Skill 본문은 in-place 로 읽히므로 transform 이 없고, frontmatter 유효성만 남습니다.
- 생성물은 `.agents/plugins/marketplace.json` + 플러그인별 `.codex-plugin/plugin.json`, eligible 22개 대상. `.agents/` 와 `plugins/<name>/.codex-plugin/` 하위 파일은 손으로 편집하지 마세요 — `scripts/sync-codex-manifests.mjs` 가 진실의 원천입니다.
- 새 플러그인 추가 / 기존 플러그인의 `version` / `description` / `category` 변경 시 반드시 `node scripts/sync-codex-manifests.mjs` 를 실행해 매니페스트를 재생성하세요. `--check` 는 플러그인 제거 후 남은 orphan 매니페스트도 감지합니다.
- Skill `description` frontmatter 는 1024자 미만으로 유지하세요. Codex 0.135 는 1024자 초과 description 을 가진 skill 을 **silent 하게 skip** 합니다 (Claude Code 는 제한이 없어 위반이 안 보임). `--check` 가 drift 외에 description 길이도 검증하고, 공유 `.githooks/pre-commit` 이 매 커밋마다 실행합니다 — clone 당 한 번 `git config core.hooksPath .githooks` 로 활성화하세요. 전체 trigger 목록 / per-tool rationale 는 description 이 아니라 skill 본문에 두세요.
- Skill `description` frontmatter 에 콜론+공백(`: `) 이 들어가면 반드시 따옴표로 감싸세요 (또는 `>-` block scalar). 안 하면 YAML frontmatter 가 nested mapping 으로 파싱돼 `mapping values are not allowed here` 로 실패하고 skill 이 양쪽 런타임에서 silent 하게 로드 안 됩니다. `plugin.json` / `marketplace.json` 은 JSON 이라 무관; lenient 매니페스트 생성기와 `--check` 는 못 잡습니다.
- Codex 0.135 manifest top-level 은 `skills` / `hooks` / `mcpServers` / `apps` 만 지원합니다 (참조: `~/.codex/skills/.system/plugin-creator/references/plugin-json-spec.md`). `commands` / `agents` 는 생성기가 emit 하지 않습니다 — Claude 만 인식하는 필드입니다.
- Codex 에서 제외할 플러그인은 `scripts/sync-codex-manifests.mjs` 의 `EXCLUDED` 셋에 등록하세요 (현재: `core-config`, `codex-image`). `core-config` 는 Claude-only hooks 라 Codex 에 대응 surface 가 없고, `codex-image` 는 Claude->Codex 브리지라 Codex 로 sync 하면 순환입니다. 이후 marketplace 에서 제거된 플러그인은 EXCLUDED 에 남길 필요 없습니다 — drift 가드의 orphan 감지가 매니페스트 잔존을 잡아냅니다.
- 생성기는 Node 18+ built-in 만 사용합니다. 런타임 의존성을 추가하지 마세요.

## Hermes 통합 (shared-source)

```bash
node scripts/sync-hermes-manifests.mjs           # write adapters
node scripts/sync-hermes-manifests.mjs --check   # CI drift guard (validate-codex.yml + .githooks/pre-commit)
```

- Hermes Agent 도 **동일한** `plugins/<name>/` 트리를 직접 읽습니다. 어댑터(`plugin.yaml` + `__init__.py`)는 `scripts/sync-hermes-manifests.mjs` 가 `.claude-plugin/marketplace.json` 으로부터 생성합니다 — `plugins/<name>/plugin.yaml` / `__init__.py` 를 손으로 편집하지 마세요.
- 대상은 생성기의 `HERMES_ELIGIBLE` allowlist (Codex `EXCLUDED` denylist 의 대칭). 현재 7개: `github-dev`, `interview`, `anti-slop-design`, `tcrei-prompt`, `ppt-yeong-style`, `ml-toolkit`, `brightdata-guide`. 커버리지 확장은 allowlist 에 이름 추가.
- Hermes-eligible 플러그인의 `version` / `description` 을 바꾸면 `node scripts/sync-hermes-manifests.mjs` 를 실행해 어댑터를 재생성하세요. `plugin.yaml` 의 `version` 은 marketplace 파생이므로 `--check` 가 drift + orphan 어댑터를 잡습니다 (수동 동기화 불필요 — 생성으로 해소).
- `__init__.py` 는 `skills/*/SKILL.md` 를 `<plugin>:<skill>` 으로 등록하는 제네릭 엔트리포인트입니다 (플러그인별 로직 없음, `import yaml`=PyYAML 가정).
- 공유 skill 본문은 3런타임 포터블이어야 합니다. Claude/Codex 는 도구명이 동일하므로, 본문에 Claude/Codex 도구 용어를 Hermes 도구로 매핑하는 호환 표(`Bash`→`terminal`, `Read`→`read_file`, `Edit`→`patch`, `AskUserQuestion`→`clarify`, `Task`→`delegate_task`, `Skill`→`skill_view`, 이미지 생성→`image_generate`, `NotebookEdit`→Hermes Jupyter Live Kernel / `write_file`·`patch` 등)를 둡니다. 새 skill 추가/도구 사용 변경 시 이 표를 점검하세요.
- 번들 `scripts/` 를 호출하는 skill 본문은 `${CLAUDE_PLUGIN_ROOT}` 를 그대로 쓰지 마세요 — Codex 0.135 는 이 변수를 export 하지 않아 첫 단계에서 실패합니다. 크로스 런타임 `PLUGIN_ROOT` resolver 블록(`CLAUDE_PLUGIN_ROOT` → 소스트리 `plugins/<name>` → Codex 캐시 탐색)을 본문에 포함하세요 (레퍼런스 구현: project-init, mem0-ops).
- Hermes plugin 스킬은 opt-in 입니다 — `skill_view("<plugin>:<skill>")` 로 명시 로드, `--enable` 후 새 세션. 어댑터와 무관한 스킬 단위 설치는 `node scripts/install-skills.mjs` (`npx skills`) 로 가능합니다.
- 생성기는 Node 18+ built-in 만 사용합니다. 런타임 의존성을 추가하지 마세요.

## 검증

- Codex / Hermes 매니페스트 drift 가드 (모든 PR 에서 실행):

```bash
node scripts/sync-codex-manifests.mjs --check
node scripts/sync-hermes-manifests.mjs --check
```

- 로컬 Codex CLI 에서 marketplace 등록 확인:

```bash
codex plugin marketplace add ~/.claude/plugins/marketplaces/my-claude-plugins
codex plugin list --marketplace my-claude-plugins   # 22 entries
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
- **P0 (must-block)** — secret/token 노출, 사용자 확인 없는 destructive `gh` 명령 (`gh pr merge` / `gh repo create` / `gh api`), Codex 매니페스트 (`.agents/**`, `plugins/*/.codex-plugin/**`) 손편집, shell injection (사용자 입력 unquoted).
- **P1 (should-block)** — 모든 should-block 규칙은 하드 유지한다 (soft-follow 미검증이므로 code_review.md 로 demote 하지 않는다): plugin version/count drift (`plugin.json` ↔ `marketplace.json` ↔ AGENTS/README 트리·배지·`metadata.version`), idempotency 회귀 (재실행 시 사용자 파일 덮어쓰기·`nothing to commit` abort·`origin` 충돌), cross-platform shell 가정 (`sed -i` GNU-only / `${VAR,,}` Bash 4+), `gh api --paginate`+`--jq` 에 `--slurp` 누락, sed 치환 안전성 (`&`·구분자·`\` escape, 사용자 입력 정화), API 실패를 빈 결과로 삼키는 패턴 (`gh api ... || echo "[]"`), skill/command frontmatter `name`/`description` 누락·오류, `Read`/`Edit` 영역을 `Bash cat`/`sed` 로 우회, 새 dependency·GitHub Actions·CI/CD 권한 변경 (최소 권한·lockfile·supply-chain).
- **Do not flag** — 포매터 영역 (들여쓰기·따옴표·trailing whitespace), import 순서, 단순 typo, 루트 `CLAUDE.md` 가 `@AGENTS.md` 한 줄 포인터인 것 ("CLAUDE.md 가 없다/내용 없다" 지적은 오탐).
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
