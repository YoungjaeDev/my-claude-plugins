"""Pytest configuration and fixtures for interactive-review tests."""

import pytest
from typing import Dict, Any


@pytest.fixture
def sample_markdown() -> str:
    """Sample markdown content with multi-line and unicode (including Korean) characters."""
    return """# 테스트 계획 (Test Plan)

## Phase 1: 기본 기능 (Basic Features)
- [ ] Implement user authentication
- [ ] Create database schema
- [ ] 한글 지원 테스트

## Phase 2: Advanced Features
- [ ] Add caching layer
- [ ] Implement real-time updates
- [ ] Performance optimization

## Notes
Some additional context with **bold** and *italic* text.
Unicode test: 你好, مرحبا, Привет, שלום
"""


@pytest.fixture
def sample_markdown_simple() -> str:
    """Simple markdown content for basic tests."""
    return """# Simple Plan

- [ ] Task 1
- [ ] Task 2
- [ ] Task 3
"""


@pytest.fixture
def document_state_data() -> Dict[str, Any]:
    """Factory fixture for creating DocumentState test data."""
    return {
        "items": [
            {
                "id": "item-1",
                "text": "Implement authentication",
                "checked": True,
                "comment": "Using JWT tokens",
            },
            {
                "id": "item-2",
                "text": "Create database schema",
                "checked": False,
                "comment": "",
            },
            {
                "id": "item-3",
                "text": "한글 항목 테스트",
                "checked": True,
                "comment": "한글 코멘트",
            },
        ],
        "submitted": False,
    }


@pytest.fixture
def submitted_state_data() -> Dict[str, Any]:
    """DocumentState data representing a submitted review."""
    return {
        "items": [
            {
                "id": "item-1",
                "text": "Task 1",
                "checked": True,
                "comment": "Approved",
            },
            {
                "id": "item-2",
                "text": "Task 2",
                "checked": False,
                "comment": "Needs revision",
            },
        ],
        "submitted": True,
    }
