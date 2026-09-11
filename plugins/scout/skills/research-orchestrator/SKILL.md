---
name: research-orchestrator
description: "Multi-axis research orchestrator for code, ML, docs, and web sources: routes a query to github/hf/web/docs scouts in parallel, then synthesis-scout dedups, trust-ranks, and writes a Markdown report. Use on /scout:research-orchestrator, 'research X', '리서치해줘', 'best practices for Y', 'compare A vs B', 'deep dive', 'find boilerplate', or to refine prior research. Not for single-repo Q&A (/scout:ask), one-off library docs (context7 MCP), or non-code topics (/deep-research)."
---

# Research Orchestrator

The entry point for scout. A small router: it detects mode, fans the query out to the specialized per-axis scouts, and consolidates their artifacts into one report.

## When to use vs. skip

Use when:
- The query needs more than one source axis (GitHub + docs, web + HF, etc.)
- The user explicitly asks for a research report or comparison
- The user says "thorough", "deep", "comprehensive", "compare", "best practices", "research"
- A single-axis quick lookup is fine: the orchestrator will detect that and fan out to just one scout

Skip / use something else when:
- The user wants a GitHub PR review → `dev:cr-fix` / `dev:resolve-issue`
- The user wants to ask a single question about one repo → `scout:ask` directly
- The user wants to read library API docs only → `context7` MCP directly
- The user's query is **outside the code / ML domain** (politics, market, history, biographies, general policy) → `/deep-research` directly. Its 7-phase + adversarial verify + state-machine flow is tuned for generic topics; scout's axis routing is tuned for code/ML and would mis-route on those queries. Orchestrator does **not** delegate to `/deep-research`: the boundary is intentional.

See `references/agent-routing.md` for the full should / should-NOT matrix.

## Inputs

- `query` (required): user's natural-language research target
- `mode` (optional): `quick` | `deep`; auto-detected if absent
- `workspace_dir` (optional): when set, the orchestrator reuses this directory and the caller owns lifecycle (enables partial re-execution; see Phase 0 below). When unset, each run gets its own `mktemp` directory.
- `report_path` (optional): defaults to `${workspace_dir}/final_report.md`

**Data-transfer protocol:** file-based via `$WORKSPACE/{NN}_{axis}.json`. Sibling scouts do not communicate directly; everything flows through the workspace and is merged by synthesis-scout. Lexical filename ordering = deterministic merge order.

## Workflow

### Phase 0: Context check (re-execution detection)

Before mode detection, inspect the caller-supplied `workspace_dir`:

- **Fresh run** (no `workspace_dir`, or directory missing) → proceed to Phase 1 normally; Phase 2 creates a new `mktemp` directory.
- **Partial re-execution** (existing `workspace_dir` + user explicitly asks to refine one axis, e.g. "github 결과만 다시"): keep the directory, dispatch only the named scout(s) with the existing `artifact_id` (they overwrite their slot), then re-run synthesis on the merged set.
- **Fresh re-run on same workspace** (existing `workspace_dir` + user asks to redo the whole query): move the old directory to `${workspace_dir}_prev.$(date +%s)` for audit, then create a new one at the same path.

Tell the user which mode you picked in one sentence so they can correct you if intent differs.

### 1. Mode detection

Default `quick`. Upgrade to `deep` if any of these match in the query:
- Korean: 깊이, 심층, 자세히, 비교, 모범사례
- English: deep, thorough, comprehensive, compare, "best practices", "trade-offs", "vs"
- Or the caller passed `mode: "deep"` explicitly

### 2. Workspace setup

