---
id: plugin-cache-restart
aliases: [plugin-version-pin-rule, mid-migration-source-of-truth]
tier: insight
promoted_from: [[cache-version-pinning]]
evidence_count: 2
last_verified: 2026-06-01
status: active
volatility: stable
sources: 2
---

# A session pins plugin versions at startup — restart to pick up updates

Claude Code resolves and pins each plugin's version once, at session start. A `/plugin marketplace update` that lands a newer version in the cache is invisible to the running session until a restart re-resolves. So during a migration window, do NOT trust the pinned skill's defaults — drive the work from the repo's current source files (and the documented resolution order), not the cached skill body.

**When to apply**: any time observed plugin/skill behavior lags the repo source — especially mid-migration when the cache holds both old and new versions.

**Why**: acting on a stale pinned skill silently runs an older workflow (e.g. a wiki skill resolving the legacy `.claude/wiki/` root instead of `.llmwiki/`), wasting a cycle on a non-bug.

Escape hatches and the cache-vs-version-pin distinction stay in the `promoted_from:` wiki page; only the operating rule is promoted here.

## Sources

- `.llmwiki/wiki/plugin-ops/cache-version-pinning.md` — the promoted source page (the pin mechanism, escape hatches, the distinct cache-refresh bug).
- `.claude/rules/plugin-versioning.md` — the schema-layer version contract and the separate `rm -rf` cache-refresh workaround.

> Evidence: .llmwiki/wiki/plugin-ops/cache-version-pinning.md
> See-also: [[cache-version-pinning]]
