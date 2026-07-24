# Generate llms.txt — procedure

Shared procedure body for `/deepwiki:generate-llmstxt` (command) and the `generate-llmstxt` skill. Both resolve this file via `references/generate-llmstxt-procedure.md` relative to the plugin's installed root (`${CLAUDE_PLUGIN_ROOT}/...` under Claude Code; the same relative path under the Codex plugin cache).

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

1. **Discover URLs (sitemap first)**: fetch `curl -sL --compressed <origin>/sitemap.xml`. On a 404 or a non-XML body, read `robots.txt` and follow its `Sitemap:` lines instead. Pipe a `.gz` sitemap through `zcat`. When the document is a `<sitemapindex>`, descend one level only — prefer children whose path reads documentary (`docs`, `guide`, `api`, `reference`) and cap at roughly 5 children. Extract the `<loc>` values, keep same-origin URLs only, strip fragments and query strings, and dedupe. If `curl` is turned away by a WAF, retry the same sitemap URL through `mcp__brightdata__scrape_as_markdown`. If the site publishes no sitemap at all, scrape the homepage with `scrape_as_markdown` and collect its same-origin markdown links instead — one level of breadth-first expansion under the same caps. That path also covers JS-only sites, since Bright Data renders the page before returning it.
2. **Cap the set**: at most ~50 URLs total, which is five batches. Prefer shallow paths and `docs` / `guide` / `api` / `reference` sections. Past the cap, sample across sections rather than truncating one section wholesale, and say in the final summary that the set was truncated.
3. **Scrape content**: `mcp__brightdata__scrape_batch` in groups of 10 — that is the tool's schema-enforced `maxItems`, not a style preference — retrying stragglers one at a time with `mcp__brightdata__scrape_as_markdown`. When the Bright Data MCP tools are absent, loop the terminal CLI instead: `bdata scrape <url> -f markdown` per URL, following the `brightdata-guide` conventions. If `bdata` is missing too, run that guide's four-gate preflight, report the gate that failed, and stop — do not fall back to a plain fetch, which the bot-protected docs sites this mode targets will block.
4. **Synthesize**: extract key information and organize into sections.
5. **Generate**: write `llms.txt` to the current directory.

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
