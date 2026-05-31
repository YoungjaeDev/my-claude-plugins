# Generate llms.txt — procedure

Shared procedure body for `/deepwiki:generate-llmstxt` (command) and the `generate-llmstxt` skill. Both resolve this file via `${CLAUDE_PLUGIN_ROOT}/references/generate-llmstxt-procedure.md`.

## Input shape

The caller passes either:
- **A URL**: produce llms.txt by mapping + scraping the site.
- **A local directory**: produce llms.txt by walking markdown/doc files.

For the command surface, `$ARGUMENTS` is the raw user text — extract a URL (starts with `http`) or a path. For the skill surface, ask the user explicitly when ambiguous.

## llms.txt format

```markdown
# Title

> Optional description

## Section name

- [Link title](URL): Brief description (10-15 words)
```

## Workflow

### URL input

1. **Map URLs**: use `mcp__firecrawl__firecrawl_map` to discover all URLs on the site.
2. **Scrape content**: use `mcp__firecrawl__firecrawl_scrape` for each URL (batch of 10–20).
3. **Synthesize**: extract key information and organize into sections.
4. **Generate**: write `llms.txt` to the current directory.

### Local directory input

1. **Discover files**: use Glob to find all markdown / docs files recursively.
2. **Read content**: read relevant files (README, `docs/`, guides).
3. **Synthesize**: extract purpose, key concepts, APIs.
4. **Generate**: write `llms.txt` to the current directory.

## Guidelines

- **Descriptions**: 10–15 words, specific to content (never generic).
- **Sections**: group by type (Documentation, API Reference, Examples, Tools).
- **URLs**: prefer official docs URLs over GitHub raw URLs.
- **Errors**: note failed URLs / files, continue with the rest.

## Output

Write `llms.txt` to the current directory with a summary:
- Number of sources processed.
- Number of sections created.
- Any errors or warnings.
