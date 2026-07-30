---
id: shared-source-codex-manifests
aliases: [codex-shared-source, sync-codex-manifests, codex-manifest-generator, retired-codex-bridge]
last_verified: 2026-07-14
status: active
volatility: stable
sources: 10
---

# Shared-source Codex manifests

Claude Code and Codex 0.135 load the **same** `plugins/<name>/skills/` tree.
There is no mirror, no per-agent fork, and no body transform. A thin manifest
generator (`scripts/sync-codex-manifests.mjs`, ~140 LOC, zero runtime
dependencies) emits Codex's required catalog files from `.claude-plugin/
marketplace.json`; both runtimes then read the same skill bodies in place.

> See-also: [[hermes-plugin-adapter]]

A third runtime, Hermes Agent, now consumes the same tree via a native
`plugin.yaml` + `__init__.py` adapter (github-dev pilot) — "Claude + Codex" is
the original pair, not the ceiling.

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
side. The generator excludes plugins via an `EXCLUDED` set; the **sole** current entry
is `codex-image` — a Claude->Codex *bridge* (it delegates image generation to
`codex exec`), so syncing it back into Codex would be circular (Codex asked to
load a skill whose only job is to call Codex). So **all plugins except that 1 are
eligible** for Codex (eligible count = total − 1 = 23); the absolute number shifts
on every plugin add/remove, so the durable invariant is the EXCLUDED set, not a
fixed count. (`core-config` was the second EXCLUDED member until PR #124 promoted
it to eligible — see *Native plugin hooks* below; `midjourney` was a third until
PR #84 deleted the plugin — a removed plugin needs no EXCLUDED entry; the drift
guard's orphan detection covers any stale manifest.) EXCLUDED scopes Codex *manifest
eligibility* only — it is not an *install* filter: the `install-skills` wrapper
(which pushes these skills into Codex/Hermes via `npx skills`) filters by skill
count, so codex-image stays installable to Codex from that tool (`> See-also:` below).

`deepwiki` and `project-init` were in the EXCLUDED set before 1.41.0 because
they shipped only `commands/`. The 1.41.0 dual-surface conversion added
`skills/` directories whose bodies point at the same `references/` procedures
the commands use, so the plugins now have something for Codex to load and leave
the exclusion list (the layout is the `> See-also:` page below).

`.mcp.json` is treated as a *file* path in the Codex manifest, not a directory
— a subtle schema difference from Claude's behavior that the generator handles
when reading per-plugin entries.

## Native plugin hooks (core-config eligibility)

Codex 0.135 **does** support bundled plugin hooks — the earlier assumption that
it had "no equivalent hook surface" (which kept `core-config` EXCLUDED) was wrong.
A plugin ships a source-controlled descriptor at `hooks/codex-hooks.json`, and the
generator wires it into the manifest's top-level `hooks` as a **path**
(`"hooks": "./hooks/codex-hooks.json"`), not an inlined object — the descriptor
stays the single source, and Codex's own discovery only finds `hooks/hooks.json`
by default, so the Codex-named descriptor *must* be declared in the manifest.
`--check` validates each descriptor's shape (top-level `hooks` object keyed on
known events, each group `{matcher?, hooks:[{type:"command",command}]}`), that
every `$PLUGIN_ROOT`-relative script exists, and rejects orphans. The orphan-hooks
case (descriptor removed but a stale generated `hooks` field survives) is a
violation **only in `--check`/dry mode** — in write mode the regeneration drops it,
exactly like an orphan manifest, so it must not fatal-abort before outputs are
built.

`core-config` therefore left EXCLUDED in PR #124 as a **hooks-only** Codex
manifest: it has no skills, so its generated `plugin.json` carries only `hooks`
(the `UserPromptSubmit` prompt-inject descriptor invoked with the `codex` arg).
Its Python auto-formatter + notification hooks stay Claude-only — they assume
Claude Write/Edit payloads and Stop/Notification events that do not map onto Codex.
Codex still requires a `/hooks` trust approval before a plugin's hooks run; the
bundled descriptor is now the primary path (the legacy hand-copied
`~/.codex/hooks.json` still works). `PLUGIN_ROOT` is the Codex-provided plugin-root
env-var (`CLAUDE_PLUGIN_ROOT` is a compat alias), quoted so a path with spaces
still resolves.

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

## Skill bodies must be runtime-portable

Both runtimes read the same skill body **in place**, so the body itself must be
followable on both. A body that hard-depends on a **Claude-only built-in agent**
— e.g. routing a command or a fact-check step through `claude-code-guide` — is
unfollowable under Codex, which has no such agent: the step silently dead-ends on
half the toolchain, the same asymmetric-loss failure mode as the description cap.
The rule: in a shared body the **default** path must be one *both* runtimes can
take (official-docs lookup, a CLI, an MCP tool), and a Claude-only agent is at
most an *optional enhancement* gated on the runtime ("Claude 런타임이면 ... 도
활용 — 미번들·타 런타임이면 공식 docs 직접"). `commands/` and `agents/` are not
emitted to Codex at all (above), but a Claude-only agent named inside a *skill
body* slips past that exclusion — it ships to Codex as unfollowable prose unless
the body demotes it to optional.

A sharper version of the same failure surfaced with a plugin that ships its
**own** `agents/` directory and a skill that *dispatches* them. `ppt-yeong-style`
0.7.0 (PR #94) added four review agents (`agents/{audience-fit,story-flow,fact-check,design-qa}.md`)
and a `deck-review` skill that fans them out as parallel subagents. This is
doubly broken off the Claude surface: (1) the generator does not emit `agents/`
to the Codex manifest, so the agent *definitions* never ship, and (2) Codex 0.135
and Hermes have no subagent-dispatch mechanism at all, so even a shipped
definition could not be invoked. A skill whose core loop is "dispatch N agents in
parallel" therefore dead-ends on both non-Claude runtimes. The fix is the same
shape as the description-cap fix — keep meaning in the shared body, don't rely on
a Claude-only surface: `deck-review`'s body declares an explicit **runtime
fallback** — on a runtime without subagent dispatch (Codex, Hermes), run the same
four review *perspectives* as a sequential checklist in the main session, keeping
the input/output contract identical. The rule: a shared skill body that dispatches
subagents must name its no-dispatch fallback, or it is Claude-only in effect while
appearing cross-runtime.

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
- PR #74 body — `ppt-yeong-style` v0.2.0; the fact-check principle (SKILL.md §원칙4
  + `references/ppt-master-and-qa.md` + `assets/injection-prompt.md`) defaults to
  official docs and demotes the Claude-only `claude-code-guide` agent to an
  optional, runtime-gated enhancement — the runtime-portable-body rule.
- PR #94 body (merge `7b5a721`) — `ppt-yeong-style` 0.7.0 sub-skill split adds
  `agents/` (4 review agents) + a `deck-review` dispatch skill; the plugin-own-
  agents dispatch case + the sequential-checklist runtime fallback for Codex/Hermes
  (no subagent dispatch). Verified against the merged `deck-review/SKILL.md`
  runtime-fallback rule.
- PR #124 body (merge `c694f1e`) — Codex native plugin hooks + core-config
  eligibility: the `hooks/codex-hooks.json` descriptor convention wired to the
  manifest's top-level `hooks` (path form), the `--check` descriptor validation
  (shape + referenced-script existence + orphan rejection, orphan-hooks scoped to
  check mode), and the EXCLUDED shrink to `{codex-image}` with `core-config` as a
  hooks-only manifest. Verified against the merged `sync-codex-manifests.mjs` +
  `manifest-eligibility.mjs`.

> Supersedes: (retired plugin `codex-bridge` 1.0.0)
> Refined-by: [[agents-md-verbatim-no-import]]
> Promoted-to: [[codex-skill-desc-1024]]
> See-also: [[neutral-llmwiki-root]]
> See-also: [[cache-version-pinning]]
> See-also: [[dual-surface-command-skill-pattern]]
> See-also: [[skills-install-wrapper]]
> See-also: [[skill-engine-layering]]
> Evidence: scripts/sync-codex-manifests.mjs
> Evidence: AGENTS.md
> Evidence: plugins/ppt-yeong-style/skills/deck-review/SKILL.md (path dead — plugin removed in the 2.9.0 release; read it at merge `7b5a721`)
