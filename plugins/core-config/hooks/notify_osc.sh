#!/bin/bash
# Claude Code OSC Notification Script
# Output to /dev/tty to deliver directly to terminal

# Read JSON from stdin (prevent blocking with timeout)
INPUT=$(timeout 1 cat 2>/dev/null || true)

# JSON parsing
if command -v jq &>/dev/null && [ -n "$INPUT" ]; then
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
    CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
    EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)
    NOTIF_TYPE=$(echo "$INPUT" | jq -r '.notification_type // empty' 2>/dev/null)
    MESSAGE=$(echo "$INPUT" | jq -r '.message // empty' 2>/dev/null)

    FOLDER=$(basename "${CWD:-$PWD}" 2>/dev/null)
    SHORT_ID="${SESSION_ID:0:8}"

    # Title construction
    TITLE="Claude"
    [ -n "$FOLDER" ] && TITLE="$TITLE - $FOLDER"
    [ -n "$SHORT_ID" ] && TITLE="$TITLE [$SHORT_ID]"

    # Message body construction
    case "$EVENT" in
        "Stop")
            BODY="Task completed"
            ;;
        "Notification")
            case "$NOTIF_TYPE" in
                "permission_prompt") BODY="Permission needed" ;;
                "idle_prompt") BODY="Waiting for input" ;;
                *) BODY="${MESSAGE:-$NOTIF_TYPE}" ;;
            esac
            ;;
        *)
            BODY="${MESSAGE:-Notification}"
            ;;
    esac
else
    TITLE="${1:-Claude Code}"
    BODY="${2:-Task completed}"
fi

# OSC 777 notification output (excluding OSC 9 as it causes duplicate notifications)
# Output directly to /dev/tty if available, otherwise stdout
{
    printf '\033]777;notify;%s;%s\007' "$TITLE" "$BODY"
} > /dev/tty 2>/dev/null || {
    printf '\033]777;notify;%s;%s\007' "$TITLE" "$BODY"
}

exit 0
