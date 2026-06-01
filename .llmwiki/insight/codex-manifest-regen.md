---
id: codex-manifest-regen
aliases: [regen-codex-manifests, codex-manifest-drift]
tier: insight
promoted_from: [[shared-source-codex-manifests]]
evidence_count: 2
last_verified: 2026-06-01
status: active
volatility: stable
sources: 2
---

# Regenerate Codex manifests after any plugin surface change

Run `node scripts/sync-codex-manifests.mjs` whenever a plugin's `skills` / `version` / `description` / `category` changes. Both runtimes read one source tree in place — there is no mirror and no body transform, so never hand-edit a generated `.codex-plugin/plugin.json` or `.agents/plugins/marketplace.json`, and never reintroduce a `.claude/`→`.codex/` body-rewrite.

**When to apply**: any edit to a plugin's marketplace metadata or skill set; before committing such a change.

**Why**: the `--check` mode is the CI drift gate — a stale or hand-edited manifest fails it; the retired `codex-bridge` body-transform corrupted authorial intent (275 audited hits were legitimate filesystem docs, not stale refs).

The full story (the generator's three modes, the schema constraints, the 275-hit audit) stays in the `promoted_from:` wiki page — not inlined here.

## Sources

- `.llmwiki/wiki/plugin-ops/shared-source-codex-manifests.md` — the promoted source page (generator modes, EXCLUDED set, orphan detection, the body-transform audit).
- `scripts/sync-codex-manifests.mjs` — the generator and `--check` drift guard itself.

> Evidence: .llmwiki/wiki/plugin-ops/shared-source-codex-manifests.md
> See-also: [[shared-source-codex-manifests]]
