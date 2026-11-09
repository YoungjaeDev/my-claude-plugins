---
name: research-orchestrator
description: "Multi-axis research orchestrator for code, ML, docs, and web sources: routes a query to github/hf/web/docs scouts in parallel, then synthesis-scout dedups, trust-ranks, and writes a Markdown report. Use on /scout:research-orchestrator, 'research X', '리서치해줘', 'best practices for Y', 'compare A vs B', 'deep dive', 'find boilerplate', or to refine prior research. Not for single-repo Q&A (/scout:ask), one-off library docs (context7 MCP), non-code topics (/deep-research), or academic literature — papers, arXiv, citations and literature reviews have no axis here and belong to a dedicated paper-search tool."
---

# Research Orchestrator

The entry point for scout: it picks a mode, fans a code, ML, docs or web query out to up to 4 per-axis scouts, and merges their artifacts into one Markdown report. Read `references/procedure.md` before Phase 0; it holds the Phase 0 modes and the dispatch blocks for every path.

## Scope

- **Route elsewhere**: a PR review to `dev:review-loop`, one question about one repo to `scout:ask`, library API docs alone to the `context7` MCP, academic papers to a paper-search tool, and topics outside code and ML (politics, markets, history, biographies) to `/deep-research`, which the orchestrator never delegates to.
- **Single axis**: a one-axis lookup still runs here; the orchestrator fans out to one scout.
- **Routing matrix**: `references/agent-routing.md` holds the should / should-NOT table and the near-miss cases.

## Inputs and artifacts

- `query` (required): the natural-language research target.
- `mode` (optional): `quick` | `deep`, auto-detected if absent.
- `workspace_dir` (optional): when set, the orchestrator reuses this directory and the caller owns its lifecycle (this enables partial re-execution). When unset, each run gets its own `mktemp` directory.
- `report_path` (optional): defaults to `${workspace_dir}/final_report.md`.
- **Artifacts**: each axis writes `$WORKSPACE/{NN}_{axis}.json` in dispatch order (`01_github`, `02_hf`, `03_web`, `04_docs`); a skipped axis leaves its slot empty. Scouts never talk to each other, and lexical filename order is the merge order.

## Workflow

Ask with `AskUserQuestion` on Claude Code or `request_user_input` on Codex; when neither is available, proceed with the safe default and say so. The two questions are the `.gitignore` append in Phase 2 (default: leave it alone) and a retry after every axis failed (default: no retry).

- **Phase 0, context check**: pick fresh run, partial re-execution of named axes, or fresh re-run on the same workspace by the rules in `references/procedure.md`. Tell the user the mode picked in one sentence so they can correct it.
- **1. Mode detection**: default `quick`. Upgrade to `deep` when the caller passed `mode: "deep"` or the query says 깊이, 심층, 자세히, 비교, 모범사례, deep, thorough, comprehensive, compare, "best practices", "trade-offs" or "vs".

### 2. Workspace setup

```bash
# Per-run isolated workspace — never share a fixed path across runs
# (parallel orchestrator runs would otherwise clobber each other's artifacts).
# Inside a git repo the run lives under the gitignored <repo>/.tmp/research/ so it is
# easy to find and survives the session; outside one, fall back to the system temp dir.
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) && PARENT="$ROOT/.tmp/research" \
  || PARENT="${TMPDIR:-/tmp}/research"
mkdir -p "$PARENT"
WORKSPACE="${workspace_dir:-$(mktemp -d "$PARENT/run.XXXXXXXX")}"
REPORT="${report_path:-${WORKSPACE%/}/final_report.md}"
mkdir -p "$WORKSPACE" "$(dirname "$REPORT")"
```

When the run uses the default workspace inside a repo, `.tmp/` must be gitignored or the run shows up as untracked changes; test it with `git check-ignore -q .tmp/`. When it is not ignored, ask whether to append `.tmp/` to `.gitignore`. A caller-supplied `workspace_dir` or `report_path` is used verbatim and is the caller's to manage, and scouts that download files put them under `$WORKSPACE/dl/<name>`, never a fixed `/tmp` path.

