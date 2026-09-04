# scout

Multi-axis code & ML research harness. v2.1 grows the v2.0 4-axis team to a 5-axis team (adds `paper-scout`) + synthesis orchestrator, and wires `insane-search` as a tier-4 transport fetch fallback.

## When to use

| Situation | Entry point |
|---|---|
| "Research X", "best practices for Y", "compare A vs B" | `Skill("scout:research-orchestrator")` |
| Single-axis: GitHub-only discovery | `Agent(subagent_type="scout:github-scout")` |
| Single-axis: HF models / datasets / Spaces | `Agent(subagent_type="scout:hf-scout")` |
| Single-axis: web / blogs / community | `Agent(subagent_type="scout:web-scout")` |
| Single-axis: official docs / repo Q&A | `Agent(subagent_type="scout:docs-scout")` |
| Single-axis: academic papers (arxiv / DOI / SOTA / benchmark) | `Agent(subagent_type="scout:paper-scout")` |
| Already have artifacts, just need merge | `Agent(subagent_type="scout:synthesis-scout")` |
| General non-code/ML topic (politics / market / history / biographies) | `/deep-research` directly — scout doesn't delegate, boundary is intentional |

**Runtime note:** the single-axis `Agent(subagent_type="scout:*-scout")` rows above are **Claude-only** — Codex 0.135 exposes the skills but cannot register the `agents/*.md` definitions. Under Codex, enter through `Skill("scout:research-orchestrator")`; it detects that the named agents are unregisterable and runs the same axes via generic parallel subagents (or sequential in-agent when delegation is unavailable), synthesizing in-skill. See `skills/research-orchestrator/references/axis-contracts.md` for the shared contract all three execution paths consume.

For the full routing matrix (should / should-NOT, near-miss disambiguation vs `scout:paper-search`, `scout:ask`, `dev:*`, `/deep-research`), see `skills/research-orchestrator/references/agent-routing.md`.

## Team layout

```text
research-orchestrator (skill, entry point)
  │   $WORKSPACE = ${TMPDIR:-/tmp}/research/run.XXXXXXXX  (per-run mktemp)
  │   $REPORT    = $WORKSPACE/final_report.md             (override via report_path)
  │
  ├─ fan-out (parallel) ──────────────────────────────┐
  │   github-scout    (gh search repos/code)          │
  │   hf-scout        (uvx hf + HF REST)              │ → $WORKSPACE/{NN}_{axis}.json
  │   web-scout       (exa → brightdata → insane)     │
  │   docs-scout      (context7 + deepwiki)           │
  │   paper-scout     (scout:paper-search 8-source)   │
  │                                                   │
  └─ fan-in ─────────────────────────────────────────►│
      synthesis-scout (dedup, trust, conflict)
        → $REPORT  (= $WORKSPACE/final_report.md unless caller overrode it)
```

All scouts use `model: opus`. Workspace artifacts use `{NN}_{axis}.json` lexical order so synthesis merges deterministically. See `skills/research-orchestrator/references/synthesis-rules.md` for dedup keys, trust rubric, and conflict resolution, and `skills/research-orchestrator/references/axis-contracts.md` for the shared per-axis query shape + result envelope that keeps the named-agent (Claude), generic-subagent (Codex), and sequential fallback paths interchangeable.

## Skills

| Skill | Purpose |
|---|---|
| `research-orchestrator` | Entry point. Mode detection, fan-out routing, synthesis dispatch. |

`exa-web-search`, `resource-finder`, and `brightdata-guide` were demoted from standalone skills to `research-orchestrator/references/*.md` — their only real consumers are the scout agents and the orchestrator itself, not a session-level skill surface, so agents `Read` them by path instead of triggering a separate skill description.

## Migration

### v1.x → v2.0

| v1 entry point | v2 replacement |
|---|---|
| `Agent(subagent_type="scout:scout")` | `Skill("scout:research-orchestrator")` (quick mode auto-detected) — or call `github-scout` / `hf-scout` directly for single-axis |

