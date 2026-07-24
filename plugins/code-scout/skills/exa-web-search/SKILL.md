---
name: exa-web-search
description: |
  Exa MCP web-search guide for code-scout's web-scout agent. Covers query phrasing,
  numResults sizing, when to follow up with web_fetch_exa, and the WebSearch fallback
  contract. Use when a scout or skill needs to call `mcp__exa__web_search_exa` /
  `mcp__exa__web_fetch_exa` and wants the canonical patterns.
---

# Exa Web Search

How to use the exa MCP tools (`mcp__exa__web_search_exa`, `mcp__exa__web_fetch_exa`) effectively from `web-scout` and anywhere else in the code-scout plugin. Why exa over `WebSearch`: semantic ranking (intent-aware), inline `Highlights` (often enough without a fetch), and consistent JSON shape across queries.

## Tools at a glance

| Tool | Purpose | Cost | Use when |
|---|---|---|---|
| `mcp__exa__web_search_exa` | semantic web search returning ranked results with highlights | low | always start here |
| `mcp__exa__web_fetch_exa` | full-page extraction for a single URL | medium | when highlights aren't enough |
| `WebSearch` (built-in) | keyword web search | low | exa fallback only |
| `mcp__brightdata__scrape_as_markdown` | JS-aware fetch with bot-detection bypass | medium | Tier 3 — `web_fetch_exa` failed on SPA / Cloudflare |
| `Skill("insane-search:insane-search", url=...)` | WAF / anti-bot transport fallback | high | Tier 4 — `scrape_as_markdown` also blocked (WAF / 403 / challenge); URL must already be known |

## `web_search_exa` call shape

```
mcp__exa__web_search_exa({
  query: "<natural language phrase>",
  numResults: 3-8       # default 5; use 8 for breadth, 3 for narrow factual
})
```

### Response shape (one entry per result)

```yaml
- Title: "Page title"
  URL: "https://..."
  Published: "2026-04-16T00:00:00.000Z"  # or "N/A"
  Author: "..."                           # or "N/A"
  Highlights: |
    [...]
    Excerpted text — usually rich enough to extract a finding without a follow-up fetch.
    [...]
```

`Highlights` may include `[...]` truncation markers. They are not literal ellipses; they signal that the highlighter skipped non-matching text between matching spans.

## Query phrasing

| Goal | Good query | Why |
|---|---|---|
| Recent release notes | `"Claude Opus 4.7 release notes 2026"` | year anchors recency |
| Community sentiment | `"vLLM vs TGI production serving 2026 reddit"` | platform hint without `site:` |
| Tutorial / how-to | `"how to deploy fastapi to fly.io 2026"` | "how to" + year |
| Person / company background | `"Anthropic researcher Dario Amodei interview 2026"` | named entity + recency |
| Comparison | `"RAG eval framework comparison ragas vs deepeval"` | named candidates |

Do **not** use Google operators (`site:`, `intitle:`, `OR`). Exa is semantic — phrase the query like you'd ask a person. For domain restriction, prefer adding the platform name to the query ("on reddit", "stackoverflow answer") rather than `site:`.

## When to follow up with `web_fetch_exa`

Fetch the full page only when:
- The `Highlights` clearly contain the answer but truncate mid-sentence on the key claim
- You need numeric data (benchmarks, prices, version numbers) that appears partial in highlights
- You need code blocks (highlights strip most code formatting)

Otherwise, the `Highlights` are usually sufficient — fetching is medium-cost and slower.

```
mcp__exa__web_fetch_exa({ url: "<url from a prior search result>" })
```

## numResults sizing

| Use case | numResults |
|---|---|
| Narrow factual ("when was X released") | 3 |
| Standard research axis | 5 (default) |
| Broad survey ("what frameworks exist for X") | 8 |

Avoid `numResults > 10` — return diminishes fast and the response gets unwieldy in synthesis.

## Combining with `WebSearch` (mode-dependent)

| Mode | Pattern |
|---|---|
| `quick` | exa primary; `WebSearch` only as fallback when exa is unavailable, quota-exhausted, or returns empty. Record `tool_used: "websearch"` + the exa error in the artifact. |
| `deep` | run exa and `WebSearch` **in parallel** as co-searches and merge before fetching. They are complementary — exa wins on semantic intent + official sources, `WebSearch` wins on `site:`-scoped community results (Reddit threads, niche SO answers, GitHub issue discussions). The +30%-ish token cost is worth the ~2× long-tail coverage on deep mode. |

