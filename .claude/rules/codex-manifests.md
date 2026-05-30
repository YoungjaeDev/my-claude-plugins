---
paths: plugins/**, .agents/plugins/marketplace.json, scripts/sync-codex-manifests.mjs
---

# Codex Manifest Sync Rules

This repo co-locates a Claude Code marketplace (`.claude-plugin/marketplace.json`)
and a Codex marketplace (`.agents/plugins/marketplace.json`) in one tree using the
**shared-source** model: Codex loads the same `plugins/<name>/skills/` that Claude
auto-discovers — no transform, no copies.

## Invariants

- **Generated, not hand-edited.** `plugins/<name>/.codex-plugin/plugin.json` and
  `.agents/plugins/marketplace.json` are produced by `scripts/sync-codex-manifests.mjs`
  from the Claude `.claude-plugin/` source. Never edit them by hand — change the
  source manifest and regenerate.
- **Regenerate on change.** After adding/removing a skill, or changing a plugin's
  version/description, run `node scripts/sync-codex-manifests.mjs` and include the
  result in the same commit. CI/review can guard with `--check` (exits 1 on drift).
- **Inclusion rule.** A plugin enters the Codex catalog only if it ships ≥1 skill
  and is not in the script's `EXCLUDE` set (currently `midjourney`). Command-only
  plugins (no skills) are Claude-only — Codex cannot load commands.
- **`source.path` is repo-root relative** and points at the real plugin dir
  (`./plugins/<name>`); `./` (repo root itself) is rejected by Codex.
- **Single skills root.** Each `.codex-plugin/plugin.json` uses `skills: "./skills/"`;
  Codex loads exactly that one directory (it has no `commands`/`agents` fields).
