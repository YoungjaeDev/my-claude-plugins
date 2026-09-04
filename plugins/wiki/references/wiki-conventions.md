# Wiki conventions (canonical, agent-facing)

Canonical definitions shared by the wiki skills. `plugins/wiki/CLAUDE.md` is the
human-facing copy; this file is the agent-facing SSOT that skill bodies point to instead of
re-stating the full grammar (same dual-home pattern `dev:post-merge` uses for
`references/core-principle.md`). Skills keep the standalone-critical one-liners inline (the
resolution-order blockquote, the bare cross-ref token list, the `log.md` footer); the verbose
explanations below are the deduped material.

## Resolution order

Skills and hooks resolve the wiki root in order:

1. `.llmwiki/wiki/` (preferred) — what new repos get.
2. `.claude/wiki/` (legacy v1) — pre-`.llmwiki/` deployments.
3. `.codex/wiki/` (legacy Codex fork) — produced by a retired `.claude/`→`.codex/`
   body transform.

Examples in skill bodies use `.llmwiki/wiki/`; substitute the legacy path if that is what the repo
has. If none of the three resolve, the layer is not initialized — suggest `/wiki:bootstrap-wiki`.

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

## raw/ layout & frontmatter

`.llmwiki/raw/` holds immutable evidence the wiki cites (never copies). It is **not** a flat dump —
raw material is heterogeneous by *source*, so it is bucketed on a source-type axis (distinct from
`wiki/`'s domain subdirs and `insight/`'s deliberate flatness — each layer's structure follows where
its content actually varies):

```text
raw/
├── external/      # third-party originals (gist, paper, vendor doc, web article)
├── research/      # our own generated research (deep-research, scout, survey dumps)
├── transcripts/   # conversation / recording captures (chat exports, meeting/call transcripts)
└── audits/        # debug / audit captures (audit md, session debug notes)
```

- **Filename**: `YYYY-MM-DD-<slug>.<ext>` — date is the capture/ingested day, matching the
  `ingested:` frontmatter field and the `.staging/` marker naming. Sortable + grep-friendly.
- **Immutability is content, not path**: raw file *bytes* never change (so the sha256 drift check
  below holds), but a file may be relocated/renamed with `git mv` — the body hash is unchanged, and
  updating the `> Evidence:` refs that point at it is a wiki edit, not a raw mutation. Pre-existing
  raw files without frontmatter are moved as-is (no backfill — prospective-only).

Frontmatter is added to **newly captured text** raw files (md/txt/html; prospective-only — existing
files are not backfilled, per raw-immutability). **Binary raw (`.pdf`) is stored as-is** — inline YAML
would corrupt the bytes, so it carries no frontmatter and stays outside the `sha256` drift check
(`lint-wiki` Step 11 excludes `.pdf`):

```yaml
---
source_url: https://...        # original URL (when applicable)
ingested: YYYY-MM-DD
sha256: <hex>                   # hash of the body ONLY (below the frontmatter)
---
```

Re-ingesting the same `source_url`: recompute the body hash — identical → skip; different → flag drift
+ write a new dated snapshot (never edit the existing raw file). Files without a `sha256:` field are
skipped by the drift check (`lint-wiki` Step 11).

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

**Yearly rotation**: on the first wiki event after the calendar year turns over, migrate the previous
year's entries out of `log.md` into a sibling `log-YYYY.md` (e.g. `log-2026.md`), preserving
newest-first order; `log.md` keeps only the current year. Time-series recovery becomes
`grep '## ' log*.md` (globs the rotated files too). This keeps the hot `log.md` bounded without an
entry-count threshold — the date headers make the cut deterministic and grep-friendly. `lint-wiki`
Step 13 flags when a rotation is due.
