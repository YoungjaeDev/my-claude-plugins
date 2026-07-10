# Core Config Plugin

Development workflow essentials: Python formatting and notifications.

## Hooks

| Hook | Trigger | Description |
|------|---------|-------------|
| `auto-format-python.py` | Post Write/Edit | Auto-format Python with ruff |
| `notify_osc.py` | Stop/Notification | Terminal OSC 777 notifications |
| `prompt_inject.sh` | UserPromptSubmit | Per-prompt compact behavioral block — English rules with a Korean-output mandate + `.llmwiki/insight/`·wiki pointer + `[council]` delegation reminder. Federation labels off by default. Shared Claude + Codex. |

The single `UserPromptSubmit` hook:

- `prompt_inject.sh` fires **every** prompt with a fixed ~6-line block: the rules are written in **English**, but the first line mandates a **Korean final reply**, followed by a few core behavioral one-liners (surgical-diff, AskUserQuestion-first, no AI attribution, no emoji, verify-before-report) and a pointer to consult `.llmwiki/insight/` (promoted cross-agent rules) then the wiki MOC *before* reasoning. It does **not** inline insight/wiki content — only the instruction to read it. mem0 federation labels are **off by default** (the pointer is plain); `CORE_CONFIG_FEDERATE_MEM0=1` restores them — the pointer becomes `[AUTHORITATIVE]` (dated/sourced `.llmwiki/` wins on conflict) plus a `[RECALL]` line placing mem0 recall as the secondary layer, **labels only, no mem0 call/read** (the `codex` branch omits `[RECALL]`; Codex has no mem0 layer). The English wording keeps the model from drifting into an English block of its own while still pinning the reply language to Korean, and the pointer is the only reminder either agent gets to check the wiki/insight layer. Zero deps (no `jq`/`python`) — JSON encoding is bash parameter expansion.

Both extra pointers are conditional on what the machine actually has, mirroring the same rule: never name a path or a tool that is not there.

- **Wiki pointer** — emitted only when a knowledge root resolves in cwd (`.llmwiki` → legacy `.claude` → `.codex`). core-config installs globally, so a repo with no wiki must not be told to read one.
- **`[council]` line** — emitted only when `codex` or `agy` is on `PATH`, and it names the CLI roster it found, never a model. It is one sentence: when something needs real depth, a second pair of eyes, or input the model cannot read, delegate rather than decide alone, and never auto-apply what comes back. The invocation names and the full post-delegation rules live in `~/.claude/CLAUDE.md`, which loads once per session and costs nothing per turn — this line is only the per-prompt reminder that a different model exists. It is Claude-only: Codex is itself a council member, so pointing it back at `codex` would be circular (same reasoning as the `[RECALL]` omission).

Keep the injected text free of literal `"` and `\` — the `codex` JSON branch encodes it with bash parameter expansion, not `jq`.

Output is quiet-friendly and becomes `additionalContext`. Disable it by removing its entry from the `UserPromptSubmit` block in `plugin.json`.

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
