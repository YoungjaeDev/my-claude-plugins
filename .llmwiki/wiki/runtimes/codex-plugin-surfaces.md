---
id: codex-plugin-surfaces
aliases: [codex-hook-trust, codex-skills-only, codex-plugin-install]
last_verified: 2026-09-04
status: active
volatility: volatile
sources: 3
---

# What Codex actually registers from an installed plugin

`codex plugin add <name>@my-claude-plugins` registers the plugin's `skills/` and nothing else.

- `commands/` and `agents/` in `plugin.json` are ignored. Skill logic moved into an agent definition disappears on Codex without an error.
- Bundled hooks are copied into the cache but never run until the user registers them in `~/.codex/hooks.json` and approves them in `/hooks`. Until then there is no signal at all; `codex exec` (headless) can never grant trust, so plugin hooks never fire in CI.
- A per-turn convention (for example "read the wiki MOC before answering lore questions") therefore has only two carriers on Codex: the manually registered hook, or the repo's own `AGENTS.md`. A skill cannot carry it because a skill loads only on the turn it is selected.
- Skill `description` over 1024 characters is skipped silently; `: ` inside an unquoted description collapses the YAML on both runtimes. `scripts/check-skill-contract.mjs` guards both.
- The 2.30.0 rename moved the cache paths: hook entries pointing at `core-config/<ver>/hooks/...` or `llm-wiki/<ver>/hooks/...` must be re-pointed at `core/1.0.0/...` and `wiki/1.0.0/...` and re-trusted.

## Sources

- GitHub issue #169 (measured on codex-cli 0.145.0, 2026-07-27)
- PR #213 Codex review thread on `plugins/llm-wiki/CLAUDE.md` (2026-09-04)
- `plugins/wiki/CLAUDE.md` "Codex hooks (descriptor shipped, manual wiring)"

> Evidence: https://github.com/YoungjaeDev/my-claude-plugins/issues/169
> See-also: [[bundle-rename-is-a-new-entry]]
