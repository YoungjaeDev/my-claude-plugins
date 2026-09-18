# lint-wiki: output schema

Produce a Markdown report:

```text
## Wiki Health Report — YYYY-MM-DD

- Identity: <n duplicate clusters, each with overlap band + merge/supersede/alias suggestion / clean>
- Level: <n pages > 5KB>
- Relationship: <n bare wikilinks / clean>
- Staleness: <n pages past their volatility window>
- Status: <n status: stale pages / clean>
- Supersession: <n broken Supersedes/Superseded-by pairs / clean>
- Sources: <n pages with sources:N mismatched vs ## Sources count / clean>
- Insight: <n promoted_from unresolved / oversize / missing-frontmatter / clean | no insight layer>
- Source drift: <n raw files whose body hash != stored sha256 / clean (no sha256-bearing files)>
- Link poverty: <n wiki pages with 0 typed cross-refs / clean>
- Log rotation: <prior-year block present in log.md -> migrate to log-YYYY.md / clean>
- Orphans: <list>
- Broken refs: <list>
- Open contradictions: <list>
```

Report only. Do not auto-fix. User reviews and triggers `/wiki:ingest-finding` for each remediation.

### Worked example

```text
## Wiki Health Report — 2026-05-29

- Identity: 1 duplicate cluster (backend/cache.md + backend/caching.md share id `cache-policy` — overlap: High — suggest: merge into backend/cache.md, redirect `caching` alias)
- Level: 1 page > 5KB (backend/provider-x.md, 6.2 KB → propose split)
- Relationship: clean
- Staleness: 2 past window (backend/old-quirk.md 41 days, volatile 30d window; design/layout.md 190 days, stable 180d window)
- Status: 1 stale page (backend/old-quirk.md)
- Supersession: 1 broken pair (backend/old-quirk.md is status: stale but has no > Superseded-by:)
- Sources: clean
- Insight: clean (2 entries, promoted_from resolves, all condensed)
- Source drift: clean (no sha256-bearing raw files — frontmatter is prospective-only)
- Link poverty: 1 (research/leaf-note.md has 0 typed cross-refs — standalone, human to confirm)
- Log rotation: clean (log.md current-year only)
- Orphans: none
- Broken refs: none
- Open contradictions: 1 (design/cache.md > Contradicts: [[design/cache-v2]])
```

**Persist the report**: after producing the Markdown report and confirming with the user, append a block to the resolved root's `log.md` with the standard schema header `## YYYY-MM-DD — <event-type> (lint-wiki)` (e.g. `## 2026-05-26 — v2 0-week baseline (lint-wiki)`). Do **not** create a separate `_audits/` directory: all wiki audit/ingest/post-merge events accumulate in `log.md` so `grep '## YYYY-MM-DD'` recovers a time-series.
