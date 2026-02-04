"""
Web UI Generator for Interactive Review

Generates a self-contained HTML file with embedded CSS and JavaScript
for reviewing markdown content with line-level comments (GitHub-style).
Uses marked.js for markdown rendering.
"""

import json
from typing import List
from dataclasses import dataclass, field


@dataclass
class Block:
    """Represents a reviewable block in the markdown content."""

    id: str
    type: str  # heading, list-item, paragraph, code
    text: str
    level: int = 0  # for headings
    raw: str = ""  # original markdown


@dataclass
class DocumentState:
    """Memory-efficient document storage using line offsets instead of per-line objects."""

    raw_content: str
    _line_offsets: List[int] = field(default_factory=list)

    def __post_init__(self):
        self._line_offsets = [0]
        for i, char in enumerate(self.raw_content):
            if char == "\n":
                self._line_offsets.append(i + 1)

    def get_line(self, index: int) -> str:
        if index < 0 or index >= self.line_count:
            raise IndexError(f"Line index {index} out of range")
        start = self._line_offsets[index]
        if index + 1 < len(self._line_offsets):
            end = self._line_offsets[index + 1] - 1
        else:
            end = len(self.raw_content)
        return self.raw_content[start:end]

    @property
    def line_count(self) -> int:
        return len(self._line_offsets)


def parse_markdown(content: str) -> List[Block]:
    """
    Parse markdown content into lines for line-level commenting.
    Returns list of Block objects, one per line.
    """
    blocks = []
    lines = content.split("\n")

    for i, line in enumerate(lines):
        blocks.append(Block(id=f"line-{i}", type="line", text=line, level=0, raw=line))

    return blocks


