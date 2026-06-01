---
id: insight-layer-via-hook
aliases: [insight-layer, promoted-layer, insight-via-hook, no-rules-promotion]
last_verified: 2026-06-01
status: active
volatility: stable
sources: 2
---

# Insight layer, delivered via prompt-injection hook

This page refines `[[neutral-llmwiki-root]]` with two decisions made once the
marketplace became dual-runtime (Claude Code + Codex CLI): a promoted **insight**
layer at `.llmwiki/insight/`, and the retirement of `.claude/rules/` as a
wiki-promotion target. The neutral-root page still owns the physical-layout
rationale (why wiki/raw live under `.llmwiki/`); this page covers where *promoted*
rules go and how they reach both agents.

## The three layers under `.llmwiki/`

- `.llmwiki/insight/` — promoted, cross-agent rules (the small graduated set).
- `.llmwiki/wiki/` — LLM-maintained lore.
- `.llmwiki/raw/` — immutable evidence (wiki cites, never copies).

All three sit under the neutral `.llmwiki/` root so a single source serves both
runtimes — the rationale and its 2026-05 vindication are in `[[neutral-llmwiki-root]]`
and `[[shared-source-codex-manifests]]` (the old `codex-bridge` body-transform
mirror was retired in 1.40.0; Codex now reads the same tree in place).

## Why the promoted layer is `.llmwiki/insight/`, not `.claude/rules/`

`[[neutral-llmwiki-root]]` pins the *schema* layer at `.claude/rules/` because
that is the only path that auto-loads at Claude session start. That holds for
Claude — but it does NOT extend to *promotion*: **Codex never reads
`.claude/rules/`**, so any rule promoted there is invisible to half the
toolchain. Auto-load on one agent is worth less than visibility on both.

So llm-wiki **retires `.claude/rules/` as a wiki-promotion target entirely**.
Cross-agent rules graduate to `.llmwiki/insight/` and are surfaced to *both*
runtimes by the `core-config` `prompt_inject.sh` hook — a Claude
`UserPromptSubmit` hook and a Codex `~/.codex/hooks.json` `UserPromptSubmit`
hook running the same script (plain stdout for Claude, `additionalContext` JSON
for Codex). The hook injects a pointer ("consult `.llmwiki/insight/` first"),
not the insight content itself. This trades Claude's `paths:`-glob auto-load for
hook-delivered parity across agents — a deliberate, full migration, not a
straddle.

`.claude/rules/` survives only for **mechanical tool-operation rules**
(`plugin-versioning.md`, `dual-integration.md`) — repo machinery, not wiki lore.

## `.llmwiki/insight/` is the one justified new physical directory

`[[curated-conservative]]` rejected adding physical memory-tier directories
(`working/`, `episodic/`, `semantic/`, `procedural/`) and adopted a
documentation-only conceptual overlay onto existing artifacts — "no new dirs."
`.llmwiki/insight/` is a new physical directory, so it refines that stance with
one carved-out exception. The exception is justified on different grounds than
the rejected tiers: insight is not a memory-model tier mirrored onto data that
already exists elsewhere; it is the **only cross-agent-visible, hook-delivered
surface** for promoted rules. There is no existing artifact both agents load that
could host it (`.claude/rules/` fails the Codex test; the wiki MOC is on-demand,
not injected). The directory earns its place by being the delivery mechanism, not
a speculative taxonomy. The no-new-dir default still holds for everything else.

## Sources

- `.claude/spec/2026-05-29-llm-wiki-v2.md` — records the verified `.claude/rules/`
  auto-load path (the original, now-refined promotion argument).
- `.llmwiki/insight/index.md` — the insight layer's own MOC: promotion criteria,
  frontmatter schema, and the non-append consolidation discipline.

> Refines: [[neutral-llmwiki-root]]
> Refines: [[curated-conservative]]
> See-also: [[shared-source-codex-manifests]]
> Evidence: .claude/spec/2026-05-29-llm-wiki-v2.md
> Evidence: .llmwiki/insight/index.md