The legacy `scout` agent remains as a **doc-only deprecation pointer**: it returns a migration message but does not run searches. Subagents cannot reliably spawn further subagents, so the fan-out + synthesis flow must be initiated from the main session via the orchestrator skill or a direct `Agent(subagent_type="scout:{axis}-scout", ...)` call. Existing scripts that called the old `subagent_type` need to migrate — there is no transparent shim.

### v2.0 → v2.1

- `paper-scout` 5th axis is auto-included in `deep` mode when the query carries academic signal (paper / arxiv / DOI / SOTA / benchmark / 인용 / venue names). Existing 4-axis deep flows are unchanged.
- `Agent(subagent_type="scout:deep-scout")` continues to return the same v2.0 deprecation message — the doc-only stub is **retained** for backward compatibility (no user-visible change vs v2.0). Permanent removal is deferred to a future MAJOR release. Callers should migrate to `Skill("scout:research-orchestrator")` (deep mode auto-detected from "deep / thorough / comprehensive / compare / best practices" keywords).
- `web-scout` now auto-retries WAF / 403 / blocked fetches through `insane-search` as a tier-4 transport fallback. No caller change required.
- General non-code/ML research (politics / market / history / biographies) → call `/deep-research` directly. scout does not delegate; the boundary is intentional (each harness is tuned for its domain).

## Requirements

- `gh` CLI authenticated (github-scout)
- `uv`, `jq` (hf-scout, `research-orchestrator/references/resource-finder.md` wrappers)
- exa MCP enabled in `~/.claude/settings.json` (web-scout primary; falls back to built-in `WebSearch`)
- brightdata MCP enabled (web-scout tier-3 fetch fallback; `bdata` CLI is the delegate-subagent path — see the `research-orchestrator/references/brightdata-guide.md` preflight)
- `insane-search` plugin installed (web-scout tier-4 fetch fallback for WAF / blocked pages; optional but recommended)
- Context7 + DeepWiki MCPs enabled (docs-scout)
- the bundled `paper-search` MCP server (`.mcp.json`, Docker) running (paper-scout)

## Change log

| Version | Notes |
|---|---|
| 2.3.0 | Moves `web-scout`'s tier-3 fetch slot onto Bright Data `scrape_as_markdown`, replacing the scraping MCP retired in this release. The exa-first pipeline is unchanged — only the tier-3 tool swaps, and tier-4 `insane-search` now triggers when `scrape_as_markdown` is the one that gets blocked. Adds a scope guard so the axis stays fetch-only (no `search_engine` as a search axis, no `web_data_*` / `scraping_browser_*` / `scrape_batch`) and routes an unconfigured Bright Data through the `brightdata-guide` four-gate preflight, recording the failing gate in `errors` instead of silently downgrading the fetch. Drops the routing row for the presentation plugin retired in this release. |
| 2.2.0 | `research-orchestrator` now runs under Codex 0.135, where the `agents/*.md` scout definitions are not registerable. Adds a Phase 3.5 capability branch: **Path A** named plugin agents (Claude Code — unchanged), **Path B** generic parallel subagents (Codex `Task`), **Path C** sequential in-agent. Synthesis is runtime-independent (named `synthesis-scout` on Path A, in-skill synthesis on B / C). New `references/axis-contracts.md` holds the shared per-axis query shape + result envelope + tool order / fallback / reliability so all three paths stay interchangeable. Claude named-agent quick + deep paths are behaviorally unchanged. |
| 2.1.1 | Shortens `research-orchestrator` skill description under the Codex 1024-char frontmatter limit (full routing matrix kept in the skill body). Adds a pre-commit hook + `validate-codex.yml` CI guard that enforces the limit on every skill description. |
| 2.1.0 | Adds `paper-scout` as the 5th axis (wraps scout:paper-search 8-source MCP family — arXiv / Semantic Scholar / Crossref / PubMed / bioRxiv / medRxiv / IACR / Google Scholar — with domain-driven source selection). Wires `insane-search` as `web-scout` tier-4 transport fetch fallback for WAF / 403 / blocked URLs (X / Reddit / Coupang). Documents the `/deep-research` boundary — scout owns code/ML/docs/papers, `/deep-research` owns generic topics; orchestrator does not delegate. The v2.0 `deep-scout` doc-only stub is retained for backward compatibility (permanent removal deferred to a future MAJOR release). |
| 2.0.0 | Harness refactor — 5-scout team (`github` / `hf` / `web` / `docs` / `synthesis`) + `research-orchestrator` skill + `exa-web-search` skill. exa MCP wired into web-scout. Legacy `scout` / `deep-scout` agents stubbed. cr-fix loop converged after 9 substantive fixes across 5 iters (Codex P2 ×8 + CR Major ×1: paper-scout routing, sort merge, mktemp parent + isolation, hf CLI subcommands, workspace propagation, stub auto-delegate, Context7 fallback, synthesis Write permission). Harness audit boost — Phase 0 context-check + partial re-execution mode + follow-up triggers + scout re-invoke rule + test scenarios + negative trigger surface in description. **Breaking**: direct `subagent_type` callers should migrate per table above. |
| 1.1.0 | Portable-tools-first refactor (`gh`, `uvx hf`, REST + jq). PEP 723 wrappers for cwd-free `uv run`. |
| 1.0.0 | Initial release — `scout` (haiku) + `deep-scout` (sonnet) with `resource-finder` skill. |


