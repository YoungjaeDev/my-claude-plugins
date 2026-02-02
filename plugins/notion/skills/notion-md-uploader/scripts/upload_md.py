#!/usr/bin/env python3
"""
Markdown to Notion Uploader.

Main script for uploading Markdown files to Notion pages.

Usage:
    python upload_md.py <md_file> --parent-page-id <page_id> [options]

Examples:
    python upload_md.py README.md --parent-page-id abc123
    python upload_md.py docs/report.md --parent-page-id abc123 --title "Custom Title"
"""

import argparse
import os
import sys
from pathlib import Path
from typing import Any

# Load .env file if python-dotenv is available
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass  # python-dotenv not installed, use env vars directly

# Add scripts directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from markdown_parser import BlockType, MarkdownParser
from notion_client import NotionClient, NotionAPIError, NotionConfig
from notion_converter import NotionBlockConverter


class MarkdownToNotionUploader:
    """Uploads Markdown files to Notion pages."""

    def __init__(self, notion_client: NotionClient | None = None):
        """Initialize the uploader.

        Args:
            notion_client: NotionClient instance. If None, creates from env.
        """
        self.client = notion_client or NotionClient()
        self._uploaded_images: dict[str, str] = {}  # path -> file_upload_id

    def upload_image(self, image_path: str) -> str:
        """Upload an image to Notion.

        Args:
            image_path: Path to the image file

        Returns:
            File upload ID

        Raises:
            FileNotFoundError: If image file doesn't exist
        """
        # Check cache first
        if image_path in self._uploaded_images:
            return self._uploaded_images[image_path]

        file_upload_id = self.client.upload_file(image_path)
        self._uploaded_images[image_path] = file_upload_id
        return file_upload_id

    def upload_markdown(
        self,
        md_file: str | Path,
        parent_page_id: str,
        title: str | None = None,
    ) -> dict[str, Any]:
        """Upload a Markdown file to Notion.

        Args:
            md_file: Path to the Markdown file
            parent_page_id: ID of the parent Notion page
            title: Optional custom title (defaults to filename)

        Returns:
            Created page object from Notion API

        Raises:
            FileNotFoundError: If Markdown file doesn't exist
            NotionAPIError: If Notion API returns an error
        """
        md_path = Path(md_file)
        if not md_path.exists():
            raise FileNotFoundError(f"Markdown file not found: {md_file}")

        # Read Markdown content
        content = md_path.read_text(encoding="utf-8")

        # Determine title
        if not title:
            # Try to extract from first heading
            for line in content.split("\n"):
                line = line.strip()
                if line.startswith("# "):
                    title = line[2:].strip()
                    break
            if not title:
                title = md_path.stem  # Use filename without extension

        # Parse Markdown
        parser = MarkdownParser(base_path=str(md_path.parent))
        blocks = parser.parse(content)

        # Convert to Notion blocks with image upload support
        converter = NotionBlockConverter(
            image_uploader=self.upload_image,
            base_path=str(md_path.parent),
        )
        notion_blocks = converter.convert_blocks(blocks)

        # Create page with initial blocks (Notion limit: 100 blocks per request)
        initial_blocks = notion_blocks[:100]
        remaining_blocks = notion_blocks[100:]

        page = self.client.create_page(
            parent_page_id=parent_page_id,
            title=title,
            children=initial_blocks,
        )

        # Append remaining blocks if any
        if remaining_blocks:
            page_id = page["id"]
            self.client.append_blocks_chunked(page_id, remaining_blocks)

        return page


def extract_page_id(page_id_or_url: str) -> str:
    """Extract page ID from URL or return as-is if already an ID.

    Args:
        page_id_or_url: Notion page ID or URL

    Returns:
        Clean page ID (32 chars with hyphens)
    """
    # If it's a URL, extract the ID
    if "notion.so" in page_id_or_url or "notion.site" in page_id_or_url:
        # URL format: https://www.notion.so/pagename-32charID
        # or https://www.notion.so/workspace/32charID
        parts = page_id_or_url.rstrip("/").split("/")
        last_part = parts[-1]

        # Handle query params
        if "?" in last_part:
            last_part = last_part.split("?")[0]

        # The ID is the last 32 characters (may have hyphens)
        if "-" in last_part:
            # Take the last segment after the final hyphen if it looks like an ID
            segments = last_part.rsplit("-", 1)
            if len(segments[-1]) == 32:
                page_id = segments[-1]
            else:
                page_id = last_part.replace("-", "")[-32:]
        else:
            page_id = last_part[-32:]
    else:
        page_id = page_id_or_url.replace("-", "")

    # Format as UUID with hyphens: 8-4-4-4-12
    if len(page_id) == 32:
        return f"{page_id[:8]}-{page_id[8:12]}-{page_id[12:16]}-{page_id[16:20]}-{page_id[20:]}"

    return page_id_or_url  # Return as-is if can't parse


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Upload Markdown files to Notion",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python upload_md.py README.md --parent-page-id abc123
    python upload_md.py docs/report.md --parent-page-id "https://notion.so/page-abc123"
    python upload_md.py report.md --parent-page-id abc123 --title "My Report"

