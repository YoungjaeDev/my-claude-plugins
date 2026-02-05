---
name: setup
description: Use when user encounters "paper-search MCP error", "Docker not found", "Docker not running", "paper search not working", "Semantic Scholar rate limit", or needs help configuring paper search integration.
---

# Paper Search Tools Setup

Run `/paper-search-tools:setup` to configure Paper Search MCP.

## Quick Fixes

- **Docker not found** - Install Docker (see setup command)
- **Docker not running** - Start Docker Desktop
- **Connection failed** - Restart Claude Code after Docker starts
- **Semantic Scholar rate limited** - Set `SEMANTIC_SCHOLAR_API_KEY` environment variable

## API Key (Optional)

For enhanced Semantic Scholar functionality:
- Get free API key: https://www.semanticscholar.org/product/api
- Set: `export SEMANTIC_SCHOLAR_API_KEY="your-key"`

## Don't Need Paper Search?

Disable via `/mcp` command to prevent errors.
