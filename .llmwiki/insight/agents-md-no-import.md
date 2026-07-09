---
id: agents-md-no-import
aliases: [agents-md-pointer-trap, codex-no-at-import]
tier: insight
promoted_from: [[agents-md-verbatim-no-import]]
evidence_count: 2
last_verified: 2026-07-09
status: active
volatility: stable
sources: 1
---

# Never reduce AGENTS.md to a pointer — `@import` is Claude-only and one-directional

**Rule.** `AGENTS.md` must carry its guidance inline. Codex has no `@import` mechanism at all — it byte-reads `AGENTS.md` and expands nothing — and Hermes shows no evidence of one. `@path` imports are a Claude-only feature that works only *from* `CLAUDE.md`, which is the file Claude reads; Claude never reads `AGENTS.md`.

**Apply when.** Anyone proposes to stop hand-maintaining an `AGENTS.md` mirror by replacing it with `@CLAUDE.md`, a `See CLAUDE.md` line, or a prose "read CLAUDE.md first" redirect. Also when writing any cross-runtime guidance that Codex or Hermes must honor.

**Why.** The failure is silent: Codex reports no error, it just runs with an empty rule set. A prose redirect additionally cannot reach the Codex GitHub cloud reviewer, which loads the `## Review guidelines` section straight into its system prompt rather than walking files. If the mirror ever becomes too costly, invert the direction — make `AGENTS.md` the SSOT and have `CLAUDE.md` carry `@AGENTS.md`, which every runtime honors.

> Evidence: .llmwiki/wiki/plugin-ops/agents-md-verbatim-no-import.md
> See-also: [[insight-layer-via-hook]]

## Sources

1. `.llmwiki/wiki/plugin-ops/agents-md-verbatim-no-import.md` — `codex-rs/core/src/agents_md.rs`, the installed codex-cli 0.142.3 system prompt, the agents.md spec, and the Claude Code memory docs.
