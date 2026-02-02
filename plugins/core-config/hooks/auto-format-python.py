#!/usr/bin/env python3
"""Auto-fix Python files with ruff after Write/Edit operations."""

import json
import sys
import subprocess
import os


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

    try:
        # Lint fix
        subprocess.run(
            ["uv", "run", "ruff", "check", "--fix", file_path],
            cwd=project_dir,
            capture_output=True,
            timeout=30,
        )
        # Format
        subprocess.run(
            ["uv", "run", "ruff", "format", file_path],
            cwd=project_dir,
            capture_output=True,
            timeout=30,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    sys.exit(0)


if __name__ == "__main__":
    main()
