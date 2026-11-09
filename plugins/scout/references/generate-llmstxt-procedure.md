# Generate llms.txt — procedure

The workflow behind the `generate-llmstxt` skill (`/scout:generate-llmstxt`): discover up to about 50 sources from a URL or a local directory, then write one `llms.txt`. The skill resolves this file at `references/generate-llmstxt-procedure.md` under the plugin's installed root.

## Input shape

The caller passes either:
- **A URL** (starts with `http`): produce llms.txt by mapping + scraping the site.
- **A local directory**: produce llms.txt by walking markdown/doc files.

## llms.txt format

```markdown
# Title

> Optional description

## Section name

- [Link title](URL): Brief description (10-15 words)
```

## Workflow

### URL input

1. **Discover URLs (sitemap first)**: fetch `curl -sL --compressed <origin>/sitemap.xml`. On a 404 or a non-XML body, read `robots.txt` and follow its `Sitemap:` lines instead, and pipe a `.gz` sitemap through `zcat`. Extract the `<loc>` values, keep same-origin URLs only, strip fragments and query strings, and dedupe.
   - **Sitemap index**: when the document is a `<sitemapindex>`, descend one level only, preferring children whose path reads documentary (`docs`, `guide`, `api`, `reference`), capped at roughly 5 children.
   - **WAF on `curl`**: retry the same sitemap URL through `mcp__brightdata__scrape_as_markdown`, or in a CLI-only session `bdata scrape <sitemap-url> -f markdown` (the same terminal fallback step 3 uses).
   - **No sitemap**: scrape the homepage the same way and collect its same-origin markdown links instead, one level of breadth-first expansion under the same caps. This also covers JS-only sites, since Bright Data renders the page before returning it.
2. **Cap the set**: at most ~50 URLs total, which is ten batches. Prefer shallow paths and `docs` / `guide` / `api` / `reference` sections. Past the cap, sample across sections rather than truncating one section wholesale, and say in the final summary that the set was truncated.
3. **Scrape content**: when `mcp__brightdata__scrape_batch` is available, batch in groups of at most 5 (the `urls` cap in the tool's schema; follow the registered schema if it differs) and retry stragglers one at a time with `mcp__brightdata__scrape_as_markdown`.
   - **No `scrape_batch`**: it may be missing from the server's loaded tool groups; loop `scrape_as_markdown` per URL instead (same result, more round trips).
   - **No Bright Data MCP**: loop the terminal CLI, `bdata scrape <url> -f markdown` per URL, following the `brightdata-guide` conventions.
   - **No `bdata` either**: run that guide's four-gate preflight, report the gate that failed, and stop. Never fall back to a plain fetch, which the bot-protected docs sites this mode targets will block.
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
