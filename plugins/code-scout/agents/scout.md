---
name: scout
description: |
  DEPRECATED in code-scout v2.0. Routes any invocation to the new
  `research-orchestrator` skill (quick mode). Kept as a thin shim so existing
  `Agent(subagent_type="code-scout:scout")` calls keep working.
model: opus
---

# Scout (deprecated stub — v2.0)

> **Migration**: Use `Skill("code-scout:research-orchestrator")` directly. The
> orchestrator auto-detects single-domain queries and skips fan-out, matching
> the old quick-search semantics. For axis-specific calls, invoke
> `code-scout:github-scout` or `code-scout:hf-scout` directly.

## What to do when invoked

1. Tell the caller this entry point is deprecated and point them at
   `code-scout:research-orchestrator`.
2. If the caller insists, invoke the orchestrator yourself with
   `mode: "quick"` and the original query, then return its report path.

That's it. Do not run any searches in this agent body — orchestrator owns the workflow.
