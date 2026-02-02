#!/usr/bin/env python3
"""
Notion API Client for file uploads and page creation.

This module provides a wrapper around the Notion API for:
- Creating pages with content blocks
- Uploading files (images, documents)
- Appending blocks to existing pages
"""

import json
import mimetypes
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import requests


@dataclass
class NotionConfig:
    """Notion API configuration."""

    api_key: str
    api_version: str = "2022-06-28"
    base_url: str = "https://api.notion.com/v1"

    @classmethod
    def from_env(cls) -> "NotionConfig":
        """Create config from environment variables."""
        api_key = os.getenv("NOTION_API_KEY")
        if not api_key:
            raise ValueError("NOTION_API_KEY environment variable is not set")
        return cls(api_key=api_key)


class NotionAPIError(Exception):
    """Custom exception for Notion API errors."""

    def __init__(self, status_code: int, message: str, response_body: str = ""):
        self.status_code = status_code
        self.message = message
        self.response_body = response_body
        super().__init__(f"Notion API Error ({status_code}): {message}")


class NotionClient:
    """Client for interacting with Notion API."""

    def __init__(self, config: NotionConfig | None = None):
        """Initialize the Notion client.

        Args:
            config: NotionConfig instance. If None, loads from environment.
        """
        self.config = config or NotionConfig.from_env()
        self._session = requests.Session()
        self._session.headers.update(self._default_headers())

    def _default_headers(self) -> dict[str, str]:
        """Return default headers for API requests."""
        return {
            "Authorization": f"Bearer {self.config.api_key}",
            "Notion-Version": self.config.api_version,
            "Content-Type": "application/json",
        }

    def _request(
        self,
        method: str,
        endpoint: str,
        json_data: dict[str, Any] | None = None,
        **kwargs: Any,
    ) -> dict[str, Any]:
        """Make an API request to Notion.

        Args:
            method: HTTP method (GET, POST, PATCH, DELETE)
            endpoint: API endpoint (without base URL)
            json_data: JSON payload for the request
            **kwargs: Additional arguments for requests

        Returns:
            JSON response from the API

        Raises:
            NotionAPIError: If the API returns an error
        """
        url = f"{self.config.base_url}/{endpoint.lstrip('/')}"

        response = self._session.request(
            method=method,
            url=url,
            json=json_data,
            **kwargs,
        )

        if not response.ok:
            raise NotionAPIError(
                status_code=response.status_code,
                message=response.reason,
                response_body=response.text,
            )

        return response.json()

    def create_page(
        self,
        parent_page_id: str,
        title: str,
        children: list[dict[str, Any]] | None = None,
        icon: dict[str, Any] | None = None,
        cover: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Create a new page under a parent page.

        Args:
            parent_page_id: ID of the parent page
            title: Page title
            children: List of block objects for page content
            icon: Page icon (emoji or file)
            cover: Page cover image

        Returns:
            Created page object
        """
        payload: dict[str, Any] = {
            "parent": {"type": "page_id", "page_id": parent_page_id},
            "properties": {
                "title": {
                    "title": [{"type": "text", "text": {"content": title}}]
                }
            },
        }

        if children:
            payload["children"] = children
        if icon:
            payload["icon"] = icon
        if cover:
            payload["cover"] = cover

        return self._request("POST", "/pages", json_data=payload)

    def append_blocks(
        self,
        block_id: str,
        children: list[dict[str, Any]],
    ) -> dict[str, Any]:
        """Append blocks to an existing page or block.

        Note: Notion API has a limit of 100 blocks per request.
        For larger content, use append_blocks_chunked.

        Args:
            block_id: ID of the page or block to append to
            children: List of block objects to append

        Returns:
            Response containing the appended blocks
        """
        return self._request(
            "PATCH",
            f"/blocks/{block_id}/children",
            json_data={"children": children},
        )

    def append_blocks_chunked(
        self,
        block_id: str,
        children: list[dict[str, Any]],
        chunk_size: int = 100,
    ) -> list[dict[str, Any]]:
        """Append blocks in chunks to handle Notion's 100 block limit.

        Args:
            block_id: ID of the page or block to append to
            children: List of block objects to append
            chunk_size: Maximum blocks per request (default 100)

        Returns:
            List of responses from each chunk
        """
        responses = []
        for i in range(0, len(children), chunk_size):
            chunk = children[i : i + chunk_size]
            response = self.append_blocks(block_id, chunk)
            responses.append(response)
        return responses

    def create_file_upload(
        self,
        filename: str | None = None,
        content_type: str | None = None,
    ) -> dict[str, Any]:
        """Create a file upload object.

        Args:
            filename: Optional filename
            content_type: Optional MIME type

        Returns:
            File upload object with id and upload_url
        """
        payload = {}
        if filename:
            payload["filename"] = filename
        if content_type:
            payload["content_type"] = content_type

        return self._request("POST", "/file_uploads", json_data=payload)

    def send_file_upload(
        self,
        file_upload_id: str,
        file_path: str | Path,
    ) -> dict[str, Any]:
        """Upload file contents to a file upload object.

        Args:
            file_upload_id: ID from create_file_upload
            file_path: Path to the file to upload

        Returns:
            Updated file upload object with status 'uploaded'
        """
        file_path = Path(file_path)
        if not file_path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")

        # Detect MIME type
        mime_type, _ = mimetypes.guess_type(str(file_path))
        if mime_type is None:
            mime_type = "application/octet-stream"

        url = f"{self.config.base_url}/file_uploads/{file_upload_id}/send"

        with open(file_path, "rb") as f:
            files = {"file": (file_path.name, f, mime_type)}
            # Remove Content-Type header for multipart/form-data
            headers = {
                "Authorization": f"Bearer {self.config.api_key}",
                "Notion-Version": self.config.api_version,
            }
            response = requests.post(url, headers=headers, files=files)

        if not response.ok:
            raise NotionAPIError(
                status_code=response.status_code,
                message=response.reason,
                response_body=response.text,
            )

        return response.json()

    def upload_file(self, file_path: str | Path) -> str:
        """Upload a file to Notion and return the file_upload ID.

        This is a convenience method that combines create_file_upload
        and send_file_upload.

        Args:
            file_path: Path to the file to upload

        Returns:
            File upload ID that can be used in blocks
        """
        file_path = Path(file_path)
        mime_type, _ = mimetypes.guess_type(str(file_path))

        # Step 1: Create file upload object
        file_upload = self.create_file_upload(
            filename=file_path.name,
            content_type=mime_type,
        )
        file_upload_id = file_upload["id"]

        # Step 2: Send file contents
        self.send_file_upload(file_upload_id, file_path)

        return file_upload_id

    def get_page(self, page_id: str) -> dict[str, Any]:
        """Retrieve a page by ID.

        Args:
            page_id: The page ID

        Returns:
            Page object
        """
        return self._request("GET", f"/pages/{page_id}")

    def search(
        self,
        query: str = "",
        filter_type: str | None = None,
        page_size: int = 100,
    ) -> dict[str, Any]:
        """Search for pages and databases.

        Args:
            query: Search query string
            filter_type: Filter by 'page' or 'database'
            page_size: Number of results per page

        Returns:
            Search results
        """
        payload: dict[str, Any] = {"page_size": page_size}
        if query:
            payload["query"] = query
        if filter_type:
            payload["filter"] = {"property": "object", "value": filter_type}

        return self._request("POST", "/search", json_data=payload)


def main():
    """Test the Notion client."""
    try:
        client = NotionClient()
        print("Notion client initialized successfully")

        # Test search
        results = client.search(query="", page_size=5)
        print(f"Found {len(results.get('results', []))} items")

    except NotionAPIError as e:
        print(f"API Error: {e}")
    except ValueError as e:
        print(f"Configuration Error: {e}")


if __name__ == "__main__":
    main()
