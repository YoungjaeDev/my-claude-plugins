# Synthesis Rules

Rules `synthesis-scout` follows when merging artifacts from `${workspace_dir}/*.json` into the final Markdown report.

## Dedup keys

| Artifact platform | Primary dedup key | Notes |
|---|---|---|
| github | `id` (`<owner>/<repo>`, lowercase) | Strip leading `https://github.com/` if present |
| huggingface | `id` (repo id, lowercase) | Same for models / datasets / spaces |
| web | canonical URL — drop query-string + fragment, lowercase host, strip trailing `/` | Treat `www.` and bare host as equivalent |
| docs | `(source_type, url)` tuple | Context7 sections under the same library are deduped on full URL incl. fragment |
| paper | DOI (lowercase, strip leading `https://doi.org/` or `doi:`) | Fall back to canonical preprint id (`arxiv:<id>`, `iacr:<year>/<n>`) when DOI absent; never dedup on title alone (homonyms across years are common) |

### Cross-platform dedup

When the same resource appears across axes:
- A GitHub repo URL appearing in a web finding → keep the github entry, append the web `summary` to its `evidence` and add the web `url` to its source list.
- A HF model URL appearing in a web finding → keep the hf entry, same merge.
- An official docs URL appearing in a web finding → keep the docs entry; do not duplicate as a web row.
- The same DOI appearing in **paper findings and web findings** → keep the paper entry (structured metadata is richer), append the web `summary` to its `evidence`, drop the web row. Match also by canonical preprint URL (`arxiv.org/abs/...`) when DOI absent on the paper side.

## Trust ranking

Within each category, sort by:

1. `source_type` priority (highest first):
   - `official_docs`
   - `official_blog`
   - `deepwiki_qa`
   - `peer-reviewed paper` (journal / top conference, paper-scout `venue` != `arXiv preprint`)
   - `arxiv preprint with >100 citations`
   - `github` (with stars-weighted boost: >5k = +1 tier, >50k = +2 tiers)
   - `huggingface` (with downloads-weighted boost: >100k = +1, >1M = +2)
   - `arxiv preprint recent` (< 2 years, citation_count unset or < 100)
   - `stackoverflow` (accepted answer = +1 tier)
   - `reddit`, `hackernews`
   - `workshop paper`, `blog mention` of a paper
   - `news`, `twitter`, opinion blogs
   - `unverified`
2. Tie-break: recency. Use `pushed_at` for github, `published` for web/paper, `ran_at` as final fallback.
3. Tie-break #2: `reliability` field set by the scout (`high` > `medium` > `low`).

### Paper-specific time weighting

Paper findings get a time-based adjustment on top of the source-type ranking:

- `published` within 2 years → +1 tier boost (recency bonus)
- `published` more than 5 years ago → −1 tier penalty (staleness)
- Exception: if the scout tagged the finding as a "seminal paper" in `evidence` (citation_count > 1000, or canonical reference in the field), no penalty regardless of age. The boost still applies if also recent.

## Conflict resolution

Two findings conflict if they make incompatible claims about the same subject (e.g., "vLLM is faster than TGI" vs "TGI is faster than vLLM at batch=1").

Resolution order:
1. **Official docs win** over community opinion, unless docs are >18 months stale and community has fresh benchmarks.
2. **Recent wins over old** (≤ 18 months threshold).
3. **Quantitative evidence wins** over qualitative ("benchmark showed 2.3x" beats "feels faster").
4. **Majority consensus wins** when 3+ independent community sources agree against 1 dissenter.
5. **Unresolved** → list under `## Conflicts` with both sources side-by-side; do not pick a winner.

## Coverage / gap detection

Quick mode: no gap reporting (single axis by design).

Deep mode expected axes: `github`, `hf`, `web`, `docs`, and `paper` when the query had academic signal (orchestrator decides — it's the only one that saw the query at dispatch time). If any expected artifact is missing or `findings: []`:
- Add to `## Gaps` with the missing axis name
- Recommend a follow-up scout dispatch and suggest a refined query (e.g., "no GitHub results — try `awesome-{topic}` variant")
- Do **not** silently proceed as if the axis returned nothing — surface it

## Recommended-picks table

The `## Recommended Picks` table at the top of the report has at most 5 rows. Selection rule:

1. Start with the highest-trust finding from each axis (one per axis at most).
2. If the same resource is recommended by 2+ axes, it ranks #1 by default.
3. If after step 1 there are <5 picks, fill remaining slots with the next-highest within each axis (round-robin, never two from the same axis until all axes are represented).

## Output integrity rules

- Every URL in the report must come from a scout's `findings[].url` — never invent or guess URLs.
- If a finding lacks a URL, drop it from the report (the scout should not emit URL-less findings; if it does, treat as a scout bug).
- Quoted text from `docs-scout` must use blockquote (`>`) syntax with the source URL on the line below.
- Counts in the stdout summary (`sources_merged`, `conflicts`) must match what landed in the Markdown.
