# DeepWiki Plugin

AI-powered deep queries on GitHub repositories. Ships **two surfaces** so both Claude Code and Codex can use it:

- **Commands** (`/deepwiki:ask`, `/deepwiki:generate-llmstxt`) — explicit user invocation.
- **Skills** (`ask`, `generate-llmstxt`) — capability discovery; the model reaches for them on matching conversational triggers.

Both surfaces resolve the same workflow body in `references/`, so there is no body duplication.

## Surfaces

| Command | Skill | Procedure file | Description |
|---------|-------|----------------|-------------|
| `/deepwiki:ask` | `ask` | `references/ask-procedure.md` | Query any GitHub repo with AI-powered documentation. |
| `/deepwiki:generate-llmstxt` | `generate-llmstxt` | `references/generate-llmstxt-procedure.md` | Generate llms.txt from a URL or local directory. |

## Usage

```bash
# Basic query
/deepwiki:ask facebook/react "How does reconciliation work?"

# Architecture questions
/deepwiki:ask vercel/next.js explain the app router

# Compare repositories
/deepwiki:ask pytorch/pytorch,tensorflow/tensorflow "Compare eager vs graph execution"

# llms.txt from a docs site
/deepwiki:generate-llmstxt https://docs.example.com
```

In conversational use (skill surface) the model can pick the right capability without the explicit slash — e.g. "what's the autograd internals of pytorch/pytorch?" triggers the `ask` skill.

## How it works

1. **Structure** — first understand what documentation exists.
2. **Context** — gather relevant sections (for broad questions).
3. **Answer** — provide an AI-powered comprehensive response.
4. **Expand** — decompose complex questions if needed.

## MCP Tools Used

| Tool | Purpose |
|------|---------|
| `mcp__deepwiki__read_wiki_structure` | Get documentation topics. |
| `mcp__deepwiki__read_wiki_contents` | Get full documentation. |
| `mcp__deepwiki__ask_question` | AI-powered Q&A. |
| `mcp__firecrawl__firecrawl_map` / `firecrawl_scrape` | URL-mode `generate-llmstxt`. |

## Best practices

- **Specific > Vague**: "How does X work?" beats "Tell me about X".
- **Check structure first**: see what docs exist before deep diving.
- **Use for learning**: great for understanding unfamiliar codebases.
- **Compare repos**: powerful for framework/library comparisons.

## Requirements

- DeepWiki MCP server configured in the host runtime. Setup: <https://mcp.deepwiki.com/>. If the MCP is missing, the skill will fail at the first `mcp__deepwiki__*` tool call — that is a host-side configuration step, not something this plugin auto-installs.
- For `generate-llmstxt` URL mode, the firecrawl MCP must be available as well.
- Internet connection (queries the DeepWiki API).
