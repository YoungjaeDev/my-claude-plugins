# Claude Code Settings

Plugin-based configuration for Claude Code with multi-agent orchestration. The same plugin tree is loaded by Codex 0.135 via `scripts/sync-codex-manifests.mjs` and by Hermes Agent via `scripts/sync-hermes-manifests.mjs` — one source, three runtimes.

## Plugins (23)

### Core
| Plugin | Description |
|--------|-------------|
| `core-config` | Python auto-format + cross-platform notifications + per-prompt behavioral block (`prompt_inject.sh`, shared Claude + Codex; points at `.llmwiki/insight/`) (work guidelines live in `~/.claude/CLAUDE.md`) |

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
| `project-init` | First-day project bootstrap (.claude/ + CLAUDE.md + AGENTS.md w/ Codex review guidelines + README/CHANGELOG + gh repo create) |

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
| `ppt-yeong-style` | yeong 스타일 강의·제안 덱 작성 규약 — `ppt-master` 엔진 위에 얹는 작성 레이어. 덱 유형·md 소스 규약·작성 원칙 15종·밀도 리듬(중간 강화)·역할 기반 색·codex vs SVG 경계·앱 UI 실물 강제·ppt-master 레버 조합 차별화·빌드 후 스토리 review·공식 로고 fetch·윤문·렌더 QA. 진입점 SKILL.md + references/ 6종 + assets/injection-prompt.md |

### Productivity
| Plugin | Description |
|--------|-------------|
| `gws-sync` | 로컬 → Google Drive 단방향 제안형 동기화 (gws CLI 기반). 매핑 설정(`.gws-sync.json`) → Drive 트리 탐색 → 신규·변경 diff 리포트 → 업로드 위치 AskUserQuestion 승인 → 업로드(기존 파일 content update로 ID·공유링크 보존). 삭제는 제안만. gws 미설치 시 설치 안내 후 중단. googleworkspace/cli 스킬 95종 카탈로그 동봉 |

### Memory & Lore
| Plugin | Description |
|--------|-------------|
| `llm-wiki` | Karpathy LLM-Wiki 3-layer (insight + wiki + raw under neutral `.llmwiki/`): 5 skills + 5 hooks (incl. Stop-capture + SessionStart-drain auto-ingest) + bootstrap templates. Post-merge wiki ingest is a mandatory step inside `github-dev:post-merge` (post-merge-wiki absorbed). Promoted cross-agent rules graduate to `.llmwiki/insight/` (surfaced via core-config prompt-inject hook), not `.claude/rules/` |

### Workflow State
| Plugin | Description |
|--------|-------------|
| `spec-state` | Spec / issue / PR work-pipeline aggregate (`state-tracker` skill, `.claude/state/spec.json`) |

## Structure

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
│   ├── spec-state/         # spec/issue/PR work-pipeline aggregate
│   ├── anti-slop-design/   # Anti-AI-slop design guard (web/ppt/dashboard/copy)
│   ├── ppt-yeong-style/    # yeong-style lecture/proposal deck writing layer (on ppt-master)
│   ├── tally-form/         # Checklist md -> Tally questionnaire/survey form builder
│   └── project-init/       # Day-1 project bootstrap (interview + .claude/ + AGENTS.md + gh repo)
├── CLAUDE.md               # This file
└── README.md               # Full documentation
```

## Usage

Plugins auto-load from `settings.json`. See README.md for detailed usage of each plugin.

## Codex integration

Codex 0.135 reads the same `plugins/<name>/` tree. Manifests are generated:

```bash
node scripts/sync-codex-manifests.mjs           # write manifests
node scripts/sync-codex-manifests.mjs --check   # CI drift guard
```

Produces `.agents/plugins/marketplace.json` + per-plugin `.codex-plugin/plugin.json` for 21 eligible plugins. Codex 0.135 manifest top-level only supports `skills` / `hooks` / `mcpServers` / `apps` — `commands` and `agents` are not emitted. Excluded: `core-config` (Claude-only hooks; no Codex hook surface for the same patterns), `codex-image` (Claude->Codex bridge; syncing it into Codex would be circular). Skill bodies are read in place — no mirror, no transform. `--check` also detects orphan manifests left behind when a plugin is removed.

## Hermes integration

Hermes Agent reads the same `plugins/<name>/` tree via generated native adapters (`plugin.yaml` + `__init__.py`):

```bash
node scripts/sync-hermes-manifests.mjs           # write adapters
node scripts/sync-hermes-manifests.mjs --check   # CI drift guard (also in validate-codex.yml + .githooks/pre-commit)
```

Adapter fields derive from `marketplace.json` (`plugin.yaml` name/version/description; `__init__.py` a generic skill-registration entrypoint, no per-plugin logic). Coverage is an allowlist — `HERMES_ELIGIBLE` (7 plugins this round: `github-dev`, `interview`, `anti-slop-design`, `tcrei-prompt`, `ppt-yeong-style`, `ml-toolkit`, `brightdata-guide`); add a name to extend. `--check` flags adapter drift + orphan adapters. Shared skill bodies carry a Hermes tool-compatibility table (Claude/Codex tool terms → Hermes tools). Skill-level install (no adapter needed) is also available via `node scripts/install-skills.mjs` (wraps `npx skills`).

## Modular Rules

- See @.claude/rules/plugin-versioning.md for plugin version bump contract and cache-refresh workflow.
- See @.claude/rules/dual-integration.md for keeping the Claude Code, Codex, and Hermes surfaces in sync when editing guidance, hooks, or derived artifacts (mirrored into `AGENTS.md` since Codex/Hermes cannot `@import` `.claude/rules/`).
