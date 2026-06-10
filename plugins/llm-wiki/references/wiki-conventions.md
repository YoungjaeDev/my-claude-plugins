# Wiki conventions (canonical, agent-facing)

Canonical definitions shared by the llm-wiki skills. `plugins/llm-wiki/CLAUDE.md` is the
human-facing copy; this file is the agent-facing SSOT that skill bodies point to instead of
re-stating the full grammar (same dual-home pattern `github-dev:post-merge` uses for
`references/core-principle.md`). Skills keep the standalone-critical one-liners inline (the
resolution-order blockquote, the bare cross-ref token list, the `log.md` footer); the verbose
explanations below are the deduped material.

## Resolution order

Skills and hooks resolve the wiki root in order:

1. `.llmwiki/wiki/` (preferred) — what new repos get.
2. `.claude/wiki/` (legacy v1) — pre-`.llmwiki/` deployments.
3. `.codex/wiki/` (legacy Codex fork) — produced by the retired `codex-bridge` `.claude/`→`.codex/`
   body transform.

Examples in skill bodies use `.llmwiki/wiki/`; substitute the legacy path if that is what the repo
has. If none of the three resolve, the layer is not initialized — suggest `/llm-wiki:bootstrap-wiki`.

## Frontmatter schema

Every wiki page (not `index.md`, not `log.md`) carries:

```yaml
---
id: <kebab-case-slug>          # unique page identity
aliases: [other-names]         # dedup / search keys
last_verified: YYYY-MM-DD      # bump ONLY after re-checking vs code/source
status: active                 # active | stale (stale = kept+marked, never deleted)
volatility: stable             # stable (180d window) | volatile (30d window); default stable
sources: 2                     # integer count of named provenance under ## Sources
---
```

`sources` (an integer count under `## Sources`) replaces numeric confidence floats. "How sure" =
source count + `last_verified` recency + presence of `> Contradicts:`. Insight-layer entries add
`tier: insight` + `promoted_from: [[wiki-id]]` + `evidence_count: N` on top of this schema.

## Cross-reference grammar

Pages link via **typed** references only — never raw `[[wikilink]]`. The token set and each token's
meaning:

- `> Refines: [[page-id]]` — this page adds deeper detail to another.
- `> Contradicts: [[page-id]]` — a conflict that must be resolved before the next edit / before acting.
- `> Evidence: .llmwiki/raw/<file>` — citation to immutable raw evidence (may also point at external `docs/...`).
- `> See-also: [[page-id]]` — related but independent (lateral).
- `> Supersedes: [[page-id]]` — on the NEW page, points at the claim it replaces.
- `> Superseded-by: [[page-id]]` — on the OLD page (paired with `status: stale`).
- `> Uses: [[page-id]]` — runtime/structural dependency direction.
- `> Depends-on: [[page-id]]` — this page's claim depends on another's holding.
- `> Caused-by: [[page-id]]` — causal origin of a bug/behavior.
- `> Fixed-by: [[page-id]]` — the change that resolved it.

These typed refs are the only authoritative link form. A wiki page may cross-layer reference an
insight entry the same way (`[[insight-id]]`); the id resolves in either layer.

## log.md discipline

All wiki events (lint reports, ingest summaries, post-merge ingests, migrations) accumulate in the
resolved root's `log.md` (`.llmwiki/wiki/log.md`, or a legacy `.claude/wiki/log.md`) with schema
header `## YYYY-MM-DD — <event-type> (<source-skill>)`. The diff-log entry is appended **first**
(before the page edit) so `git revert` of the commit undoes both the log line and the page change in
sync. `grep '## ' log.md` recovers the time-series.
