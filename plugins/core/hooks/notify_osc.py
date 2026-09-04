#!/usr/bin/env python3
"""Claude Code Notification Script.

Windows: BurntToast PowerShell Toast notifications.
macOS:   osascript notification, falling back to OSC 777.
Linux:   OSC 777 terminal notifications.
"""

import json
import os
import subprocess
import sys


def send_notification(title: str, body: str):
    """Send platform-appropriate notification."""
    if sys.platform == "win32":
        _send_toast(title, body)
    elif sys.platform == "darwin":
        # OSC 777 is an rxvt-unicode extension that Terminal.app does not
        # implement, so the Unix path below fires on every Stop and shows the
        # user nothing. Try the native notification first and keep OSC as the
        # fallback for the terminals that do speak it (WezTerm, kitty).
        if not _send_darwin(title, body):
            _send_osc(title, body)
    else:
        _send_osc(title, body)


def _send_darwin(title: str, body: str) -> bool:
    """Post a macOS notification via osascript; False when it could not run.

    The text is handed to an ``on run argv`` handler as arguments rather than
    interpolated into the AppleScript source. Interpolating would break on a
    title containing a double quote, and would make any notification text
    executable AppleScript -- the body can come from a hook payload.
    """
    script = (
        "on run argv\n"
        "display notification (item 1 of argv) with title (item 2 of argv)\n"
        "end run"
    )
    # 3s, not the hook's full 5000ms budget: a stalled osascript must still leave
    # the caller room to fall through to _send_osc before Claude Code kills the
    # hook, or the fallback exists on paper only.
    try:
        proc = subprocess.run(
            ["osascript", "-e", script, body, title],
            capture_output=True,
            timeout=3,
        )
        return proc.returncode == 0
    except Exception:
        return False


def _send_toast(title: str, body: str):
    """Send Windows Toast notification via BurntToast."""
    safe_title = title.replace("'", "''")
    safe_body = body.replace("'", "''")
    cmd = (
        f"Import-Module BurntToast; "
        f"New-BurntToastNotification -Text '{safe_title}', '{safe_body}'"
    )
    try:
        subprocess.run(
            ["powershell", "-ExecutionPolicy", "Bypass", "-Command", cmd],
            capture_output=True,
            timeout=5,
        )
    except Exception:
        pass


def _send_osc(title: str, body: str):
    """Send OSC 777 notification to terminal (Unix)."""
    notification = f"\033]777;notify;{title};{body}\007"
    try:
        if os.path.exists("/dev/tty"):
            with open("/dev/tty", "w") as tty:
                tty.write(notification)
                tty.flush()
                return
    except Exception:
        pass
    try:
        sys.stdout.write(notification)
        sys.stdout.flush()
    except Exception:
        pass


def main():
    """Main hook handler."""
    title = "Claude"
    body = "Task completed"

    # Try to read JSON from stdin
    try:
        if not sys.stdin.isatty():
            if sys.platform == "win32":
                input_data = sys.stdin.read()
            else:
                import select

                readable, _, _ = select.select([sys.stdin], [], [], 1.0)
                input_data = sys.stdin.read() if readable else ""
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

    send_notification(title, body)
    sys.exit(0)


if __name__ == "__main__":
    main()