def generate_html(
    title: str, content: str, blocks: List[Block], server_port: int
) -> str:
    """Generate the complete HTML for the review UI with marked.js and line comments."""

    # Escape content for JSON embedding
    content_json = json.dumps(content)
    lines_json = json.dumps(
        [{"id": b.id, "text": b.text, "lineNum": i} for i, b in enumerate(blocks)]
    )

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title} - Interactive Review</title>
    <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/lib/highlight.min.js"></script>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/styles/github-dark.min.css">
    <style>
        :root {{
            --bg-primary: #0d1117;
            --bg-secondary: #161b22;
            --bg-tertiary: #21262d;
            --bg-card: #1c2128;
            --text-primary: #e6edf3;
            --text-secondary: #8b949e;
            --text-muted: #6e7681;
            --accent: #58a6ff;
            --accent-hover: #79b8ff;
            --success: #3fb950;
            --warning: #d29922;
            --danger: #f85149;
            --border: #30363d;
            --border-accent: #388bfd;
            --highlight-bg: rgba(56, 139, 253, 0.15);
            --comment-bg: #2d333b;
            --selection-bg: rgba(56, 139, 253, 0.3);

            /* Extended design system */
            --surface-elevated: #1c2128;
            --surface-overlay: rgba(0, 0, 0, 0.6);
            --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.2);
            --shadow-md: 0 4px 12px rgba(0, 0, 0, 0.3);
            --shadow-lg: 0 8px 24px rgba(0, 0, 0, 0.4);

            /* Spacing */
            --space-1: 0.25rem;
            --space-2: 0.5rem;
            --space-3: 0.75rem;
            --space-4: 1rem;
            --space-6: 1.5rem;
        }}

        * {{
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }}

        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif;
            background: var(--bg-primary);
            color: var(--text-primary);
            line-height: 1.6;
            min-height: 100vh;
        }}

        .layout {{
            display: flex;
            min-height: 100vh;
        }}

        .main-content {{
            flex: 1;
            max-width: 900px;
            padding: 2rem;
            overflow-y: auto;
        }}

        .comments-sidebar {{
            width: 350px;
            background: var(--bg-secondary);
            border-left: 1px solid var(--border);
            padding: 1rem;
            overflow-y: auto;
            position: sticky;
            top: 0;
            height: 100vh;
        }}

        header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 1.5rem;
            padding-bottom: 1rem;
            border-bottom: 1px solid var(--border);
        }}

        h1 {{
            font-size: 1.5rem;
            font-weight: 600;
        }}

        .summary {{
            font-size: 0.875rem;
            color: var(--text-secondary);
        }}

        .summary .count {{
            background: var(--bg-tertiary);
            padding: 0.25rem 0.5rem;
            border-radius: 12px;
            margin-left: 0.5rem;
        }}

        /* Markdown content area */
        .markdown-container {{
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 8px;
            overflow: hidden;
        }}

        .line-wrapper {{
            display: flex;
            position: relative;
            border-bottom: 1px solid transparent;
            contain: layout style;
            will-change: background-color;
        }}

        .line-wrapper:hover {{
            background: var(--bg-tertiary);
        }}

        .line-wrapper.has-comment {{
            background: var(--highlight-bg);
            border-left: 3px solid var(--accent);
        }}

        .line-wrapper.selecting {{
            background: var(--selection-bg);
        }}

        .line-number {{
            flex-shrink: 0;
            width: 50px;
            padding: 0 12px;
            text-align: right;
            color: var(--text-muted);
            font-family: 'SF Mono', Monaco, 'Consolas', monospace;
            font-size: 12px;
            user-select: none;
            cursor: pointer;
            border-right: 1px solid var(--border);
        }}

        .line-number:hover {{
            color: var(--accent);
        }}

        .add-comment-btn {{
            position: absolute;
            left: 8px;
            top: 50%;
            transform: translateY(-50%);
            width: 22px;
            height: 22px;
            background: var(--accent);
            border: none;
            border-radius: 50%;
            color: white;
            font-size: 16px;
            font-weight: bold;
            cursor: pointer;
            opacity: 0;
            transition: opacity 0.2s;
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 10;
        }}

        .line-wrapper:hover .add-comment-btn {{
            opacity: 1;
        }}

        .line-content {{
            flex: 1;
            padding: 0 16px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif;
            font-size: 14px;
            white-space: pre-wrap;
            word-wrap: break-word;
        }}

        /* Rendered markdown styling */
        .rendered-markdown {{
            padding: 24px;
        }}

        .rendered-markdown h1,
        .rendered-markdown h2,
        .rendered-markdown h3,
        .rendered-markdown h4,
        .rendered-markdown h5,
        .rendered-markdown h6 {{
            margin-top: 24px;
            margin-bottom: 16px;
            font-weight: 600;
            line-height: 1.25;
            border-bottom: 1px solid var(--border);
            padding-bottom: 0.3em;
        }}

        .rendered-markdown h1 {{ font-size: 2em; }}
        .rendered-markdown h2 {{ font-size: 1.5em; }}
        .rendered-markdown h3 {{ font-size: 1.25em; border-bottom: none; }}
        .rendered-markdown h4 {{ font-size: 1em; border-bottom: none; }}

        .rendered-markdown p {{
            margin-bottom: 16px;
        }}

        .rendered-markdown ul,
        .rendered-markdown ol {{
            margin-bottom: 16px;
            padding-left: 2em;
        }}

        .rendered-markdown li {{
            margin-bottom: 4px;
        }}

        .rendered-markdown code {{
            background: var(--bg-tertiary);
            padding: 0.2em 0.4em;
            border-radius: 6px;
            font-family: 'SF Mono', Monaco, 'Consolas', monospace;
            font-size: 85%;
        }}

        .rendered-markdown pre {{
            background: var(--bg-tertiary);
            padding: 16px;
            border-radius: 6px;
            overflow-x: auto;
            margin-bottom: 16px;
        }}

        .rendered-markdown pre code {{
            background: none;
            padding: 0;
            font-size: 14px;
        }}

        .rendered-markdown table {{
            border-collapse: collapse;
            width: 100%;
            margin-bottom: 16px;
        }}

        .rendered-markdown th,
        .rendered-markdown td {{
            border: 1px solid var(--border);
            padding: 6px 13px;
        }}

        .rendered-markdown th {{
            background: var(--bg-tertiary);
            font-weight: 600;
        }}

        .rendered-markdown blockquote {{
            border-left: 4px solid var(--border);
            padding-left: 16px;
            color: var(--text-secondary);
            margin-bottom: 16px;
        }}

        /* Source view with line numbers - performance optimized */
        .source-view {{
            display: none;
        }}

        .source-view.active {{
            display: block;
            contain: content;
        }}

        .rendered-view {{
            display: block;
        }}

        .rendered-view.hidden {{
            display: none;
        }}

        /* View toggle */
        .view-toggle {{
            display: flex;
            gap: 0;
            margin-bottom: 1rem;
            border: 1px solid var(--border);
            border-radius: 6px;
            overflow: hidden;
            width: fit-content;
        }}

        .view-toggle button {{
            padding: 0.5rem 1rem;
            background: var(--bg-secondary);
            border: none;
            color: var(--text-secondary);
            cursor: pointer;
            font-size: 0.875rem;
            transition: all 0.2s;
        }}

        .view-toggle button:not(:last-child) {{
            border-right: 1px solid var(--border);
        }}

        .view-toggle button.active {{
            background: var(--accent);
            color: white;
        }}

        .view-toggle button:hover:not(.active) {{
            background: var(--bg-tertiary);
        }}

        /* Comments sidebar */
        .sidebar-header {{
            font-size: 0.875rem;
            font-weight: 600;
            color: var(--text-secondary);
            margin-bottom: 1rem;
            padding-bottom: 0.5rem;
            border-bottom: 1px solid var(--border);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }}

        .comment-card {{
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: 8px;
            margin-bottom: 1rem;
            overflow: hidden;
        }}

        .comment-card.editing {{
            border-color: var(--accent);
        }}

        .comment-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 0.75rem;
            background: var(--bg-tertiary);
            font-size: 0.75rem;
            color: var(--text-secondary);
        }}

        .comment-lines {{
            font-family: 'SF Mono', Monaco, monospace;
            color: var(--accent);
        }}

        .comment-preview {{
            padding: 0.75rem;
            font-size: 0.875rem;
            background: var(--bg-primary);
            border-bottom: 1px solid var(--border);
            color: var(--text-muted);
            font-family: 'SF Mono', Monaco, monospace;
            max-height: 60px;
            overflow: hidden;
            white-space: pre-wrap;
        }}

        .comment-body {{
            padding: 0.75rem;
        }}

        .comment-textarea {{
            width: 100%;
            min-height: 80px;
            padding: 0.75rem;
            background: var(--bg-primary);
            border: 1px solid var(--border);
            border-radius: 6px;
            color: var(--text-primary);
            font-size: 0.875rem;
            resize: vertical;
            font-family: inherit;
        }}

        .comment-textarea:focus {{
            outline: none;
            border-color: var(--accent);
        }}

        .comment-textarea::placeholder {{
            color: var(--text-muted);
        }}

        .comment-textarea.saved {{
            border-color: var(--success);
            transition: border-color 0.3s;
        }}

        .save-indicator {{
            font-size: 0.7rem;
            color: var(--success);
            opacity: 0;
            transition: opacity 0.2s;
            margin-top: 0.25rem;
        }}

        .save-indicator.visible {{
            opacity: 1;
        }}

        .comment-actions {{
            display: flex;
            justify-content: flex-end;
            gap: 0.5rem;
            margin-top: 0.5rem;
        }}

        .comment-text {{
            font-size: 0.875rem;
            line-height: 1.5;
            white-space: pre-wrap;
        }}

        .comment-text.empty {{
            color: var(--text-muted);
            font-style: italic;
        }}

        .no-comments {{
            text-align: center;
            color: var(--text-muted);
            padding: 2rem;
            font-size: 0.875rem;
        }}

        /* Inline comment box (appears when selecting lines) */
        .inline-comment-box {{
            display: none;
            background: var(--bg-card);
            border: 1px solid var(--accent);
            border-radius: 8px;
            margin: 0.5rem 0;
            overflow: hidden;
        }}

        .inline-comment-box.visible {{
            display: block;
        }}

        .inline-comment-header {{
            padding: 0.5rem 0.75rem;
            background: var(--bg-tertiary);
            font-size: 0.75rem;
            color: var(--text-secondary);
            border-bottom: 1px solid var(--border);
        }}

        .inline-comment-body {{
            padding: 0.75rem;
        }}

        /* Actions bar */
        .actions {{
            display: flex;
            gap: 1rem;
            justify-content: space-between;
            align-items: center;
            margin-top: 1.5rem;
            padding-top: 1rem;
            border-top: 1px solid var(--border);
        }}

        .action-group {{
            display: flex;
            gap: 0.5rem;
        }}

        button {{
            padding: 0.5rem 1rem;
            border: none;
            border-radius: 6px;
            font-size: 0.875rem;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.2s;
        }}

        .btn-sm {{
            padding: 0.25rem 0.5rem;
            font-size: 0.75rem;
        }}

        .btn-secondary {{
            background: var(--bg-tertiary);
            color: var(--text-primary);
            border: 1px solid var(--border);
        }}

        .btn-secondary:hover {{
            background: var(--border);
        }}

        .btn-success {{
            background: var(--success);
            color: white;
        }}

        .btn-success:hover {{
            opacity: 0.9;
        }}

        .btn-danger {{
            background: transparent;
            color: var(--danger);
            border: 1px solid var(--danger);
        }}

        .btn-danger:hover {{
            background: var(--danger);
            color: white;
        }}

        .btn-primary {{
            background: var(--accent);
            color: white;
        }}

        .btn-primary:hover {{
            background: var(--accent-hover);
        }}

        .keyboard-hint {{
            font-size: 0.75rem;
            color: var(--text-muted);
        }}

        kbd {{
            background: var(--bg-tertiary);
            padding: 0.2rem 0.4rem;
            border-radius: 4px;
            font-family: inherit;
            border: 1px solid var(--border);
            font-size: 0.7rem;
        }}

        /* Selection highlight */
        .selection-indicator {{
            position: fixed;
            bottom: 20px;
            left: 50%;
            transform: translateX(-50%);
            background: var(--accent);
            color: white;
            padding: 0.75rem 1.5rem;
            border-radius: 8px;
            display: none;
            align-items: center;
            gap: 1rem;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
            z-index: 1000;
        }}

        .selection-indicator.visible {{
            display: flex;
        }}

        /* Delete button for comments */
        .delete-comment {{
            background: none;
            border: none;
            color: var(--text-muted);
            cursor: pointer;
            padding: 0.25rem;
            font-size: 1rem;
            line-height: 1;
        }}

        .delete-comment:hover {{
            color: var(--danger);
        }}

        /* Accessibility: Focus styles */
        :focus-visible {{
            outline: 2px solid var(--accent);
            outline-offset: 2px;
        }}

        button:focus-visible {{
            outline: 2px solid var(--accent);
            outline-offset: 2px;
        }}

        textarea:focus-visible,
        input:focus-visible {{
            outline: none;
            border-color: var(--accent);
            box-shadow: 0 0 0 3px rgba(88, 166, 255, 0.2);
        }}

        /* Accessibility: High contrast mode */
        @media (prefers-contrast: more) {{
            :root {{
                --text-primary: #ffffff;
                --text-secondary: #d0d0d0;
                --text-muted: #a0a0a0;
                --accent: #0096ff;
                --border: #555555;
            }}
        }}

        /* Accessibility: Reduced motion */
        @media (prefers-reduced-motion: reduce) {{
            *,
            *::before,
            *::after {{
                animation-duration: 0.01ms !important;
                animation-iteration-count: 1 !important;
                transition-duration: 0.01ms !important;
            }}
        }}

        /* Accessibility: Skip link */
        .skip-link {{
            position: absolute;
            top: -40px;
            left: 0;
            background: var(--accent);
            color: white;
            padding: 8px 16px;
            z-index: 9999;
            transition: top 0.2s;
        }}

        .skip-link:focus {{
            top: 0;
        }}

        /* Floating comment toolbar for text selection */
        .floating-toolbar {{
            position: fixed;
            background: var(--bg-card);
            border: 1px solid var(--accent);
            border-radius: 8px;
            padding: 0.5rem;
            box-shadow: 0 4px 16px rgba(0, 0, 0, 0.5);
            z-index: 1000;
            display: none;
            align-items: center;
            gap: 0.5rem;
            animation: fadeIn 0.15s ease-out;
        }}

        @keyframes fadeIn {{
            from {{ opacity: 0; transform: translateY(-4px); }}
            to {{ opacity: 1; transform: translateY(0); }}
        }}

        .floating-toolbar.visible {{
            display: flex;
        }}

        .floating-toolbar button {{
            padding: 0.4rem 0.75rem;
            font-size: 0.8rem;
        }}

        /* Highlighted text in preview */
        .commented-text {{
            background: var(--highlight-bg);
            border-bottom: 2px solid var(--accent);
            cursor: pointer;
            padding: 0 2px;
            border-radius: 2px;
        }}

        .commented-text:hover {{
            background: var(--selection-bg);
        }}

        /* Modal overlay and dialog */
        .modal-overlay {{
            position: fixed;
            inset: 0;
            background: var(--surface-overlay);
            display: none;
            align-items: center;
            justify-content: center;
            z-index: 2000;
        }}

        .modal-overlay.visible {{
            display: flex;
        }}

        .comment-modal {{
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: 12px;
            width: min(600px, 90vw);
            max-height: 90vh;
            box-shadow: var(--shadow-lg);
            animation: modalFadeIn 0.2s ease-out;
        }}

        @keyframes modalFadeIn {{
            from {{ opacity: 0; transform: scale(0.95); }}
            to {{ opacity: 1; transform: scale(1); }}
        }}

        .modal-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: var(--space-4) var(--space-6);
            border-bottom: 1px solid var(--border);
        }}

        .modal-header h3 {{
            font-size: 1.125rem;
            font-weight: 600;
        }}

        .modal-close {{
            background: none;
            border: none;
            color: var(--text-secondary);
            font-size: 1.5rem;
            cursor: pointer;
            padding: var(--space-1);
            line-height: 1;
        }}

        .modal-close:hover {{
            color: var(--text-primary);
        }}

        .modal-body {{
            padding: var(--space-6);
        }}

        .selected-text-preview {{
            margin-bottom: var(--space-4);
        }}

        .selected-text-preview label {{
            display: block;
            font-size: 0.875rem;
            color: var(--text-secondary);
            margin-bottom: var(--space-2);
        }}

        .selected-text-preview pre {{
            background: var(--bg-primary);
            border: 1px solid var(--border);
            border-radius: 6px;
            padding: var(--space-3);
            font-family: 'SF Mono', Monaco, monospace;
            font-size: 0.8125rem;
            max-height: 120px;
            overflow: auto;
            white-space: pre-wrap;
            color: var(--text-muted);
        }}

        .comment-input-area label {{
            display: block;
            font-size: 0.875rem;
            color: var(--text-secondary);
            margin-bottom: var(--space-2);
        }}

        .comment-input-area textarea {{
            width: 100%;
            min-height: 120px;
            padding: var(--space-3);
            background: var(--bg-primary);
            border: 1px solid var(--border);
            border-radius: 6px;
            color: var(--text-primary);
            font-size: 0.875rem;
            resize: vertical;
            font-family: inherit;
        }}

        .comment-input-area textarea:focus {{
            outline: none;
            border-color: var(--accent);
            box-shadow: 0 0 0 3px rgba(88, 166, 255, 0.2);
        }}

        .modal-hint {{
            margin-top: var(--space-3);
            font-size: 0.75rem;
            color: var(--text-muted);
        }}

        .modal-footer {{
            display: flex;
            justify-content: flex-end;
            gap: var(--space-3);
            padding: var(--space-4) var(--space-6);
            border-top: 1px solid var(--border);
        }}

        /* Responsive */
        @media (max-width: 1200px) {{
            .comments-sidebar {{
                width: 300px;
            }}
        }}

        @media (max-width: 900px) {{
            .layout {{
                flex-direction: column;
            }}

            .comments-sidebar {{
                width: 100%;
                height: auto;
                position: static;
                border-left: none;
                border-top: 1px solid var(--border);
            }}
        }}
    </style>
