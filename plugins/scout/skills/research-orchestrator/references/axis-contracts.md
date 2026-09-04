# Axis Contracts

Shared per-axis input/output contract consumed by **all three orchestrator execution paths** — named plugin agents, generic parallel subagents, sequential in-agent. Path A (named agents) uses the full agent definitions in `../../../agents/{axis}-scout.md` as the canonical detail; this file is the portable condensation that the generic-agent and sequential paths embed inline, because `agents/*.md` are Claude-only and are **not registerable** under Codex 0.135. Keep the two in sync when an axis contract changes.

## Shared query shape (input to every axis)

Every axis receives the same fields:

- `query` — natural-language research target (required)
- `workspace_dir` — absolute path to the run workspace (required)
- `artifact_id` — slot name `NN_axis` (e.g. `01_github`); the axis writes `${workspace_dir}/${artifact_id}.json`
- axis-specific optionals (listed per axis below)

## Shared result envelope (output of every axis)

Every axis writes exactly one JSON file at `${workspace_dir}/${artifact_id}.json`:

```json
{
  "platform": "github|huggingface|web|docs|paper",
  "query_used": ["variant 1", "variant 2"],
  "ran_at": "2026-07-14T10:00:00Z",
  "findings": [
    {
      "url": "https://...",              // REQUIRED — drop URL-less findings
      "summary": "one-line claim",
      "reliability": "high|medium|low",  // REQUIRED
      "evidence": ["why this is trustworthy"]
      // + axis-specific fields (below)
    }
  ],
  "notes": "free-form for synthesis",
  "error": "set with findings:[] only when the whole axis failed",
  "errors": [ { "tool": "exa", "reason": "quota" } ]
}
```

Envelope rules that hold on **every** path:

- Never emit a finding without a `url` and a `reliability`.
- On total-axis failure write `findings: []` + `error` — never hang, never abort the whole run.
- On partial (per-tool / per-source) failure keep what succeeded and record the rest in `errors`.
- If the artifact already exists (partial re-execution), overwrite it in place; sibling artifacts stay untouched.

## Per-axis contracts

### `01_github` — GitHub axis (`platform: github`)
- **Role**: repos, code patterns, awesome-lists, issues/PRs.
- **Optional inputs**: `language`, `min_stars`, `pushed_since` (e.g. `2025-01-01`).
- **Tool order**: `date +%Y-%m-%d` anchor → `gh search repos` / `gh search code` (2-3 variants: base, `awesome-{topic}`, narrow stack phrase) → `gh repo view <owner>/<repo> --json description,stargazerCount,pushedAt,primaryLanguage`. Query hygiene: `resource-finder.md` (sibling in this directory).
- **Finding fields**: `id` (`owner/repo`, lowercase), `title`, `stars`, `pushed_at`, `language`, `kind`, plus shared.
- **Reliability**: `high` = official org / >5k stars + recent push; `medium` = active community repo; `low` = single-contributor / stale.
- **Fallback**: on `gh` rate-limit / auth error write `findings: []` + `error`.

### `02_hf` — Hugging Face axis (`platform: huggingface`)
- **Role**: models, datasets, Spaces.
- **Optional inputs**: `repo_type` (`model`|`dataset`|`space`), `sort` (`downloads`|`likes`), `limit`.
- **Tool order**: `date` anchor → `curl "https://huggingface.co/api/{models,datasets,spaces}?search=...&sort=downloads&direction=-1&limit=10"` (cwd-free) parsed with `jq`; use `uvx hf {models,spaces,datasets} ls|search|info` for CLI subcommands (no top-level `hf search-repos`). Never download weights — config-only `--include "*.json"` if shape comparison is needed.
- **Finding fields**: `id` (repo id, lowercase), `kind`, `downloads`, `likes`, `library`, `license`, `tags`, plus shared.
- **Reliability**: `high` = official org / >100k downloads; `medium` = active community model with a clear license; `low` = experimental / no license / no demo.
- **Fallback**: on HF rate-limit / 5xx write partial findings + `error`.

