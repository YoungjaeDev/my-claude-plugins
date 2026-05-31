---
name: ask
description: Use when the user asks an in-depth question about a GitHub repository's internals, architecture, or implementation details — anything that benefits from AI-summarized repo documentation rather than raw code reading. Triggers on phrases like "how does <repo> handle X", "explain the architecture of <repo>", "what's inside <owner/repo>", or "compare <repoA> and <repoB>". Wraps the DeepWiki MCP (`mcp__deepwiki__read_wiki_structure` / `read_wiki_contents` / `ask_question`).
---

# DeepWiki ask

Deep query a GitHub repository using DeepWiki's AI-powered documentation. Same workflow as the `/deepwiki:ask` slash command — this skill exposes it as a capability so the model can reach for it during conversational research.

1. Restate the repository (`owner/repo`) and the question back to the user so the parse is auditable.
2. Follow the four-phase procedure (structure → optional contents → ask → optional multi-query expansion).
3. Return the answer in the documented output format.

See `${CLAUDE_PLUGIN_ROOT}/references/ask-procedure.md` for the full workflow, smart-query strategy, multi-repo patterns, and error handling table.

## Requirements

- DeepWiki MCP must be configured in the host runtime (`mcp__deepwiki__*` tools available). If absent, surface the setup link: `https://mcp.deepwiki.com/`.
- Internet connection (queries the DeepWiki API).
