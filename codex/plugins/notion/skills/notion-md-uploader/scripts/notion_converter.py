#!/usr/bin/env python3
"""
Notion Block Converter.

Converts parsed Markdown blocks to Notion API block objects.
"""

from pathlib import Path
from typing import Any

from markdown_parser import BlockType, InlineStyle, MarkdownBlock


class NotionBlockConverter:
    """Converts MarkdownBlock objects to Notion API block format."""

    # Emoji mapping for callout types
    CALLOUT_ICONS = {
        "note": "information_source",
        "warning": "warning",
        "tip": "bulb",
        "important": "star",
        "caution": "warning",
    }

    # Language mapping for code blocks
    LANGUAGE_MAP = {
        "py": "python",
        "js": "javascript",
        "ts": "typescript",
        "sh": "shell",
        "bash": "shell",
        "yml": "yaml",
        "": "plain text",
    }

    def __init__(
        self,
        image_uploader: Any | None = None,
        base_path: str = "",
    ):
        """Initialize the converter.

        Args:
            image_uploader: Optional callable that uploads images and returns file_upload_id
            base_path: Base path for resolving relative image paths
        """
        self.image_uploader = image_uploader
        self.base_path = Path(base_path) if base_path else Path.cwd()

    def convert_blocks(
        self,
        blocks: list[MarkdownBlock],
    ) -> list[dict[str, Any]]:
        """Convert a list of MarkdownBlocks to Notion blocks.

        Args:
            blocks: List of parsed MarkdownBlock objects

        Returns:
            List of Notion block objects
        """
        notion_blocks = []
        for block in blocks:
            converted = self.convert_block(block)
            if converted:
                if isinstance(converted, list):
                    notion_blocks.extend(converted)
                else:
                    notion_blocks.append(converted)
        return notion_blocks

    def convert_block(
        self,
        block: MarkdownBlock,
    ) -> dict[str, Any] | list[dict[str, Any]] | None:
        """Convert a single MarkdownBlock to Notion block(s).

        Args:
            block: Parsed MarkdownBlock object

        Returns:
            Notion block object, list of blocks, or None
        """
        converters = {
            BlockType.HEADING1: self._convert_heading,
            BlockType.HEADING2: self._convert_heading,
            BlockType.HEADING3: self._convert_heading,
            BlockType.PARAGRAPH: self._convert_paragraph,
            BlockType.BULLETED_LIST: self._convert_bulleted_list,
            BlockType.NUMBERED_LIST: self._convert_numbered_list,
            BlockType.CODE_BLOCK: self._convert_code_block,
            BlockType.QUOTE: self._convert_quote,
            BlockType.DIVIDER: self._convert_divider,
            BlockType.IMAGE: self._convert_image,
            BlockType.TABLE: self._convert_table,
            BlockType.TODO: self._convert_todo,
            BlockType.CALLOUT: self._convert_callout,
        }

        converter = converters.get(block.block_type)
        if converter:
            return converter(block)
        return None

    def _convert_rich_text(
        self,
        content: list[InlineStyle] | str,
    ) -> list[dict[str, Any]]:
        """Convert inline content to Notion rich_text array.

        Args:
            content: InlineStyle list or plain string

        Returns:
            Notion rich_text array
        """
        if isinstance(content, str):
            return [{"type": "text", "text": {"content": content}}]

        rich_text = []
        for style in content:
            text_obj: dict[str, Any] = {
                "type": "text",
                "text": {"content": style.text},
                "annotations": {
                    "bold": style.bold,
                    "italic": style.italic,
                    "strikethrough": style.strikethrough,
                    "underline": False,
                    "code": style.code,
                    "color": "default",
                },
            }
            # Only add link if it's a valid HTTP(S) URL
            if style.link and style.link.startswith(("http://", "https://")):
                text_obj["text"]["link"] = {"url": style.link}

            rich_text.append(text_obj)

        return rich_text if rich_text else [{"type": "text", "text": {"content": ""}}]

    def _convert_heading(
        self,
        block: MarkdownBlock,
    ) -> dict[str, Any]:
        """Convert heading block."""
        heading_map = {
            BlockType.HEADING1: "heading_1",
            BlockType.HEADING2: "heading_2",
            BlockType.HEADING3: "heading_3",
        }
        heading_type = heading_map[block.block_type]

        return {
            "object": "block",
            "type": heading_type,
            heading_type: {
                "rich_text": self._convert_rich_text(block.content),
                "color": "default",
                "is_toggleable": False,
            },
        }

    def _convert_paragraph(
        self,
        block: MarkdownBlock,
    ) -> dict[str, Any]:
        """Convert paragraph block."""
        return {
            "object": "block",
            "type": "paragraph",
            "paragraph": {
                "rich_text": self._convert_rich_text(block.content),
                "color": "default",
            },
        }

    def _convert_bulleted_list(
        self,
        block: MarkdownBlock,
    ) -> dict[str, Any]:
        """Convert bulleted list item."""
        return {
            "object": "block",
            "type": "bulleted_list_item",
            "bulleted_list_item": {
                "rich_text": self._convert_rich_text(block.content),
                "color": "default",
            },
        }

    def _convert_numbered_list(
        self,
        block: MarkdownBlock,
    ) -> dict[str, Any]:
        """Convert numbered list item."""
        return {
            "object": "block",
            "type": "numbered_list_item",
            "numbered_list_item": {
                "rich_text": self._convert_rich_text(block.content),
                "color": "default",
            },
        }

    def _convert_code_block(
        self,
        block: MarkdownBlock,
    ) -> dict[str, Any]:
        """Convert code block."""
        language = block.metadata.get("language", "plain text")
        language = self.LANGUAGE_MAP.get(language, language)

        # Notion has specific language values
        valid_languages = {
            "abap", "arduino", "bash", "basic", "c", "clojure", "coffeescript",
            "c++", "c#", "css", "dart", "diff", "docker", "elixir", "elm",
            "erlang", "flow", "fortran", "f#", "gherkin", "glsl", "go", "graphql",
            "groovy", "haskell", "html", "java", "javascript", "json", "julia",
            "kotlin", "latex", "less", "lisp", "livescript", "lua", "makefile",
            "markdown", "markup", "matlab", "mermaid", "nix", "objective-c",
            "ocaml", "pascal", "perl", "php", "plain text", "powershell",
            "prolog", "protobuf", "python", "r", "reason", "ruby", "rust",
            "sass", "scala", "scheme", "scss", "shell", "sql", "swift",
            "typescript", "vb.net", "verilog", "vhdl", "visual basic",
            "webassembly", "xml", "yaml", "java/c/c++/c#",
        }

        if language.lower() not in valid_languages:
            language = "plain text"

        return {
            "object": "block",
            "type": "code",
            "code": {
                "rich_text": [
                    {"type": "text", "text": {"content": block.content}}
                ],
                "language": language.lower(),
                "caption": [],
            },
        }

    def _convert_quote(
        self,
        block: MarkdownBlock,
    ) -> dict[str, Any]:
        """Convert quote block."""
        return {
            "object": "block",
            "type": "quote",
            "quote": {
                "rich_text": self._convert_rich_text(block.content),
                "color": "default",
            },
        }

    def _convert_divider(
        self,
        block: MarkdownBlock,
    ) -> dict[str, Any]:
        """Convert divider block."""
        return {
            "object": "block",
            "type": "divider",
            "divider": {},
        }

    def _convert_image(
        self,
        block: MarkdownBlock,
    ) -> dict[str, Any]:
        """Convert image block."""
        url = block.metadata.get("url", "")
        alt_text = block.content if isinstance(block.content, str) else ""

        # Check if it's a local file or URL
        if url.startswith(("http://", "https://")):
            # External URL
            return {
                "object": "block",
                "type": "image",
                "image": {
                    "type": "external",
                    "external": {"url": url},
                    "caption": [
                        {"type": "text", "text": {"content": alt_text}}
                    ] if alt_text else [],
                },
            }
        else:
            # Local file - needs upload
            local_path = self.base_path / url
            if self.image_uploader and local_path.exists():
                try:
                    file_upload_id = self.image_uploader(str(local_path))
                    return {
                        "object": "block",
                        "type": "image",
                        "image": {
                            "type": "file_upload",
                            "file_upload": {"id": file_upload_id},
                            "caption": [
                                {"type": "text", "text": {"content": alt_text}}
                            ] if alt_text else [],
                        },
                    }
                except Exception as e:
                    # Fall back to paragraph with error message
                    return {
                        "object": "block",
                        "type": "paragraph",
                        "paragraph": {
                            "rich_text": [
                                {
                                    "type": "text",
                                    "text": {"content": f"[Image upload failed: {url}] - {e}"},
                                    "annotations": {"italic": True, "color": "red"},
                                }
                            ],
                        },
                    }
            else:
                # No uploader or file not found
                return {
                    "object": "block",
                    "type": "paragraph",
                    "paragraph": {
                        "rich_text": [
                            {
                                "type": "text",
                                "text": {"content": f"[Image: {url}]"},
                                "annotations": {"italic": True, "bold": False, "strikethrough": False, "underline": False, "code": False, "color": "gray"},
                            }
                        ],
                    },
                }

    def _convert_table(
        self,
        block: MarkdownBlock,
    ) -> list[dict[str, Any]]:
        """Convert table block to Notion table blocks."""
        rows = block.metadata.get("rows", [])
        has_header = block.metadata.get("has_header", True)
        column_count = block.metadata.get("column_count", 0)

        if not rows or column_count == 0:
            return []

        # Create table block with children
        table_rows = []
        for row in rows:
            # Ensure row has correct number of cells
            cells = row[:column_count]
            while len(cells) < column_count:
                cells.append("")

            table_row = {
                "object": "block",
                "type": "table_row",
                "table_row": {
                    "cells": [
                        [{"type": "text", "text": {"content": cell}}]
                        for cell in cells
                    ]
                },
            }
            table_rows.append(table_row)

        table_block = {
            "object": "block",
            "type": "table",
            "table": {
                "table_width": column_count,
                "has_column_header": has_header,
                "has_row_header": False,
                "children": table_rows,
            },
        }

        return [table_block]

    def _convert_todo(
        self,
        block: MarkdownBlock,
    ) -> dict[str, Any]:
        """Convert todo/checkbox block."""
        checked = block.metadata.get("checked", False)

        return {
            "object": "block",
            "type": "to_do",
            "to_do": {
                "rich_text": self._convert_rich_text(block.content),
                "checked": checked,
                "color": "default",
            },
        }

    def _convert_callout(
        self,
        block: MarkdownBlock,
    ) -> dict[str, Any]:
        """Convert callout block."""
        callout_type = block.metadata.get("type", "note")

        # Emoji mapping
        emoji_map = {
            "note": "information_source",
            "warning": "warning",
            "tip": "bulb",
            "important": "star",
            "caution": "construction",
        }
        emoji = emoji_map.get(callout_type, "memo")

        return {
            "object": "block",
            "type": "callout",
            "callout": {
                "rich_text": self._convert_rich_text(block.content),
                "icon": {"type": "emoji", "emoji": self._get_emoji(emoji)},
                "color": "default",
            },
        }

    def _get_emoji(self, name: str) -> str:
        """Get emoji character from name."""
        emoji_map = {
            "information_source": "ℹ️",
            "warning": "⚠️",
            "bulb": "💡",
            "star": "⭐",
            "construction": "🚧",
            "memo": "📝",
        }
        return emoji_map.get(name, "ℹ️")


def main():
    """Test the converter."""
    from markdown_parser import MarkdownParser

    test_md = """# Test Document

This is a **bold** paragraph with *italic* text.

## Features

- Item 1
- Item 2

```python
print("Hello")
```

> Quote text

| A | B |
|---|---|
| 1 | 2 |
"""

    parser = MarkdownParser()
    blocks = parser.parse(test_md)

    converter = NotionBlockConverter()
    notion_blocks = converter.convert_blocks(blocks)

    import json
    print(json.dumps(notion_blocks, indent=2))


if __name__ == "__main__":
    main()
