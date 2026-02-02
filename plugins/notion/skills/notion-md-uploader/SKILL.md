---
name: notion-md-uploader
description: Upload Markdown files to Notion pages with full formatting support including headings, lists, code blocks, images, tables, callouts, and todos. This skill should be used when users want to publish documentation, reports, or notes from Markdown files to their Notion workspace with preserved formatting and automatic image uploads.
---

# Notion Markdown Uploader

## Overview

To upload Markdown files to Notion with full formatting preservation, use this skill. It converts Markdown syntax to Notion blocks and handles local image uploads automatically via the Notion File Upload API.

## Prerequisites

Before using this skill, ensure the following setup is complete:

### 1. Notion Integration Setup

1. Visit https://www.notion.so/my-integrations
2. Click "+ New integration"
3. Configure the integration:
   - Name: "MD Uploader" (or preferred name)
   - Associated workspace: Select target workspace
   - Capabilities: Enable Read, Update, and Insert content
4. Click "Submit" and copy the API key

### 2. Environment Configuration

Set the API key in the environment. The script automatically loads `.env` files if `python-dotenv` is installed:

```bash
# In .env file (recommended - auto-loaded)
NOTION_API_KEY=ntn_xxxxx

# Or export directly
export NOTION_API_KEY=ntn_xxxxx
```

To install dotenv support:

```bash
uv add python-dotenv
```

### 3. Page Access

Share the target parent page with the integration:

1. Open the Notion page where documents will be uploaded
2. Click "..." menu (top right)
3. Select "Add connections"
4. Find and select the integration

## Quick Start

### Basic Upload

```bash
uv run python .claude/skills/notion-md-uploader/scripts/upload_md.py \
    docs/report.md \
    --parent-page-id "abc123def456"
```

### With Custom Title

```bash
uv run python .claude/skills/notion-md-uploader/scripts/upload_md.py \
    README.md \
    --parent-page-id "abc123def456" \
    --title "Project Documentation"
```

### Dry Run (Preview)

Preview parsing results and validate local images before uploading:

```bash
uv run python .claude/skills/notion-md-uploader/scripts/upload_md.py \
    docs/analysis.md \
    --parent-page-id "abc123def456" \
    --dry-run
```

The dry run validates:
- Markdown block parsing
- Local image file existence
- Conversion to Notion blocks

## Supported Markdown Elements

| Element | Markdown Syntax | Notion Block |
|---------|----------------|--------------|
| Heading 1 | `# Title` | heading_1 |
| Heading 2 | `## Subtitle` | heading_2 |
| Heading 3 | `### Section` | heading_3 |
| Paragraph | Plain text | paragraph |
| Bold | `**text**` | bold annotation |
| Italic | `*text*` | italic annotation |
| Strikethrough | `~~text~~` | strikethrough annotation |
| Inline Code | `` `code` `` | code annotation |
| Link | `[text](url)` | link |
| Bulleted List | `- item` | bulleted_list_item |
| Numbered List | `1. item` | numbered_list_item |
| Code Block | ` ```lang ``` ` | code (with language) |
| Quote | `> text` | quote |
| Divider | `---` | divider |
| Image | `![alt](path)` | image (with upload) |
| Table | `\| A \| B \|` | table + table_row |
| Todo | `- [ ] task` | to_do |
| Callout | `> [!NOTE]` | callout |

## Image Handling

### External URLs

Images with HTTP/HTTPS URLs are embedded directly:

```markdown
![Logo](https://example.com/logo.png)
```

### Local Images

Local images are automatically uploaded to Notion:

```markdown
![Chart](./figures/chart.png)
![Result](../outputs/result.jpg)
```

The uploader:
1. Detects local image paths
2. Creates a Notion File Upload object
3. Uploads the image binary
4. Attaches the uploaded file to an image block

Supported formats: `.png`, `.jpg`, `.jpeg`, `.gif`, `.svg`, `.webp`

## Finding Parent Page ID

### Option 1: From URL

Copy the page URL and extract the ID:

```
https://www.notion.so/workspace/Page-Title-abc123def456ghi789
                                        ^^^^^^^^^^^^^^^^^^^^^^^^
                                        This is the page ID (32 chars)
```

### Option 2: Use Search API

```bash
# The script accepts full URLs
uv run python .claude/skills/notion-md-uploader/scripts/upload_md.py \
    report.md \
    --parent-page-id "https://www.notion.so/workspace/Reports-abc123"
```

## Workflow Decision Tree

```
User wants to upload Markdown to Notion
    |
    +-- Is NOTION_API_KEY set?
    |   +-- No: Set up integration (see Prerequisites)
    |   +-- Yes: Continue
    |
    +-- Is parent page shared with integration?
    |   +-- No: Add connection to page
    |   +-- Yes: Continue
    |
    +-- Run upload script
        +-- Has local images?
        |   +-- Yes: Images uploaded automatically
        |   +-- No: Continue
        |
        +-- Success: Page created with URL
```

## Scripts

### upload_md.py

Main upload script. Run with `--help` for full options:

```bash
uv run python .claude/skills/notion-md-uploader/scripts/upload_md.py --help
```

Arguments:
- `md_file`: Path to Markdown file (required)
- `--parent-page-id`, `-p`: Notion parent page ID or URL (required)
- `--title`, `-t`: Custom page title (optional)
- `--dry-run`: Preview without uploading (optional)

### notion_client.py

Low-level Notion API client. Can be imported for custom workflows:

```python
from scripts.notion_client import NotionClient

client = NotionClient()
page = client.create_page(
    parent_page_id="abc123",
    title="My Page",
    children=[...]
)
```

### markdown_parser.py

Markdown parser for converting to AST. Useful for custom processing:

```python
from scripts.markdown_parser import MarkdownParser

parser = MarkdownParser()
blocks = parser.parse(markdown_text)
```

### notion_converter.py

Converts parsed Markdown blocks to Notion API format:

```python
from scripts.notion_converter import NotionBlockConverter

converter = NotionBlockConverter(image_uploader=upload_func)
notion_blocks = converter.convert_blocks(blocks)
```

## Limitations

1. **Block Limit**: Notion API allows max 100 blocks per request. The script handles this by chunking.
2. **File Size**: Images must be under 20MB (5MB for free workspaces)
3. **Nested Lists**: Currently flattened (nested items become top-level)
4. **Complex Tables**: Cell formatting may be simplified
5. **Attachments**: Only images are auto-uploaded; other files need manual handling

## Troubleshooting

### "Could not find page" Error

The parent page is not shared with the integration:
1. Open the page in Notion
2. Click "..." > "Add connections"
3. Select your integration

### "unauthorized" Error

API key is invalid or not set:
1. Check `NOTION_API_KEY` in `.env`
2. Verify the key at https://www.notion.so/my-integrations

### Image Upload Failed

1. Check file exists at the specified path
2. Verify file size is under limit
3. Ensure file format is supported

## References

- `references/notion_block_types.md` - Detailed Notion block type reference
- `references/setup_guide.md` - Step-by-step integration setup guide
