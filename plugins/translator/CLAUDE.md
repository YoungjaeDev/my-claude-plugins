# Translator Plugin

Translate web articles to Korean markdown with intelligent image captioning.

## Skill

| Skill | Description |
|-------|-------------|
| `translate-web-article` | Web page to Korean markdown conversion |

## Features

- Fetch web pages via firecrawl MCP
- Translate text to natural Korean
- Keep technical terms in English
- VLM analysis for image captions
- Preserve code blocks and tables with Korean explanations

## Triggers

- "translate web page"
- "blog to Korean"
- "translate this article"

## Usage

```
/translate-web-article https://example.com/blog-post
```

## Workflow

1. Fetch page via firecrawl
2. Ask user for output directory and image options
3. Translate text (keep tech terms)
4. Analyze images with VLM for Korean captions
5. Generate markdown file

## Requirements

- firecrawl MCP configured
- VLM capability for image analysis

## Output

```
{output_dir}/
├── {article_name}.md    # Translated markdown
└── images/              # Downloaded images (optional)
```
