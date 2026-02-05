# Claude Code Settings

Plugin-based configuration for Claude Code with multi-agent orchestration.

## Plugins (15)

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
│   ├── notion/             # Notion
│   └── humanizer/          # AI text humanizer
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
| `.claude-plugin/marketplace.json` | UI display/metadata (recommended) |

Release workflow:
1. Update version in `plugin.json`
2. Sync version in `marketplace.json`
3. Commit and push

User-side update:
```bash
/plugin marketplace update my-claude-plugins
/plugin update <plugin-name>@my-claude-plugins
```