### `03_web` — Web axis (`platform: web`)
- **Role**: Reddit, StackOverflow, blogs, news, announcements, person/company background.
- **Optional inputs**: `mode` (`quick`|`deep` — drives search tiers), `site_hints`, `time_range`.
- **Search tool order**: tier-1 `mcp__exa__web_search_exa` (always first). Deep mode also runs `WebSearch` in parallel (keyword + `site:` coverage); quick mode falls back to `WebSearch` when exa is unavailable / quota-exhausted / empty.
- **Fetch tool order** (escalate only on failure): `mcp__exa__web_fetch_exa` → `mcp__brightdata__scrape_as_markdown` (JS-heavy / anti-bot) → `Skill("insane-search:insane-search", url=...)` (tier-4 transport for WAF / 403 / challenge on X/Reddit/Coupang; treat `challenge`/`blocked` as terminal and emit from `Highlights`). `insane-search` is **optional** — if not installed / errors, skip tier-4 and record `insane_search: not_installed` (or the error) in `errors`. Bright Data is fetch-only here: do **not** call `search_engine` / `search_engine_batch` as a search axis, and do not call `web_data_*` / `scraping_browser_*` / `scrape_batch`. If Bright Data is unconfigured, follow the preflight in `brightdata-guide.md` (sibling in this directory) and record the failing gate in `errors` instead of downgrading the fetch.
- **Finding fields**: `title`, `published`, `source_type` (`reddit`|`stackoverflow`|`hackernews`|`blog`|`news`|`twitter`|`official_blog`|`other`), plus shared. Top-level `tools_used`, `fetch_tools_used`.
- **Reliability**: `high` = official blog / vendor docs / stable consensus; `medium` = corroborated community thread; `low` = single tweet / opinion blog.
- **Fallback**: record failed tools in `errors`; abort the artifact only if both search tools fail.

### `04_docs` — Docs axis (`platform: docs`)
- **Role**: official library API / migration docs + repo-internal architecture Q&A.
- **Optional inputs**: `library_hint`, `repo_hint`, `topic`.
- **Tool order**: API / migration → `mcp__context7__resolve-library-id` → `mcp__context7__get-library-docs` (public Context7; some installs expose the older `mcp__context7__query-docs` — try public first, fall back). Repo architecture → `mcp__deepwiki__ask_question` (escalate to `read_wiki_structure` / `read_wiki_contents` only if too shallow). Quote snippets verbatim with the source URL.
- **Finding fields**: `topic`, `answer`, `source_type` (`official_docs`|`deepwiki_qa`|`deepwiki_wiki`|`other`), plus shared. Top-level `sources_used`.
- **Reliability**: `high` = official docs / DeepWiki verbatim quote; `medium` = inferred from docs; `low` = uncertain / stale MCP content.
- **Fallback**: if both MCPs fail / return empty write `findings: []` + `error`.

### `05_paper` — Paper axis (`platform: paper`; deep + academic signal only)
- **Role**: academic literature; metadata-only (no PDF download).
- **Optional inputs**: `sources` (subset of `arxiv`|`semantic`|`crossref`|`pubmed`|`biorxiv`|`medrxiv`|`iacr`|`google_scholar`), `year_from`, `year_to`, `authors`, `limit`.
- **Source selection** (pick 2-3, not all 8): CS/ML/AI/NLP/vision/RL → `arxiv`+`semantic`; medical/bio/clinical → `pubmed`+`biorxiv` (+`medrxiv` for epidemiology / clinical-trial); crypto/security → `iacr`+`semantic`; physics/chemistry → `arxiv`+`crossref`; cross-disciplinary → `semantic`+`crossref`. User `sources` overrides.
- **Tool order**: `mcp__plugin_scout_paper-search__search_{source}` (parallel, cap ~5 searches) → optional `..._read_{source}_paper` / `get_crossref_paper_by_doi` for enrichment. Google Scholar has no read tool — enrich DOI hits via `get_crossref_paper_by_doi`. Never call `download_*`.
- **Finding fields**: `id` (DOI lowercase with `https://doi.org/` stripped, else `arxiv:<id>` / `iacr:<year>/<n>`), `title`, `authors`, `published`, `venue`, `abstract`, `citation_count`, `kind`, plus shared. Top-level `sources_used`.
- **Reliability**: `high` = peer-reviewed venue or arXiv preprint with citation_count > 100; `medium` = recent arXiv (< 2yr) / workshop / obscure venue; `low` = unverified / retracted / no citations and > 3yr old.
- **Fallback**: record failed sources in `errors`, keep the rest; `findings: []` + top-level `error` only if all chosen sources fail.

## Synthesis (`synthesis-scout` agent on Path A / in-skill on Paths B-C)

Consumes every `${workspace_dir}/*.json` in lexical order (deterministic merge), dedups, trust-ranks, resolves conflicts, and emits the final Markdown report to `${report_path}`. Read-only on the workspace — never rewrite a sibling artifact. Full dedup keys, trust rubric, conflict order, coverage/gap detection, and recommended-picks rule: `synthesis-rules.md`; the report template lives in the `../../../agents/synthesis-scout.md` definition. Runtime-independent: the named `synthesis-scout` agent runs it on Path A, the orchestrator runs the identical logic in-skill on Paths B and C.
