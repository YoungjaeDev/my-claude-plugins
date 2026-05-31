---
name: generate-llmstxt
description: Use when generating an llms.txt index file from a URL or local directory. Triggers on phrases like "generate llms.txt for <site>", "create an llms.txt from this docs site", or "build an llms.txt for the current repo". Follows the llms.txt standard (title, optional description, sections of `[title](URL): 10-15 word description`).
---

# Generate llms.txt

Generate a well-structured `llms.txt` from a URL (via firecrawl map + scrape) or a local directory (via Glob + Read). Same workflow as the `/deepwiki:generate-llmstxt` command.

1. Confirm the input source: URL or local path. If ambiguous, ask.
2. Follow the workflow in the procedure file for the matched input type.
3. Write `llms.txt` to the current directory and report sources processed, sections created, and any errors.

See `${CLAUDE_PLUGIN_ROOT}/references/generate-llmstxt-procedure.md` for the full workflow and guidelines.
