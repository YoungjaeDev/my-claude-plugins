# Dual-Integration Rules

This marketplace is driven by **both Codex CLI and Claude Code**. Instructions, hooks, and lore that live on only one surface are invisible to half the toolchain. When you edit anything that shapes agent behavior, check the paired surface on the other runtime in the same change.

Since 1.40.0 the two runtimes share one source tree: Codex 0.135 reads `plugins/<name>/` in place via generated `.codex-plugin/plugin.json` manifests (the old `codex-bridge` body-transform mirror was retired). So "keeping the surfaces in sync" is mostly about guidance, hooks, and manifest regeneration — not copying files.

## Role

Keep the Claude Code surface and the Codex surface in sync whenever guidance, hooks, or derived artifacts change — so a rule added for one agent is not silently missing for the other. This rule itself is mirrored into the root `AGENTS.md` (Codex cannot `@import` `.claude/rules/`), making it self-demonstrating.

## Surface Map

| Concern | Claude Code surface | Codex surface |
|---|---|---|
| Top-level guidance | `CLAUDE.md`, `.claude/rules/*.md` (`@import`) | `AGENTS.md` (no `@import` — inline or mirror) |
| Prompt-submit injection | plugin `UserPromptSubmit` hook (`plugin.json` → `hooks/*.sh`) | `~/.codex/hooks.json` `UserPromptSubmit` → same script, `codex` format arg |
| Skill delivery | `plugins/*/skills` (native) | same `plugins/<name>/` tree in place + generated `.codex-plugin/plugin.json` (via `scripts/sync-codex-manifests.mjs`) |
| Command / subagent | `plugins/*/{commands,agents}` (native) | not supported by Codex 0.135 — Claude-only, not emitted to manifests |
| Shared neutral lore | `.llmwiki/` (read by Claude) | `.llmwiki/` (read by Codex — same root, never forked) |

## Do's

- **Edit guidance in pairs.** When you change `CLAUDE.md` behavioral guidance that Codex should also follow, update the matching `AGENTS.md` block (or confirm it is already covered). The reverse holds too.
- **Mirror cross-cutting `.claude/rules/` rules into `AGENTS.md`.** Codex cannot `@import` `.claude/rules/`, so a rule that both agents must honor needs a concise mirror block in `AGENTS.md` plus a one-line pointer in `CLAUDE.md` `## Modular Rules`.
- **Pair every hook change.** A new or changed Claude `UserPromptSubmit` / `SessionStart` hook in a `plugin.json` should be checked against the Codex `~/.codex/hooks.json` equivalent. Prefer one shared script with a format arg (plain stdout for Claude, JSON `additionalContext` for Codex) over two divergent copies.
- **Regenerate Codex manifests after a plugin's skills / `version` / `description` / `category` change.** Run `node scripts/sync-codex-manifests.mjs` (the `--check` drift guard otherwise fails). Codex reads skill bodies in place — no transform — so valid frontmatter still matters; `commands/` and `agents/` are Claude-only and are not emitted. core-config and midjourney are intentionally excluded (see the generator's `EXCLUDED` set).
- **Keep shared lore in the neutral root.** Cross-agent insight and wiki content live under `.llmwiki/` (never `.claude/`-only), so both runtimes read one copy.
- **State when a change is intentionally single-surface.** If guidance applies to only one agent (e.g. a Claude-only Plan Mode rule), say so in the change so the asymmetry reads as deliberate, not forgotten.

## Don'ts

- **Never add behavioral guidance to `CLAUDE.md` alone when it should bind both agents.** A Claude-only edit silently exempts every Codex session.
- **Never wire a Claude hook without considering the Codex counterpart.** Codex hooks require a separate `~/.codex/hooks.json` entry and a `/hooks` trust step — they are not auto-registered by the Claude plugin.
- **Never hand-edit generated Codex manifests.** `.codex-plugin/plugin.json` and `.agents/plugins/marketplace.json` are `sync-codex-manifests.mjs` output; edit the marketplace source + regenerate, or the `--check` guard flags drift.
- **Never promote wiki lore to `.claude/rules/`.** Codex never reads `.claude/rules/`. Cross-agent insight graduates to `.llmwiki/insight/` and is surfaced via the shared prompt-injection hook (see `llm-wiki` ingest rules). `.claude/rules/` is reserved for mechanical tool-operation rules (versioning, this file), not lore.
- **Never fork `.llmwiki/` into per-agent copies.** One neutral root is the point; a `.codex/wiki/` fork defeats it.

## Source of Truth

- This file is the Claude-side SSOT; the `AGENTS.md` "듀얼 통합" block is its Codex mirror — keep them consistent.
- Related: `plugin-versioning.md` (version bump + manifest regen), the `AGENTS.md` "Codex 통합 (shared-source)" section, and `.llmwiki/wiki/plugin-ops/shared-source-codex-manifests.md` (design rationale for the shared-source model).
