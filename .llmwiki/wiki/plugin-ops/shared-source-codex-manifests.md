---
id: shared-source-codex-manifests
aliases: [codex-shared-source, sync-codex-manifests, codex-manifest-generator, retired-codex-bridge]
last_verified: 2026-06-08
status: active
volatility: stable
sources: 7
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
  marketplace catalog, if an orphan `.codex-plugin/` directory exists for a
  plugin no longer in `.claude-plugin/marketplace.json`, or if any skill
  `description` exceeds the Codex length cap (see the guard section below)
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
are `core-config` (Claude-only hooks; Codex has no equivalent hook surface),
`midjourney` (image-gen workflow does not fit Codex's execution model), and
`codex-image`. The last has a different reason from the other two: it is a
Claude->Codex *bridge* (it delegates image generation to `codex exec`), so
syncing it back into Codex would be circular — Codex would be asked to load a
skill whose only job is to call Codex. That yields **19 of 22** plugins
eligible for Codex.

`deepwiki` and `project-init` were in the EXCLUDED set before 1.41.0 because
they shipped only `commands/`. The 1.41.0 dual-surface conversion added
`skills/` directories whose bodies point at the same `references/` procedures
the commands use, so the plugins now have something for Codex to load and leave
the exclusion list (the layout is the `> See-also:` page below).

`.mcp.json` is treated as a *file* path in the Codex manifest, not a directory
— a subtle schema difference from Claude's behavior that the generator handles
when reading per-plugin entries.

## Skill-description length guard

Codex 0.135 silently **skips** any skill whose `description` frontmatter exceeds
1024 characters — no warning, no manifest error, the skill just never loads on
the Codex side. Claude Code has no such cap, so a too-long description is
invisible from the Claude surface: the skill works for Claude while quietly
vanishing for Codex. `research-orchestrator` (1214 chars) was lost this way until
PR #46 surfaced it.

The structural failure is the asymmetry — one runtime enforces a limit the other
ignores, so the shared-source model needs an enforced floor rather than relying
on either runtime to complain. The guard is three-layered so a violation is
caught at the earliest point a contributor touches it:

- **Generator** — `sync-codex-manifests.mjs` runs `validateSkillDescriptions`
  (via `extractFrontmatterDescription`) against `SKILL_DESC_MAX = 1024` in
  *every* mode, before the drift check. It is scoped to the
  marketplace-listed plugin set, not all on-disk `plugins/` dirs, so an
  unpublished local plugin can't false-fail `--check`.
- **Pre-commit** — the shared `.githooks/pre-commit` runs `--check` on every
  commit. It lives in-repo (not `.git/hooks/`), so it is version-controlled;
  activate once per clone with `git config core.hooksPath .githooks`.
- **CI** — `.github/workflows/validate-codex.yml` runs `--check` on push/PR with
  `permissions: contents: read`, catching anyone who skipped the local hook.

The fix when a description trips the cap is **not** to truncate meaning: move the
full trigger list and per-tool rationale into the skill *body* (and
`references/`), keeping the `description` to a tight routing summary. Codex reads
the body in place, so nothing is lost.

The guard has already paid for itself a second time: in PR #51 the `post-merge`
skill description sat at 1019 chars, and swapping its `humanizer` reference for
the longer `humanize-korean` would have pushed it to 1026 — a silent Codex drop
of the whole skill. The author offset the +7 by trimming `gracefully skip` →
`skip` elsewhere in the same description, landing at 1014. Two independent
recurrences (PR #46 hard-fail, PR #51 near-miss) graduated this rule to the
insight layer.

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
- PR #41 body — records the EXCLUDED-set shrink from 4 to 2 after the
  dual-surface conversion of `deepwiki` + `project-init`, plus the
  cross-runtime portability discoveries (`${CLAUDE_PLUGIN_ROOT}` does not
  expand under Codex 0.135) that the conversion surfaced.
- PR #46 body — records the 1024-char Codex skill-description silent-skip quirk
  (`research-orchestrator` at 1214 chars) and the three-layer length guard
  (generator `SKILL_DESC_MAX`, `.githooks/pre-commit`, `validate-codex.yml`).
- PR #49 body — adds `codex-image` (Claude->Codex image-gen bridge) as the 22nd
  plugin and the 3rd EXCLUDED entry, with the circular-bridge exclusion rationale.
- PR #51 body — the length-guard near-miss (post-merge skill 1019 → would-be 1026
  on the `humanize-korean` swap, offset to 1014); the second recurrence that
  graduated the rule to insight.

> Supersedes: (retired plugin `codex-bridge` 1.0.0)
> Promoted-to: [[codex-skill-desc-1024]]
> See-also: [[neutral-llmwiki-root]]
> See-also: [[cache-version-pinning]]
> See-also: [[dual-surface-command-skill-pattern]]
> Evidence: scripts/sync-codex-manifests.mjs
> Evidence: AGENTS.md
