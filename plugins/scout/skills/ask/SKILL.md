---
name: ask
description: Use when the user asks an in-depth question about a GitHub repository's internals, architecture, or implementation details — anything that benefits from AI-summarized repo documentation rather than raw code reading. Triggers on phrases like "how does <repo> handle X", "explain the architecture of <repo>", "what's inside <owner/repo>", or "compare <repoA> and <repoB>". Wraps the DeepWiki MCP (`mcp__deepwiki__read_wiki_structure` / `read_wiki_contents` / `ask_wiki_question`).
---

# DeepWiki ask

Deep query a GitHub repository through DeepWiki's AI-generated documentation, in up to 4 phases. Invoke it as `/scout:ask` or let the model reach for it during conversational research.

1. Restate the repository (`owner/repo`) and the question back to the user so the parse is auditable.
2. Follow the four-phase procedure (structure → optional contents → ask → optional multi-query expansion).
3. Return the answer in the documented output format.

When the repository or the question cannot be parsed, ask with `AskUserQuestion` on Claude Code or `request_user_input` on Codex; when neither is available, stop and report.

## Procedure file and requirements

- **Procedure**: `references/ask-procedure.md` in this plugin's installed root holds the workflow, the smart-query strategy, multi-repo queries, the output format and the error table. It is a plugin-root file shared with `generate-llmstxt`, so a skill-level install carries it only when the whole plugin is installed.
- **Resolving it**: under Claude Code the path is `${CLAUDE_PLUGIN_ROOT}/references/ask-procedure.md`. Codex does not export `CLAUDE_PLUGIN_ROOT`; its plugin cache has the same `references/` directory next to `skills/` (`~/.codex/plugins/cache/<marketplace>/scout/<version>/references/`).
- **DeepWiki MCP**: the host runtime must have the `mcp__deepwiki__*` tools, and the DeepWiki API needs internet access. When the tools are absent, surface the setup link `https://mcp.deepwiki.com/`.
