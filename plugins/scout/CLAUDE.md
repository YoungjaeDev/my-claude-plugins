# scout

Multi-axis code and ML research harness: 4 single-axis scouts (`github` / `hf` / `web` / `docs`) fan out in parallel and `synthesis-scout` merges their artifacts into one report. Two DeepWiki skills, `ask` and `generate-llmstxt`, sit beside it; `insane-search` is an optional tier-4 fetch fallback.

## When to use

| Situation | Entry point |
|---|---|
| "Research X", "best practices for Y", "compare A vs B" | `Skill("scout:research-orchestrator")` |
| Single-axis: GitHub-only discovery | `Agent(subagent_type="scout:github-scout")` |
| Single-axis: HF models / datasets / Spaces | `Agent(subagent_type="scout:hf-scout")` |
| Single-axis: web / blogs / community | `Agent(subagent_type="scout:web-scout")` |
| Single-axis: official docs / repo Q&A | `Agent(subagent_type="scout:docs-scout")` |
| Already have artifacts, just need merge | `Agent(subagent_type="scout:synthesis-scout")` |
| One question about one GitHub repo | `/scout:ask` |
| `llms.txt` from a URL or local directory | `/scout:generate-llmstxt` |
| General non-code/ML topic (politics / market / history / biographies) | `/deep-research` directly (scout never delegates to it) |

The single-axis `Agent(...)` rows are Claude-only: Codex exposes the skills but cannot register `agents/*.md`. Under Codex, enter through `Skill("scout:research-orchestrator")`, which runs the same axes through generic or sequential subagents (its Phase 3.5). The full routing matrix is `skills/research-orchestrator/references/agent-routing.md`.

## Team layout

```text
research-orchestrator (skill, entry point)
  │   $WORKSPACE = <repo>/.tmp/research/run.XXXXXXXX      (per-run mktemp; ${TMPDIR:-/tmp}/research outside a repo)
  │   $REPORT    = $WORKSPACE/final_report.md             (override via report_path)
  │
  ├─ fan-out (parallel) ──────────────────────────────┐
  │   github-scout    (gh search repos/code)          │
  │   hf-scout        (uvx hf + HF REST)              │ → $WORKSPACE/{NN}_{axis}.json
  │   web-scout       (exa → brightdata → insane)     │
  │   docs-scout      (context7 + deepwiki)           │
  │                                                   │
  └─ fan-in ─────────────────────────────────────────►│
      synthesis-scout (dedup, trust, conflict)
        → $REPORT  (= $WORKSPACE/final_report.md unless caller overrode it)
```

- **Agents**: all scouts use `model: opus`, and `{NN}_{axis}.json` lexical order makes the merge deterministic.
- **Shared contract**: `skills/research-orchestrator/references/axis-contracts.md` holds the per-axis query shape and result envelope that keep the named-agent (Claude), generic-subagent (Codex) and sequential paths interchangeable.
- **Merge rules**: `skills/research-orchestrator/references/synthesis-rules.md` holds the dedup keys, trust rubric and conflict order.

## Skills

| Skill | Procedure file | Purpose |
|---|---|---|
| `research-orchestrator` | `skills/research-orchestrator/references/procedure.md` | Entry point: mode detection, fan-out routing, synthesis dispatch |
| `ask` | `references/ask-procedure.md` | Query a GitHub repo through the DeepWiki MCP |
| `generate-llmstxt` | `references/generate-llmstxt-procedure.md` | Generate `llms.txt` from a URL or a local directory |

The orchestrator's tool guides (`exa-web-search.md`, `resource-finder.md`, `brightdata-guide.md`) are references under `skills/research-orchestrator/references/`, read by path from the agents and the axis contracts.

## Requirements

- `gh` CLI authenticated (github-scout).
- `uv`, `jq` (hf-scout and the `resource-finder.md` wrappers).
- exa MCP (web-scout primary; falls back to built-in `WebSearch`).
- Bright Data MCP, or the `bdata` CLI on the delegated-subagent path (web-scout tier-3 fetch and `generate-llmstxt` URL mode; see the `brightdata-guide.md` preflight).
- `insane-search` plugin (web-scout tier-4 fetch fallback for WAF / blocked pages; optional).
- Context7 + DeepWiki MCPs (docs-scout, `ask`). DeepWiki setup: <https://mcp.deepwiki.com/>; this plugin does not install it, and `ask` fails at the first `mcp__deepwiki__*` call without it.

## MCP tools used by the DeepWiki skills

| Tool | Purpose |
|------|---------|
| `mcp__deepwiki__read_wiki_structure` | Documentation topics |
| `mcp__deepwiki__read_wiki_contents` | Full documentation |
| `mcp__deepwiki__ask_wiki_question` | AI-powered Q&A |
| `mcp__brightdata__scrape_as_markdown` / `scrape_batch` | URL-mode `generate-llmstxt` (sitemap discovery runs on `curl`; `bdata` CLI is the terminal fallback) |
