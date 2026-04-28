# Claude Code Settings

Plugin-based configuration for Claude Code with multi-agent orchestration.

## Plugins (22)

### Core
| Plugin | Description |
|--------|-------------|
| `core-config` | Guidelines auto-injection, Python formatting, notifications |
| `omc` | oh-my-claudecode wrapper (marketplace) |

### GitHub & Code Review
| Plugin | Description |
|--------|-------------|
| `github-dev` | GitHub workflow (commit, PR, issue, unified cr-fix CodeRabbit pipeline) |
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
| `ml-toolkit` | GPU parallel processing, Gradio CV apps, CV notebooks, dataset exploration |

### Content & Translation
| Plugin | Description |
|--------|-------------|
| `translator` | Web article translation to Korean |
| `notion` | Markdown to Notion upload |
| `humanizer` | Remove AI writing patterns from text |
| `tcrei-prompt` | Rewrite prompts using Google's TCREI structure for next-session reuse |

### Planning
| Plugin | Description |
|--------|-------------|
| `interview` | Structured requirements gathering |
| `prd-suite` | PRD, Tech Spec, Use Case, IA document generation |

### Presentation
| Plugin | Description |
|--------|-------------|
| `slidev` | Slidev markdown presentation generator with interview workflow |

### Documentation
| Plugin | Description |
|--------|-------------|
| `docs-forge` | README/CHANGELOG generation with CRO best practices |
| `rules-forge` | CLAUDE.md generation and .claude/rules/ modular structure |

### Visualization
| Plugin | Description |
|--------|-------------|
| `workflow-viz` | System workflow Mermaid diagrams and ASCII progress tracking |

### Integration
| Plugin | Description |
|--------|-------------|
| `codex-bridge` | Sync OMC plugin skills to Codex `~/.agents/skills/` with body-only transform |

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
│   ├── docs-forge/         # README/CHANGELOG
│   ├── rules-forge/        # CLAUDE.md rules
│   ├── slidev/             # Presentation generator
│   ├── workflow-viz/       # Workflow visualization
│   ├── tcrei-prompt/       # TCREI prompt structuring
│   └── codex-bridge/       # OMC → Codex skill sync
├── CLAUDE.md               # This file
└── README.md               # Full documentation
```

## Usage

Plugins auto-load from `settings.json`. See README.md for detailed usage of each plugin.

## Modular Rules

- See @.claude/rules/plugin-versioning.md for plugin version bump contract and cache-refresh workflow.
- See @.claude/rules/codex-bridge-sync.md for codex-bridge sync invariants (SSOT, body-only transform, `bridge_source` marker, collision guard).
