---
paths: .claude-plugin/marketplace.json, plugins/*/.claude-plugin/plugin.json, plugins/*/CLAUDE.md, plugins/*/plugin.yaml
---

# Plugin Versioning Rules

Version bump contract for plugins in this marketplace.

## Role

Keep plugin versions synchronized across the two source-of-truth files and document cache-refresh workflow for downstream users.

## Key Components

- `plugins/<name>/.claude-plugin/plugin.json` — per-plugin manifest. Bumping `version` triggers Claude Code's plugin cache refresh.
- `.claude-plugin/marketplace.json` — marketplace registry. Contains per-plugin `version` (must match `plugin.json`) and top-level `metadata.version` (bumped once per marketplace release).
- `plugins/<name>/plugin.yaml` + `plugins/<name>/__init__.py` — Hermes adapters for HERMES_ELIGIBLE plugins, **generated** by `scripts/sync-hermes-manifests.mjs` from `marketplace.json` (`plugin.yaml` `version` / `description` are marketplace-derived; `__init__.py` is a generic skill-registration entrypoint). Do not hand-edit — bump the marketplace entry and re-run the generator. `sync-hermes-manifests.mjs --check` guards adapter drift + orphans, so this is no longer a manual three-way sync. (`sync-codex-manifests.mjs --check` validates Codex manifests only.)
- `CLAUDE.md` (root) — plugin count summary (keep in sync when adding/removing plugins).
- `README.md` — user-facing plugin count + badge.
- `.claude/settings.json` — tracked local-load list (`plugins.local`). A plugin absent here is registered in the marketplace but does NOT auto-load in local dev.

## Do's

- **Sync both version files on every bump**: update `plugins/<name>/.claude-plugin/plugin.json` AND the matching entry in `.claude-plugin/marketplace.json` in the same commit.
- **Bump `metadata.version` in marketplace.json** whenever any plugin version changes. This signals a marketplace release to users.
- **Update plugin count** in root `CLAUDE.md` (`## Plugins (N)` + structure tree) AND `README.md` (description sentence + badge + detail section) when adding or removing a plugin.
- **Adding a skill to an existing plugin syncs docs too** (distinct from the plugin-count update above — a skill add does NOT change the plugin count): update that plugin's `plugins/<name>/CLAUDE.md` skill listing, and — when the version bump also changed the plugin `description` — the matching one-line description in root `CLAUDE.md` and `README.md`. Manifest regen + `metadata.version` bump still apply.
- **Update the Codex-eligible count too** — distinct from the total and easy to miss. Adding/removing a plugin changes the Codex-eligible number (total − 2 EXCLUDED: `core-config`, `codex-image`). Fix it in `CLAUDE.md`'s Codex-integration section (`for N eligible plugins`) and `README.md`'s Codex section (`N / M plugins`). Neither the version files nor `sync-codex-manifests.mjs --check` catches a stale eligible count.
- **Re-run both generators after any version / description change** — `node scripts/sync-codex-manifests.mjs` (regenerates `.codex-plugin/` + catalog) and `node scripts/sync-hermes-manifests.mjs` (regenerates `plugin.yaml` + `__init__.py` for HERMES_ELIGIBLE plugins). Both `--check` guards run in `.githooks/pre-commit` + `.github/workflows/validate-codex.yml`, so unregenerated output fails CI.
- **Register new plugins in `.claude/settings.json`** (`plugins.local` array, `./plugins/<name>`) when adding a plugin — this tracked file is what auto-loads plugins locally; marketplace registration alone does not. Neither the version files nor `sync-codex-manifests.mjs --check` catch this omission.
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
4. (If adding/removing a plugin) update plugin counts in `CLAUDE.md` and `README.md`, and add/remove its `./plugins/<name>` entry in `.claude/settings.json` (`plugins.local`).
5. Re-run `node scripts/sync-codex-manifests.mjs` and `node scripts/sync-hermes-manifests.mjs` to regenerate derived manifests/adapters.
6. Commit all changes together.

## User Update Workflow

Due to plugin cache bugs, users refresh plugins via:

```bash
rm -rf ~/.claude/plugins/cache/my-claude-plugins/
/plugin marketplace update my-claude-plugins
# Restart Claude Code
```