```bash
# Per-run isolated workspace — never share a fixed path across runs
# (parallel orchestrator runs would otherwise clobber each other's artifacts).
# Ensure the parent exists before mktemp, then create the workspace.
PARENT="${TMPDIR:-/tmp}/research"
mkdir -p "$PARENT"
WORKSPACE="${workspace_dir:-$(mktemp -d "$PARENT/run.XXXXXXXX")}"
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

Assign sequential `artifact_id` slots in dispatch order: `01_github`, `02_hf`, `03_web`, `04_docs`. Skipped axes leave their slot unallocated; synthesis-scout's `find` enumeration handles sparse workspaces deterministically.

### 3.5 Execution capability detection

Before dispatch, pick the execution path **once**. This decides *how* the chosen axes run, not *which*; Phase 3 already fixed the axis set. All three paths consume the shared query shape and emit the shared result envelope in `references/axis-contracts.md`, so synthesis and the final report are identical regardless of path.

| Path | Condition | How the axes run |
|---|---|---|
| **A: named plugin agents** | The qualified `scout:{axis}-scout` subagents are registered (Claude Code with scout installed). | Current named-agent fan-out (Phase 4A / 5A), **unchanged**. Default on Claude Code. |
| **B: generic parallel subagents** | Named `scout:*-scout` are NOT registerable, but a generic subagent-delegation tool is available (Codex `Task`). | Phase 4B: one generic subagent per axis, each carrying its `axis-contracts.md` contract inline. |
| **C: sequential in-agent** | Neither named agents nor generic delegation is available (delegation unsupported / disabled, or concurrency exhausted / repeated dispatch failure). | Phase 4C: run the axes one at a time in the current agent, following each `axis-contracts.md` contract. |

Detection is a runtime fact: Claude Code registers `agents/*.md` as plugin subagents (Path A); Codex exposes this skill but cannot register those agent files, so it lands on Path B (generic `Agent` delegation), degrading to Path C only when delegation is unavailable. **Never silently drop an axis because its named agent is missing: switch paths instead.** Tell the user which path you took in one sentence.

### 4. Fan-out dispatch

Run the axes Phase 3 selected via the path Phase 3.5 chose. Always pass the **resolved `$WORKSPACE`** from step 2: never a literal fixed path, otherwise parallel orchestrator runs collide. Drop axis lines when fan-out narrows to a single-axis quick dispatch. `web`/`web-scout` takes `mode` to choose exa-only (quick) vs exa + WebSearch in parallel (deep); the other axes ignore `mode`: their search surface is single-tool by design.

**Wait for every dispatched axis to finish before step 5** on all paths: partial-result synthesis is a regression of the v1 quality bar. A stalled axis is expected to write a `{ "findings": [], "error": "..." }` artifact rather than hang.

#### 4A. Named plugin agents (Path A: Claude Code, unchanged)

For `deep` mode, dispatch all chosen scouts in a single message so they run concurrently:

```text
Agent(subagent_type="scout:github-scout",
      prompt="query=<...>\nworkspace_dir=$WORKSPACE\nartifact_id=01_github")
Agent(subagent_type="scout:hf-scout",
      prompt="query=<...>\nworkspace_dir=$WORKSPACE\nartifact_id=02_hf")
Agent(subagent_type="scout:web-scout",
      prompt="query=<...>\nworkspace_dir=$WORKSPACE\nartifact_id=03_web\nmode=deep")
Agent(subagent_type="scout:docs-scout",
      prompt="query=<...>\nworkspace_dir=$WORKSPACE\nartifact_id=04_docs")
```

For long-running runs (more than ~2 minutes expected per scout), prefer `Agent({...}, {run_in_background: true})` + `Monitor` so the orchestrator can stream progress.

#### 4B. Generic parallel subagents (Path B: Codex)

The named `scout:*-scout` agents do not exist here. Dispatch one **generic** subagent per chosen axis in a single message so they run concurrently. Each task must carry that axis's contract from `references/axis-contracts.md` inline: role, tool order (with documented MCP fallback), the shared query shape, the result-envelope schema, and the reliability rubric, because the generic worker lacks the agent-definition context Path A relies on:

```text
Agent(prompt="""
  You are the GitHub research axis of scout. Contract (from axis-contracts.md):
  - role: repos / code / awesome-lists / issues-PRs
  - tools: date anchor -> gh search repos|code (2-3 variants) -> gh repo view --json ...
  - query=<...>  workspace_dir=$WORKSPACE  artifact_id=01_github
  - write ${workspace_dir}/01_github.json in the shared envelope; url REQUIRED,
    reliability high|medium|low + evidence[]
  - on gh rate-limit/auth error: findings:[] + error, never abort the run
""")
# ...one such task per chosen axis: 02_hf, 03_web (+mode=deep), 04_docs...
```

Pass the resolved `$WORKSPACE` and the same optional inputs Phase 3 selected (`mode=deep` for web). If a generic dispatch fails outright (delegation unsupported / concurrency exhausted), fall to Path C rather than dropping the axis.

#### 4C. Sequential in-agent execution (Path C: no delegation)

When no delegation channel is available, run each chosen axis yourself, one at a time, following its `axis-contracts.md` contract with your own tools (`gh`, `curl` / `uvx hf`, exa / WebSearch, Context7 / DeepWiki). After each axis, write its `${workspace_dir}/${artifact_id}.json` in the shared envelope, then move on. A failed axis writes `findings:[] + error` and you continue: never abandon the remaining axes. This path is slower (no concurrency) but produces byte-identical artifacts, so synthesis is unchanged.

### 5. Synthesis dispatch

Synthesis is runtime-independent: identical merge, dedup, trust ranking, conflict resolution, and report contract on every path. It is strictly read-only on the workspace (never calls exa / gh / HF, never rewrites a sibling artifact). See `references/synthesis-rules.md` for the merge / trust / conflict rules. **Do not skip synthesis just because the named agent is unavailable**: use the in-skill variant. Pick by capability:

#### 5A. Named synthesis-scout (Path A)

After every fan-out scout has written its artifact:

```text
Agent(subagent_type="scout:synthesis-scout",
      prompt="workspace_dir=$WORKSPACE\nquery=<...>\nmode=<quick|deep>\nreport_path=$REPORT")
```

#### 5B. In-skill synthesis (Paths B and C)

`synthesis-scout` is not registerable under Codex. Synthesize in the orchestrator instead: read every `${WORKSPACE}/*.json` in lexical order and apply `references/synthesis-rules.md` (dedup keys, trust rubric, conflict order, coverage / gap detection, recommended-picks) plus the report template in the `synthesis-scout` agent definition, writing `$REPORT`. Under Path B you may hand this to one generic subagent carrying `synthesis-rules.md` inline; the default is to do it directly. Same output either way.

### 6. Return

Surface the resolved `$REPORT` path and top-3 picks to the user. Do not paste the entire report inline unless the user asked for it; the file path is enough for follow-up.

## Quick mode shortcut

For a single-axis query, still allocate the per-run `$WORKSPACE` (so the axis contract is consistent and you can re-run synthesis later). Dispatch just the one axis with a single `artifact_id` **via the Phase 3.5 path** (4A named agent / 4B generic subagent / 4C sequential), then either skip synthesis (read the one artifact yourself for an inline summary) or run synthesis (5A / 5B) for a one-axis report:

```text
# Step 2 already set $WORKSPACE via mktemp.
# Path A (Claude Code):
Agent(subagent_type="scout:<single>-scout",
      prompt="query=<...>\nworkspace_dir=$WORKSPACE\nartifact_id=01_<axis>")
# Path B (Codex): a generic subagent carrying the axis's axis-contracts.md
#   contract inline, writing the same 01_<axis>.json.
# Path C: run the single axis in-agent.

# Then either: orchestrator reads $WORKSPACE/01_<axis>.json directly and
# emits a short Markdown summary (cheaper for trivial queries), OR run synthesis:
#   Path A: Agent(subagent_type="scout:synthesis-scout", ...)
#   Path B/C: in-skill synthesis over $WORKSPACE/*.json per synthesis-rules.md.
```

Do **not** ask the axis to "write findings to stdout": every axis contract is artifact-based; ad-hoc stdout-only mode is not supported.

## Failure handling

- Workspace empty after fan-out → synthesis (named or in-skill) emits an "all axes failed" report; orchestrator surfaces it with `BLOCKED` status and asks the user whether to retry with different axes.
- exa MCP unavailable → the web axis falls back to WebSearch per its `axis-contracts.md` contract; the orchestrator does not need to know. Any axis whose MCP is missing follows its own documented fallback rather than aborting the run.
- One axis errors out → synthesis proceeds with what it has and lists the missing axis in `## Gaps`. A partial axis failure never discards the axes that returned usable evidence.
- Named `scout:*-scout` agents unavailable (Codex) → switch to Path B / C (Phase 3.5); never drop an axis for a missing named agent.
- `synthesis-scout` agent unavailable (Codex) → in-skill synthesis (5B); never skip synthesis.

## Reference files

- `references/agent-routing.md`: full routing matrix (should / should-NOT per axis, near-miss disambiguation vs `scout:ask`, `dev:*`)
- `references/axis-contracts.md`: shared per-axis query shape + result envelope + tool order / fallback / reliability rubric; the SoT the named-agent, generic-agent, and sequential paths all consume
- `references/synthesis-rules.md`: synthesis dedup keys, trust rubric, and conflict resolution order

`axis-contracts.md` is the hub for the rest of `references/`: each axis contract names the per-tool
file it needs (`exa-web-search.md`, `brightdata-guide.md`, `resource-finder.md`, and the API and CLI
files those in turn point at). Follow the chain from the axis you are running rather than reading
the directory front to back — on Paths B and C that chain is the only route to them, because the
`agents/*.md` definitions that also point there are Claude-only.

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
