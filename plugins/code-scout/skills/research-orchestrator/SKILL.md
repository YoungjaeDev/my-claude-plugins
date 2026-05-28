---
name: research-orchestrator
description: |
  Multi-axis research orchestrator for code, ML, docs, and web sources. Routes a
  natural-language query to one or more specialized scouts (github, hf, web, docs,
  paper) running in parallel, then dispatches synthesis-scout to dedup, trust-rank,
  and emit a final Markdown report. Use when the user asks "research X", "find best
  practices for Y", "compare A vs B", "what's the consensus on Z", or wants a
  cross-source technical brief. Triggers — "research", "조사해줘", "best practices",
  "compare frameworks", "what does the community say", "deep dive", "find boilerplate".
---

# Research Orchestrator

Entry point for code-scout v2.0. Replaces the legacy `scout` / `deep-scout` agents with a small router that fans out to specialized scouts and consolidates via `synthesis-scout`.

## When to use vs. skip

Use when:
- The query needs more than one source axis (GitHub + docs, web + HF, etc.)
- The user explicitly asks for a research report or comparison
- The user says "thorough", "deep", "comprehensive", "compare", "best practices", "research"
- A single-axis quick lookup is fine — the orchestrator will detect that and fan out to just one scout

Skip / use something else when:
- The user wants a GitHub PR review → `github-dev:cr-fix` / `github-dev:resolve-issue`
- The user wants academic papers only → `paper-search-tools` plugin (paper-scout placeholder until next PR)
- The user wants to ask a single question about one repo → `deepwiki:ask` directly
- The user wants to read library API docs only → `context7` MCP directly

See `references/agent-routing.md` for the full should / should-NOT matrix.

## Inputs

- `query` (required) — user's natural-language research target
- `mode` (optional) — `quick` | `deep`; auto-detected if absent
- `workspace_dir` (optional) — defaults to `/tmp/research/_workspace`
- `report_path` (optional) — defaults to `/tmp/research/final_report.md`

## Workflow

### 1. Mode detection

Default `quick`. Upgrade to `deep` if any of these match in the query:
- Korean: 깊이, 심층, 자세히, 비교, 모범사례
- English: deep, thorough, comprehensive, compare, "best practices", "trade-offs", "vs"
- Or the caller passed `mode: "deep"` explicitly

### 2. Workspace setup

```bash
# Per-run isolated workspace — never share /tmp/research/_workspace across runs
# (parallel orchestrator runs would otherwise clobber each other's artifacts).
WORKSPACE="${workspace_dir:-$(mktemp -d /tmp/research/run.XXXXXXXX)}"
REPORT="${report_path:-${WORKSPACE%/}/final_report.md}"
mkdir -p "$WORKSPACE" "$(dirname "$REPORT")"
```

Caller-supplied `workspace_dir` / `report_path` are honored verbatim; otherwise each run gets its own `mktemp` directory. Tell the user the resolved `$WORKSPACE` and `$REPORT` paths in the final summary so they can inspect or delete the run's artifacts.

### 3. Axis routing

Look at the query and pick scouts. See `references/agent-routing.md` for the full table. Defaults:

| Mode | Default fan-out |
|---|---|
| `quick`, GitHub-leaning query | `github-scout` only |
| `quick`, HF-leaning query | `hf-scout` only |
| `quick`, docs question | `docs-scout` only |
| `quick`, web/community question | `web-scout` only |
| `deep` | `github-scout` + `hf-scout` + `web-scout` + `docs-scout` |

Assign sequential `artifact_id` slots in dispatch order: `01_github`, `02_hf`, `03_web`, `04_docs`.

For academic queries (papers, benchmarks, SOTA), do **not** dispatch a `paper-scout` — that agent is not wired up in v2.0. Instead, point the user at the `paper-search-tools` plugin directly (`mcp__plugin_paper-search-tools_*` MCP tools), or include a `## Gaps` note in the report. Native `paper-scout` integration is scheduled for the next PR.

### 4. Fan-out dispatch

For `deep` mode, dispatch all chosen scouts in a single message so they run concurrently:

```
Agent(subagent_type="code-scout:github-scout",
      prompt="query=<...>\nworkspace_dir=/tmp/research/_workspace\nartifact_id=01_github")
Agent(subagent_type="code-scout:hf-scout",
      prompt="query=<...>\nworkspace_dir=/tmp/research/_workspace\nartifact_id=02_hf")
Agent(subagent_type="code-scout:web-scout", ...)
Agent(subagent_type="code-scout:docs-scout", ...)
```

For long-running runs (more than ~2 minutes expected per scout), prefer `Agent({...}, {run_in_background: true})` + `Monitor` so the orchestrator can stream progress.

**Wait for every dispatched scout to complete before step 5** — partial-result synthesis is a regression of the v1 quality bar. If a scout times out, it is expected to write a `{ "findings": [], "error": "..." }` artifact rather than hang.

### 5. Synthesis dispatch

After every fan-out scout has written its artifact:

```
Agent(subagent_type="code-scout:synthesis-scout",
      prompt="workspace_dir=/tmp/research/_workspace\nquery=<...>\nmode=<quick|deep>\nreport_path=/tmp/research/final_report.md")
```

Synthesis is strictly read-only on the workspace — it cannot call exa, gh, or HF tools. See `references/synthesis-rules.md` for the merge / trust / conflict rules synthesis-scout follows.

### 6. Return

Surface the report path and top-3 picks to the user. Do not paste the entire report inline unless the user asked for it — the file path is enough for follow-up.

## Quick mode shortcut

If only one scout is needed, skip the workspace dance:

```
Agent(subagent_type="code-scout:<single>-scout", prompt="query=<...>\n# no workspace_dir/artifact_id; write findings to stdout")
```

The scout will return its findings JSON inline; the orchestrator turns it into a one-page Markdown summary itself.

## Failure handling

- Workspace empty after fan-out → synthesis-scout emits an "all axes failed" report; orchestrator surfaces it with `BLOCKED` status and asks user whether to retry with different axes.
- exa MCP unavailable → web-scout falls back to WebSearch automatically; the orchestrator does not need to know.
- One axis errors out → synthesis-scout proceeds with what it has and lists the missing axis in `## Gaps`.

## Reference files

- `references/agent-routing.md` — full routing matrix (should / should-NOT per scout, near-miss disambiguation vs `paper-search-tools`, `deepwiki:ask`, `github-dev:*`)
- `references/synthesis-rules.md` — synthesis-scout's dedup keys, trust rubric, and conflict resolution order

## Examples

### "Research deployment options for Llama 4 in production"

Mode: `deep` (has "deployment" + comparison intent).
Fan-out: `github-scout` (deployment frameworks), `hf-scout` (Llama 4 model cards / Spaces), `web-scout` (recent practitioner blogs), `docs-scout` (vLLM / TGI docs via Context7).
Synthesis emits `final_report.md` with Recommended Picks table + Conflicts (e.g., vLLM vs SGLang).

### "Find a FastAPI boilerplate with auth and Postgres"

Mode: `quick` (single-axis GitHub).
Dispatch: `github-scout` only, inline output.
Orchestrator wraps top picks into a short Markdown answer.

### "What's the consensus on Pydantic v3 migration?"

Mode: `deep` (compare + consensus).
Fan-out: `web-scout` (community sentiment), `docs-scout` (Pydantic migration docs via Context7), `github-scout` (issues / migration PRs).
Synthesis reconciles official migration guide vs community pain points.
