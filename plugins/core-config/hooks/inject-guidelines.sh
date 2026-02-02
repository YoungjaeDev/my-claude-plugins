#!/bin/bash
# UserPromptSubmit Hook: Auto-inject guidelines on every prompt
# Location: plugins/core-config/hooks/inject-guidelines.sh

set -e

# Plugin root directory (provided by Claude Code)
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"
GUIDELINES_DIR="$PLUGIN_ROOT/guidelines"

# Primary guideline file to always inject
PRIMARY_GUIDELINE="$GUIDELINES_DIR/work-guidelines.md"

# Output as system-reminder for Claude to process
if [ -f "$PRIMARY_GUIDELINE" ]; then
  echo "<system-reminder>"
  echo "Called the Read tool with the following input: {\"file_path\":\"work-guidelines.md\"}"
  echo "</system-reminder>"
  echo "<system-reminder>"
  echo "Result of calling the Read tool:"
  cat "$PRIMARY_GUIDELINE"
  echo "</system-reminder>"
fi

exit 0
