# Core Config Plugin

Development workflow essentials: Python formatting and notifications.

## Hooks

| Hook | Trigger | Description |
|------|---------|-------------|
| `auto-format-python.py` | Post Write/Edit | Auto-format Python with ruff |
| `notify_osc.py` | Stop/Notification | Native notification per platform: macOS `osascript`, Windows BurntToast toast, Linux terminal OSC 777 |
| `prompt_inject.sh` | UserPromptSubmit + SessionStart:compact | Per-prompt compact behavioral block: English rules with a Korean-output mandate + `.llmwiki/insight/`·wiki pointer + `[council]` delegation reminder. Federation labels off by default. Shared Claude + Codex; the SessionStart:compact re-injection is Claude-only. |

The `prompt_inject.sh` hook:

- `prompt_inject.sh` fires **every** prompt with a fixed ~6-line block: the rules are written in **English**, but the first line mandates a **Korean final reply**, followed by a few core behavioral one-liners (surgical-diff, AskUserQuestion-first, no AI attribution, no emoji, verify-before-report) and a pointer to consult `.llmwiki/insight/` (promoted cross-agent rules) then the wiki MOC *before* reasoning. It does **not** inline insight/wiki content, only the instruction to read it. mem0 federation labels are **off by default** (the pointer is plain); `CORE_CONFIG_FEDERATE_MEM0=1` restores them: the pointer becomes `[AUTHORITATIVE]` (dated/sourced `.llmwiki/` wins on conflict) plus a `[RECALL]` line placing mem0 recall as the secondary layer, **labels only, no mem0 call/read** (the `codex` branch omits `[RECALL]`; Codex has no mem0 layer). The English wording keeps the model from drifting into an English block of its own while still pinning the reply language to Korean, and the pointer is the only reminder either agent gets to check the wiki/insight layer. Zero deps (no `jq`/`python`): JSON encoding is bash parameter expansion.

