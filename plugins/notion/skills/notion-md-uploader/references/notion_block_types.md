# Notion Block Types Reference

This document provides a comprehensive reference for Notion API block types used by the uploader.

## Block Object Structure

Every Notion block follows this base structure:

```json
{
  "object": "block",
  "id": "block-uuid",
  "type": "block_type",
  "created_time": "2024-01-01T00:00:00.000Z",
  "last_edited_time": "2024-01-01T00:00:00.000Z",
  "has_children": false,
  "{block_type}": {
    // type-specific properties
  }
}
```

## Text Block Types

### Paragraph

```json
{
  "type": "paragraph",
  "paragraph": {
    "rich_text": [
      {
        "type": "text",
        "text": { "content": "Paragraph text" },
        "annotations": {
          "bold": false,
          "italic": false,
          "strikethrough": false,
          "underline": false,
          "code": false,
          "color": "default"
        }
      }
    ],
    "color": "default"
  }
}
```

### Headings

```json
// heading_1, heading_2, heading_3
{
  "type": "heading_1",
  "heading_1": {
    "rich_text": [{"type": "text", "text": {"content": "Heading"}}],
    "color": "default",
    "is_toggleable": false
  }
}
```

### Quote

```json
{
  "type": "quote",
  "quote": {
    "rich_text": [{"type": "text", "text": {"content": "Quote text"}}],
    "color": "default"
  }
}
```

### Callout

```json
{
  "type": "callout",
  "callout": {
    "rich_text": [{"type": "text", "text": {"content": "Note content"}}],
    "icon": {"type": "emoji", "emoji": "i"},
    "color": "default"
  }
}
```

## List Block Types

### Bulleted List Item

```json
{
  "type": "bulleted_list_item",
  "bulleted_list_item": {
    "rich_text": [{"type": "text", "text": {"content": "Item"}}],
    "color": "default",
    "children": []  // optional nested blocks
  }
}
```

### Numbered List Item

```json
{
  "type": "numbered_list_item",
  "numbered_list_item": {
    "rich_text": [{"type": "text", "text": {"content": "Item"}}],
    "color": "default",
    "children": []
  }
}
```

### To-Do

```json
{
  "type": "to_do",
  "to_do": {
    "rich_text": [{"type": "text", "text": {"content": "Task"}}],
    "checked": false,
    "color": "default"
  }
}
```

## Code Block

```json
{
  "type": "code",
  "code": {
    "rich_text": [{"type": "text", "text": {"content": "print('hello')"}}],
    "language": "python",
    "caption": []
  }
}
```

### Supported Languages

```
abap, arduino, bash, basic, c, clojure, coffeescript, c++, c#, css,
dart, diff, docker, elixir, elm, erlang, flow, fortran, f#, gherkin,
glsl, go, graphql, groovy, haskell, html, java, javascript, json,
julia, kotlin, latex, less, lisp, livescript, lua, makefile, markdown,
markup, matlab, mermaid, nix, objective-c, ocaml, pascal, perl, php,
plain text, powershell, prolog, protobuf, python, r, reason, ruby,
rust, sass, scala, scheme, scss, shell, sql, swift, typescript,
vb.net, verilog, vhdl, visual basic, webassembly, xml, yaml
```

## Media Block Types

### Image

External URL:
```json
{
  "type": "image",
  "image": {
    "type": "external",
    "external": {"url": "https://example.com/image.png"},
    "caption": []
  }
}
```

File Upload:
```json
{
  "type": "image",
  "image": {
    "type": "file_upload",
    "file_upload": {"id": "file-upload-uuid"},
    "caption": []
  }
}
```

### File

```json
{
  "type": "file",
  "file": {
    "type": "file_upload",
    "file_upload": {"id": "file-upload-uuid"},
    "name": "document.pdf"
  }
}
```

## Table Block Types

### Table

```json
{
  "type": "table",
  "table": {
    "table_width": 3,
    "has_column_header": true,
    "has_row_header": false,
    "children": [/* table_row blocks */]
  }
}
```

### Table Row

```json
{
  "type": "table_row",
  "table_row": {
    "cells": [
      [{"type": "text", "text": {"content": "Cell 1"}}],
      [{"type": "text", "text": {"content": "Cell 2"}}],
      [{"type": "text", "text": {"content": "Cell 3"}}]
    ]
  }
}
```

## Other Block Types

### Divider

```json
{
  "type": "divider",
  "divider": {}
}
```

### Bookmark

```json
{
  "type": "bookmark",
  "bookmark": {
    "url": "https://example.com",
    "caption": []
  }
}
```

## Rich Text Object

Rich text objects are used within blocks for formatted text:

```json
{
  "type": "text",
  "text": {
    "content": "Text content",
    "link": {"url": "https://example.com"}  // optional
  },
  "annotations": {
    "bold": false,
    "italic": false,
    "strikethrough": false,
    "underline": false,
    "code": false,
    "color": "default"
  },
  "plain_text": "Text content",
  "href": null
}
```

### Available Colors

```
default, gray, brown, orange, yellow, green, blue, purple, pink, red
gray_background, brown_background, orange_background, yellow_background,
green_background, blue_background, purple_background, pink_background, red_background
```

## File Upload Object

Used for uploading local files to Notion:

```json
{
  "object": "file_upload",
  "id": "uuid",
  "status": "uploaded",
  "filename": "image.png",
  "content_type": "image/png",
  "content_length": 12345
}
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/pages` | POST | Create a new page |
| `/v1/blocks/{id}/children` | PATCH | Append blocks to page |
| `/v1/blocks/{id}/children` | GET | Retrieve child blocks |
| `/v1/file_uploads` | POST | Create file upload |
| `/v1/file_uploads/{id}/send` | POST | Upload file content |

## Rate Limits

- Average: 3 requests per second
- Burst: Up to 3 concurrent requests
- Block limit: 100 blocks per request

## Error Codes

| Code | Description |
|------|-------------|
| 400 | Invalid request body |
| 401 | Invalid API key |
| 403 | Access denied to resource |
| 404 | Resource not found |
| 429 | Rate limit exceeded |
| 500 | Internal server error |
