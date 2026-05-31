---
name: generate-llmstxt
description: Use when generating an llms.txt index file from a URL or local directory. Triggers on phrases like "generate llms.txt for <site>", "create an llms.txt from this docs site", or "build an llms.txt for the current repo". Follows the llms.txt standard — title, optional description, sections listing links followed by 10-15 word descriptions.
---

# Generate llms.txt

Generate a well-structured `llms.txt` from a URL (via firecrawl map + scrape) or a local directory (via Glob + Read). Same workflow as the `/deepwiki:generate-llmstxt` command.

1. Confirm the input source: URL or local path. If ambiguous, ask.
2. Follow the workflow in the procedure file for the matched input type.
3. Write `llms.txt` to the current directory and report sources processed, sections created, and any errors.

See `references/generate-llmstxt-procedure.md` in this plugin's installed root for the full workflow and guidelines. Under Claude Code this resolves to `${CLAUDE_PLUGIN_ROOT}/references/generate-llmstxt-procedure.md`; under Codex the equivalent path lives next to `skills/` in the plugin cache.

## Requirements

This skill does NOT call the DeepWiki MCP — the procedure only uses firecrawl (URL mode) or Glob + Read (local mode). Pick the row for the input you pass:

- **URL mode**: firecrawl MCP must be available (`mcp__firecrawl__firecrawl_map`, `mcp__firecrawl__firecrawl_scrape`). Internet connection required (the scrape hits external sites).
- **Local directory mode**: read permission on the target directory. No MCP or network required.
