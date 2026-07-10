# Multi-Runtime Integration Rules

This marketplace is driven by **Claude Code, Codex CLI, and Hermes Agent**. Instructions, hooks, and lore that live on only one surface are invisible to part of the toolchain. When you edit anything that shapes agent behavior, check the paired surfaces on the other runtimes in the same change.

Since 1.40.0 the runtimes share one source tree: Codex 0.135 reads `plugins/<name>/` in place via generated `.codex-plugin/plugin.json` manifests, and Hermes Agent reads it via generated `plugin.yaml` + `__init__.py` adapters (the old `codex-bridge` body-transform mirror was retired). So "keeping the surfaces in sync" is mostly about guidance, hooks, and manifest/adapter regeneration — not copying files.

## Role

Keep the Claude Code, Codex, and Hermes surfaces in sync whenever guidance, hooks, or derived artifacts change — so a rule added for one agent is not silently missing for the others. This rule itself is mirrored into the root `AGENTS.md` (Codex/Hermes cannot `@import` `.claude/rules/`), making it self-demonstrating. (File kept as `dual-integration.md`; scope is now three runtimes.)

Top-level guidance no longer needs mirroring at all: root `CLAUDE.md` is a **symlink to `AGENTS.md`**, so the two names resolve to one file and cannot drift. Only `.claude/rules/*.md` — which Codex and Hermes cannot read — still needs a hand-kept mirror block inside `AGENTS.md`.

## Surface Map

| Concern | Claude Code surface | Codex surface | Hermes surface |
|---|---|---|---|
| Top-level guidance | `CLAUDE.md` → symlink to `AGENTS.md`; `.claude/rules/*.md` (auto-loaded) | `AGENTS.md` (read verbatim — no `@import` mechanism) | `AGENTS.md` (read verbatim) |
| Prompt-submit injection | plugin `UserPromptSubmit` hook (`plugin.json` → `hooks/*.sh`) | `~/.codex/hooks.json` `UserPromptSubmit` → same script, `codex` format arg | (separate hook surface — currently unused) |
| Skill delivery | `plugins/*/skills` (native) | same tree in place + generated `.codex-plugin/plugin.json` (`scripts/sync-codex-manifests.mjs`) | same tree in place + generated `plugin.yaml` + `__init__.py` (`scripts/sync-hermes-manifests.mjs`) |
| Command / subagent | `plugins/*/{commands,agents}` (native) | not supported by Codex 0.135 — Claude-only | not supported by Hermes — skills only |
| Skill-body tool names | Claude tool names (`Bash`, `Read`, …) | identical to Claude (body read verbatim) | mapped to Hermes tools via in-body compat table (`Bash`→`terminal`, `AskUserQuestion`→`clarify`, …) |
| Shared neutral lore | `.llmwiki/` (read by Claude) | `.llmwiki/` (read by Codex — same root, never forked) | `.llmwiki/` (read by Hermes — same root) |

## Do's