</head>
<body>
    <a href="#main-content" class="skip-link">Skip to main content</a>
    <div class="layout">
        <div class="main-content" id="main-content">
            <header>
                <h1>{title}</h1>
                <div class="summary">
                    Comments: <span class="count" id="comment-count">0</span>
                </div>
            </header>

            <div class="view-toggle">
                <button class="active" onclick="switchView('rendered')">Preview</button>
                <button onclick="switchView('source')">Source</button>
            </div>

            <div class="markdown-container">
                <div class="rendered-view" id="rendered-view">
                    <div class="rendered-markdown" id="rendered-content"></div>
                </div>
                <div class="source-view" id="source-view"></div>
            </div>

            <div class="actions">
                <div class="keyboard-hint">
                    <kbd>Cmd</kbd>+<kbd>Enter</kbd> submit | <kbd>Esc</kbd> cancel
                </div>
                <div class="action-group">
                    <button class="btn-secondary" onclick="cancelReview()">Cancel</button>
                    <button class="btn-primary" onclick="submitReview()">Submit Review</button>
                </div>
            </div>
        </div>

        <div class="comments-sidebar">
            <div class="sidebar-header">
                <span>Comments</span>
                <button class="btn-sm btn-secondary" onclick="clearAllComments()" aria-label="Clear all comments">Clear All</button>
            </div>
            <div id="comments-list" role="region" aria-live="polite" aria-label="Comments list">
                <div class="no-comments">
                    Click on a line number or select text to add comments
                </div>
            </div>
        </div>
    </div>

    <div class="selection-indicator" id="selection-indicator">
        <span id="selection-text">Lines 1-3 selected</span>
        <button class="btn-sm btn-primary" onclick="addCommentForSelection()">Add Comment</button>
        <button class="btn-sm btn-secondary" onclick="clearSelection()">Cancel</button>
    </div>

    <div class="floating-toolbar" id="floating-toolbar">
        <span style="color: var(--text-secondary); font-size: 0.75rem; margin-right: 0.5rem;">💬</span>
        <button class="btn-sm btn-primary" onclick="openCommentModalForTextSelection()">Comment</button>
    </div>

    <!-- Comment Modal Dialog -->
    <div class="modal-overlay" id="comment-modal-overlay">
        <div class="comment-modal" role="dialog" aria-modal="true" aria-labelledby="modal-title">
            <div class="modal-header">
                <h3 id="modal-title">Add Comment</h3>
                <button class="modal-close" aria-label="Close modal">&times;</button>
            </div>
            <div class="modal-body">
                <div class="selected-text-preview">
                    <label>Selected Text:</label>
                    <pre id="modal-preview-text"></pre>
                </div>
                <div class="comment-input-area">
                    <label for="modal-comment-textarea">Your Comment:</label>
                    <textarea id="modal-comment-textarea"
                              placeholder="Enter your comment..."
                              rows="5"></textarea>
                </div>
                <div class="modal-hint">
                    <kbd>Cmd</kbd>+<kbd>Enter</kbd> to save, <kbd>Esc</kbd> to cancel
                </div>
            </div>
            <div class="modal-footer">
                <button class="btn-secondary" id="modal-cancel-btn">Cancel</button>
                <button class="btn-primary" id="modal-save-btn">Save Comment</button>
            </div>
        </div>
    </div>

    <script>
        const rawContent = {content_json};
        const lines = {lines_json};
        const serverPort = {server_port};

        // State
        let comments = []; // {{ id, startLine, endLine, text, linePreview, type }}
        let selectionStart = null;
        let selectionEnd = null;
        let currentView = 'rendered';
        let commentIdCounter = 0;
        let selectedText = '';
        let selectionRange = null;
        let isSelecting = false;

        // Modal state
        let modalContext = null; // {{ type: 'line'|'text', startLine, endLine, selectedText, range, preview }}

        // Comment index for O(1) lookup
        class CommentIndex {{
            constructor() {{
                this.lineToComments = new Map();
            }}

            rebuild(commentsList) {{
                this.lineToComments.clear();
                commentsList.forEach(comment => {{
                    if (comment.type !== 'line') return;
                    for (let i = comment.startLine; i <= comment.endLine; i++) {{
                        if (!this.lineToComments.has(i)) {{
                            this.lineToComments.set(i, new Set());
                        }}
                        this.lineToComments.get(i).add(comment.id);
                    }}
                }});
            }}

            hasCommentOnLine(lineIndex) {{
                return this.lineToComments.has(lineIndex);
            }}
        }}

        const commentIndex = new CommentIndex();

        // Debounce utility
        function debounce(fn, delay) {{
            let timer = null;
            return function(...args) {{
                clearTimeout(timer);
                timer = setTimeout(() => fn.apply(this, args), delay);
            }};
        }}

        // Initialize marked
        marked.setOptions({{
            highlight: function(code, lang) {{
                if (lang && hljs.getLanguage(lang)) {{
                    return hljs.highlight(code, {{ language: lang }}).value;
                }}
                return hljs.highlightAuto(code).value;
            }},
            breaks: false,
            gfm: true
        }});

        function init() {{
            // Render markdown preview
            document.getElementById('rendered-content').innerHTML = marked.parse(rawContent);

            // Render source view with line numbers
            renderSourceView();

            // Apply syntax highlighting to rendered code blocks
            document.querySelectorAll('.rendered-markdown pre code').forEach(block => {{
                hljs.highlightElement(block);
            }});

            // Setup text selection handler for preview (with debouncing)
            setupTextSelectionHandler();

            // Setup event delegation for source view (performance optimization)
            setupSourceViewEventDelegation();

            // Setup modal event listeners
            setupModalEventListeners();

            // Setup sidebar event delegation
            setupSidebarEventDelegation();
        }}

        // Text selection in Preview view (with debouncing)
        function setupTextSelectionHandler() {{
            const renderedContent = document.getElementById('rendered-content');
            const floatingToolbar = document.getElementById('floating-toolbar');

            const handleSelection = debounce(() => {{
                const selection = window.getSelection();
                const text = selection.toString().trim();

                if (text && text.length > 0) {{
                    selectedText = text;
                    try {{
                        selectionRange = selection.getRangeAt(0).cloneRange();

                        // Position floating toolbar near selection (fixed positioning)
                        const rect = selection.getRangeAt(0).getBoundingClientRect();
                        const top = rect.bottom + 8;
                        const left = Math.max(10, rect.left + (rect.width / 2) - 50);

                        floatingToolbar.style.top = `${{top}}px`;
                        floatingToolbar.style.left = `${{left}}px`;
                        floatingToolbar.classList.add('visible');
                    }} catch (err) {{
                        console.log('Selection error:', err);
                    }}
                }} else {{
                    hideFloatingToolbar();
                }}
            }}, 100);

            renderedContent.addEventListener('mouseup', handleSelection);

            // Hide toolbar when clicking elsewhere
            document.addEventListener('mousedown', (e) => {{
                if (!floatingToolbar.contains(e.target) && !renderedContent.contains(e.target)) {{
                    hideFloatingToolbar();
                }}
            }});
        }}

        function setupSourceViewEventDelegation() {{
            const sourceView = document.getElementById('source-view');

            // Single mousedown handler for all line interactions
            sourceView.addEventListener('mousedown', (e) => {{
                const wrapper = e.target.closest('.line-wrapper');
                if (!wrapper) return;

                const index = parseInt(wrapper.dataset.lineIndex, 10);

                // Handle add-comment button click
                if (e.target.matches('.add-comment-btn') || e.target.closest('.add-comment-btn')) {{
                    e.stopPropagation();
                    quickAddComment(index);
                    return;
                }}

                // Start line selection
                startLineSelection(index);
            }});

            // Mouseenter for extending selection (use capture for better performance)
            sourceView.addEventListener('mouseenter', (e) => {{
                const wrapper = e.target.closest('.line-wrapper');
                if (wrapper && isSelecting) {{
                    const index = parseInt(wrapper.dataset.lineIndex, 10);
                    extendLineSelection(index);
                }}
            }}, true);
        }}

        // Sidebar event delegation (remove inline onclick handlers)
        function setupSidebarEventDelegation() {{
            const commentsList = document.getElementById('comments-list');

            commentsList.addEventListener('click', (e) => {{
                const deleteBtn = e.target.closest('.delete-comment');
                if (deleteBtn) {{
                    const card = deleteBtn.closest('.comment-card');
                    if (card) {{
                        const commentId = card.dataset.commentId;
                        deleteComment(commentId);
                    }}
                }}
            }});
        }}

        // Modal functions
        function openCommentModal(context) {{
            modalContext = context;
            const overlay = document.getElementById('comment-modal-overlay');
            const previewEl = document.getElementById('modal-preview-text');
            const textarea = document.getElementById('modal-comment-textarea');

            // Set preview text
            previewEl.textContent = context.preview || context.selectedText || '';
            textarea.value = '';

            // Show modal
            overlay.classList.add('visible');

            // Focus trap setup - delay focus for animation
            setTimeout(() => textarea.focus(), 50);
        }}

        function closeCommentModal() {{
            const overlay = document.getElementById('comment-modal-overlay');
            overlay.classList.remove('visible');
            modalContext = null;
        }}

        function saveModalComment() {{
            if (!modalContext) return;

            const textarea = document.getElementById('modal-comment-textarea');
            const commentText = textarea.value.trim();

            const comment = {{
                id: `comment-${{commentIdCounter++}}`,
                type: modalContext.type,
                startLine: modalContext.startLine,
                endLine: modalContext.endLine,
                text: commentText,
                linePreview: modalContext.preview,
                selectedText: modalContext.selectedText
            }};

            comments.push(comment);

            // Highlight text in preview (text type only)
            if (modalContext.type === 'text' && modalContext.range) {{
                highlightTextInPreview(modalContext.range, comment.id);
            }}

            closeCommentModal();
            clearSelection();
            window.getSelection().removeAllRanges();
            selectedText = '';
            selectionRange = null;
            renderComments();
            renderSourceView();
        }}

        function setupModalEventListeners() {{
            const overlay = document.getElementById('comment-modal-overlay');
            const closeBtn = overlay.querySelector('.modal-close');
            const cancelBtn = document.getElementById('modal-cancel-btn');
            const saveBtn = document.getElementById('modal-save-btn');
            const textarea = document.getElementById('modal-comment-textarea');

            // Close buttons
            closeBtn.addEventListener('click', closeCommentModal);
            cancelBtn.addEventListener('click', closeCommentModal);
            saveBtn.addEventListener('click', saveModalComment);

            // Close on overlay click
            overlay.addEventListener('click', (e) => {{
                if (e.target === overlay) closeCommentModal();
            }});

            // Keyboard shortcuts
            textarea.addEventListener('keydown', (e) => {{
                if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {{
                    e.preventDefault();
                    saveModalComment();
                }} else if (e.key === 'Escape') {{
                    e.preventDefault();
                    closeCommentModal();
                }}
            }});

            // Focus trap
            overlay.addEventListener('keydown', (e) => {{
                if (e.key === 'Tab') {{
                    const focusables = overlay.querySelectorAll('button, textarea');
                    const first = focusables[0];
                    const last = focusables[focusables.length - 1];

                    if (e.shiftKey && document.activeElement === first) {{
                        e.preventDefault();
                        last.focus();
                    }} else if (!e.shiftKey && document.activeElement === last) {{
                        e.preventDefault();
                        first.focus();
                    }}
                }}
            }});
        }}

        // Open modal for text selection (from floating toolbar)
        function openCommentModalForTextSelection() {{
            if (!selectedText) return;

            const preview = selectedText.length > 100 ? selectedText.substring(0, 100) + '...' : selectedText;

            openCommentModal({{
                type: 'text',
                startLine: null,
                endLine: null,
                selectedText: selectedText,
                range: selectionRange,
                preview: preview
            }});

            hideFloatingToolbar();
        }}

        function hideFloatingToolbar() {{
            const floatingToolbar = document.getElementById('floating-toolbar');
            floatingToolbar.classList.remove('visible');
        }}

        function highlightTextInPreview(range, commentId) {{
            if (!range) return null;

            const textNodes = getTextNodesInRange(range);
            if (textNodes.length === 0) {{
                // Fallback: try original surroundContents
                try {{
                    const span = document.createElement('span');
                    span.className = 'commented-text';
                    span.dataset.commentId = commentId;
                    span.onclick = () => scrollToComment(commentId);
                    range.surroundContents(span);
                    return [span];
                }} catch (e) {{
                    console.log('Could not highlight selection:', e);
                    return null;
                }}
            }}

            const highlights = [];

            textNodes.forEach((node, index) => {{
                const nodeRange = document.createRange();

                // First node: start from selection startOffset
                if (index === 0) {{
                    nodeRange.setStart(node, Math.min(range.startOffset, node.length));
                }} else {{
                    nodeRange.setStart(node, 0);
                }}

                // Last node: end at selection endOffset
                if (index === textNodes.length - 1) {{
                    nodeRange.setEnd(node, Math.min(range.endOffset, node.length));
                }} else {{
                    nodeRange.setEnd(node, node.length);
                }}

                // Skip empty ranges
                if (nodeRange.toString().length === 0) return;

                const span = document.createElement('span');
                span.className = 'commented-text';
                span.dataset.commentId = commentId;
                span.dataset.highlightGroup = commentId;
                span.onclick = () => scrollToComment(commentId);

                try {{
                    nodeRange.surroundContents(span);
                    highlights.push(span);
                }} catch (e) {{
                    console.warn('Highlight failed for node:', e);
                }}
            }});

            return highlights.length > 0 ? highlights : null;
        }}

        function getTextNodesInRange(range) {{
            const textNodes = [];

            // Handle case where commonAncestorContainer is a text node
            const container = range.commonAncestorContainer.nodeType === Node.TEXT_NODE
                ? range.commonAncestorContainer.parentNode
                : range.commonAncestorContainer;

            const walker = document.createTreeWalker(
                container,
                NodeFilter.SHOW_TEXT,
                {{
                    acceptNode: (node) => {{
                        // Skip empty text nodes
                        if (!node.textContent.trim() && node.textContent.length === 0) {{
                            return NodeFilter.FILTER_REJECT;
                        }}

                        const nodeRange = document.createRange();
                        nodeRange.selectNodeContents(node);

                        // Check if node overlaps with selection range
                        const startsBeforeEnd = range.compareBoundaryPoints(Range.END_TO_START, nodeRange) <= 0;
                        const endsAfterStart = range.compareBoundaryPoints(Range.START_TO_END, nodeRange) >= 0;

                        if (startsBeforeEnd && endsAfterStart) {{
                            return NodeFilter.FILTER_ACCEPT;
                        }}
                        return NodeFilter.FILTER_REJECT;
                    }}
                }}
            );

            let node;
            while ((node = walker.nextNode())) {{
                textNodes.push(node);
            }}

            return textNodes;
        }}

        function scrollToComment(commentId) {{
            const commentCard = document.querySelector(`[data-comment-id="${{commentId}}"]`);
            if (commentCard) {{
                commentCard.scrollIntoView({{ behavior: 'smooth', block: 'center' }});
                commentCard.style.borderColor = 'var(--accent)';
                setTimeout(() => commentCard.style.borderColor = '', 1500);
            }}
        }}

        function renderSourceView() {{
            const container = document.getElementById('source-view');
            commentIndex.rebuild(comments);

            container.innerHTML = lines.map((line, index) => {{
                const hasComment = commentIndex.hasCommentOnLine(index);
                const isSelectingLine = selectionStart !== null &&
                    index >= Math.min(selectionStart, selectionEnd || selectionStart) &&
                    index <= Math.max(selectionStart, selectionEnd || selectionStart);

                return `
                    <div class="line-wrapper ${{hasComment ? 'has-comment' : ''}} ${{isSelectingLine ? 'selecting' : ''}}"
                         data-line-index="${{index}}">
                        <button class="add-comment-btn" data-action="add-comment" title="Add comment" aria-label="Add comment to line ${{index + 1}}">+</button>
                        <div class="line-number">${{index + 1}}</div>
                        <div class="line-content">${{escapeHtml(line.text) || '&nbsp;'}}</div>
                    </div>
                `;
            }}).join('');
        }}

        // Targeted DOM update (avoids full re-render)
        function updateLineStates() {{
            commentIndex.rebuild(comments);
            document.querySelectorAll('.line-wrapper').forEach(wrapper => {{
                const index = parseInt(wrapper.dataset.lineIndex, 10);
                const hasComment = commentIndex.hasCommentOnLine(index);
                const isSelectingLine = selectionStart !== null &&
                    index >= Math.min(selectionStart, selectionEnd || selectionStart) &&
                    index <= Math.max(selectionStart, selectionEnd || selectionStart);

                wrapper.classList.toggle('has-comment', hasComment);
                wrapper.classList.toggle('selecting', isSelectingLine);
            }});
        }}

        function escapeHtml(text) {{
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }}

        function switchView(view) {{
            currentView = view;
            document.querySelectorAll('.view-toggle button').forEach(btn => btn.classList.remove('active'));
            document.querySelector(`.view-toggle button[onclick="switchView('${{view}}')"]`).classList.add('active');

            if (view === 'rendered') {{
                document.getElementById('rendered-view').classList.remove('hidden');
                document.getElementById('source-view').classList.remove('active');
            }} else {{
                document.getElementById('rendered-view').classList.add('hidden');
                document.getElementById('source-view').classList.add('active');
            }}
        }}

        // Line selection
        function startLineSelection(lineNum) {{
            isSelecting = true;
            selectionStart = lineNum;
            selectionEnd = lineNum;
            updateLineStates();
        }}

        function extendLineSelection(lineNum) {{
            if (isSelecting && selectionStart !== null) {{
                selectionEnd = lineNum;
                updateLineStates();
                updateSelectionIndicator();
            }}
        }}

        document.addEventListener('mouseup', () => {{
            if (isSelecting && selectionStart !== null) {{
                isSelecting = false;
                if (selectionEnd === null) selectionEnd = selectionStart;
                updateSelectionIndicator();
            }}
        }});

        function updateSelectionIndicator() {{
            const indicator = document.getElementById('selection-indicator');
            if (selectionStart !== null) {{
                const start = Math.min(selectionStart, selectionEnd || selectionStart);
                const end = Math.max(selectionStart, selectionEnd || selectionStart);
                document.getElementById('selection-text').textContent =
                    start === end ? `Line ${{start + 1}} selected` : `Lines ${{start + 1}}-${{end + 1}} selected`;
                indicator.classList.add('visible');
            }} else {{
                indicator.classList.remove('visible');
            }}
        }}

        function clearSelection() {{
            selectionStart = null;
            selectionEnd = null;
            document.getElementById('selection-indicator').classList.remove('visible');
            updateLineStates();
        }}

        function quickAddComment(lineNum) {{
            selectionStart = lineNum;
            selectionEnd = lineNum;
            addCommentForSelection();
        }}

        function addCommentForSelection() {{
            if (selectionStart === null) return;

            const start = Math.min(selectionStart, selectionEnd || selectionStart);
            const end = Math.max(selectionStart, selectionEnd || selectionStart);

            // Get preview text
            const previewLines = lines.slice(start, end + 1).map(l => l.text);
            const preview = previewLines.join('\\n').substring(0, 100) + (previewLines.join('\\n').length > 100 ? '...' : '');

            // Open modal instead of directly adding comment
            openCommentModal({{
                type: 'line',
                startLine: start,
                endLine: end,
                selectedText: null,
                range: null,
                preview: preview
            }});
        }}

        function renderComments() {{
            const container = document.getElementById('comments-list');

            if (comments.length === 0) {{
                container.innerHTML = '<div class="no-comments">Select text in Preview or click lines in Source to add comments</div>';
            }} else {{
                container.innerHTML = comments.map(comment => {{
                    const headerLabel = comment.type === 'text'
                        ? 'Selected text'
                        : (comment.startLine === comment.endLine
                            ? `Line ${{comment.startLine + 1}}`
                            : `Lines ${{comment.startLine + 1}}-${{comment.endLine + 1}}`);

                    return `
                        <div class="comment-card" data-comment-id="${{comment.id}}">
                            <div class="comment-header">
                                <span class="comment-lines">${{headerLabel}}</span>
                                <button class="delete-comment" title="Delete comment" aria-label="Delete comment">&times;</button>
                            </div>
                            <div class="comment-preview">${{escapeHtml(comment.linePreview)}}</div>
                            <div class="comment-body">
                                ${{comment.text
                                    ? `<div class="comment-text">${{escapeHtml(comment.text)}}</div>`
                                    : `<div class="comment-text empty">(no comment)</div>`
                                }}
                            </div>
                        </div>
                    `;
                }}).join('');
            }}

            updateCommentCount();
        }}

        function updateCommentText(commentId, text) {{
            const comment = comments.find(c => c.id === commentId);
            if (comment) {{
                comment.text = text;
            }}
        }}

        function deleteComment(commentId) {{
            // Remove all highlight spans from preview if it's a text comment
            const highlightedSpans = document.querySelectorAll(`.commented-text[data-comment-id="${{commentId}}"]`);
            highlightedSpans.forEach(span => {{
                const parent = span.parentNode;
                while (span.firstChild) {{
                    parent.insertBefore(span.firstChild, span);
                }}
                parent.removeChild(span);
            }});

            comments = comments.filter(c => c.id !== commentId);
            renderComments();
            updateLineStates();
        }}

        function clearAllComments() {{
            if (comments.length > 0 && confirm('Delete all comments?')) {{
                // Remove all highlights from preview
                document.querySelectorAll('.commented-text').forEach(span => {{
                    const parent = span.parentNode;
                    while (span.firstChild) {{
                        parent.insertBefore(span.firstChild, span);
                    }}
                    parent.removeChild(span);
                }});

                comments = [];
                renderComments();
                updateLineStates();
            }}
        }}

        function updateCommentCount() {{
            document.getElementById('comment-count').textContent = comments.length;
        }}

        function scrollToLine(lineNum) {{
            switchView('source');
            const lineEl = document.querySelector(`[data-line="${{lineNum}}"]`);
            if (lineEl) {{
                lineEl.scrollIntoView({{ behavior: 'smooth', block: 'center' }});
                lineEl.style.background = 'var(--selection-bg)';
                setTimeout(() => lineEl.style.background = '', 1000);
            }}
        }}

        async function submitReview() {{
            const result = {{
                status: 'submitted',
                timestamp: new Date().toISOString(),
                items: comments.map(c => ({{
                    id: c.id,
                    startLine: c.startLine,
                    endLine: c.endLine,
                    text: c.text,
                    linePreview: c.linePreview,
                    checked: true,
                    comment: c.text
                }}))
            }};

            try {{
                await fetch(`http://localhost:${{serverPort}}/submit`, {{
                    method: 'POST',
                    headers: {{ 'Content-Type': 'application/json' }},
                    body: JSON.stringify(result)
                }});
                window.close();
            }} catch (e) {{
                alert('Failed to submit review. Please try again.');
                console.error(e);
            }}
        }}

        async function cancelReview() {{
            try {{
                await fetch(`http://localhost:${{serverPort}}/submit`, {{
                    method: 'POST',
                    headers: {{ 'Content-Type': 'application/json' }},
                    body: JSON.stringify({{ status: 'cancelled', items: [] }})
                }});
                window.close();
            }} catch (e) {{
                window.close();
            }}
        }}

        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {{
            // Check if modal is open
            const modalOverlay = document.getElementById('comment-modal-overlay');
            if (modalOverlay && modalOverlay.classList.contains('visible')) {{
                // Let modal handle its own keyboard events
                return;
            }}

            if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {{
                e.preventDefault();
                submitReview();
            }}
            if (e.key === 'Escape') {{
                if (selectionStart !== null) {{
                    clearSelection();
                }} else {{
                    cancelReview();
                }}
            }}
        }});

        // Initialize
        init();
    </script>
</body>
</html>"""
