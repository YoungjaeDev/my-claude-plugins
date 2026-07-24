---
id: brightdata-cli-preflight-quirks
aliases: [bdata-preflight, brightdata-zone-gate, bdata-budget-exit-0, brightdata-search-serp-zone, scrape-batch-tier, search-stack-brightdata]
last_verified: 2026-07-24
status: active
volatility: volatile
sources: 3
---

# Bright Data CLI preflight quirks (bdata 0.3.2)

When Bright Data is promoted from a fallback to a primary search/fetch path, an unconfigured setup must **stop and guide**, not silently degrade to the built-in web search. Building that four-gate preflight (MCP → CLI installed → authenticated → default zone) surfaced four provider quirks, each of which breaks a naive gate.

## `bdata budget` exits 0 on HTTP 403 — judge auth on `zones` output, not `$?`

`bdata budget` returns **exit 0 even when the API answers `403 … lacks the required permissions`**. An auth gate that only tests `$?` reports a broken token as healthy — the exact silent-degrade the preflight exists to prevent. Judge authentication on the **output** of `bdata zones`: a printed zone table means the credentials work; an auth/permission message in the output is a failure whatever the exit status says. (Contrast gate 4 below, which *is* honestly exit-coded.)

## `search` requires a SERP zone; `scrape` does not — the two default-zone keys are not interchangeable

Verified empirically: with only `default_zone_unlocker` set (and `default_zone_serp` unset), `bdata scrape <url>` works but `bdata search "<q>"` fails with `No zone specified` (the error names `BRIGHTDATA_SERP_ZONE`). So:

- `bdata scrape` runs on `default_zone_unlocker` alone.
- `bdata search` **requires** `default_zone_serp` — an unlocker default does not cover it.

This **refutes** the official-docs reading (docs.brightdata.com/cli/commands) that `default_zone_unlocker` is the base default for both scrape and search. A reviewer cited that doc to argue the zone gate was too strict and should pass on unlocker-only; the empirical test refuted it — relaxing to unlocker-only would let `bdata search` through the gate and then fail at call time, reintroducing the silent search failure. Requiring **both** keys is correct. Gate 4 is honestly exit-coded: `bdata config get default_zone_serp` exits 1 when unset, so unlike auth it *can* be tested on `$?`. Many accounts expose no `serp`-type zone at all — an `unblocker` zone (e.g. `cli_unlocker`) is a valid value for both keys.

## `scrape_batch` group membership is ambiguous — treat it as optional

The `brightdata-guide` SKILL is internally inconsistent about which tier holds `scrape_batch`: its "Two Modes" section lists it under Rapid/Free (alongside `scrape_as_markdown`), but its Tool-Group Reference table lists "batch tools" under `advanced_scraping` (Pro). A default Rapid/Free MCP may therefore expose `scrape_as_markdown` **without** `scrape_batch`. Robust consumers (e.g. deepwiki URL-mode llms.txt generation) make `scrape_batch` optional: batch in groups of 10 (its schema-enforced `maxItems`) when present, else loop `scrape_as_markdown` per URL — same result, more round trips.

## "Pro" is a tool-group toggle, not a billing tier

`&pro=1` / `GROUPS=` enables the Pro tool groups (`web_data_*`, `scraping_browser_*`, `extract`) — it is **not** a paid plan. The 5,000 free requests/month allowance covers Pro tools too, so a `$0` account balance still runs both Rapid and Pro tools within quota; balance is only consumed past the free 5k. The migration keeps Pro off and uses only Rapid tools (`search_engine`, `scrape_as_markdown`, `scrape_batch`); promoting to `&pro=1` is proposed only when repeated `web_data_*` structured extraction is actually needed.

## Global tier + preflight contract

The global search stack (in `CLAUDE.md.global`) is: brightdata `search_engine` default (real Google SERP JSON) · exa for semantic discovery · WebSearch/WebFetch for a trivial single fact · `scrape_as_markdown` for blocked/parse-failure (structured via `bdata pipelines`) · insane-search for platform APIs / media / high-volume · context7+deepwiki for codebase questions. This global tier **overrides** `brightdata-guide`'s own "prefer Bright Data over the built-in web tools" default. The single-lookup WebSearch tier is a deliberate choice for a trivial fact, **not** a fallback for a blocked/unconfigured Bright Data search — that case follows the four-gate preflight and stops with setup guidance. Quality gate: results existing ≠ passing; finish only with evidence that answers the question.

> See-also: [[code-scout-vs-deep-research-boundary]]
> See-also: [[detector-cannot-look-vs-nothing-wrong]]
> Evidence: plugins/brightdata-guide/skills/brightdata-guide/SKILL.md
> Evidence: plugins/deepwiki/references/generate-llmstxt-procedure.md
> Evidence: CLAUDE.md.global

## Sources

1. Session empirical tests (2026-07-24, PR #164): `bdata budget` → exit 0 on 403; `bdata search` fails "No zone specified" with only `default_zone_unlocker` set while `bdata scrape` succeeds; `scrape_batch` returned live results in the deepwiki URL-mode smoke.
2. **PR #164** (`feat(search-stack): replace firecrawl with brightdata, remove slidev plugin`) — the brightdata-guide four-gate preflight, the code-scout/translator/deepwiki retrofits, and the global-tier rewrite; cr-fix skipped the Codex zone-relaxation P2 as empirically refuted and applied the scrape_batch-optional P2.
3. Bright Data CLI docs (docs.brightdata.com/cli/commands, docs.brightdata.com/ai/mcp-server/tools) — cited by the Codex review for the zone-default and tool-group claims; recorded here as the doc-vs-binary discrepancy, not as ground truth.
