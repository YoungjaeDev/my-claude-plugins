---
name: generate-llmstxt
description: Use when generating an llms.txt index file from a URL or local directory. Triggers on phrases like "generate llms.txt for <site>", "create an llms.txt from this docs site", or "build an llms.txt for the current repo". Follows the llms.txt standard — title, optional description, sections listing links followed by 10-15 word descriptions.
---

# Generate llms.txt

Generate an `llms.txt` (title, optional description, link sections with 10-15 word descriptions) from a URL, through sitemap discovery and a Bright Data scrape of at most about 50 URLs, or from a local directory through Glob + Read. Invoke it as `/scout:generate-llmstxt` or let the model reach for it on matching requests.

1. Confirm the input source: URL or local path.
2. Follow the workflow in the procedure file for the matched input type.
3. Write `llms.txt` to the current directory and report sources processed, sections created, and any errors.

When the input source is ambiguous, ask with `AskUserQuestion` on Claude Code or `request_user_input` on Codex; when neither is available, stop and report.

## Procedure file and requirements

- **Procedure**: `references/generate-llmstxt-procedure.md` in this plugin's installed root. Under Claude Code it resolves to `${CLAUDE_PLUGIN_ROOT}/references/generate-llmstxt-procedure.md`; under Codex the same path sits next to `skills/` in the plugin cache.
- **URL mode**: needs `mcp__brightdata__scrape_as_markdown` or the `bdata` CLI, and internet access. When neither is reachable, run the four-gate preflight in this plugin's `skills/research-orchestrator/references/brightdata-guide.md`, report the failing gate, and stop instead of degrading to a plain fetch.
- **Local directory mode**: read permission on the target directory; no MCP or network. Neither mode calls the DeepWiki MCP.
