---
paths: .claude-plugin/marketplace.json, plugins/*/.claude-plugin/plugin.json, plugins/*/CLAUDE.md
---

# Plugin Versioning Rules

The version contract for the 9 plugins in this marketplace, beyond what `AGENTS.md` "플러그인 변경 규칙" already states (bump with `scripts/bump-version.mjs`, every `plugins/<name>/` edit is bump-worthy, `metadata.version` goes MINOR even for a removal, a renamed plugin starts at 1.0.0). Read that section first; this file adds the cases it does not cover.

## Bumps and docs

- **Cache refresh**: bumping `version` in `plugins/<name>/.claude-plugin/plugin.json` is what makes Claude Code refresh a user's plugin cache, and `marketplace.json` carries the same per-plugin `version`. Codex reads both files natively, so there is no generated layer to regenerate.
- **Skill added to an existing plugin**: update that plugin's `plugins/<name>/CLAUDE.md` skill listing. When the bump also changed the plugin `description`, update the matching one-line description in `README.md` too. The plugin count does not change.
- **Concurrent branches**: two branches that each bump `metadata.version` to the same next value merge without a conflict and leave `main` one release short. `bump-version.mjs` computes from `origin/main`, so rerun it right before merging and after the other branch lands.

## Plugin removal or absorption

Absorbing a plugin's skills into another bundle is a removal plus a re-home, so every rule here applies.

- **Bump the destination even when only references changed**: a plugin touched only by a rename sweep still changed, and skipping the bump strands cache-gated users on pointers to deleted commands.
- **Grep the whole repo**: beyond `CLAUDE.md`, `README.md`, `marketplace.json` and `.claude/settings.json`, a removed plugin is often still named in another plugin's skill body (for example `scout`'s `agent-routing.md`) or under `docs/`. Run `git grep -niE '<name>'` before finalizing.
- **Delete orphaned generated artifacts**: tracked output of a removed generator goes in the same change.

## User update workflow

Plugin cache bugs ([#17361](https://github.com/anthropics/claude-code/issues/17361), [#19197](https://github.com/anthropics/claude-code/issues/19197)) keep `/plugin update` and `/plugin marketplace update` from refreshing file contents, so release notes and user docs keep this sequence:

```bash
rm -rf ~/.claude/plugins/cache/my-claude-plugins/
/plugin marketplace update my-claude-plugins
# Restart Claude Code
```
