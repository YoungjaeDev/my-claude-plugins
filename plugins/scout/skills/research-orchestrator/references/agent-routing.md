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
| "학술 논문 / arxiv / SOTA benchmark / 인용 / DOI / {venue} paper" | `paper-scout` | scout:paper-search 8-source family |

## Multi-axis triggers (deep mode)

Any of these forces deep fan-out:

- "research", "deep dive", "comprehensive", "best practices", "thorough"
- Korean: 조사, 심층, 깊이, 모범사례, 비교
- Query contains two domains (e.g. "Llama 4 deployment" = HF model + deployment docs + web blogs)
- User explicitly asks for a comparison ("X vs Y", "compare", "trade-offs")
- User asks "should I use ...?" (decision support — needs multiple voices)

When the deep query **also** carries an academic signal (paper / arxiv / SOTA / DOI / benchmark / 인용 / venue names like ICML, NeurIPS, CVPR, RSA, PubMed), add `paper-scout` to the fan-out for the full **5-axis** dispatch. Otherwise stick to the 4-axis baseline.

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
1. "단순 GitHub PR 검색 / merge" → `dev:resolve-issue` or `dev:cr-fix`
2. "Ask a single question about pytorch/serve repo" → `scout:ask` directly
3. "Resolve library ID for langchain" → `context7` MCP directly
4. "Download arxiv 2406.04093 PDF" → `scout:paper-search` `download_*` directly (paper-scout is metadata-only)
5. "한국 대선 정책 리서치" / "tesla market share history" / "general policy / biography / market trend" — anything **outside the code/ML domain** → `/deep-research` directly. Its 7-phase + adversarial verify + state machine is built for generic topics; scout 5-axis routes are tuned for code/ML and would mis-route. **Orchestrator does NOT delegate to /deep-research** — boundary is intentional, user invokes it themselves.
6. "Translate this article" → `docs:translate-web-article`
7. "Generate a CHANGELOG entry" → `docs:changelog`

## Near-miss disambiguation

### vs. `scout:paper-search`

`scout:paper-search` plugin owns the 8-source MCP family (arXiv / PubMed / Semantic Scholar / Crossref / bioRxiv / medRxiv / IACR / Google Scholar) — search across all 8, **read + download on 7 (arXiv / PubMed / Semantic Scholar / Crossref / bioRxiv / medRxiv / IACR only — Google Scholar is search-only)**. `paper-scout` (v2.1) wraps the search half for fan-out research: it picks 2-3 sources by domain, runs parallel searches, scores reliability, and writes `05_paper.json`. Route through `paper-scout` (via orchestrator) when papers are an axis of a broader research query. Call `scout:paper-search` directly when the user wants a single paper's PDF / full text (`download_*` / `read_*`) — that's the user's follow-up after seeing paper-scout's metadata, not part of the scout's job (LLM context budget). For Google Scholar hits with a DOI, use `get_crossref_paper_by_doi` to enrich; there is no `read_google_scholar_paper` or `download_google_scholar`.

### vs. `/deep-research`

`/deep-research` is the sibling plugin for **non-code/ML** topics — politics, market, policy, history, biographies, general knowledge. It runs a 7-phase pipeline with adversarial verify and a state-machine for long sessions. `scout` 5-axis routing is tuned for code/ML/docs and would mis-route on generic topics (e.g., a github-scout pass on a political-policy query returns junk). Pick by domain: code/ML → scout; everything else → `/deep-research`. The orchestrator does **not** delegate to `/deep-research`; the user calls each tool directly. This boundary keeps each harness focused on the domain it was tuned for.

### vs. `scout:ask`

`scout:ask` is a single-question wrapper around DeepWiki MCP. If the user asks one focused question about one repo, use it. `docs-scout` (within orchestrator) bundles Context7 + DeepWiki across topics — use it when the user wants a researched answer, not a quick lookup.

### vs. `dev:*`

`dev:*` skills act on GitHub state — issues, PRs, reviews, releases. `github-scout` is read-only discovery. If the user is editing repo state, never route through orchestrator.

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
"paper", "arxiv", "preprint", "DOI",        paper-scout
  "SOTA benchmark", "citation", "venue",
  "ICML / NeurIPS / CVPR / RSA", "논문"
```

When in doubt at `deep` mode, include `github-scout` + `web-scout` + `docs-scout` as the baseline trio. Add `paper-scout` when academic-signal keywords appear; add `hf-scout` when model/dataset names or tasks appear.
