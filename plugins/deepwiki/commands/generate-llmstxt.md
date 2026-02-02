---
description: Generate llms.txt from URL or local directory
---

# Generate llms.txt

Generate well-structured llms.txt documentation following the llms.txt standard specification.

## llms.txt Format

```markdown
# Title

> Optional description

## Section name

- [Link title](URL): Brief description (10-15 words)
```

## Workflow

### URL Input

1. **Map URLs**: Use `firecrawl_map` to discover all URLs on the website
2. **Scrape Content**: Use `firecrawl_scrape` for each URL (batch of 10-20)
3. **Synthesize**: Extract key information and organize into sections
4. **Generate**: Write llms.txt to current directory

### Local Directory Input

1. **Discover Files**: Use Glob to find all markdown/docs files recursively
2. **Read Content**: Read relevant files (README, docs/, guides)
3. **Synthesize**: Extract purpose, key concepts, APIs
4. **Generate**: Write llms.txt to current directory

## Guidelines

- **Descriptions**: 10-15 words, specific to content (not generic)
- **Sections**: Group by type (Documentation, API Reference, Examples, Tools)
- **URLs**: Prefer official docs URLs over GitHub raw URLs
- **Errors**: Note failed URLs/files, continue with others

## Output

Write `llms.txt` to current directory with summary:
- Number of sources processed
- Number of sections created
- Any errors or warnings
