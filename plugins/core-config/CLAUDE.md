# Core Config Plugin

Development workflow essentials: Python formatting and notifications.

## Hooks

| Hook | Trigger | Description |
|------|---------|-------------|
| `auto-format-python.py` | Post Write/Edit | Auto-format Python with ruff |
| `notify_osc.sh` | Stop/Notification | Terminal OSC 777 notifications |
| `memory_nudge.sh` | UserPromptSubmit | Soft memory-discipline reminder (rate-limited ~3h per cwd) |

`memory_nudge.sh` does **not** re-inject `~/.claude/CLAUDE.md` — that was the `inject-guidelines` `UserPromptSubmit` hook removed in v1.4.0, because CLAUDE.md is native-loaded once per session and re-injecting it every prompt wasted context. Instead it emits a rate-limited 4-line soft hint nudging the LLM to *recall* and *save* memory it already has loaded (MEMORY.md index + the `# Memory` section of `~/.claude/CLAUDE.md`). Quiet by default; output becomes `additionalContext`. Disable by removing the `UserPromptSubmit` block from `plugin.json`.

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
