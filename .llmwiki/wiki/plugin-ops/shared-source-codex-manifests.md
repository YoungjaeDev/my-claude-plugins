---
id: shared-source-codex-manifests
aliases: [codex-shared-source, sync-codex-manifests, codex-manifest-generator, retired-codex-bridge]
last_verified: 2026-05-31
status: active
volatility: stable
sources: 3
---

# Shared-source Codex manifests

Claude Code and Codex 0.135 load the **same** `plugins/<name>/skills/` tree.
There is no mirror, no per-agent fork, and no body transform. A thin manifest
generator (`scripts/sync-codex-manifests.mjs`, ~140 LOC, zero runtime
dependencies) emits Codex's required catalog files from `.claude-plugin/
marketplace.json`; both runtimes then read the same skill bodies in place.

This replaced the retired `codex-bridge` plugin, which had been a 1,214-line
`sync.mjs` that copied skills into `~/.agents/skills/` while rewriting
`.claude/` to `.codex/`, `CLAUDE.md` to `AGENTS.md`, and `/plugin:skill` to
`$skill` inside the bodies.

## Why the body-transform mirror was wrong

A pre-PR audit grepped the three transform targets across the marketplace and
found ~275 hits. The audit found these were nearly all **legitimate
documentation of Claude's filesystem**, not stale references that needed
rewriting:

- `llm-wiki` bootstraps `.claude/rules/` literally — that path is the only
  verified session-start auto-load location and must not be renamed.
- `github-dev/cr-fix` already accepts `CONFIG_FILES="CLAUDE.md AGENTS.md"` and
  iterates both — rewriting `CLAUDE.md` to `AGENTS.md` inside its skill body
  would corrupt that iteration.
- `rules-forge` explains the semantics of `CLAUDE.md` to readers — the literal
  filename IS the lesson.

The transforms therefore corrupted authorial intent rather than translating it.
The structural fix is shared-source: keep one source, generate only what each
runtime requires *outside* the source body.

## The generator

`scripts/sync-codex-manifests.mjs` runs in three modes:

- default: write `.agents/plugins/marketplace.json` + per-plugin
  `plugins/<name>/.codex-plugin/plugin.json`
- `--check`: CI drift guard, exits 1 if any manifest disagrees with the
  marketplace catalog or if an orphan `.codex-plugin/` directory exists for a
  plugin no longer in `.claude-plugin/marketplace.json`
- `--dry-run`: print the would-be writes without touching disk

`.agents/` and `plugins/<name>/.codex-plugin/` are **generated**. Hand edits
are caught by the next `--check` and treated as drift.

## Codex 0.135 manifest schema constraints

Codex 0.135's plugin manifest top-level supports exactly four fields:

```
skills | hooks | mcpServers | apps
```

`commands` and `agents` exist in Claude's plugin schema but are **not** emitted
by the generator — Codex does not recognize them. Plugins whose value is
entirely in `commands` or `agents` therefore have nothing to load on the Codex
side. The generator excludes them via an `EXCLUDED` set; the current entries
are `core-config` (Claude-only hooks), `midjourney` (image-gen workflow not
portable), `deepwiki` and `project-init` (command-only, no Codex-loadable
component). That yields 17 of 21 plugins eligible for Codex.

`.mcp.json` is treated as a *file* path in the Codex manifest, not a directory
— a subtle schema difference from Claude's behavior that the generator handles
when reading per-plugin entries.

## Orphan manifest detection

`--check`'s drift guard also catches the inverse failure: a manifest file left
behind for a plugin that has since been removed from
`.claude-plugin/marketplace.json` (e.g. the deleted `codex-bridge` would have
left a stale `.codex-plugin/plugin.json` if not cleaned). The `EXCLUDED` set
does NOT need to retain removed plugins — orphan detection covers that case.

## Sources

- `scripts/sync-codex-manifests.mjs` — the generator itself; the source of
  truth for which fields are emitted, the `EXCLUDED` set, the orphan detection,
  and the `--check` / `--dry-run` flags.
- `~/.codex/skills/.system/plugin-creator/references/plugin-json-spec.md` —
  Codex 0.135's published plugin manifest spec; documents the four supported
  top-level fields and `.mcp.json` file-vs-directory handling.
- PR #39 body — records the 275-hit body-transform audit and the three
  audited rewrites (`CLAUDE.md`→`AGENTS.md`, `.claude/`→`.codex/`,
  `/plugin:skill`→`$skill`) that were found to corrupt authorial intent.

> Supersedes: (retired plugin `codex-bridge` 1.0.0)
> See-also: [[neutral-llmwiki-root]]
> See-also: [[cache-version-pinning]]
> Evidence: scripts/sync-codex-manifests.mjs
> Evidence: AGENTS.md
