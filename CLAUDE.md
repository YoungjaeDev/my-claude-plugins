# Claude Code Settings

Plugin-based configuration for Claude Code with multi-agent orchestration. The same plugin tree is loaded by Codex 0.135 via `scripts/sync-codex-manifests.mjs` — one source, two runtimes.

## Plugins (23)

### Core
| Plugin | Description |
|--------|-------------|
| `core-config` | Python auto-format + cross-platform notifications + per-prompt behavioral block (`prompt_inject.sh`, shared Claude + Codex; points at `.llmwiki/insight/`) (work guidelines live in `~/.claude/CLAUDE.md`) |

### GitHub
| Plugin | Description |
|--------|-------------|
| `github-dev` | GitHub workflow (commit, PR, issue, unified cr-fix CodeRabbit + Codex skill with PR-bot → CLI → codex-only auto-fallback on rate-limit) |

### Research & Search
| Plugin | Description |
|--------|-------------|
| `code-scout` | Multi-axis research harness — 5-axis scout team (github/hf/web/docs/paper) + synthesis-scout + research-orchestrator skill. exa MCP + WebSearch + firecrawl tier-3 + insane-search tier-4 for WAF/blocked URLs. paper-scout wraps paper-search-tools 8-source family. /deep-research is the sibling for non-code/ML topics. |
| `deepwiki` | AI-powered GitHub repo documentation |
| `paper-search-tools` | Academic paper search (arXiv, PubMed, Semantic Scholar, etc.) |

### AI Models
| Plugin | Description |
|--------|-------------|
| `council` | Multi-model deliberation (Claude, Codex, Gemini) |
| `midjourney` | Midjourney V7 image generation |
| `codex-image` | Claude->Codex image generation bridge (delegates to Codex CLI image gen via ChatGPT OAuth, no OpenAI API key). Claude-only — excluded from Codex sync |

### Development Tools
| Plugin | Description |
|--------|-------------|
| `notebook` | Safe Jupyter notebook editing |
| `ml-toolkit` | GPU parallel processing, Gradio CV apps, CV notebooks, dataset exploration |

### Content & Translation
| Plugin | Description |
|--------|-------------|
| `translator` | Web article translation to Korean |
| `notion` | Markdown to Notion upload |
| `tcrei-prompt` | Rewrite prompts using Google's TCREI structure for next-session reuse |
| `tally-form` | Checklist markdown to Tally questionnaire/survey form — deterministic urllib builder, theme presets, section dividers, native scheduling (matrix/date/time), idempotent publish, humanize routing. Dev-survey + lecture-consultation presets |

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

### Visualization
| Plugin | Description |
|--------|-------------|
| `workflow-viz` | System workflow Mermaid diagrams and ASCII progress tracking |

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
│   ├── code-scout/         # Resource discovery
│   ├── council/            # LLM Council
│   ├── deepwiki/           # Repo docs
│   ├── paper-search-tools/ # Academic papers
│   ├── notebook/           # Jupyter
│   ├── ml-toolkit/         # ML tools
│   ├── translator/         # Translation
│   ├── midjourney/         # Image gen
│   ├── codex-image/        # Claude->Codex image gen bridge
│   ├── interview/          # Requirements
│   ├── notion/             # Notion
│   ├── docs-forge/         # README/CHANGELOG + deploy-doc + MOC
│   ├── rules-forge/        # write-rules skill (auto mode detection)
│   ├── slidev/             # Presentation generator
│   ├── workflow-viz/       # Workflow visualization
│   ├── tcrei-prompt/       # TCREI prompt structuring
│   ├── llm-wiki/           # LLM-Wiki 3-layer (wiki lore)
│   ├── spec-state/         # spec/issue/PR work-pipeline aggregate
│   ├── anti-slop-design/   # Anti-AI-slop design guard (web/ppt/dashboard/copy)
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

Produces `.agents/plugins/marketplace.json` + per-plugin `.codex-plugin/plugin.json` for 19 eligible plugins. Codex 0.135 manifest top-level only supports `skills` / `hooks` / `mcpServers` / `apps` — `commands` and `agents` are not emitted. Excluded: `core-config` (Claude-only hooks; no Codex hook surface for the same patterns), `midjourney` (image-gen execution model differs), `codex-image` (Claude->Codex bridge; syncing it into Codex would be circular). Skill bodies are read in place — no mirror, no transform. `--check` also detects orphan manifests left behind when a plugin is removed.

## Modular Rules

- See @.claude/rules/plugin-versioning.md for plugin version bump contract and cache-refresh workflow.
- See @.claude/rules/dual-integration.md for keeping the Claude Code and Codex surfaces in sync when editing guidance, hooks, or derived artifacts (mirrored into `AGENTS.md` since Codex cannot `@import` `.claude/rules/`).