Environment Variables:
    NOTION_API_KEY    Required. Your Notion integration API key.

Setup:
    1. Create a Notion integration at https://www.notion.so/my-integrations
    2. Copy the API key and set it as NOTION_API_KEY
    3. Share the parent page with your integration
        """,
    )

    parser.add_argument(
        "md_file",
        type=str,
        help="Path to the Markdown file to upload",
    )
    parser.add_argument(
        "--parent-page-id",
        "-p",
        type=str,
        required=True,
        help="Notion parent page ID or URL",
    )
    parser.add_argument(
        "--title",
        "-t",
        type=str,
        default=None,
        help="Custom page title (defaults to first heading or filename)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse and convert without uploading",
    )

    args = parser.parse_args()

    # Check API key
    if not os.getenv("NOTION_API_KEY"):
        print("Error: NOTION_API_KEY environment variable is not set")
        print("\nTo set it:")
        print("  export NOTION_API_KEY=your_api_key_here")
        print("\nOr create a .env file with:")
        print("  NOTION_API_KEY=your_api_key_here")
        sys.exit(1)

    # Validate file exists
    md_path = Path(args.md_file)
    if not md_path.exists():
        print(f"Error: File not found: {args.md_file}")
        sys.exit(1)

    # Extract clean page ID
    parent_page_id = extract_page_id(args.parent_page_id)

    if args.dry_run:
        # Dry run mode
        print(f"Parsing: {args.md_file}")
        content = md_path.read_text(encoding="utf-8")

        md_parser = MarkdownParser(base_path=str(md_path.parent))
        blocks = md_parser.parse(content)

        print(f"Found {len(blocks)} blocks:")
        for i, block in enumerate(blocks[:10]):
            content_preview = ""
            if isinstance(block.content, str):
                content_preview = block.content[:50]
            elif isinstance(block.content, list) and block.content:
                content_preview = block.content[0].text[:50] if block.content[0].text else ""
            print(f"  {i+1}. {block.block_type.name}: {content_preview}...")

        if len(blocks) > 10:
            print(f"  ... and {len(blocks) - 10} more blocks")

        # Validate image files
        base_path = md_path.parent
        image_blocks = [b for b in blocks if b.block_type == BlockType.IMAGE]
        missing_images = []
        found_images = []

        for block in image_blocks:
            img_src = block.metadata.get("url", "")
            if img_src and not img_src.startswith(("http://", "https://")):
                img_path = base_path / img_src
                if img_path.exists():
                    found_images.append(str(img_src))
                else:
                    missing_images.append(str(img_src))

        if found_images:
            print(f"\nLocal images ({len(found_images)}):")
            for img in found_images[:5]:
                print(f"  [OK] {img}")
            if len(found_images) > 5:
                print(f"  ... and {len(found_images) - 5} more")

        if missing_images:
            print(f"\nMissing images ({len(missing_images)}):")
            for img in missing_images:
                print(f"  [MISSING] {img}")
            print("\nWarning: Missing images will cause upload to fail.")

        converter = NotionBlockConverter(base_path=str(md_path.parent))
        notion_blocks = converter.convert_blocks(blocks)
        print(f"\nConverted to {len(notion_blocks)} Notion blocks")

        print("\nDry run complete. Use without --dry-run to upload.")
        return

    # Upload
    try:
        print(f"Uploading: {args.md_file}")
        print(f"Parent page: {parent_page_id}")

        uploader = MarkdownToNotionUploader()
        page = uploader.upload_markdown(
            md_file=args.md_file,
            parent_page_id=parent_page_id,
            title=args.title,
        )

        page_url = page.get("url", "")
        page_id = page.get("id", "")
        image_count = len(uploader._uploaded_images)

        print(f"\nSuccess!")
        print(f"Page ID: {page_id}")
        print(f"URL: {page_url}")
        if image_count > 0:
            print(f"Images uploaded: {image_count}")

    except NotionAPIError as e:
        print(f"\nNotion API Error: {e}")
        if "Could not find page" in str(e.response_body):
            print("\nHint: Make sure the parent page is shared with your integration.")
            print("1. Open the parent page in Notion")
            print("2. Click '...' in the top right")
            print("3. Click 'Add connections'")
            print("4. Select your integration")
        sys.exit(1)
    except FileNotFoundError as e:
        print(f"\nFile Error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"\nUnexpected Error: {e}")
        raise


if __name__ == "__main__":
    main()
