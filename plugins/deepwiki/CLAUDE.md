# DeepWiki Plugin

AI-powered deep queries on GitHub repositories.

## Skills

| Skill | Description |
|-------|-------------|
| `ask` | Query any GitHub repo with AI-powered documentation |
| `generate-llmstxt` | Generate llms.txt from a URL or local directory |

These are auto-triggering skills (not slash commands) — describe your intent in
natural language and Claude invokes them. They are also exported to Codex as
native `$ask` / `$generate-llmstxt`.

## Usage

```text
# Basic query — just describe intent, naming the repo
How does reconciliation work in facebook/react?

# Architecture questions
Explain the app router architecture in vercel/next.js

# Compare repositories
Compare eager vs graph execution in pytorch/pytorch and tensorflow/tensorflow
```

## How It Works

1. **Structure** - First understands what documentation exists
2. **Context** - Gathers relevant sections (for broad questions)
3. **Answer** - Provides AI-powered comprehensive response
4. **Expand** - Decomposes complex questions if needed

## MCP Tools Used

| Tool | Purpose |
|------|---------|
| `mcp__deepwiki__read_wiki_structure` | Get documentation topics |
| `mcp__deepwiki__read_wiki_contents` | Get full documentation |
| `mcp__deepwiki__ask_question` | AI-powered Q&A |

## Best Practices

- **Specific > Vague**: "How does X work?" beats "Tell me about X"
- **Check structure first**: See what docs exist before deep diving
- **Use for learning**: Great for understanding unfamiliar codebases
- **Compare repos**: Powerful for framework/library comparisons

## Requirements

- DeepWiki MCP server configured
- Internet connection (queries DeepWiki API)
