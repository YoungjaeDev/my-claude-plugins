# Claude Code Settings

Plugin-based configuration for Claude Code with multi-agent orchestration.

## Installation

### Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/claude-code) installed
- `gh` CLI for GitHub plugins
- `uv` for Python-based MCP servers

### Quick Start (Local)

```bash
git clone git@github.com:YoungjaeDev/my-claude-plugins.git
cd my-claude-plugins
claude  # Plugins auto-load from .claude/settings.json
```

### Install from Marketplace

Add marketplace and install plugins in Claude Code:

```bash
# 1. Add marketplace
/plugin marketplace add YoungjaeDev/my-claude-plugins

# 2. Install individual plugins
/plugin install core-config@my-claude-plugins
/plugin install github-dev@my-claude-plugins
/plugin install code-scout@my-claude-plugins
```

### Install Scope Options

```bash
# User scope (all projects) - default
/plugin install core-config@my-claude-plugins

# Project scope (team shared, git tracked)
/plugin install core-config@my-claude-plugins --scope project

# Local scope (personal, not tracked)
/plugin install core-config@my-claude-plugins --scope local
```

## Plugins

12 plugins organized by functionality.

> **oh-my-claudecode**: For multi-agent orchestration, install separately:
> ```bash
> /plugin marketplace add Yeachan-Heo/oh-my-claudecode
> /plugin install oh-my-claudecode@omc
> ```

### Core

<details>
<summary><strong>core-config</strong> - Development Essentials</summary>

Auto-injected guidelines and workflow hooks.

**Hooks:**
| Hook | Trigger | Description |
|------|---------|-------------|
| `inject-guidelines.sh` | UserPromptSubmit | Auto-inject work guidelines |
| `auto-format-python.py` | Post Write/Edit | Python formatting with ruff |
| `notify_osc.sh` | Stop/Notification | Terminal notifications |

**Guidelines:**
| File | Purpose |
|------|---------|
| `work-guidelines.md` | Core workflow (auto-injected) |
| `ml-guidelines.md` | ML/CV best practices |
| `id-reference.md` | GitHub/TaskMaster ID formats |
| `prd-guide.md` | PRD template |

**Requirements:** `uv`, `ruff`

</details>


### GitHub & Code Review

<details>
<summary><strong>github-dev</strong> - GitHub Workflow Automation</summary>

**Commands:**
| Command | Description |
|---------|-------------|
| `/github-dev:commit-and-push` | Analyze, commit, push |
| `/github-dev:code-review` | Process CodeRabbit feedback |
| `/github-dev:create-issue-label` | Create standardized labels |
| `/github-dev:decompose-issue` | Break down issues |
| `/github-dev:parallel-resolve` | Resolve multiple issues in parallel |
| `/github-dev:post-merge` | Post-merge cleanup |
| `/github-dev:resolve-issue` | End-to-end issue resolution (worktree, review, verification) |

**Flags (resolve-issue):** `--worktree`, `--skip-review`, `--strict`

**Requirements:** `gh` CLI installed and authenticated

</details>

<details>
<summary><strong>interactive-review</strong> - Web UI Code Review</summary>

Browser-based interactive code review with MCP server.

**Features:**
- Checkbox approval workflow
- Real-time review interface
- PEP 723 dependencies

**Requirements:** `uv` installed

</details>

### Research & Search

<details>
<summary><strong>code-scout</strong> - Code & ML Resource Discovery</summary>

Find boilerplates, templates, and ML resources.

**Agents:**
| Agent | Model | Platforms |
|-------|-------|-----------|
| `scout` | haiku | GitHub, HuggingFace |
| `deep-scout` | sonnet | 10+ platforms (Reddit, SO, arXiv, etc.) |

**Skill:** `resource-finder` - GitHub + HuggingFace search

**Usage:**
```
Task(subagent_type="code-scout:scout", model="haiku", prompt="Find FastAPI boilerplate")
Task(subagent_type="code-scout:deep-scout", model="sonnet", prompt="Research PyTorch deployment")
```

</details>

