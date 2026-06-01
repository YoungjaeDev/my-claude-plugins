---
id: code-scout-vs-deep-research-boundary
aliases: [research-harness-boundary, code-scout-vs-deep-research, code-scout-deep-research-boundary, orchestrator-non-delegation]
last_verified: 2026-06-01
status: active
volatility: stable
sources: 2
---

# Research harness boundary: code-scout vs `/deep-research`

## The boundary

| Harness | Owns | Tuning |
|---|---|---|
| `code-scout` (`research-orchestrator` skill) | code / ML / docs / academic papers | 5-axis fan-out (github / hf / web / docs / paper) with per-axis tooling (Context7, DeepWiki, exa, gh, hf CLI, paper-search-tools) |
| `/deep-research` | generic topics — politics, market, history, biographies, general policy | 7-phase + adversarial verify state machine, broader web sweep |

Both are research harnesses; they tune their fan-out for incompatible domains. Misrouting between them produces low-signal output: code-scout's 5-axis matrix wastes phases on irrelevant tools when given a generic topic, and `/deep-research`'s broader sweep dilutes precision when given a code/ML query that needed Context7 + DeepWiki + paper-search.

## The non-delegation rule

`research-orchestrator` explicitly does **NOT** delegate to `/deep-research` even when the user's query falls outside the code / ML domain. The orchestrator's SKILL.md (lines 17-21 frontmatter exclusion + line 41 in the "should-NOT" matrix) names this as an intentional design choice:

> Orchestrator does **not** delegate to `/deep-research` — the boundary is intentional.

Instead, the orchestrator's frontmatter `description` field tells the **caller** (the main session) to invoke `/deep-research` directly when the query is generic. The handoff happens before code-scout is invoked, not inside it.

## Why the non-delegation matters

Future-you will be tempted to add a "missing topic" delegation: when code-scout detects an out-of-domain query, route it to `/deep-research` and merge results. **Resist this.**

- The two harnesses have different state machines (5-axis fan-out vs 7-phase). Merging mid-flight breaks both.
- The synthesis stage (`synthesis-scout` for code-scout, in-skill for `/deep-research`) applies harness-specific dedup keys and trust rubrics. Cross-harness merging would mis-score.
- The boundary keeps each harness debuggable in isolation. A regression in code-scout's web-scout doesn't infect `/deep-research`'s coverage.

The right escape valve when code-scout receives an out-of-domain query: emit a `BLOCKED` status with `gate=out-of-domain` and let the caller re-route at the top level.

## Adjacent contracts

- `paper-search-tools` is a primitive (8-source MCP family); code-scout's `paper-scout` wraps it as one axis. `/deep-research` may use `paper-search-tools` differently for its own phases. The primitive is shared; the harnesses are not.
- `deepwiki:ask` and `context7` MCP are direct-call paths for single-question lookups — neither code-scout nor `/deep-research` is invoked for those (per the orchestrator's near-miss disambiguation in `references/agent-routing.md`).

> Evidence: plugins/code-scout/skills/research-orchestrator/SKILL.md
> See-also: [[curated-conservative]]

## Sources

1. **plugins/code-scout/skills/research-orchestrator/SKILL.md** — frontmatter `description` field (lines 17-21) excludes generic non-code/ML topics and points at `/deep-research`. Body line 41 in the "should-NOT" matrix names the non-delegation as intentional. Authored in PR #30 (commit `fc4d994`).
2. **PR #30 merge commit `fc4d994`** — `feat(code-scout): v2.1 — paper-scout 5th axis + insane-search tier-4 + deep-research boundary + drop deep-scout`. The "deep-research boundary" phrase in the squash title is the design-record header for this contract.
