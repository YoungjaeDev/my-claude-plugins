#!/usr/bin/env python3
"""Claude Code OSC Notification Script.

Cross-platform compatible (Windows/Linux/macOS).
Sends OSC 777 notifications to terminal.
"""

import json
import os
import sys


def send_osc_notification(title: str, body: str):
    """Send OSC 777 notification to terminal."""
    notification = f"\033]777;notify;{title};{body}\007"

    # Try /dev/tty first (Unix), then stdout
    try:
        if os.path.exists("/dev/tty"):
            with open("/dev/tty", "w") as tty:
                tty.write(notification)
                tty.flush()
                return
    except Exception:
        pass

    # Fallback to stdout (works on Windows too)
    try:
        sys.stdout.write(notification)
        sys.stdout.flush()
    except Exception:
        pass


def main():
    """Main hook handler."""
    title = "Claude"
    body = "Task completed"

    # Try to read JSON from stdin (with timeout simulation via non-blocking)
    try:
        # Check if stdin has data
        if not sys.stdin.isatty():
            import select

            # Unix: use select for timeout
            if hasattr(select, "select"):
                readable, _, _ = select.select([sys.stdin], [], [], 1.0)
                if readable:
                    input_data = sys.stdin.read()
                else:
                    input_data = ""
            else:
                # Windows: just try to read
                input_data = sys.stdin.read()
        else:
            input_data = ""
    except Exception:
        input_data = ""

    # Parse JSON input
    if input_data.strip():
        try:
            data = json.loads(input_data)
            session_id = data.get("session_id", "")
            cwd = data.get("cwd", os.getcwd())
            event = data.get("hook_event_name", "")
            notif_type = data.get("notification_type", "")
            message = data.get("message", "")

            folder = os.path.basename(cwd) if cwd else ""
            short_id = session_id[:8] if session_id else ""

            # Build title
            if folder:
                title = f"Claude - {folder}"
            if short_id:
                title = f"{title} [{short_id}]"

            # Build body based on event
            if event == "Stop":
                body = "Task completed"
            elif event == "Notification":
                if notif_type == "permission_prompt":
                    body = "Permission needed"
                elif notif_type == "idle_prompt":
                    body = "Waiting for input"
                else:
                    body = message or notif_type or "Notification"
            else:
                body = message or "Notification"
        except json.JSONDecodeError:
            pass

    # Handle command line arguments as fallback
    if len(sys.argv) >= 2:
        title = sys.argv[1]
    if len(sys.argv) >= 3:
        body = sys.argv[2]

    send_osc_notification(title, body)
    sys.exit(0)


if __name__ == "__main__":
    main()
