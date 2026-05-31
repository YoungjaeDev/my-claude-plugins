---
description: Generate llms.txt from URL or local directory
---

# /deepwiki:generate-llmstxt

Generate a well-structured `llms.txt` following the llms.txt standard.

## Argument parsing

`$ARGUMENTS` may be either:
- A URL (starts with `http`) — produces llms.txt via firecrawl map + scrape.
- A local path — produces llms.txt by walking markdown/docs files with Glob + Read.

If `$ARGUMENTS` is empty or ambiguous, prompt the user for the input source.

## Procedure

Follow the shared procedure in `${CLAUDE_PLUGIN_ROOT}/references/generate-llmstxt-procedure.md` — workflows for both input types, output format, and guidelines. The `generate-llmstxt` skill uses the same file.
