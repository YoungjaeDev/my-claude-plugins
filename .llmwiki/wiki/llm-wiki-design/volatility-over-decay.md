---
id: volatility-over-decay
aliases: [volatility, staleness-window, old-is-not-stale, anti-ebbinghaus]
last_verified: 2026-05-29
status: active
volatility: stable
sources: 2
---

# Volatility over decay

v2 rejects literal Ebbinghaus exponential decay math and adopts a discrete
`volatility:` class that drives a fixed staleness window. The principle that
forces the choice: **old is not stale.**

## What rohitg00 proposed, and why it is wrong here

The rohitg00 gist's memory-lifecycle section proposes a retention curve where
content "fades" exponentially with time and each access or reinforcement resets
the curve, citing Ebbinghaus. The gist itself notes the tension that breaks the
model: architecture decisions decay slowly while transient bugs decay fast. A
single continuous time-since-write score cannot encode that. An architecture
decision written six months ago and never re-touched is not stale; a bug note
from last week may already be. Time alone is the wrong axis, and a continuous
decay score is false precision over a number nobody measured.

## What v2 adopts instead

A page declares a `volatility:` class and a `last_verified:` date. The class
selects a fixed window:

- `volatility: stable` (arch / design / decision lore) -> 180-day window
- `volatility: volatile` (bug / debug / quirk / transient lore) -> 30-day window
- absent -> treated as `stable` (180 days)

Staleness is `age_days = (today - last_verified) > window`. There is no curve,
no reinforcement bookkeeping, no per-access decay state. The decision of how
fast a page ages is made once, by a human, at write time, by picking the class.

## Why this is better

`last_verified:` plus a fixed window is fully git-auditable: a reviewer reads
two plain fields and computes the answer with `date` arithmetic, exactly what
`lint-wiki` and the stale-check hook do. A continuous decay score would need
stored state that drifts, cannot be reviewed in a diff, and pretends to a
precision it does not have. The class is legible; the score is not. `lint-wiki`
flags a page only when its `last_verified:` is older than its class window, and
stale pages are marked `status: stale`, never deleted.

## Sources

- `.llmwiki/raw/rohitg00-llm-wiki-v2-gist.md` — the Forgetting / memory-lifecycle
  section proposing the Ebbinghaus retention curve and the slow-vs-fast decay
  observation that the discrete class encodes more honestly.
- `.llmwiki/raw/karpathy-llm-wiki-gist.md` — the lint operation, which lists
  "stale claims that newer sources have superseded" as a health check, grounding
  staleness as a lint concern rather than an automatic decay process.

> Refines: [[curated-conservative]]
> See-also: [[provenance-over-confidence]]
> Evidence: .llmwiki/raw/rohitg00-llm-wiki-v2-gist.md
> Evidence: .llmwiki/raw/karpathy-llm-wiki-gist.md
