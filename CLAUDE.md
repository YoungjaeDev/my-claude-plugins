# Claude Code Settings

Plugin-based configuration for Claude Code with multi-agent orchestration.

## Plugins (14)

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

플러그인 버전 업데이트 시 두 파일을 동기화해야 함:

| 파일 | 역할 |
|------|------|
| `plugins/<name>/.claude-plugin/plugin.json` | 실제 캐시 갱신 기준 (필수) |
| `.claude-plugin/marketplace.json` | UI 표시/메타데이터 (권장) |

릴리스 워크플로우:
1. `plugin.json` 버전 업데이트
2. `marketplace.json` 버전 동기화
3. 커밋 및 푸시

사용자 측 업데이트:
```bash
/plugin marketplace update my-claude-plugins
/plugin update <plugin-name>@my-claude-plugins
```
