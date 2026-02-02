#!/usr/bin/env python3
"""
Markdown Parser for Notion conversion.

Parses Markdown text into an AST-like structure that can be
converted to Notion blocks. Uses regex-based parsing to avoid
external dependencies.
"""

import re
from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Any


class BlockType(Enum):
    """Types of Markdown blocks."""

    HEADING1 = auto()
    HEADING2 = auto()
    HEADING3 = auto()
    PARAGRAPH = auto()
    BULLETED_LIST = auto()
    NUMBERED_LIST = auto()
    CODE_BLOCK = auto()
    QUOTE = auto()
    DIVIDER = auto()
    IMAGE = auto()
    TABLE = auto()
    TODO = auto()
    CALLOUT = auto()


@dataclass
class InlineStyle:
    """Represents inline text styling."""

    text: str
    bold: bool = False
    italic: bool = False
    strikethrough: bool = False
    code: bool = False
    link: str | None = None


@dataclass
class MarkdownBlock:
    """Represents a parsed Markdown block."""

    block_type: BlockType
    content: list[InlineStyle] | str = ""
    children: list["MarkdownBlock"] = field(default_factory=list)
    metadata: dict[str, Any] = field(default_factory=dict)


class MarkdownParser:
    """Parser for Markdown text."""

    # Regex patterns for block-level elements
    HEADING_PATTERN = re.compile(r"^(#{1,6})\s+(.+)$")
    CODE_BLOCK_START = re.compile(r"^```(\w*)$")
    CODE_BLOCK_END = re.compile(r"^```$")
    BULLETED_LIST_PATTERN = re.compile(r"^(\s*)[-*+]\s+(.+)$")
    NUMBERED_LIST_PATTERN = re.compile(r"^(\s*)\d+\.\s+(.+)$")
    QUOTE_PATTERN = re.compile(r"^>\s*(.*)$")
    DIVIDER_PATTERN = re.compile(r"^-{3,}$|^\*{3,}$|^_{3,}$")
    IMAGE_PATTERN = re.compile(r"!\[([^\]]*)\]\(([^)]+)\)")
    TODO_PATTERN = re.compile(r"^(\s*)[-*]\s+\[([ xX])\]\s+(.+)$")
    CALLOUT_PATTERN = re.compile(r"^>\s*\[!(NOTE|WARNING|TIP|IMPORTANT|CAUTION)\]\s*$", re.IGNORECASE)
    TABLE_ROW_PATTERN = re.compile(r"^\|(.+)\|$")
    TABLE_SEPARATOR_PATTERN = re.compile(r"^\|[\s\-:|]+\|$")

    # Regex patterns for inline elements
    BOLD_PATTERN = re.compile(r"\*\*(.+?)\*\*|__(.+?)__")
    ITALIC_PATTERN = re.compile(r"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)|(?<!_)_(?!_)(.+?)(?<!_)_(?!_)")
    STRIKETHROUGH_PATTERN = re.compile(r"~~(.+?)~~")
    INLINE_CODE_PATTERN = re.compile(r"`([^`]+)`")
    LINK_PATTERN = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")

    def __init__(self, base_path: str = ""):
        """Initialize the parser.

        Args:
            base_path: Base path for resolving relative image paths
        """
        self.base_path = base_path

    def parse(self, markdown_text: str) -> list[MarkdownBlock]:
        """Parse Markdown text into a list of blocks.

        Args:
            markdown_text: The Markdown text to parse

        Returns:
            List of MarkdownBlock objects
        """
        lines = markdown_text.split("\n")
        blocks: list[MarkdownBlock] = []
        i = 0

        while i < len(lines):
            line = lines[i]

            # Skip empty lines
            if not line.strip():
                i += 1
                continue

            # Check for code block
            code_match = self.CODE_BLOCK_START.match(line)
            if code_match:
                block, i = self._parse_code_block(lines, i)
                blocks.append(block)
                continue

            # Check for divider
            if self.DIVIDER_PATTERN.match(line.strip()):
                blocks.append(MarkdownBlock(block_type=BlockType.DIVIDER))
                i += 1
                continue

            # Check for heading
            heading_match = self.HEADING_PATTERN.match(line)
            if heading_match:
                level = len(heading_match.group(1))
                text = heading_match.group(2)
                block_type = {
                    1: BlockType.HEADING1,
                    2: BlockType.HEADING2,
                    3: BlockType.HEADING3,
                }.get(level, BlockType.HEADING3)
                blocks.append(MarkdownBlock(
                    block_type=block_type,
                    content=self._parse_inline(text),
                ))
                i += 1
                continue

            # Check for callout (GitHub-style)
            callout_match = self.CALLOUT_PATTERN.match(line)
            if callout_match:
                block, i = self._parse_callout(lines, i, callout_match.group(1))
                blocks.append(block)
                continue

            # Check for quote
            quote_match = self.QUOTE_PATTERN.match(line)
            if quote_match:
                block, i = self._parse_quote(lines, i)
                blocks.append(block)
                continue

            # Check for TODO item
            todo_match = self.TODO_PATTERN.match(line)
            if todo_match:
                checked = todo_match.group(2).lower() == "x"
                text = todo_match.group(3)
                blocks.append(MarkdownBlock(
                    block_type=BlockType.TODO,
                    content=self._parse_inline(text),
                    metadata={"checked": checked},
                ))
                i += 1
                continue

            # Check for bulleted list
            bullet_match = self.BULLETED_LIST_PATTERN.match(line)
            if bullet_match:
                block, i = self._parse_list(lines, i, is_numbered=False)
                blocks.extend(block)
                continue

            # Check for numbered list
            number_match = self.NUMBERED_LIST_PATTERN.match(line)
            if number_match:
                block, i = self._parse_list(lines, i, is_numbered=True)
                blocks.extend(block)
                continue

            # Check for table
            table_match = self.TABLE_ROW_PATTERN.match(line)
            if table_match and i + 1 < len(lines):
                next_line = lines[i + 1]
                if self.TABLE_SEPARATOR_PATTERN.match(next_line):
                    block, i = self._parse_table(lines, i)
                    blocks.append(block)
                    continue

            # Check for standalone image
            if line.strip().startswith("!["):
                image_match = self.IMAGE_PATTERN.search(line)
                if image_match:
                    blocks.append(MarkdownBlock(
                        block_type=BlockType.IMAGE,
                        content=image_match.group(1),  # alt text
                        metadata={"url": image_match.group(2)},
                    ))
                    i += 1
                    continue

            # Default: paragraph
            block, i = self._parse_paragraph(lines, i)
            blocks.append(block)

        return blocks

    def _parse_inline(self, text: str) -> list[InlineStyle]:
        """Parse inline formatting in text.

        Args:
            text: Text to parse

        Returns:
            List of InlineStyle objects
        """
        if not text:
            return []

        # Simple approach: split by formatting markers and track state
        result: list[InlineStyle] = []

        # First, handle links and images specially
        # Then handle bold, italic, strikethrough, code

        # For simplicity, use a token-based approach
        segments = self._tokenize_inline(text)
        return segments

    def _tokenize_inline(self, text: str) -> list[InlineStyle]:
        """Tokenize inline text into styled segments.

        Args:
            text: Text to tokenize

        Returns:
            List of InlineStyle objects
        """
        if not text:
            return []

        result: list[InlineStyle] = []
        pos = 0

        while pos < len(text):
            # Check for inline code (highest priority, doesn't nest)
            code_match = self.INLINE_CODE_PATTERN.match(text, pos)
            if code_match:
                result.append(InlineStyle(text=code_match.group(1), code=True))
                pos = code_match.end()
                continue

            # Check for link
            link_match = self.LINK_PATTERN.match(text, pos)
            if link_match:
                link_text = link_match.group(1)
                link_url = link_match.group(2)
                result.append(InlineStyle(text=link_text, link=link_url))
                pos = link_match.end()
                continue

            # Check for bold
            bold_match = self.BOLD_PATTERN.match(text, pos)
            if bold_match:
                content = bold_match.group(1) or bold_match.group(2)
                result.append(InlineStyle(text=content, bold=True))
                pos = bold_match.end()
                continue

            # Check for strikethrough
            strike_match = self.STRIKETHROUGH_PATTERN.match(text, pos)
            if strike_match:
                result.append(InlineStyle(text=strike_match.group(1), strikethrough=True))
                pos = strike_match.end()
                continue

            # Check for italic (must be after bold check)
            italic_match = self.ITALIC_PATTERN.match(text, pos)
            if italic_match:
                content = italic_match.group(1) or italic_match.group(2)
                result.append(InlineStyle(text=content, italic=True))
                pos = italic_match.end()
                continue

            # Regular text - find next special character
            next_special = len(text)
            for pattern in [r"\*", r"_", r"`", r"\[", r"~"]:
                match = re.search(pattern, text[pos + 1:])
                if match:
                    next_special = min(next_special, pos + 1 + match.start())

            plain_text = text[pos:next_special]
            if plain_text:
                result.append(InlineStyle(text=plain_text))
            pos = next_special

        # Merge adjacent plain text segments
        merged: list[InlineStyle] = []
        for segment in result:
            if (merged and
                not segment.bold and not segment.italic and
                not segment.strikethrough and not segment.code and
                not segment.link and
                not merged[-1].bold and not merged[-1].italic and
                not merged[-1].strikethrough and not merged[-1].code and
                not merged[-1].link):
                merged[-1] = InlineStyle(text=merged[-1].text + segment.text)
            else:
                merged.append(segment)

        return merged if merged else [InlineStyle(text=text)]

    def _parse_code_block(
        self, lines: list[str], start: int
    ) -> tuple[MarkdownBlock, int]:
        """Parse a fenced code block.

        Args:
            lines: All lines
            start: Starting line index

        Returns:
            Tuple of (MarkdownBlock, next line index)
        """
        match = self.CODE_BLOCK_START.match(lines[start])
        language = match.group(1) if match else ""

        code_lines = []
        i = start + 1
        while i < len(lines):
            if self.CODE_BLOCK_END.match(lines[i]):
                i += 1
                break
            code_lines.append(lines[i])
            i += 1

        return (
            MarkdownBlock(
                block_type=BlockType.CODE_BLOCK,
                content="\n".join(code_lines),
                metadata={"language": language or "plain text"},
            ),
            i,
        )

    def _parse_quote(
        self, lines: list[str], start: int
    ) -> tuple[MarkdownBlock, int]:
        """Parse a blockquote.

        Args:
            lines: All lines
            start: Starting line index

        Returns:
            Tuple of (MarkdownBlock, next line index)
        """
        quote_lines = []
        i = start
        while i < len(lines):
            match = self.QUOTE_PATTERN.match(lines[i])
            if match:
                quote_lines.append(match.group(1))
                i += 1
            else:
                break

        content = " ".join(quote_lines)
        return (
            MarkdownBlock(
                block_type=BlockType.QUOTE,
                content=self._parse_inline(content),
            ),
            i,
        )

    def _parse_callout(
        self, lines: list[str], start: int, callout_type: str
    ) -> tuple[MarkdownBlock, int]:
        """Parse a GitHub-style callout.

        Args:
            lines: All lines
            start: Starting line index
            callout_type: Type of callout (NOTE, WARNING, etc.)

        Returns:
            Tuple of (MarkdownBlock, next line index)
        """
        callout_lines = []
        i = start + 1
        while i < len(lines):
            match = self.QUOTE_PATTERN.match(lines[i])
            if match:
                callout_lines.append(match.group(1))
                i += 1
            else:
                break

        content = " ".join(callout_lines)
        icon_map = {
            "note": "info",
            "warning": "warning",
            "tip": "lightbulb",
            "important": "star",
            "caution": "warning",
        }

        return (
            MarkdownBlock(
                block_type=BlockType.CALLOUT,
                content=self._parse_inline(content),
                metadata={
                    "type": callout_type.lower(),
                    "icon": icon_map.get(callout_type.lower(), "info"),
                },
            ),
            i,
        )

    def _parse_list(
        self, lines: list[str], start: int, is_numbered: bool
    ) -> tuple[list[MarkdownBlock], int]:
        """Parse a list (bulleted or numbered).

        Args:
            lines: All lines
            start: Starting line index
            is_numbered: True for numbered lists

        Returns:
            Tuple of (list of MarkdownBlocks, next line index)
        """
        blocks: list[MarkdownBlock] = []
        pattern = self.NUMBERED_LIST_PATTERN if is_numbered else self.BULLETED_LIST_PATTERN
        block_type = BlockType.NUMBERED_LIST if is_numbered else BlockType.BULLETED_LIST

        i = start
        while i < len(lines):
            line = lines[i]
            if not line.strip():
                i += 1
                break

            match = pattern.match(line)
            if match:
                text = match.group(2)
                blocks.append(MarkdownBlock(
                    block_type=block_type,
                    content=self._parse_inline(text),
                ))
                i += 1
            else:
                break

        return blocks, i

    def _parse_table(
        self, lines: list[str], start: int
    ) -> tuple[MarkdownBlock, int]:
        """Parse a Markdown table.

        Args:
            lines: All lines
            start: Starting line index

        Returns:
            Tuple of (MarkdownBlock, next line index)
        """
        rows: list[list[str]] = []
        i = start

        # Parse header row
        header_match = self.TABLE_ROW_PATTERN.match(lines[i])
        if header_match:
            cells = [c.strip() for c in header_match.group(1).split("|")]
            rows.append(cells)
            i += 1

        # Skip separator row
        if i < len(lines) and self.TABLE_SEPARATOR_PATTERN.match(lines[i]):
            i += 1

        # Parse data rows
        while i < len(lines):
            row_match = self.TABLE_ROW_PATTERN.match(lines[i])
            if row_match:
                cells = [c.strip() for c in row_match.group(1).split("|")]
                rows.append(cells)
                i += 1
            else:
                break

        return (
            MarkdownBlock(
                block_type=BlockType.TABLE,
                metadata={
                    "rows": rows,
                    "has_header": True,
                    "column_count": len(rows[0]) if rows else 0,
                },
            ),
            i,
        )

    def _parse_paragraph(
        self, lines: list[str], start: int
    ) -> tuple[MarkdownBlock, int]:
        """Parse a paragraph.

        Args:
            lines: All lines
            start: Starting line index

        Returns:
            Tuple of (MarkdownBlock, next line index)
        """
        para_lines = []
        i = start

        while i < len(lines):
            line = lines[i]
            # Stop at empty line or new block-level element
            if not line.strip():
                break
            if self.HEADING_PATTERN.match(line):
                break
            if self.CODE_BLOCK_START.match(line):
                break
            if self.BULLETED_LIST_PATTERN.match(line):
                break
            if self.NUMBERED_LIST_PATTERN.match(line):
                break
            if self.QUOTE_PATTERN.match(line):
                break
            if self.DIVIDER_PATTERN.match(line.strip()):
                break
            if self.TODO_PATTERN.match(line):
                break
            # Stop at image lines to allow them to be parsed as IMAGE blocks
            if line.strip().startswith("![") and self.IMAGE_PATTERN.search(line):
                break

            para_lines.append(line)
            i += 1

        # Handle trailing double spaces as line breaks
        processed_lines = []
        for line in para_lines:
            if line.endswith("  "):
                processed_lines.append(line.rstrip() + "\n")
            else:
                processed_lines.append(line + " ")
        content = "".join(processed_lines).strip()

        return (
            MarkdownBlock(
                block_type=BlockType.PARAGRAPH,
                content=self._parse_inline(content),
            ),
            i,
        )


def main():
    """Test the Markdown parser."""
    test_md = """# Heading 1

This is a paragraph with **bold** and *italic* text.

## Heading 2

- Bullet item 1
- Bullet item 2

1. Numbered item 1
2. Numbered item 2

```python
def hello():
    print("Hello, World!")
```

> This is a quote

> [!NOTE]
> This is a callout

| Col1 | Col2 |
|------|------|
| A    | B    |

- [x] Completed task
- [ ] Pending task

![Alt text](image.png)

---
"""
    parser = MarkdownParser()
    blocks = parser.parse(test_md)

    for block in blocks:
        print(f"{block.block_type.name}: {block.content[:50] if isinstance(block.content, str) else len(block.content)} items")


if __name__ == "__main__":
    main()