- **SessionStart `compact` re-injection (Claude-only).** Claude Code drops the per-prompt `additionalContext` when it compacts the conversation, so the behavioral block and its wiki/council pointers silently vanish mid-session. A `SessionStart` hook with `matcher: "compact"` re-runs the *same* `prompt_inject.sh` (no arg) right after a compaction to restore the block (one hook entry, no new script). It is intentionally **single-surface**: the `compact` SessionStart source is a Claude Code concept, so the Codex descriptor (`hooks/codex-hooks.json`, `UserPromptSubmit` only) is left unchanged rather than assuming Codex compaction behaves the same.

  > **Runtime-verify: pending.** The config is correct by inspection; the end-to-end behavior (that a real compaction re-fires the hook with a non-empty block) needs one human `/compact` check (agents cannot trigger compaction). Procedure: `claude --debug hooks` → send a prompt to confirm the baseline block → `/compact` → confirm a `SessionStart` invocation with `matcher: compact` whose stdout is non-empty and carries the fixed `[harness]` block, then quote its first line back in the next prompt as a cross-check. Upstream reports of SessionStart-`compact` stdout being dropped (anthropics/claude-code #13650, #15174) are why this is verified rather than assumed; if the re-injected block comes back empty, the next `UserPromptSubmit` recovers it within one turn. Last verified: _pending_.

Both extra pointers are conditional on what the machine actually has, mirroring the same rule: never name a path or a tool that is not there.

- **Wiki pointer**: emitted only when a knowledge root resolves in cwd (`.llmwiki` → legacy `.claude` → `.codex`). core installs globally, so a repo with no wiki must not be told to read one. Every branch `-f`-tests the exact file it names, not its parent directory: a wiki root can exist carrying only `log.md`, so `-d .../wiki` would inject a nonexistent `index.md` into every prompt. A repo carrying `.llmwiki/insight/` alone gets an insight-only pointer; a wiki root with no MOC gets no wiki pointer at all.
- **`[council]` line**: emitted only when `codex` or `agy` is on `PATH` (`type -P`, not `command -v`: the latter also resolves an exported shell function and would announce a CLI that is not installed), and it names the CLI roster it found, never a model. It is one sentence: when something needs real depth, a second pair of eyes, or input the model cannot read, delegate rather than decide alone, and never auto-apply what comes back. The invocation names and the full post-delegation rules live in `~/.claude/CLAUDE.md`, which loads once per session and costs nothing per turn. This line is only the per-prompt reminder that a different model exists. It is Claude-only: Codex is itself a council member, so pointing it back at `codex` would be circular (same reasoning as the `[RECALL]` omission).

Keep the injected text free of literal `"` and `\`: the `codex` JSON branch encodes it with bash parameter expansion, not `jq`.

Output is quiet-friendly and becomes `additionalContext`. Disable it by removing its entry from the `UserPromptSubmit` block in `plugin.json`.

### Codex CLI parity (`prompt_inject.sh codex`)

Codex CLI is a sibling runtime for this marketplace (Claude and Codex read the same `plugins/<name>/` tree; see the `Codex 통합 (shared-source)` section in the root `AGENTS.md`). Codex supports `UserPromptSubmit` hooks with `additionalContext`, so the *same* script serves both agents. Pass `codex` to get JSON instead of plain stdout:

```bash
bash prompt_inject.sh        # Claude: plain stdout → additionalContext
bash prompt_inject.sh codex  # Codex:  {"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"..."}}
```

The bundled descriptor `hooks/codex-hooks.json` is still shipped as source:

```json
{ "hooks": { "UserPromptSubmit": [ { "hooks": [ { "type": "command", "command": "bash \"$PLUGIN_ROOT/hooks/prompt_inject.sh\" codex" } ] } ] } }
```

**Auto-wiring status**: with the generated Codex manifest layer removed (2026-08 restructure), nothing wires this descriptor automatically: `plugins/core/.claude-plugin/plugin.json`'s `hooks` field is the Claude-format inline object, which Codex does not consume. A Codex machine that wants the per-prompt injection registers the hook manually via the legacy `~/.codex/hooks.json` path, pointing at the installed plugin's `prompt_inject.sh` with the `codex` argument (JSON envelope output). This is a deliberate trade-off, not an oversight; native re-wiring is deferred to the restructure's audit phase. The Python auto-formatter (`auto-format-python.py`) and notification (`notify_osc.py`) hooks stay **Claude-only** (they assume Claude Write/Edit tool payloads and Stop/Notification events, which do not map onto Codex the same way).

Manual registration / verify:

```bash
# verify the script emits the Codex envelope
bash <plugin-root>/hooks/prompt_inject.sh codex   # -> {"hookSpecificOutput":{...}}

# then add a ~/.codex/hooks.json UserPromptSubmit entry running that command,
# and approve it via /hooks in a Codex session (Codex requires hook trust)
```

The descriptor and script update with the plugin, but on Codex they run only through the manual `~/.codex/hooks.json` registration above. There is no automatic wiring.

## Guidelines

User-global work guidelines live in `~/.claude/CLAUDE.md` (SSOT, auto-loaded by Claude Code). Project-specific guidelines live in each repo's `CLAUDE.md`.

| File | Purpose |
|------|---------|
| `ml-guidelines.md` | ML/CV best practices (reference, on-demand) |

## Requirements

- `ruff` for Python auto-formatting (invoked directly if on `PATH`, else via `uv run ruff` when `uv` is present; the hook no-ops with a one-line stderr note when neither is found)
- **macOS**: nothing to install; notifications go through `osascript` (Notification Center). A terminal that speaks OSC 777 (WezTerm, kitty) is used as the fallback when `osascript` cannot run; Terminal.app does not implement OSC 777, which is why the native path is tried first.
- **Linux**: Terminal with OSC 777 support for notifications
- **Windows**: BurntToast PowerShell module for toast notifications
  ```powershell
  Install-Module -Name BurntToast -Scope CurrentUser
  ```
