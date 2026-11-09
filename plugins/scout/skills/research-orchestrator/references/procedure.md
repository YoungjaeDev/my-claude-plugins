# Research orchestrator procedure

Step detail for `research-orchestrator`, keyed by the phase numbers in its SKILL.md: the Phase 0 modes, the dispatch blocks for Paths A, B and C, the two synthesis variants and the single-axis shortcut. The bright lines stay in SKILL.md; this file holds the call shapes.

## Phase 0: Context check

Inspect the caller-supplied `workspace_dir` before mode detection.

- **Fresh run** (no `workspace_dir`, or the directory is missing): proceed to Phase 1; Phase 2 creates a new `mktemp` directory.
- **Partial re-execution** (existing `workspace_dir` and the user asks to refine one axis, e.g. "github 결과만 다시"): keep the directory, dispatch only the named scout(s) with the existing `artifact_id` (they overwrite their slot), then re-run synthesis on the merged set.
- **Fresh re-run on the same workspace** (existing `workspace_dir` and the user asks to redo the whole query): move the old directory to `${workspace_dir}_prev.$(date +%s)` for audit, then create a new one at the same path.

## 4A. Named plugin agents (Path A: Claude Code)

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

For long runs (more than about 2 minutes expected per scout), prefer `Agent({...}, {run_in_background: true})` + `Monitor` so the orchestrator can stream progress.

## 4B. Generic parallel subagents (Path B: Codex)

The named `scout:*-scout` agents do not exist here. Dispatch one generic subagent per chosen axis in a single message so they run concurrently. Each task carries that axis's contract from `axis-contracts.md` inline (role, tool order with its MCP fallback, the shared query shape, the result envelope and the reliability rubric), because the generic worker lacks the agent definition Path A relies on:

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

Pass the resolved `$WORKSPACE` and the same optional inputs Phase 3 selected (`mode=deep` for web). If a generic dispatch fails outright (delegation unsupported, concurrency exhausted), fall to Path C rather than dropping the axis.

## 4C. Sequential in-agent execution (Path C: no delegation)

- Run each chosen axis yourself, one at a time, following its `axis-contracts.md` contract with your own tools (`gh`, `curl` / `uvx hf`, exa / WebSearch, Context7 / DeepWiki).
- After each axis, write its `${workspace_dir}/${artifact_id}.json` in the shared envelope, then move on.
- A failed axis writes `findings:[] + error` and the run continues with the remaining axes. This path is slower but produces the same artifacts, so synthesis is unchanged.

## 5A. Named synthesis-scout (Path A)

After every fan-out scout has written its artifact:

```text
Agent(subagent_type="scout:synthesis-scout",
      prompt="workspace_dir=$WORKSPACE\nquery=<...>\nmode=<quick|deep>\nreport_path=$REPORT")
```

## 5B. In-skill synthesis (Paths B and C)

`synthesis-scout` is not registerable under Codex, so the orchestrator synthesizes itself.

- Read every `${WORKSPACE}/*.json` in lexical order, apply `synthesis-rules.md` (dedup keys, trust rubric, conflict order, gap detection, recommended picks) and the report template in this plugin's `agents/synthesis-scout.md`, and write `$REPORT`.
- Under Path B this may go to one generic subagent carrying `synthesis-rules.md` inline; the default is to do it directly. The output is the same either way.

## Quick mode shortcut

For a single-axis query, still allocate the per-run `$WORKSPACE` so the axis contract holds and synthesis can run later. Dispatch the one axis with a single `artifact_id` through the Phase 3.5 path, then either read the one artifact for an inline summary or run synthesis for a one-axis report:

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
