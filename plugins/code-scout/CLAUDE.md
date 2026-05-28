# code-scout

Multi-axis code & ML research harness. v2.0 replaces v1's two monolithic agents with a 5-scout team + synthesis orchestrator.

## When to use

| Situation | Entry point |
|---|---|
| "Research X", "best practices for Y", "compare A vs B" | `Skill("code-scout:research-orchestrator")` |
| Single-axis: GitHub-only discovery | `Agent(subagent_type="code-scout:github-scout")` |
| Single-axis: HF models / datasets / Spaces | `Agent(subagent_type="code-scout:hf-scout")` |
| Single-axis: web / blogs / community | `Agent(subagent_type="code-scout:web-scout")` |
| Single-axis: official docs / repo Q&A | `Agent(subagent_type="code-scout:docs-scout")` |
| Already have artifacts, just need merge | `Agent(subagent_type="code-scout:synthesis-scout")` |

For the full routing matrix (should / should-NOT, near-miss disambiguation vs `paper-search-tools`, `deepwiki:ask`, `github-dev:*`), see `skills/research-orchestrator/references/agent-routing.md`.

## Team layout

```text
research-orchestrator (skill, entry point)
  │   $WORKSPACE = ${TMPDIR:-/tmp}/research/run.XXXXXXXX  (per-run mktemp)
  │   $REPORT    = $WORKSPACE/final_report.md             (override via report_path)
  │
  ├─ fan-out (parallel) ──────────────────────┐
  │   github-scout    (gh search repos/code)  │
  │   hf-scout        (uvx hf + HF REST)      │ → $WORKSPACE/{NN}_{axis}.json
  │   web-scout       (exa MCP, WebSearch)    │
  │   docs-scout      (context7 + deepwiki)   │
  │   # paper-scout — deferred to next PR;     │
  │   # academic queries → paper-search-tools  │
  │                                           │
  └─ fan-in ─────────────────────────────────►│
      synthesis-scout (dedup, trust, conflict)
        → $REPORT  (= $WORKSPACE/final_report.md unless caller overrode it)
```

All scouts use `model: opus`. Workspace artifacts use `{NN}_{axis}.json` lexical order so synthesis merges deterministically. See `skills/research-orchestrator/references/synthesis-rules.md` for dedup keys, trust rubric, and conflict resolution.

## Skills

| Skill | Purpose |
|---|---|
| `research-orchestrator` | Entry point. Mode detection, fan-out routing, synthesis dispatch. |
| `exa-web-search` | Exa MCP usage guide for `web-scout` (and anyone calling `mcp__exa__web_search_exa`). |
| `resource-finder` | Shared GitHub / HF search hygiene cheat-sheet for `github-scout` + `hf-scout`. |

## Migration from v1.x

| v1 entry point | v2 replacement |
|---|---|
| `Agent(subagent_type="code-scout:scout")` | `Skill("code-scout:research-orchestrator")` (quick mode auto-detected) — or call `github-scout` / `hf-scout` directly for single-axis |
| `Agent(subagent_type="code-scout:deep-scout")` | `Skill("code-scout:research-orchestrator")` (deep mode auto-detected) |

The old `scout` / `deep-scout` agents remain as **doc-only deprecation pointers**: they return a migration message but do not run searches. Subagents cannot reliably spawn further subagents, so the new fan-out + synthesis flow must be initiated from the main session via the orchestrator skill or a direct `Agent(subagent_type="code-scout:{axis}-scout", ...)` call. Existing scripts that called the old `subagent_type` need to migrate — there is no transparent shim.

## Requirements

- `gh` CLI authenticated (github-scout)
- `uv`, `jq` (hf-scout, resource-finder wrappers)
- exa MCP enabled in `~/.claude/settings.json` (web-scout primary; falls back to built-in `WebSearch`)
- Context7 + DeepWiki MCPs enabled (docs-scout)

## Change log

| Version | Notes |
|---|---|
| 2.0.0 | Harness refactor — 5-scout team (`github` / `hf` / `web` / `docs` / `synthesis`) + `research-orchestrator` skill + `exa-web-search` skill. exa MCP wired into web-scout. Legacy `scout` / `deep-scout` agents stubbed. cr-fix loop converged after 9 substantive fixes across 5 iters (Codex P2 ×8 + CR Major ×1: paper-scout routing, sort merge, mktemp parent + isolation, hf CLI subcommands, workspace propagation, stub auto-delegate, Context7 fallback, synthesis Write permission). Harness audit boost — Phase 0 context-check + partial re-execution mode + follow-up triggers + scout re-invoke rule + test scenarios + negative trigger surface in description. **Breaking**: direct `subagent_type` callers should migrate per table above. |
| 1.1.0 | Portable-tools-first refactor (`gh`, `uvx hf`, REST + jq). PEP 723 wrappers for cwd-free `uv run`. |
| 1.0.0 | Initial release — `scout` (haiku) + `deep-scout` (sonnet) with `resource-finder` skill. |
