#!/usr/bin/env python3
"""Auto-fix Python files with ruff after Write/Edit operations."""

import json
import sys
import subprocess
import os
import shutil


def _ruff_cmd():
    """Resolve a runnable ruff invocation, or None if unavailable.

    Prefers a ruff on PATH (works everywhere ruff is installed); falls back to
    `uv run ruff` only when uv itself is present. Returning None lets the caller
    report the miss once instead of silently formatting nothing — the previous
    code hard-coded `uv run` and swallowed FileNotFoundError, so with uv absent
    the advertised auto-format was a permanent silent no-op.
    """
    if shutil.which("ruff"):
        return ["ruff"]
    if shutil.which("uv"):
        return ["uv", "run", "ruff"]
    return None


def main():
    """Main hook handler."""
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    file_path = data.get("tool_input", {}).get("file_path")
    if not file_path:
        sys.exit(0)

    # Only process Python files
    if not file_path.endswith((".py", ".pyi")):
        sys.exit(0)

    # Skip if file doesn't exist
    if not os.path.isfile(file_path):
        sys.exit(0)

    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())

    ruff = _ruff_cmd()
    if ruff is None:
        # Surface the miss once instead of silently doing nothing — otherwise the
        # user and the agent both believe files are being formatted when they are not.
        print(
            "auto-format-python: neither `ruff` nor `uv` found on PATH — "
            "skipping format (install ruff to enable this hook)",
            file=sys.stderr,
        )
        sys.exit(0)

    try:
        # Lint fix
        subprocess.run(
            [*ruff, "check", "--fix", file_path],
            cwd=project_dir,
            capture_output=True,
            timeout=30,
        )
        # Format
        subprocess.run(
            [*ruff, "format", file_path],
            cwd=project_dir,
            capture_output=True,
            timeout=30,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    sys.exit(0)


if __name__ == "__main__":
    main()
