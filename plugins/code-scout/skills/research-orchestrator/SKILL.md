---
name: research-orchestrator
description: |
  Multi-axis research orchestrator for code, ML, docs, web, and academic-paper
  sources. Routes a natural-language query to one or more specialized scouts
  (github, hf, web, docs, paper) in parallel, then runs synthesis-scout to dedup,
  trust-rank, and emit a final Markdown report. Use when the user asks "research
  X", "find best practices for Y", "compare A vs B", "what's the consensus on Z",
  wants a cross-source technical brief, or asks to refine prior research.
  Triggers — "research", "조사해줘", "조사", "보완", "재실행", "업데이트",
  "best practices", "compare frameworks", "deep dive", "find boilerplate",
  "follow up". Do NOT trigger for single-repo GitHub PR/issue work (github-dev),
  single repo Q&A (deepwiki:ask), one-off library docs (context7 MCP),
  single-paper download (paper-search-tools), or general non-code/ML topics like
  politics / market / history (use /deep-research). Full routing in the body.
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
- The user wants to ask a single question about one repo → `deepwiki:ask` directly
- The user wants to read library API docs only → `context7` MCP directly
- The user wants a single paper's PDF or full text → `paper-search-tools` `download_*` / `read_*` directly (paper-scout is metadata-only)
- The user's query is **outside the code / ML domain** (politics, market, history, biographies, general policy) → `/deep-research` directly. Its 7-phase + adversarial verify + state-machine flow is tuned for generic topics; code-scout's 5-axis routing is tuned for code/ML and would mis-route on those queries. Orchestrator does **not** delegate to `/deep-research` — the boundary is intentional.

See `references/agent-routing.md` for the full should / should-NOT matrix.

## Inputs

- `query` (required) — user's natural-language research target
- `mode` (optional) — `quick` | `deep`; auto-detected if absent
- `workspace_dir` (optional) — when set, the orchestrator reuses this directory and the caller owns lifecycle (enables partial re-execution; see Phase 0 below). When unset, each run gets its own `mktemp` directory.
- `report_path` (optional) — defaults to `${workspace_dir}/final_report.md`

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
| `quick`, academic / arxiv / SOTA / DOI / benchmark | `paper-scout` only |
| `deep`, no academic signal | `github-scout` + `hf-scout` + `web-scout` + `docs-scout` (4-axis) |
| `deep`, with academic signal | above + `paper-scout` (5-axis) |

Assign sequential `artifact_id` slots in dispatch order: `01_github`, `02_hf`, `03_web`, `04_docs`, `05_paper`. Skipped axes leave their slot unallocated; synthesis-scout's `find` enumeration handles sparse workspaces deterministically.

Academic signal triggers: "paper", "arxiv", "preprint", "DOI", "SOTA", "benchmark paper", "citation", "venue", "ICML", "NeurIPS", "ICLR", "CVPR", "ACL", "EMNLP", "RSA", "Crypto", "PubMed", "bioRxiv", and Korean equivalents (논문, 인용, 학회, 저널).

### 4. Fan-out dispatch

For `deep` mode, dispatch all chosen scouts in a single message so they run concurrently. Always pass the **resolved `$WORKSPACE`** from step 2 — never the literal `/tmp/research/_workspace` string, otherwise parallel orchestrator runs collide:

```text
Agent(subagent_type="code-scout:github-scout",
      prompt="query=<...>\nworkspace_dir=$WORKSPACE\nartifact_id=01_github")
Agent(subagent_type="code-scout:hf-scout",
      prompt="query=<...>\nworkspace_dir=$WORKSPACE\nartifact_id=02_hf")
Agent(subagent_type="code-scout:web-scout",
      prompt="query=<...>\nworkspace_dir=$WORKSPACE\nartifact_id=03_web\nmode=deep")
Agent(subagent_type="code-scout:docs-scout",
      prompt="query=<...>\nworkspace_dir=$WORKSPACE\nartifact_id=04_docs")
Agent(subagent_type="code-scout:paper-scout",
      prompt="query=<...>\nworkspace_dir=$WORKSPACE\nartifact_id=05_paper")
```