### 3. Axis routing

| Mode | Default fan-out |
|---|---|
| `quick`, GitHub-leaning query | `github-scout` only |
| `quick`, HF-leaning query | `hf-scout` only |
| `quick`, docs question | `docs-scout` only |
| `quick`, web/community question | `web-scout` only |
| `deep` | `github-scout` + `hf-scout` + `web-scout` + `docs-scout` |

### 3.5 Execution capability detection

Pick the execution path once, before dispatch. All three paths consume the query shape and emit the result envelope in `references/axis-contracts.md`, so synthesis and the report are identical on every path. Tell the user the path taken in one sentence.

| Path | Condition | How the axes run |
|---|---|---|
| A: named plugin agents | The `scout:{axis}-scout` subagents are registered (Claude Code with scout installed). | Phase 4A / 5A. Default on Claude Code. |
| B: generic parallel subagents | Named agents are not registerable, but generic delegation is available (Codex). | Phase 4B: one generic subagent per axis, each carrying its contract inline. |
| C: sequential in-agent | No delegation (unsupported, disabled, concurrency exhausted, or repeated dispatch failure). | Phase 4C: the axes run one at a time in the current agent. |

### 4-6. Dispatch, synthesis, return

- **4. Fan-out dispatch**: run the Phase 3 axes through the Phase 3.5 path with the blocks in `references/procedure.md` (4A, 4B, 4C). Pass the resolved `$WORKSPACE` from Phase 2, and drop the axis lines a single-axis quick dispatch does not use. `web-scout` takes `mode` to choose exa-only (quick) or exa + WebSearch in parallel (deep); the other axes ignore it.
- **5. Synthesis dispatch**: Path A runs the named `synthesis-scout` (5A); Paths B and C synthesize in-skill (5B) with the same rules in `references/synthesis-rules.md` and the report template in this plugin's `agents/synthesis-scout.md`. Synthesis is read-only on the workspace: it never calls exa, gh or HF and never rewrites a sibling artifact.
- **6. Return**: surface the resolved `$REPORT` path, the resolved `$WORKSPACE` path and the top-3 picks. Paste the whole report inline only when the user asked for it.

## Bright lines

- Never pass a literal fixed workspace path to an axis; always the resolved `$WORKSPACE`, or parallel runs collide.
- Wait for every dispatched axis to finish before synthesis on every path. A stalled axis writes `{ "findings": [], "error": "..." }` instead of hanging.
- Never drop an axis because its named agent is missing: switch to Path B or C.
- Never skip synthesis because `synthesis-scout` is missing: use in-skill synthesis (5B).
- Never ask an axis to write findings to stdout; every axis contract is artifact-based.

## Failure handling

- **Workspace empty after fan-out**: synthesis emits an "all axes failed" report; surface it with `BLOCKED` status and ask whether to retry with different axes.
- **An MCP is missing** (e.g. exa): that axis follows its own documented fallback in `references/axis-contracts.md`; the run does not abort.
- **One axis errors out**: synthesis proceeds with the rest and lists the missing axis under `## Gaps`. A partial failure never discards the axes that returned usable evidence.

## Done

- The report exists at `$REPORT` (or the all-axes-failed report was surfaced as `BLOCKED`).
- The user has the report path, the workspace path and the top-3 picks.
- The user was told the Phase 0 mode and the Phase 3.5 execution path.

## References

- `references/procedure.md`: Phase 0 modes, the 4A/4B/4C dispatch blocks, 5A/5B synthesis, the quick-mode shortcut.
- `references/axis-contracts.md`: the shared query shape, result envelope and per-axis contracts. It is the hub for the rest of `references/`: each axis contract names the per-tool file it needs, and on Paths B and C that chain is the only route to them.
- `references/agent-routing.md` (routing) and `references/synthesis-rules.md` (dedup, trust, conflicts).
