# Notion Plugin

Upload Markdown files to Notion with preserved formatting.

## Skill

| Skill | Description |
|-------|-------------|
| `notion-md-uploader` | Markdown to Notion page conversion |

## Features

- Full Markdown syntax support
- Automatic local image uploads
- Code blocks with language highlighting
- Tables, callouts, todos
- Dry run preview mode

## Supported Elements

| Element | Notion Block |
|---------|--------------|
| Headings | heading_1/2/3 |
| Lists | bulleted/numbered_list_item |
| Code | code (with language) |
| Tables | table + table_row |
| Images | image (auto-upload) |
| Callouts | callout |
| Todos | to_do |

## Usage

```bash
# Basic upload
uv run python plugins/notion/skills/notion-md-uploader/scripts/upload_md.py \
    docs/report.md \
    --parent-page-id "abc123"

# Dry run
uv run python ... --dry-run
```

## Setup

1. Create integration at https://www.notion.so/my-integrations
2. Set `NOTION_API_KEY` in `.env`
3. Share target page with integration

## Requirements

- Notion API key
- Parent page shared with integration
- Python with `uv`
