---
id: curated-conservative
aliases: [curated-conservative-upgrade, steal-the-ideas-not-the-plan, v2-harvest]
last_verified: 2026-06-01
status: active
volatility: stable
sources: 2
---

# Curated-conservative v2 upgrade

llm-wiki v2 harvests the lightweight, git-auditable kernel of each rohitg00-v2
idea and rejects the heavyweight machinery wrapped around it. The governing
phrase, drawn from the rohitg00 gist's own top comments, is "steal the ideas,
not the plan." This page is the hub for the four v2 design records; the other
three refine it.

## Why conservative

The rohitg00 v2 gist is a maximalist redesign (confidence floats, Ebbinghaus
decay, four physical memory tiers, vector/BM25/graph hybrid search, event-driven
auto-writes). The gist's own comment thread rejects that blueprint on three
counts that match the failure modes a month of real use surfaced on the Karpathy
gist:

- **False precision.** A numeric float confidence (`0.85`) reads as a measured
  quantity but is an LLM guess. Cheaper and more honest: count named sources.
- **Wrong decay model.** Ebbinghaus exponential decay assumes "old equals
  stale," but architecture decisions age slowly while transient bugs age fast.
  Time-since-write is the wrong axis.
- **Silent LLM corruption.** Event-driven auto-writes (a hook that edits the
  wiki on every source/session/query) let an LLM mutate a stale page with no
  human gate and no review — rare but catastrophic.

The existing plugin already embodied the conservative pattern before the term
was coined: a git-revertible diff-log in `log.md`, `last_verified:` instead of a
decaying float, human-gated writes (no hook ever edits the wiki), and typed
cross-refs. v2 formalizes that stance rather than chasing the maximalist plan.

## Adopted (the curated kernel)

Each item is the git-auditable, human-legible core of a rohitg00 idea, stripped
of its heavyweight implementation:

- **Provenance** — `sources: <N>` + a named `## Sources` list, in place of float
  confidence. See `> See-also` below.
- **Supersession** — `> Supersedes:` / `> Superseded-by:` + `status: stale`;
  old claims are kept, marked, linked, never deleted.
- **Volatility** — a `volatility:` class (stable/volatile) drives the staleness
  window, replacing decay math. See `> See-also` below.
- **Typed relations** — `Uses` / `Depends-on` / `Caused-by` / `Fixed-by` (plus
  the existing `Refines` / `Contradicts` / `Evidence` / `See-also`), killing the
  flat-`related` failure mode without an entity-extraction graph.
- **Output schemas** — each maintenance skill gains an explicit `## Output
  format` block plus worked examples, the legible kernel of "score everything."
- **SessionStart hint** — a soft, model-visible lint-overdue reminder; a hint,
  never an auto-write.
- **Multi-agent lint** — a read-only dispatch-one-agent-per-domain note for large
  wikis, the kernel of "multi-agent" without mesh-sync machinery.

## Rejected (heavyweight, fails the senior-engineer test)

- Numeric float confidence (false precision).
- Literal Ebbinghaus / exponential decay math (wrong axis: old is not stale).
- Four physical memory directories (`working/`, `episodic/`, `semantic/`,
  `procedural/`); v2 keeps a documentation-only conceptual overlay onto existing
  artifacts, no new dirs. (Refined: `.llmwiki/insight/` is the one carved-out
  exception — a new physical directory justified as the only cross-agent,
  hook-delivered surface for promoted rules, not a memory-tier mirror. The
  no-new-dir default still governs everything else. See
  `> See-also: [[insight-layer-via-hook]]`.)
- Vector / BM25 / graph hybrid search and the entity-extraction graph (the
  `index.md` MOC suffices at this scale).
- Event-driven auto-writes, quality-score auto-rewrite, mesh-sync, and
  privacy-filter machinery (silent-corruption and portability risk).

The dividing line is the senior-engineer test: keep what stays cheap, reversible,
and legible in `git`; drop what adds an unverifiable score or an autonomous
write path.

## Sources

- `.llmwiki/raw/external/2026-05-29-rohitg00-llm-wiki-v2-gist.md` — the v2 maximalist proposal
  (confidence scoring, forgetting/Ebbinghaus, consolidation tiers, hybrid search,
  event-driven hooks) and the implementation-spectrum framing that v2 reads as
  optional, not mandatory.
- `.llmwiki/raw/external/2026-05-29-karpathy-llm-wiki-gist.md` — the original three-layer pattern
  (raw / wiki / schema), the ingest-touches-10-to-15-pages observation, and the
  "wiki is just a git repo" framing that grounds the git-auditable kernel.

> See-also: [[neutral-llmwiki-root]]
> See-also: [[insight-layer-via-hook]]
> See-also: [[provenance-over-confidence]]
> See-also: [[volatility-over-decay]]
> Evidence: .llmwiki/raw/external/2026-05-29-rohitg00-llm-wiki-v2-gist.md
> Evidence: .llmwiki/raw/external/2026-05-29-karpathy-llm-wiki-gist.md
