---
paths: .claude-plugin/marketplace.json, plugins/*/.claude-plugin/plugin.json, plugins/*/CLAUDE.md
---

# Plugin Versioning Rules

Version bump contract for plugins in this marketplace.

## Role

Keep plugin versions synchronized across the two source-of-truth files and document cache-refresh workflow for downstream users.

## Key Components

- `plugins/<name>/.claude-plugin/plugin.json` — per-plugin manifest. Bumping `version` triggers Claude Code's plugin cache refresh.
- `.claude-plugin/marketplace.json` — marketplace registry. Contains per-plugin `version` (must match `plugin.json`) and top-level `metadata.version` (bumped once per marketplace release).
- `CLAUDE.md` (root) — plugin count summary (keep in sync when adding/removing plugins).
- `README.md` — user-facing plugin count + badge.

## Do's

- **Sync both version files on every bump**: update `plugins/<name>/.claude-plugin/plugin.json` AND the matching entry in `.claude-plugin/marketplace.json` in the same commit.
- **Bump `metadata.version` in marketplace.json** whenever any plugin version changes. This signals a marketplace release to users.
- **Update plugin count** in root `CLAUDE.md` (`## Plugins (N)` + structure tree) AND `README.md` (description sentence + badge + detail section) when adding or removing a plugin.
- **Adhere to semver** at the plugin level: `MAJOR.MINOR.PATCH`. PATCH for fixes, MINOR for backward-compatible features, MAJOR for breaking changes.
- **Document cache workaround** in release notes and user docs — the manual `rm -rf` is the only reliable refresh path until the Claude Code plugin cache bugs are fixed upstream.

## Don'ts

- **Never bump `plugin.json` without `marketplace.json`** (or vice versa). Downstream users will see the mismatched version and lose trust in the registry.
- **Never rely on `/plugin update` or `/plugin marketplace update` alone** to refresh plugin files. Plugin cache bugs ([#17361](https://github.com/anthropics/claude-code/issues/17361), [#19197](https://github.com/anthropics/claude-code/issues/19197)) mean file contents do not refresh until `~/.claude/plugins/cache/my-claude-plugins/` is deleted.
- **Never skip the plugin count update** when adding/removing a plugin. Stale counts in README/CLAUDE.md erode credibility.
- **Never bump `metadata.version` against a branch's original base when concurrent branches are in flight.** Two branches off the same base that each bump `metadata.version` to the same next value (e.g. both `1.32.0` → `1.33.0`) merge with NO git conflict — the values are identical — so `main` silently ends one release short while containing two. Right before merging, re-check `metadata.version` against `origin/main` (not the branch's fork point) and bump past whatever already landed. After merging the second of two concurrent marketplace releases, verify `metadata.version` advanced by two from the shared base.

## Developer Workflow

1. Update `version` in `plugins/<name>/.claude-plugin/plugin.json`.
2. Update the matching `version` in `.claude-plugin/marketplace.json`.
3. Bump `metadata.version` in `.claude-plugin/marketplace.json`.
4. (If adding/removing a plugin) update plugin counts in `CLAUDE.md` and `README.md`.
5. Commit all changes together.

## User Update Workflow

Due to plugin cache bugs, users refresh plugins via:

```bash
rm -rf ~/.claude/plugins/cache/my-claude-plugins/
/plugin marketplace update my-claude-plugins
# Restart Claude Code
```