## deepwiki (흡수: deepwiki)


AI-powered deep queries on GitHub repositories through the DeepWiki MCP. Two skills, `/scout:ask` and `/scout:generate-llmstxt`, serve both explicit invocation and capability discovery on Claude Code and Codex (the duplicate `commands/` surface was dropped in the 2.30.0 consolidation). Each skill resolves its workflow body from `references/`.

### Surfaces

| Command | Skill | Procedure file | Description |
|---------|-------|----------------|-------------|
| `/scout:ask` | `ask` | `references/ask-procedure.md` | Query any GitHub repo with AI-powered documentation. |
| `/scout:generate-llmstxt` | `generate-llmstxt` | `references/generate-llmstxt-procedure.md` | Generate llms.txt from a URL or local directory. |

### Usage

```bash
## Basic query
/scout:ask facebook/react "How does reconciliation work?"

## Architecture questions
/scout:ask vercel/next.js explain the app router

## Compare repositories
/scout:ask pytorch/pytorch,tensorflow/tensorflow "Compare eager vs graph execution"

## llms.txt from a docs site
/scout:generate-llmstxt https://docs.example.com
```

In conversational use (skill surface) the model can pick the right capability without the explicit slash — e.g. "what's the autograd internals of pytorch/pytorch?" triggers the `ask` skill.

### How it works

1. **Structure** — first understand what documentation exists.
2. **Context** — gather relevant sections (for broad questions).
3. **Answer** — provide an AI-powered comprehensive response.
4. **Expand** — decompose complex questions if needed.

### MCP Tools Used

| Tool | Purpose |
|------|---------|
| `mcp__deepwiki__read_wiki_structure` | Get documentation topics. |
| `mcp__deepwiki__read_wiki_contents` | Get full documentation. |
| `mcp__deepwiki__ask_question` | AI-powered Q&A. |
| `mcp__brightdata__scrape_as_markdown` / `scrape_batch` | URL-mode `generate-llmstxt` (sitemap discovery runs on `curl`; `bdata` CLI is the terminal fallback). |

### Best practices

- **Specific > Vague**: "How does X work?" beats "Tell me about X".
- **Check structure first**: see what docs exist before deep diving.
- **Use for learning**: great for understanding unfamiliar codebases.
- **Compare repos**: powerful for framework/library comparisons.

### Requirements

- DeepWiki MCP server configured in the host runtime. Setup: <https://mcp.deepwiki.com/>. If the MCP is missing, the skill will fail at the first `mcp__deepwiki__*` tool call — that is a host-side configuration step, not something this plugin auto-installs.
- For `generate-llmstxt` URL mode, the Bright Data MCP must be available as well, or the `bdata` CLI installed, authenticated, and given a default zone (see the `brightdata-guide` preflight).
- Internet connection (queries the DeepWiki API).
