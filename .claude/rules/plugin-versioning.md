---
paths: .claude-plugin/marketplace.json, plugins/*/.claude-plugin/plugin.json, plugins/*/CLAUDE.md
---

# Plugin Versioning Rules

Version bump contract for plugins in this marketplace.

## Role

Keep plugin versions synchronized across the two source-of-truth files and document cache-refresh workflow for downstream users.

## Key Components

- `plugins/<name>/.claude-plugin/plugin.json` — per-plugin manifest. Bumping `version` triggers Claude Code's plugin cache refresh. Codex reads the same manifest natively (manifest fallback), so there is no generated layer to regenerate.
- `.claude-plugin/marketplace.json` — marketplace registry. Contains per-plugin `version` (must match `plugin.json`) and top-level `metadata.version` (bumped once per marketplace release). Codex also reads this catalog natively.
- `AGENTS.md` (root) — plugin count summary (keep in sync when adding/removing plugins). Root `CLAUDE.md` is a one-line `@AGENTS.md` import; edit `AGENTS.md`.
- `README.md` — user-facing plugin count + badge.
- `.claude/settings.json` — tracked local-load list (`plugins.local`). A plugin absent here is registered in the marketplace but does NOT auto-load in local dev.

## Do's

- **Sync both version files on every bump**: update `plugins/<name>/.claude-plugin/plugin.json` AND the matching entry in `.claude-plugin/marketplace.json` in the same commit.
- **A change to any file under `plugins/<name>/` is bump-worthy — including bundled `references/` / `docs/` / asset edits, not just code or skills.** Cache-gated users only receive the new content on a version bump, so a docs-only plugin edit still bumps that plugin's PATCH + `metadata.version`. Root-level docs (`AGENTS.md`, `README.md`, `code_review.md`, `.claude/rules/*`) are NOT plugin content and bump no plugin.
- **Bump `metadata.version` in marketplace.json** whenever any plugin version changes. This signals a marketplace release to users.
- **Update plugin count** in root `AGENTS.md` (`## Plugins (N)`) AND `README.md` (description sentence + badge + tree + detail section) when adding or removing a plugin.
- **Adding a skill to an existing plugin syncs docs too** (distinct from the plugin-count update above — a skill add does NOT change the plugin count): update that plugin's `plugins/<name>/CLAUDE.md` skill listing, and — when the version bump also changed the plugin `description` — the matching one-line description in root `AGENTS.md` and `README.md`. `metadata.version` bump still applies.
- **Register new plugins in `.claude/settings.json`** (`plugins.local` array, `./plugins/<name>`) when adding a plugin — this tracked file is what auto-loads plugins locally; marketplace registration alone does not. Neither the version files nor any guard catch this omission.
- **Adhere to semver** at the plugin level: `MAJOR.MINOR.PATCH`. PATCH for fixes, MINOR for backward-compatible features, MAJOR for breaking changes.
- **Document cache workaround** in release notes and user docs — the manual `rm -rf` is the only reliable refresh path until the Claude Code plugin cache bugs are fixed upstream.

## Plugin Removal or Absorption

Absorbing a plugin's skills into another bundle is a removal plus a re-home, so every rule below applies — plus ones the pure-removal case never hits.

- **Audit the absorbed skill's own body, not just the references pointing at it.** The destination wiring is the easy half; what breaks is the skill still believing it lives in the old plugin. Found classes: a `PLUGIN_ROOT` resolver globbing `*/<old-plugin>/*` in the Codex cache (the skill dies at "script not resolved" the moment `CLAUDE_PLUGIN_ROOT` is unset), an un-namespaced `/skill-name` example, and the destination's version left unbumped so cache-gated users never receive the move at all. Grep the moved tree for the old plugin name before declaring the absorption done.
- **Bump the destination even when only references changed.** A plugin whose files were touched solely by a rename sweep is still a plugin whose files changed; skipping the bump strands cache-gated users on instructions pointing at deleted commands.
- **Grep the whole repo for live references, not just the count files.** Beyond `CLAUDE.md` / `README.md` / `marketplace.json` / `settings.json`, a removed plugin is often still referenced in other plugins' skill bodies (e.g. `scout`'s `agent-routing.md` routing table) or under `docs/`. Run `git grep -niE '<name>'` across the repo before finalizing — a surviving reference ships users a route to a non-existent plugin.
- **Delete orphaned generated artifacts.** A plugin that generates tracked output leaves that output unmaintained once the generator is gone; remove the generated tree in the same change.
- **A renamed plugin is a new entry and starts at 1.0.0.** The old name leaves the registry (a removal, MINOR `metadata.version`), and the new name has no version history to continue, so `1.0.0` is the honest start even when the content is unchanged. Precedent: the 2.30.0 consolidation (`dev` 4.0.1 → `dev` 1.0.0).
- **A plugin removal is a MINOR `metadata.version` bump, not MAJOR.** `metadata.version` is a per-release counter, not strict semver — the MAJOR-for-breaking rule above is scoped to per-plugin versions. Precedent: dropping the `midjourney` plugin was a MINOR bump. A reviewer may flag a removal as "breaking → MAJOR"; that contradicts this convention.

## Don'ts

- **Never bump `plugin.json` without `marketplace.json`** (or vice versa). Downstream users will see the mismatched version and lose trust in the registry.
- **Never rely on `/plugin update` or `/plugin marketplace update` alone** to refresh plugin files. Plugin cache bugs ([#17361](https://github.com/anthropics/claude-code/issues/17361), [#19197](https://github.com/anthropics/claude-code/issues/19197)) mean file contents do not refresh until `~/.claude/plugins/cache/my-claude-plugins/` is deleted.
- **Never skip the plugin count update** when adding/removing a plugin. Stale counts in README/AGENTS.md erode credibility.
- **Never bump `metadata.version` against a branch's original base when concurrent branches are in flight.** Two branches off the same base that each bump `metadata.version` to the same next value (e.g. both `1.32.0` → `1.33.0`) merge with NO git conflict — the values are identical — so `main` silently ends one release short while containing two. Right before merging, re-check `metadata.version` against `origin/main` (not the branch's fork point) and bump past whatever already landed. After merging the second of two concurrent marketplace releases, verify `metadata.version` advanced by two from the shared base.
- **Never bump introduced-in version markers.** A version annotation that records *when* a feature shipped -- e.g. `스킬 3종 (0.7.0)`, `0.7.0부터 ...`, a SKILL.md `(0.7.0)` section tag -- is historical, not a current-version statement, so a later release leaves it. Only the per-plugin `version`, `metadata.version`, and description count strings track the current release. A grep-driven version sweep and pattern-matching reviewers (CodeRabbit) both false-flag these as stale -- skip with that reason.

## Developer Workflow

1. Update `version` in `plugins/<name>/.claude-plugin/plugin.json`.
2. Update the matching `version` in `.claude-plugin/marketplace.json`.
3. Bump `metadata.version` in `.claude-plugin/marketplace.json`.
4. (If adding/removing a plugin) update plugin counts in `AGENTS.md` and `README.md`, and add/remove its `./plugins/<name>` entry in `.claude/settings.json` (`plugins.local`).
5. Commit all changes together.

## User Update Workflow

Due to plugin cache bugs, users refresh plugins via:

```bash
rm -rf ~/.claude/plugins/cache/my-claude-plugins/
/plugin marketplace update my-claude-plugins
# Restart Claude Code
```
