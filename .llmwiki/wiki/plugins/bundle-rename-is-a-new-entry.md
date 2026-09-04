---
id: bundle-rename-is-a-new-entry
aliases: [plugin-rename, short-plugin-names, 2.30.0-consolidation]
last_verified: 2026-09-04
status: active
volatility: stable
sources: 2
---

# A renamed plugin is a new marketplace entry

Marketplace 2.30.0 consolidated 14 plugins into 8 bundles with short names (`core`, `dev`, `docs`, `scout`, `ml`, `wiki`, plus `council` and `codex-image` unchanged).

- Plugin skills are always exposed as `/plugin:skill` and slash autocomplete matches the whole name, so a long plugin name hides every skill behind it. Shortening the plugin name is the only lever the repo controls.
- A renamed plugin has no version history to continue: the old name leaves the registry (a removal, MINOR `metadata.version`) and the new name starts at `1.0.0` even when its content is unchanged. `github-dev` 4.0.1 became `dev` 1.0.0.
- Cache-gated users lose the old entries at once. The README migration table (old name to bundle, uninstall / install) and the `~/.codex/hooks.json` path re-pointing note are the only way they find out.
- `council` and `codex-image` stay standalone because installing them into Codex is circular (Codex is a council seat; codex-image delegates to Codex).

## Sources

- `.claude/rules/plugin-versioning.md` "Plugin Removal or Absorption" (rename rule added 2026-09-04)
- GitHub issue #214 (consolidation plan and decisions, 2026-09-04)

> Evidence: .claude/spec/2026-08-26-full-restructure.md
> See-also: [[codex-plugin-surfaces]]
