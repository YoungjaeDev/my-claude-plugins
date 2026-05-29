---
id: cache-version-pinning
aliases: [plugin-cache-pinning, startup-version-pin, stale-plugin-version]
last_verified: 2026-05-29
status: active
volatility: volatile
sources: 2
---

# Plugin cache version-pinning

A running Claude Code session can serve an **older** plugin version than the one
already sitting in the cache. Knowing why explains the recurring surprise that
"I updated the marketplace, the new version is in the cache, yet the session
still behaves like the old one."

## The pin

The plugin cache keeps **multiple versions side by side** per plugin under
`~/.claude/plugins/cache/my-claude-plugins/<plugin>/<version>/`. A session
resolves one version per plugin **at startup** and pins it for the whole
session. It keeps serving that pinned version even after a newer version lands
in the same cache directory.

So `/plugin marketplace update` (which populates a new `<version>/` dir) is
necessary but **not sufficient** to change behavior: the new version is not
served until the next restart. A mid-session update is invisible to the running
session.

## Distinct from the cache-refresh bug

This is a different failure mode from the one in
`.claude/rules/plugin-versioning.md`. That rule covers file *contents* not
refreshing **within** a version dir (the `rm -rf ~/.claude/plugins/cache/...`
workaround). Version-pinning is about **which already-cached version dir** a
session resolves — both versions are present and intact; the session is simply
attached to the older one.

## Manifestation: stale skill behavior mid-migration

During the llm-wiki v1->v2 migration the cache held both `1.1.1` (v1) and
`1.2.0` (v2). A session pinned to v1 runs the v1 skills, which resolve the
legacy `.claude/wiki/` root and never look at the neutral `.llmwiki/` root that
v2 introduced. github-dev showed the same shape: `1.22.0` (pre-Step-5.8) and
`1.23.0` both cached, session pinned to `1.22.0`.

Symptom: a wiki skill mis-resolves to `.claude/wiki/` and misses `.llmwiki/`;
a command runs an older workflow body than the repo's current source. Workaround
during a migration window: do not trust the pinned skill's default — drive the
work from the **repo's current source files** and follow the v2 resolution order
(`.llmwiki/wiki/` -> `.claude/wiki/` -> `.codex/wiki/`) explicitly.

## Escape hatches

- Restart Claude Code after the cache holds the new version — the restart
  re-resolves and re-pins.
- List the plugin under `local` in `.claude/settings.json`
  (`./plugins/<name>`), which loads from the repo working tree and bypasses the
  versioned cache entirely. This still only takes effect after a restart, but
  thereafter the working tree is the single source.

## Sources

- `.claude/rules/plugin-versioning.md` — the schema-layer version contract and
  the separate cache-refresh bug (`rm -rf` workaround); this page documents the
  complementary in-session pinning behavior it does not cover.
- `~/.claude/plugins/cache/my-claude-plugins/<plugin>/<version>/` — runtime
  observation of multiple coexisting versions (`llm-wiki/{1.1.1, 1.2.0}`,
  `github-dev/{1.22.0, 1.23.0}`) while the session served the older pinned one.

> See-also: [[neutral-llmwiki-root]]
> See-also: [[curated-conservative]]
> Evidence: .claude/rules/plugin-versioning.md
