---
id: agent-definition-effort
aliases: [effort-frontmatter, worker-preset-tiers, reasoning-effort-agents]
last_verified: 2026-09-15
status: active
volatility: volatile
sources: 3
---

# `effort:` in an agent definition, and why tier presets are separate files

Agent definition frontmatter accepts an `effort:` field that the public Claude Code documentation does not describe. Accepted values are `low`, `medium`, `high`, `xhigh`, `max`. A model that does not support the requested level is downgraded silently — no error, no warning line.

- Anthropic's own official marketplace ships agents that use it, so it is a real supported field and not a local invention.
- The `Agent` tool overrides only `model` at call time. There is no `effort` parameter on the call, so the effort level can be set **only** in the agent definition file.
- That asymmetry is why a tier is a file, not an argument: `dev:worker-fast` (haiku / `low`), `dev:worker-standard` (sonnet / `medium`), `dev:worker-deep` (opus / `high`), `dev:worker-max` (opus / `xhigh`). One generic worker plus a per-call effort argument is not expressible.
- `effort:` is a Claude-only surface, like the rest of `agents/`. Codex registers `skills/` only and ignores the directory entirely.

## Sources

- `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/claude-security/agents/*.md` — 8 agent definitions carrying `effort:` (`low`, `medium`, `xhigh`), read 2026-09-15
- Claude Code CLI 2.1.272 binary: `var ru=["low","medium","high","xhigh","max"]` and the string "after any silent downgrade for the selected model" (`~/.local/share/claude/versions/2.1.272`)
- commit `98f36f5` — `plugins/dev/agents/worker-*.md` (PR #227, dev 2.1.0)

> See-also: [[codex-plugin-surfaces]]
