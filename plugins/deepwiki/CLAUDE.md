# DeepWiki Plugin

AI-powered deep queries on GitHub repositories.

## Commands

| Command | Description |
|---------|-------------|
| `/deepwiki:ask` | Query any GitHub repo with AI-powered documentation |
| `/deepwiki:generate-llmstxt` | Generate llms.txt from URL or local directory |

## Usage

```bash
# Basic query
/deepwiki:ask facebook/react "How does reconciliation work?"

# Architecture questions
/deepwiki:ask vercel/next.js explain the app router

# Compare repositories
/deepwiki:ask pytorch/pytorch,tensorflow/tensorflow "Compare eager vs graph execution"
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
