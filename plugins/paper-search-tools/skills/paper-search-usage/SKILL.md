---
name: paper-search-usage
description: Use when user wants to search academic papers, find research articles, literature review, download PDFs, or extract paper content across arXiv, PubMed, bioRxiv, medRxiv, Google Scholar, IACR, Semantic Scholar, and CrossRef.
---

# Paper Search MCP

Search, download, and read academic papers across 8 platforms.

## Supported Platforms

| Platform | Search | Download | Read |
|----------|--------|----------|------|
| arXiv | Yes | Yes | Yes |
| PubMed | Yes | Limited | Limited |
| bioRxiv | Yes | Yes | Yes |
| medRxiv | Yes | Yes | Yes |
| Google Scholar | Yes | No | No |
| IACR ePrint | Yes | Yes | Yes |
| Semantic Scholar | Yes | Yes | Yes |
| CrossRef | Yes | Limited | Limited |

## Tool Naming

Tool names carry an MCP prefix that depends on how the server is registered:

- **Plugin-loaded (this repo's default, Claude Code)** — `mcp__plugin_paper-search-tools_paper-search__<tool>`, e.g. `mcp__plugin_paper-search-tools_paper-search__search_arxiv`. This is the live prefix and the one used in the tables below.
- **Standalone `.mcp.json`** — if the server is registered directly under the name `paper-search` (not via the plugin), the tools are `mcp__paper-search__<tool>` instead.

Codex 0.135 loads the same `.mcp.json`; its exact tool-name prefix is unverified here — resolve it from Codex's own tool list if the plugin-loaded name does not match.

## MCP Tools (23)

### Search Tools

| Tool | Platform | Parameters |
|------|----------|------------|
| `mcp__plugin_paper-search-tools_paper-search__search_arxiv` | arXiv | query, max_results=10 |
| `mcp__plugin_paper-search-tools_paper-search__search_pubmed` | PubMed | query, max_results=10 |
| `mcp__plugin_paper-search-tools_paper-search__search_biorxiv` | bioRxiv | query, max_results=10 |
| `mcp__plugin_paper-search-tools_paper-search__search_medrxiv` | medRxiv | query, max_results=10 |
| `mcp__plugin_paper-search-tools_paper-search__search_google_scholar` | Google Scholar | query, max_results=10 |
| `mcp__plugin_paper-search-tools_paper-search__search_iacr` | IACR ePrint | query, max_results=10, fetch_details=True |
| `mcp__plugin_paper-search-tools_paper-search__search_semantic` | Semantic Scholar | query, year (optional), max_results=10 |
| `mcp__plugin_paper-search-tools_paper-search__search_crossref` | CrossRef | query, max_results=10 |

### Download Tools

| Tool | Platform |
|------|----------|
| `mcp__plugin_paper-search-tools_paper-search__download_arxiv` | arXiv |
| `mcp__plugin_paper-search-tools_paper-search__download_pubmed` | PubMed |
| `mcp__plugin_paper-search-tools_paper-search__download_biorxiv` | bioRxiv |
| `mcp__plugin_paper-search-tools_paper-search__download_medrxiv` | medRxiv |
| `mcp__plugin_paper-search-tools_paper-search__download_iacr` | IACR ePrint |
| `mcp__plugin_paper-search-tools_paper-search__download_semantic` | Semantic Scholar |
| `mcp__plugin_paper-search-tools_paper-search__download_crossref` | CrossRef |

Parameters: `paper_id`, `save_path="/downloads"`

### Read Tools

| Tool | Platform |
|------|----------|
| `mcp__plugin_paper-search-tools_paper-search__read_arxiv_paper` | arXiv |
| `mcp__plugin_paper-search-tools_paper-search__read_pubmed_paper` | PubMed |
| `mcp__plugin_paper-search-tools_paper-search__read_biorxiv_paper` | bioRxiv |
| `mcp__plugin_paper-search-tools_paper-search__read_medrxiv_paper` | medRxiv |
| `mcp__plugin_paper-search-tools_paper-search__read_iacr_paper` | IACR ePrint |
| `mcp__plugin_paper-search-tools_paper-search__read_semantic_paper` | Semantic Scholar |
| `mcp__plugin_paper-search-tools_paper-search__read_crossref_paper` | CrossRef |

Parameters: `paper_id`, `save_path="/downloads"`

Downloaded files are stored at `/tmp/paper-search-downloads` on the host.

### Utility Tools

| Tool | Description |
|------|-------------|
| `mcp__plugin_paper-search-tools_paper-search__get_crossref_paper_by_doi` | Get paper metadata by DOI |

## Best Practices

1. Start with broad search, then narrow down
2. Use `search_semantic` with `year` parameter for recent papers
3. After finding papers, use `download_*` to get PDFs
4. Use `read_*` to extract text content for analysis
5. Combine multiple sources for comprehensive literature reviews
