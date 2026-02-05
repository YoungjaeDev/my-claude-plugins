---
name: paper-search
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

## MCP Tools (23)

### Search Tools

| Tool | Platform | Parameters |
|------|----------|------------|
| `mcp__paper-search__search_arxiv` | arXiv | query, max_results=10 |
| `mcp__paper-search__search_pubmed` | PubMed | query, max_results=10 |
| `mcp__paper-search__search_biorxiv` | bioRxiv | query, max_results=10 |
| `mcp__paper-search__search_medrxiv` | medRxiv | query, max_results=10 |
| `mcp__paper-search__search_google_scholar` | Google Scholar | query, max_results=10 |
| `mcp__paper-search__search_iacr` | IACR ePrint | query, max_results=10, fetch_details=True |
| `mcp__paper-search__search_semantic` | Semantic Scholar | query, year (optional), max_results=10 |
| `mcp__paper-search__search_crossref` | CrossRef | query, max_results=10 |

### Download Tools

| Tool | Platform |
|------|----------|
| `mcp__paper-search__download_arxiv` | arXiv |
| `mcp__paper-search__download_pubmed` | PubMed |
| `mcp__paper-search__download_biorxiv` | bioRxiv |
| `mcp__paper-search__download_medrxiv` | medRxiv |
| `mcp__paper-search__download_iacr` | IACR ePrint |
| `mcp__paper-search__download_semantic` | Semantic Scholar |
| `mcp__paper-search__download_crossref` | CrossRef |

Parameters: `paper_id`, `save_path="/downloads"`

### Read Tools

| Tool | Platform |
|------|----------|
| `mcp__paper-search__read_arxiv_paper` | arXiv |
| `mcp__paper-search__read_pubmed_paper` | PubMed |
| `mcp__paper-search__read_biorxiv_paper` | bioRxiv |
| `mcp__paper-search__read_medrxiv_paper` | medRxiv |
| `mcp__paper-search__read_iacr_paper` | IACR ePrint |
| `mcp__paper-search__read_semantic_paper` | Semantic Scholar |
| `mcp__paper-search__read_crossref_paper` | CrossRef |

Parameters: `paper_id`, `save_path="/downloads"`

Downloaded files are stored at `/tmp/paper-search-downloads` on the host.

### Utility Tools

| Tool | Description |
|------|-------------|
| `mcp__paper-search__get_crossref_paper_by_doi` | Get paper metadata by DOI |

## Best Practices

1. Start with broad search, then narrow down
2. Use `search_semantic` with `year` parameter for recent papers
3. After finding papers, use `download_*` to get PDFs
4. Use `read_*` to extract text content for analysis
5. Combine multiple sources for comprehensive literature reviews
