# Core Config Plugin

Development workflow essentials: Python formatting and notifications.

## Hooks

| Hook | Trigger | Description |
|------|---------|-------------|
| `auto-format-python.py` | Post Write/Edit | Auto-format Python with ruff |
| `notify_osc.py` | Stop/Notification | Terminal OSC 777 notifications |
| `prompt_inject.sh` | UserPromptSubmit | Per-prompt compact behavioral block (Korean default + core rules + `.llmwiki/insight/`·wiki pointer). Shared Claude + Codex. |
| `memory_nudge.sh` | UserPromptSubmit | Soft memory-discipline reminder (rate-limited ~3h per cwd) |

The two `UserPromptSubmit` hooks are complementary and run in parallel:

- `prompt_inject.sh` fires **every** prompt with a fixed ~6-line block: Korean-default response, a few core behavioral one-liners (surgical-diff, AskUserQuestion-first, no AI attribution, no emoji, verify-before-report), and a pointer to consult `.llmwiki/insight/` (promoted cross-agent rules) then the wiki MOC *before* reasoning. It does **not** inline insight/wiki content — only the instruction to read it. When a wiki root resolves, the pointer is labeled `[AUTHORITATIVE]` (dated/sourced `.llmwiki/` wins on conflict) and a `[RECALL]` line places mem0 recall as the secondary layer — **labels only, no mem0 call/read** (mem0 surfacing stays mem0's own hooks). The `codex` branch omits `[RECALL]` (Codex has no mem0 layer); `CORE_CONFIG_FEDERATE_MEM0=0` reverts to the plain pointer (default on). Claude reverts to English over long sessions, and neither agent is otherwise reminded to check the wiki/insight layer; this block fixes both. Zero deps (no `jq`/`python`) — JSON encoding is bash parameter expansion.
- `memory_nudge.sh` does **not** re-inject `~/.claude/CLAUDE.md` — that was the `inject-guidelines` `UserPromptSubmit` hook removed in v1.4.0, because CLAUDE.md is native-loaded once per session and re-injecting it every prompt wasted context. Instead it emits a rate-limited (~3h per cwd) soft hint nudging the LLM to *recall* and *save* memory it already has loaded (MEMORY.md index + the `# Memory` section of `~/.claude/CLAUDE.md`).

Both are quiet-friendly; output becomes `additionalContext`. Disable either by removing its entry from the `UserPromptSubmit` block in `plugin.json`.

### Codex CLI parity (`prompt_inject.sh codex`)

Codex CLI is a sibling runtime for this marketplace (Claude and Codex read the same `plugins/<name>/` tree — see the `Codex 통합 (shared-source)` section in the root `AGENTS.md`). Codex supports `UserPromptSubmit` hooks with `additionalContext`, so the *same* script serves both agents — pass `codex` to get JSON instead of plain stdout:

```bash
bash prompt_inject.sh        # Claude: plain stdout → additionalContext
bash prompt_inject.sh codex  # Codex:  {"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"..."}}
```

The Claude plugin loader cannot write `~/.codex/`, so the Codex side is a manual one-time setup. Copy the script to a stable path (the plugin cache path is version-pinned and churns on every bump) and register a `UserPromptSubmit` hook:

```bash
mkdir -p ~/.codex/hooks
# pick the newest cached version (glob may match several) and fail if none exist
latest_hook="$(ls -1dt ~/.claude/plugins/cache/my-claude-plugins/core-config/*/hooks/prompt_inject.sh 2>/dev/null | head -n1)"
[ -n "$latest_hook" ] || { echo "prompt_inject.sh not found in Claude plugin cache" >&2; exit 1; }
cp "$latest_hook" ~/.codex/hooks/prompt_inject.sh
chmod +x ~/.codex/hooks/prompt_inject.sh
```

Then add to `~/.codex/hooks.json` (create it if absent):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "bash ~/.codex/hooks/prompt_inject.sh codex" }] }
    ]
  }
}
```

Codex requires trusting new hooks: run `/hooks` in a Codex session and approve the entry. Re-copy the script after a `core-config` version bump if you want the latest block text (the `~/.codex/` copy does not auto-update).

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
