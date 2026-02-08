# Claude Code Settings

Plugin-based configuration for Claude Code with multi-agent orchestration.

## Plugins (17)

### Core
| Plugin | Description |
|--------|-------------|
| `core-config` | Guidelines auto-injection, Python formatting, notifications |
| `omc` | oh-my-claudecode wrapper (marketplace) |

### GitHub & Code Review
| Plugin | Description |
|--------|-------------|
| `github-dev` | GitHub workflow (commit, PR, issue, code review) |
| `interactive-review` | Web UI code review with MCP server |

### Research & Search
| Plugin | Description |
|--------|-------------|
| `code-scout` | Boilerplate/ML resource discovery (GitHub, HuggingFace, 10+ platforms) |
| `deepwiki` | AI-powered GitHub repo documentation |
| `paper-search-tools` | Academic paper search (arXiv, PubMed, Semantic Scholar, etc.) |

### AI Models
| Plugin | Description |
|--------|-------------|
| `council` | Multi-model deliberation (Claude, Codex, Gemini) |
| `midjourney` | Midjourney V7 image generation |

### Development Tools
| Plugin | Description |
|--------|-------------|
| `notebook` | Safe Jupyter notebook editing |
| `ml-toolkit` | GPU parallel processing, Gradio CV apps |

### Content & Translation
| Plugin | Description |
|--------|-------------|
| `translator` | Web article translation to Korean |
| `notion` | Markdown to Notion upload |
| `humanizer` | Remove AI writing patterns from text |

### Planning
| Plugin | Description |
|--------|-------------|
| `interview` | Structured requirements gathering |
| `prd-suite` | PRD, Tech Spec, Use Case, IA document generation |

### Documentation
| Plugin | Description |
|--------|-------------|
| `docs-forge` | README/CHANGELOG generation with CRO best practices |

## Structure

```
.
├── .claude/
│   └── settings.json       # Plugin configuration
├── plugins/
│   ├── core-config/        # Guidelines + hooks
│   ├── github-dev/         # GitHub workflow
│   ├── interactive-review/ # Web UI review
│   ├── omc/                # oh-my-claudecode
│   ├── code-scout/         # Resource discovery
│   ├── council/            # LLM Council
│   ├── deepwiki/           # Repo docs
│   ├── paper-search-tools/ # Academic papers
│   ├── notebook/           # Jupyter
│   ├── ml-toolkit/         # ML tools
│   ├── translator/         # Translation
│   ├── midjourney/         # Image gen
│   ├── interview/          # Requirements
│   ├── prd-suite/          # PRD & spec docs
│   ├── notion/             # Notion
│   ├── humanizer/          # AI text humanizer
│   └── docs-forge/         # README/CHANGELOG
├── CLAUDE.md               # This file
└── README.md               # Full documentation
```

## Usage

Plugins auto-load from `settings.json`. See README.md for detailed usage of each plugin.

## Plugin Versioning

When updating plugin versions, synchronize these two files:

| File | Purpose |
|------|---------|
| `plugins/<name>/.claude-plugin/plugin.json` | Cache refresh trigger (required) |
| `.claude-plugin/marketplace.json` | UI display/metadata (required) |

### Developer Workflow

1. Update version in `plugin.json`
2. Sync version in `marketplace.json`
3. Bump marketplace version in `marketplace.json` metadata
4. Commit and push

### User Update (Cache Bug Workaround)

Due to plugin cache bugs ([#17361](https://github.com/anthropics/claude-code/issues/17361), [#19197](https://github.com/anthropics/claude-code/issues/19197)), manual cache clearing is required:

```bash
# 1. Delete cache (required)
rm -rf ~/.claude/plugins/cache/my-claude-plugins/

# 2. Update marketplace and restart Claude Code
/plugin marketplace update my-claude-plugins
```

> **Warning**: `/plugin update` and auto-update do NOT refresh plugin files. Cache deletion is the only reliable method.