- **Edit top-level guidance in `AGENTS.md`, never in `CLAUDE.md`.** They are the same file — `CLAUDE.md` is a symlink. Writing through the symlink works but reads as a two-file edit in review; go to `AGENTS.md` directly.
- **Mirror cross-cutting `.claude/rules/` rules into `AGENTS.md`.** Codex has no `@import` mechanism at all — it reads `AGENTS.md` byte-for-byte and expands nothing — so a rule that both agents must honor needs a concise mirror block in `AGENTS.md` plus a one-line pointer in `CLAUDE.md` `## Modular Rules`. `@import` is a Claude-only feature and only works from `CLAUDE.md`; Claude never reads `AGENTS.md` at all.
- **Pair every hook change.** A new or changed Claude `UserPromptSubmit` / `SessionStart` hook in a `plugin.json` should be checked against the Codex `~/.codex/hooks.json` equivalent. Prefer one shared script with a format arg (plain stdout for Claude, JSON `additionalContext` for Codex) over two divergent copies.
- **Regenerate Codex manifests after a plugin's skills / `version` / `description` / `category` change.** Run `node scripts/sync-codex-manifests.mjs` (the `--check` drift guard otherwise fails). Codex reads skill bodies in place — no transform — so valid frontmatter still matters; `commands/` and `agents/` are Claude-only and are not emitted. core-config and codex-image are intentionally excluded (see the generator's `EXCLUDED` set).
- **Regenerate Hermes adapters after a HERMES_ELIGIBLE plugin's `version` / `description` change.** Run `node scripts/sync-hermes-manifests.mjs` (the `--check` drift + orphan guard otherwise fails). `plugin.yaml` / `__init__.py` are generated from `marketplace.json` — never hand-edit them. Coverage is the generator's `HERMES_ELIGIBLE` allowlist (the symmetric counterpart of Codex's `EXCLUDED` denylist); add a name to extend it.
- **Keep shared skill bodies runtime-portable.** Claude and Codex share tool names, so a body that also runs under Hermes carries a compatibility table mapping Claude/Codex tool terms (`Bash`, `Read`, `Edit`, `AskUserQuestion`, `Task`, `Skill`, `NotebookEdit`, image generation) to Hermes tools (`terminal`, `read_file`, `patch`, `clarify`, `delegate_task`, `skill_view`, Jupyter Live Kernel / `write_file`·`patch`, `image_generate`). Add or refresh the table when a body's tool usage changes. A body that invokes bundled `scripts/` must not reference `${CLAUDE_PLUGIN_ROOT}` bare — Codex 0.135 does not export it, so the call fails at step one; carry the cross-runtime `PLUGIN_ROOT` resolver block instead (`CLAUDE_PLUGIN_ROOT` → source-tree `plugins/<name>` → Codex cache lookup; reference implementations: project-init, mem0-ops).
- **Keep skill `description` frontmatter under 1024 chars.** Codex 0.135 silently skips any skill whose `description` exceeds 1024 characters; Claude Code has no such limit, so the violation is invisible on the Claude side. `--check` validates description length (not just drift), and the shared `.githooks/pre-commit` runs it on every commit — activate once per clone with `git config core.hooksPath .githooks`. Put the full trigger list / per-tool rationale in the skill body, not the description.
- **Quote a skill `description` that contains a colon-space (`: `).** YAML frontmatter parses `description: ...: ...` as a nested mapping and fails with `mapping values are not allowed here`, so the skill silently fails to load on both runtimes. Wrap the value in double quotes (or a `>-` block scalar). `plugin.json` / `marketplace.json` are JSON and unaffected; the lenient manifest generator and `--check` do NOT catch this.
- **Keep shared lore in the neutral root.** Cross-agent insight and wiki content live under `.llmwiki/` (never `.claude/`-only), so both runtimes read one copy.
- **State when a change is intentionally single-surface.** If guidance applies to only one agent (e.g. a Claude-only Plan Mode rule), say so in the change so the asymmetry reads as deliberate, not forgotten.

## Don'ts

- **Never add behavioral guidance to `CLAUDE.md` alone when it should bind both agents.** A Claude-only edit silently exempts every Codex session.
- **Never wire a Claude hook without considering the Codex counterpart.** Codex hooks require a separate `~/.codex/hooks.json` entry and a `/hooks` trust step — they are not auto-registered by the Claude plugin.
- **Never hand-edit generated manifests/adapters.** `.codex-plugin/plugin.json` + `.agents/plugins/marketplace.json` (Codex) and `plugin.yaml` + `__init__.py` (Hermes) are generator output; edit the marketplace source + regenerate, or the `--check` guards flag drift.
- **Never promote wiki lore to `.claude/rules/`.** Neither Codex nor Hermes reads `.claude/rules/`. Cross-agent insight graduates to `.llmwiki/insight/` and is surfaced via the shared prompt-injection hook (see `llm-wiki` ingest rules). `.claude/rules/` is reserved for mechanical tool-operation rules (versioning, this file), not lore.
- **Never fork `.llmwiki/` into per-agent copies.** One neutral root is the point; a `.codex/wiki/` fork defeats it.
- **Never reduce `AGENTS.md` to a pointer at `CLAUDE.md`.** An `@CLAUDE.md` line is dead text under Codex and Hermes (neither expands `@`), and a prose "read CLAUDE.md first" redirect cannot reach the Codex GitHub cloud reviewer, which loads the `## Review guidelines` section straight into its system prompt rather than walking files. The failure is silent — Codex reports no error, it just runs with no guidance. This repo took the inverse, which is the safe direction: `AGENTS.md` is the SSOT and `CLAUDE.md` is a symlink to it. (`CLAUDE.md` carrying `@AGENTS.md` achieves the same and is what the official Claude docs recommend; the symlink is stronger because one file cannot drift from itself, at the cost of a git mode-120000 entry that needs `core.symlinks` on Windows checkouts.)

## Source of Truth

- This file is the Claude-side SSOT; the `AGENTS.md` "멀티런타임 통합" block is its Codex/Hermes mirror — keep them consistent.
- Related: `plugin-versioning.md` (version bump + manifest/adapter regen), the `AGENTS.md` "Codex 통합 (shared-source)" and "Hermes 통합 (shared-source)" sections, `.llmwiki/wiki/plugin-ops/shared-source-codex-manifests.md` (Codex shared-source rationale), and `.llmwiki/wiki/plugin-ops/hermes-plugin-adapter.md` (Hermes adapter rationale).
