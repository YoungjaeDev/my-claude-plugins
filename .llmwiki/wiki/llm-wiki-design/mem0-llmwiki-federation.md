---
id: mem0-llmwiki-federation
aliases: [authority-header, mem0-decoupling, recall-vs-authoritative, federate-mem0]
last_verified: 2026-06-24
status: active
volatility: stable
sources: 3
---

# mem0 <-> llmwiki federation

Two memory systems run side by side — mem0 (semantic recall, its own MCP + hooks)
and llmwiki (dated/sourced lore under `.llmwiki/`). They are federated by
**labels only**, never by runtime coupling. The whole point is that borrowing
from mem0 costs zero mem0 calls: llmwiki imports mem0's *patterns* (an authority
label, a scoring rubric), not its data or its runtime.

## The authority hierarchy is a label

When federation is enabled (`CORE_CONFIG_FEDERATE_MEM0=1` — off by default, see
below), `core-config/hooks/prompt_inject.sh` (the per-prompt block) labels the
resolved wiki pointer:

- `.llmwiki/` pointer → `[AUTHORITATIVE]` — dated + sourced, wins on conflict.
- mem0 → `[RECALL]` — a secondary signal; when it conflicts with an
  `[AUTHORITATIVE]` page, the page wins.

The `[RECALL]` line is **just a label**. The hook never calls or reads mem0 —
mem0 surfacing is still mem0's own hooks. So the federation adds an authority
*ordering* without creating any dependency: rip mem0 out and the label simply
points at a layer that no longer speaks; rip llmwiki out and the pointer block
goes silent (it already guards on a wiki root resolving in CWD).

## Why labels, not integration

- **mem0 stays fully decoupled** — zero MCP calls, zero `~/.mem0` access. A
  runtime integration would couple llmwiki's prompt block to mem0's availability;
  a label couples nothing.
- **Opt-in, off by default** — federation labels ship **off**; the pointer stays
  plain unless `CORE_CONFIG_FEDERATE_MEM0=1` turns them on. The default flipped from
  on to off because the labels dragged mem0-coupling framing into every prompt as
  noise — a plain pointer is the sensible default and federation an opt-in. Either
  way the feature is a label layer, not a behavior change.
- **Codex asymmetry is deliberate** — Codex never sees mem0 recalls, so the
  shared `prompt_inject.sh` omits `[RECALL]` in its `codex` branch while keeping
  `[AUTHORITATIVE]`. Corollary: durable cross-agent lore must still graduate into
  `.llmwiki/` (read by both agents), because mem0 is a Claude-only recall layer.

## Pattern borrow, coarse band

The lint-wiki side borrows mem0's memory-reviewer *triage pattern* — per
duplicate cluster, a score mapped to a concrete remedy — but the score is a
coarse band (High/Medium/Low → merge/supersede/alias), **never a fabricated
float**. That keeps the borrow consistent with the wiki's
provenance-over-confidence rule: confidence is source-count + recency, not a
number a model invents.

## Retiring a hook that fights the enforced memory system

The same decoupling logic retired `core-config/hooks/memory_nudge.sh`. It nudged the
model to *save* durable facts to `MEMORY.md`, but the `mem0` plugin enforces mem0 as
the memory system — its `block_memory_write.sh` `PreToolUse` hook blocks native
memory writes. So the save-nudge was half-stale: it advised exactly what another
**enforced** hook forbids. The rule — when one hook advises behavior a second
enforced hook blocks, retire the advisory one; do not ship a contradiction in every
prompt.

## Sources

- `plugins/core-config/hooks/prompt_inject.sh` — the `[AUTHORITATIVE]` / `[RECALL]`
  labels, the `codex`-branch `[RECALL]` omission, and `CORE_CONFIG_FEDERATE_MEM0`
  (default off).
- `plugins/llm-wiki/skills/lint-wiki/SKILL.md` — the dedup-scoring rubric
  (coarse band, pattern not data).
- `mem0` plugin `scripts/block_memory_write.sh` — the enforced `PreToolUse` block on
  native memory writes that made `memory_nudge.sh`'s MEMORY.md save-advice stale.

> See-also: [[capture-curation-split]]
> See-also: [[provenance-over-confidence]]
> See-also: [[insight-layer-via-hook]]
> Evidence: plugins/core-config/hooks/prompt_inject.sh
