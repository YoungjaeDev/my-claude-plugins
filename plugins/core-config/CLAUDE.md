# Core Config Plugin

Development workflow essentials: Python formatting and notifications.

## Hooks

| Hook | Trigger | Description |
|------|---------|-------------|
| `auto-format-python.py` | Post Write/Edit | Auto-format Python with ruff |
| `notify_osc.sh` | Stop/Notification | Terminal OSC 777 notifications |

## Guidelines

User-global work guidelines live in `~/.claude/CLAUDE.md` (SSOT, auto-loaded by Claude Code). Project-specific guidelines live in each repo's `CLAUDE.md`.

| File | Purpose |
|------|---------|
| `ml-guidelines.md` | ML/CV best practices (reference, on-demand) |

## Requirements

- `uv` and `ruff` for Python auto-formatting
- **Unix**: Terminal with OSC 777 support for notifications
- **Windows**: BurntToast PowerShell module for toast notifications
  ```powershell
  Install-Module -Name BurntToast -Scope CurrentUser
  ```
