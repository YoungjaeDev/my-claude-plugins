---
id: neutral-llmwiki-root
aliases: [llmwiki-root, neutral-root, codex-fork-fix, dot-llmwiki]
last_verified: 2026-05-31
status: active
volatility: stable
sources: 3
---

# Neutral `.llmwiki/` root

The wiki and raw-evidence layers live under a neutral top-level `.llmwiki/` root
rather than under `.claude/`. This is a data-layout choice that defends against
a concrete bug in the sibling `codex-bridge` plugin, not a special-case code
carve-out.

## The Codex fork bug

`codex-bridge` syncs plugin skills into Codex by rewriting `.claude/` to
`.codex/` literally inside skill BODIES (a `{ from: ".claude/", to: ".codex/",
mode: "literal" }` transform, `bodyOnly: true`). A skill that names
`.claude/wiki/` therefore becomes `.codex/wiki/` once synced into Codex. The
same skill text then resolves to two different roots depending on which agent
runs it, forking the wiki into divergent per-agent copies — the opposite of a
single compounding artifact.

## The fix: a root the transform can never match

Because the transform's match string is `.claude/`, anything not under
`.claude/` is inert to it. Moving the wiki and raw layers to a neutral top-level
`.llmwiki/` root puts them outside the transform's match set entirely, so the
same skill body reads `.llmwiki/wiki/` in both Claude Code and Codex. No
per-agent fork.

The schema layer stays at `.claude/rules/` deliberately. Verified during
planning: `.claude/rules/*.md` is the only path that auto-loads at session
start (recursive, with `paths:` globs for conditional load). Moving the schema
out of `.claude/` would lose that auto-load, so only the wiki/raw layers move;
the schema is pinned where the loader expects it.

## Ecosystem corroboration

The 2026-05 ecosystem survey shows real-world llm-wiki repos converge on
neutral, runtime-agnostic data paths — sibling `raw/` and `wiki/` directories,
and a top-level `.llmwiki/` convention seen in active projects — never nesting
the knowledge data under an agent-specific `.claude/` directory. The neutral
root is the prevailing pattern, not a local invention.

## Resolution order

Skills and hooks resolve the wiki root in order, so legacy and forked
deployments keep working until migrated:

`.llmwiki/wiki/` (preferred) -> `.claude/wiki/` (legacy) ->
`.codex/wiki/` (legacy Codex fork).

New repos get `.llmwiki/`; old repos keep functioning until a migration
consolidates them into the neutral root.

## Vindication: the transform was the problem, not stale references

A pre-retirement audit grepped the three `codex-bridge` body transforms
(`.claude/`→`.codex/`, `CLAUDE.md`→`AGENTS.md`, `/plugin:skill`→`$skill`)
across the entire skill tree and found ~275 hits. Spot-checking revealed that
nearly all hits were **legitimate documentation of Claude's filesystem**, not
stale references that needed rewriting: `llm-wiki` bootstraps `.claude/rules/`
literally (the only verified session-start auto-load path), `github-dev/cr-fix`
iterates `CONFIG_FILES="CLAUDE.md AGENTS.md"`, `rules-forge` explains the
semantics of `CLAUDE.md` to its readers. The transforms were corrupting
authorial intent rather than translating it.

The fork bug is now eliminated structurally: the `codex-bridge` plugin (the
transform source) is retired, and both runtimes read the same source via a
manifest generator that emits *outside* the skill bodies — see
[[shared-source-codex-manifests]]. The neutral-root data layout remains the
correct defense against any future mirror that might re-emerge.

## Sources

- `.llmwiki/raw/perplexity-llm-wiki-survey-2026-05.md` — 2026-05 ecosystem
  survey; real repos (nvk/llm-wiki, Pratiyush/llm-wiki, dair-ai/wiki-builder and
  others) use neutral runtime-agnostic raw/ + wiki/ layouts and a `.llmwiki/`
  convention rather than nesting data under `.claude/`.
- `.claude/spec/2026-05-29-llm-wiki-v2.md` — the design contract recording the
  literal `.claude/` -> `.codex/` body transform, the verified `.claude/rules/`
  auto-load path, the per-layer-neutral decision, and the resolution order.
- `scripts/sync-codex-manifests.mjs` + PR #39 body — records the 275-hit
  body-transform audit and the structural elimination of the
  `codex-bridge` plugin (replaced by a generator that emits manifests
  outside the skill bodies). Confirms the transform was the bug, the data
  paths it touched were not.

> Refines: [[curated-conservative]]
> See-also: [[shared-source-codex-manifests]]
> Evidence: .llmwiki/raw/perplexity-llm-wiki-survey-2026-05.md
> Evidence: .claude/spec/2026-05-29-llm-wiki-v2.md
> Evidence: scripts/sync-codex-manifests.mjs