Drop the `paper-scout` line in deep dispatches with no academic signal; drop other lines accordingly when fan-out narrows. `web-scout` uses `mode` to decide between exa-only (quick) and exa + WebSearch in parallel (deep). The other scouts ignore `mode` — their search surface is single-tool by design.

For long-running runs (more than ~2 minutes expected per scout), prefer `Agent({...}, {run_in_background: true})` + `Monitor` so the orchestrator can stream progress.

**Wait for every dispatched scout to complete before step 5** — partial-result synthesis is a regression of the v1 quality bar. If a scout times out, it is expected to write a `{ "findings": [], "error": "..." }` artifact rather than hang.

### 5. Synthesis dispatch

After every fan-out scout has written its artifact:

```text
Agent(subagent_type="code-scout:synthesis-scout",
      prompt="workspace_dir=$WORKSPACE\nquery=<...>\nmode=<quick|deep>\nreport_path=$REPORT")
```

Synthesis is strictly read-only on the workspace — it cannot call exa, gh, or HF tools. See `references/synthesis-rules.md` for the merge / trust / conflict rules synthesis-scout follows.

### 6. Return

Surface the resolved `$REPORT` path and top-3 picks to the user. Do not paste the entire report inline unless the user asked for it — the file path is enough for follow-up.

## Quick mode shortcut

For a single-axis query, still allocate the per-run `$WORKSPACE` (so the scout's contract is consistent and you can re-run synthesis later). Dispatch just the one scout with a single `artifact_id`, then either skip synthesis (read the one artifact yourself for an inline summary) or dispatch synthesis-scout for a one-axis report:

```text
# Step 2 already set $WORKSPACE via mktemp.
Agent(subagent_type="code-scout:<single>-scout",
      prompt="query=<...>\nworkspace_dir=$WORKSPACE\nartifact_id=01_<axis>")

# Then either: orchestrator reads $WORKSPACE/01_<axis>.json directly and
# emits a short Markdown summary (cheaper for trivial queries), OR:
Agent(subagent_type="code-scout:synthesis-scout",
      prompt="workspace_dir=$WORKSPACE\nquery=<...>\nmode=quick\nreport_path=$REPORT")
```

Do **not** ask the scout to "write findings to stdout" — every scout's contract is artifact-based; ad-hoc stdout-only mode is not supported.

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

## Test scenarios

### Normal flow — deep mode, all axes healthy

1. User: "Compare vLLM vs TGI for production serving"
2. Phase 0: no `workspace_dir` supplied → fresh run.
3. Phase 2 creates `$PARENT/run.AbCd1234/`.
4. Phase 4 dispatches 4 scouts in parallel; each writes its `{NN}_{axis}.json` in 30-90s.
5. Phase 5 invokes synthesis-scout; it sorts artifacts, dedups (vLLM repo appears in both github + web → merged), trust-ranks, emits `final_report.md` with Recommended Picks + Conflicts table.
6. Phase 6 surfaces the report path and top-3 picks. Exit clean.

**Expected stdout:** `report_path=/tmp/research/run.AbCd1234/final_report.md mode=deep sources_merged=4 conflicts=1`.

### Error flow — one axis errors, partial re-execution

1. User: "Research RAG eval frameworks 2026" → fresh deep run as above.
2. `web-scout` returns an exa-quota error and writes `03_web.json` with `findings: []` + `error: "exa quota exhausted"`.
3. Synthesis still produces a report but adds `## Gaps` noting the missing web axis.
4. User: "이전 결과의 web 축만 다시 돌려줘 — exa quota 풀렸음"
5. Phase 0 detects existing `workspace_dir` + axis-specific refinement → partial re-execution mode.
6. Only `web-scout` is re-dispatched with `artifact_id=03_web` (overwriting the previous error artifact).
7. synthesis-scout re-runs on the merged set; `## Gaps` disappears from the new report.

**Expected behavior:** existing `01_github.json`, `02_hf.json`, `04_docs.json` are untouched; only `03_web.json` is rewritten; final report regenerated.
