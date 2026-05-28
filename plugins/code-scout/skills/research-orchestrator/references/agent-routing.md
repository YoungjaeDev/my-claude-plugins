# Agent Routing Matrix

Detailed routing decisions for `research-orchestrator`. Keep this table in sync with each scout's `## When NOT to use` block.

## Single-axis triggers (quick mode)

| Query shape | Route to | Why |
|---|---|---|
| "find {stack} boilerplate / template / starter" | `github-scout` | GitHub is canonical source |
| "awesome {topic} list" | `github-scout` | curated lists live on GitHub |
| "find {task} model / dataset / Space" | `hf-scout` | HF hub is canonical |
| "compare model X vs Y on benchmarks" | `hf-scout` + maybe `web-scout` | HF for metadata, web for practitioner reports |
| "what does Reddit / HN / r/MachineLearning say about X" | `web-scout` | social/community sources |
| "what's the {company} {product} announcement" | `web-scout` | news / blog territory |
| "{library} migration guide / API reference" | `docs-scout` | Context7 owns this |
| "how does {repo} {feature} work internally" | `docs-scout` | DeepWiki owns this |

## Multi-axis triggers (deep mode)

Any of these forces deep fan-out:

- "research", "deep dive", "comprehensive", "best practices", "thorough"
- Korean: 조사, 심층, 깊이, 모범사례, 비교
- Query contains two domains (e.g. "Llama 4 deployment" = HF model + deployment docs + web blogs)
- User explicitly asks for a comparison ("X vs Y", "compare", "trade-offs")
- User asks "should I use ...?" (decision support — needs multiple voices)

## should / should-NOT for `research-orchestrator`

**Should trigger:**
1. "ML 모델 조사" — research request
2. "PyTorch 베스트프랙티스 검색" — best-practices is a deep trigger
3. "Llama 4 deployment 모범사례" — multi-axis (docs + web + HF)
4. "Compare vLLM vs TGI for production serving" — comparison
5. "Find FastAPI boilerplate" — single-axis quick
6. "What's the consensus on Pydantic v3 migration" — deep + community
7. "Research RAG eval frameworks 2026" — deep
8. "리액트 상태관리 라이브러리 비교" — comparison

**Should NOT trigger (route elsewhere):**
1. "단순 GitHub PR 검색 / merge" → `github-dev:resolve-issue` or `github-dev:cr-fix`
2. "Academic paper on diffusion models" → `paper-search-tools` directly (paper-scout placeholder)
3. "Ask a single question about pytorch/serve repo" → `deepwiki:ask` directly
4. "Resolve library ID for langchain" → `context7` MCP directly
5. "Translate this article" → `translator` plugin
6. "Upload this markdown to Notion" → `notion` plugin
7. "Create a slide deck" → `slidev` plugin
8. "Generate a CHANGELOG entry" → `docs-forge:changelog`

## Near-miss disambiguation

### vs. `paper-search-tools`

`paper-search-tools` owns arXiv / PubMed / Semantic Scholar / Crossref / etc. with structured paper-level APIs. If the user wants citations, papers, DOIs — go there directly. `research-orchestrator` only invokes `paper-scout` (placeholder) when the topic is technical and papers would be one of several inputs (not the sole input).

### vs. `deepwiki:ask`

`deepwiki:ask` is a single-question wrapper around DeepWiki MCP. If the user asks one focused question about one repo, use it. `docs-scout` (within orchestrator) bundles Context7 + DeepWiki across topics — use it when the user wants a researched answer, not a quick lookup.

### vs. `github-dev:*`

`github-dev:*` skills act on GitHub state — issues, PRs, reviews, releases. `github-scout` is read-only discovery. If the user is editing repo state, never route through orchestrator.

### vs. direct exa MCP

If the user has a very narrow factual web query ("what was Anthropic's Opus 4.7 release date") they can hit exa directly via the MCP. `web-scout` is for queries that benefit from 2-3 query variants + synthesis with other axes.

## Axis selection cheat-sheet

```
query mentions / implies                  → add this scout
─────────────────────────────────────────   ─────────────
"repo", "boilerplate", "starter", "code"    github-scout
"model", "weights", "dataset", "Space",     hf-scout
  "Llama", "Qwen", "BERT", "Whisper"
"blog", "reddit", "consensus", "trending",  web-scout
  company / person names, "announcement"
"docs", "API", "migration guide",           docs-scout
  "how does X work in repo Y"
"paper", "arxiv", "benchmark", "SOTA"       paper-scout (placeholder)
```

When in doubt at `deep` mode, include `github-scout` + `web-scout` + `docs-scout` as the baseline trio.
