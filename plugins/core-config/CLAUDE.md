# Core Config Plugin

Development workflow essentials: guidelines auto-injection, Python formatting, and notifications.

## Hooks

| Hook | Trigger | Description |
|------|---------|-------------|
| `inject-guidelines.sh` | UserPromptSubmit | Auto-inject work guidelines on every prompt |
| `auto-format-python.py` | Post Write/Edit | Auto-format Python with ruff |
| `notify_osc.sh` | Stop/Notification | Terminal OSC 777 notifications |

## Guidelines

Guidelines are auto-injected via hook. Available references:

| File | Purpose |
|------|---------|
| `work-guidelines.md` | Core development workflow (auto-injected) |
| `ml-guidelines.md` | ML/CV best practices |

## Requirements

- `uv` and `ruff` for Python auto-formatting
- **Unix**: Terminal with OSC 777 support for notifications
- **Windows**: BurntToast PowerShell module for toast notifications
  ```powershell
  Install-Module -Name BurntToast -Scope CurrentUser
  ```
