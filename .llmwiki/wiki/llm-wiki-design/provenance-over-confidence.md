---
id: provenance-over-confidence
aliases: [provenance, sources-count, no-float-confidence, named-sources]
last_verified: 2026-05-29
status: active
volatility: stable
sources: 2
---

# Provenance over confidence

v2 rejects numeric float confidence (the `0.85`-style score) and adopts a
`sources: <N>` integer count backed by a named `## Sources` provenance list on
every page. "How sure are we" is answered by what we can point at, not by a
number nobody measured.

## What rohitg00 proposed, and why it is rejected

The rohitg00 gist's confidence-scoring section proposes that every fact carry a
float confidence that decays with time and strengthens with reinforcement, so
the wiki can say "fairly sure about X, less sure about Y." The problem is that
the float is fabricated. An LLM emitting `0.85` has not run a calibration; the
two-decimal precision reads as measured but is a guess, and it goes stale the
moment a new source lands without anyone updating it. It is exactly the false
precision the gist's own top comments call out.

## What v2 adopts instead

Each page carries `sources: <N>`, an integer equal to the number of distinct
entries under that page's `## Sources` section, and the section names each
provenance explicitly. Confidence is then a composite a reviewer can verify by
inspection:

- **Source count** (`sources: N`) — how many independent inputs back the claim.
- **`last_verified:` recency** — how recently it was checked against source.
- **Presence of a `> Contradicts:` link** — an open conflict lowers trust until
  resolved.

This is cheaper (a count, not a model output), auditable (every source is named
and citable from `## Sources`), and carries no fake precision. Adding a source
increments the count by editing one section; nothing decays silently. The same
`## Sources` discipline lets `lint-wiki` cross-check that `sources: N` matches
the listed entries.

## Sources

- `.llmwiki/raw/external/2026-05-29-rohitg00-llm-wiki-v2-gist.md` — the confidence-scoring section
  proposing per-fact float confidence (the `0.85` example) with time decay and
  reinforcement, which v2 replaces with a named source count.
- `.llmwiki/raw/external/2026-05-29-karpathy-llm-wiki-gist.md` — the index.md description, which
  lists "source count" as legitimate per-page metadata, grounding provenance
  count as the native trust signal for this pattern.

> Refines: [[curated-conservative]]
> See-also: [[volatility-over-decay]]
> Evidence: .llmwiki/raw/external/2026-05-29-rohitg00-llm-wiki-v2-gist.md
> Evidence: .llmwiki/raw/external/2026-05-29-karpathy-llm-wiki-gist.md