Drop obvious duplicates by canonical URL before the fetch phase; synthesis-scout will canonicalize again downstream, but pre-filtering saves fetch budget.

WebSearch supports `site:` operators and `allowed_domains` / `blocked_domains` — use them to compensate for the loss of exa's semantic ranking.

```text
WebSearch({
  query: "site:reddit.com r/MachineLearning pytorch lightning 2026",
  allowed_domains: ["reddit.com"]
})
```

## Fetch fallback — `scrape_as_markdown`

`web_fetch_exa` is the default extractor (cheaper, returns the same canonical URL space as the search). Switch to `mcp__brightdata__scrape_as_markdown` **only** when `web_fetch_exa` fails: timeout, 403, empty body, JS-heavy SPA, or Cloudflare / anti-bot interstitial. Record `brightdata_scrape` in `fetch_tools_used`.

Bright Data occupies the fetch slot only — stay inside it:
- `mcp__brightdata__search_engine` / `search_engine_batch` — do **not** use as a search axis here. Search belongs to exa and `WebSearch` above; a third partial-coverage axis adds cost without enough lift.
- `web_data_*` structured extractors — structured-field extraction (prices, ratings, profiles) is a different domain, and these need Pro groups this skill does not assume.
- `scraping_browser_*` — browser automation is out of scope for a research scout.
- `scrape_batch` — site-wide or list-wide fetching is out of scope; this skill retries one failed URL at a time.

If Bright Data is not configured, do not quietly drop to a weaker fetch. Follow the `brightdata-guide` preflight (MCP tools → CLI installed → authenticated → default zone), report the failing gate, and record it in `errors[]`.

## Tier-4 fetch fallback — `insane-search`

When `web_fetch_exa` returns 403/challenge **and** `scrape_as_markdown` also fails (typical pattern: X/Twitter, Reddit, Coupang, gated dashboards behind WAF), retry once with `Skill("insane-search:insane-search", url=...)`. **`insane-search` is an optional plugin** (see `plugins/code-scout/CLAUDE.md` requirements section): if the skill is not installed, or the invocation errors with skill-not-found / load failure, skip the tier-4 retry entirely and emit the finding from `Highlights` alone, recording `insane_search: not_installed` (or the error string) in `errors[]`. Otherwise it runs its own 5-phase transport escalation internally (official API index → lightweight probes → TLS impersonation → real browser → parallel) and returns a single verdict — caller only consumes it:

| verdict | meaning | action |
|---|---|---|
| `strong_ok` | clean full body extracted | use the body as a `web_fetch_exa` replacement |
| `weak_ok` | partial / approximate body | use cautiously, mark `reliability: medium` |
| `challenge` | WAF interstitial returned | terminal; emit finding from `Highlights` only |
| `blocked` | hard block, no body | terminal; emit finding from `Highlights` only |

Record `insane_search` in `fetch_tools_used` and append the verdict to `errors[]` when it's `challenge` / `blocked`. `insane-search` is a **transport** fallback, not a search axis — it does not surface new URLs, only fetches a URL you already have. Do not call it instead of exa / WebSearch.

## Citation hygiene

Every finding emitted from an exa-fetched page must include:
- `url` — the canonical URL from the exa response (`URL` field)
- `published` — the `Published` field (or `null` if `"N/A"`)
- `source_type` — derived from the URL host (reddit / stackoverflow / blog / news / official_blog / twitter / other)

Do **not** synthesize URLs that weren't in an exa response. If a highlight refers to an upstream page that exa didn't return, run a follow-up `web_search_exa` for that page rather than guessing the URL.

## Common pitfalls

- **Don't include year in every query** — only when recency matters. Many queries get worse with a year suffix (older canonical content gets demoted).
- **Don't treat `Highlights` as the full page** — they are highlighter excerpts; numeric tables and code blocks may be missing or partial.
- **Don't request `numResults` > 10** — synthesis cost climbs and the long tail is noisy.
- **Don't call `web_fetch_exa` speculatively** — confirm the `Highlights` insufficient first.

## Cross-references

- `web-scout` agent — the primary consumer; see `agents/web-scout.md` for how exa output maps into its artifact schema
- `research-orchestrator` skill — owns when web-scout fires
- `resource-finder` skill — companion skill for GitHub/HF axis hygiene
