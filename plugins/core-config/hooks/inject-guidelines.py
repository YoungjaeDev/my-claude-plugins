#!/usr/bin/env python3
"""UserPromptSubmit Hook: Auto-inject guidelines on every prompt.

Cross-platform compatible (Windows/Linux/macOS).
"""

import os
import sys
from pathlib import Path


def main():
    """Inject work guidelines as system-reminder."""
    # Plugin root directory (provided by Claude Code or fallback)
    plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT")
    if not plugin_root:
        plugin_root = Path(__file__).parent.parent
    else:
        plugin_root = Path(plugin_root)

    guidelines_dir = plugin_root / "guidelines"
    primary_guideline = guidelines_dir / "work-guidelines.md"

    if primary_guideline.is_file():
        try:
            content = primary_guideline.read_text(encoding="utf-8")
            print("<system-reminder>")
            print(
                'Called the Read tool with the following input: {"file_path":"work-guidelines.md"}'
            )
            print("</system-reminder>")
            print("<system-reminder>")
            print("Result of calling the Read tool:")
            print(content)
            print("</system-reminder>")
        except Exception:
            pass

    sys.exit(0)


if __name__ == "__main__":
    main()