<details>
<summary><strong>deepwiki</strong> - AI-Powered Repo Documentation</summary>

Query GitHub repositories with DeepWiki MCP.

**Commands:**
| Command | Description |
|---------|-------------|
| `/deepwiki:ask` | Query any repo with AI |
| `/deepwiki:generate-llmstxt` | Generate llms.txt |

**Usage:**
```bash
/deepwiki:ask facebook/react "How does reconciliation work?"
```

</details>

### AI Models

<details>
<summary><strong>council</strong> - LLM Council (Multi-Model Deliberation)</summary>

Query multiple AI models and synthesize collective wisdom.

**Commands:**
| Command | Description |
|---------|-------------|
| `/council` | Multi-model deliberation |
| `/council --quick` | Quick mode (single round) |
| `/council:ask-codex` | Query Codex directly |
| `/council:ask-gemini` | Query Gemini directly |
| `/council-setup` | Install Codex/Gemini CLI |

**Models:** Claude Opus, Claude Sonnet, Codex (optional), Gemini (optional)

</details>

<details>
<summary><strong>midjourney</strong> - Image Generation</summary>

Midjourney V7 prompt optimization and generation.

**Skill:** `midjourney-imagineapi`

**Features:**
- 5-layer prompt structure
- Style/mood clarification
- Multiple prompt variations

**Requirements:** midjourney MCP configured

</details>

### Development Tools

<details>
<summary><strong>notebook</strong> - Jupyter Notebook Editing</summary>

Safe .ipynb file manipulation.

**Skill:** `edit-notebook`

**Rules:**
- NotebookEdit tool only
- Preserve outputs
- Verify cell order

</details>

<details>
<summary><strong>ml-toolkit</strong> - ML/AI Development</summary>

**Skills:**
| Skill | Description |
|-------|-------------|
| `gpu-parallel-pipeline` | PyTorch multi-GPU processing |
| `gradio-cv-app` | Computer vision Gradio apps |

</details>

### Content & Translation

<details>
<summary><strong>translator</strong> - Web Article Translation</summary>

Translate web pages to Korean markdown.

**Skill:** `translate-web-article`

**Features:**
- firecrawl MCP for fetching
- VLM image analysis
- Preserve code/tables

</details>

<details>
<summary><strong>notion</strong> - Notion Integration</summary>

Upload Markdown to Notion with formatting.

**Skill:** `notion-md-uploader`

**Features:**
- Full Markdown support
- Auto image uploads
- Dry run preview

**Requirements:** Notion API key

</details>

### Planning & Methodology

<details>
<summary><strong>interview</strong> - Requirements Gathering</summary>

Structured interview for spec-based development.

**Skill:** `interview-methodology`

**Phases:**
1. Context Gathering
2. Deep Dive
3. Edge Case Exploration
4. Prioritization
5. Validation

**Output:** `.claude/spec/{date}-{feature}.md`

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
      "./plugins/council",
      "./plugins/deepwiki",
      "./plugins/notebook",
      "./plugins/ml-toolkit",
      "./plugins/translator",
      "./plugins/midjourney",
      "./plugins/interview",
      "./plugins/notion"
    ]
  }
}
```

## Structure

```
.
├── .claude/
│   └── settings.json          # Plugin configuration
├── plugins/
│   ├── core-config/           # Guidelines + hooks
│   ├── github-dev/            # GitHub workflow
│   ├── interactive-review/    # Web UI review
│   ├── code-scout/            # Resource discovery
│   ├── council/               # LLM Council
│   ├── deepwiki/              # Repo documentation
│   ├── notebook/              # Jupyter editing
│   ├── ml-toolkit/            # ML development
│   ├── translator/            # Web translation
│   ├── midjourney/            # Image generation
│   ├── interview/             # Requirements gathering
│   └── notion/                # Notion integration
├── CLAUDE.md                  # Project instructions
└── README.md                  # This file
```

## References

- [Claude Code Documentation](https://docs.anthropic.com/claude-code)
- [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode)
- [Claude Code Plugin System](https://docs.anthropic.com/claude-code/plugins)

## License

MIT
