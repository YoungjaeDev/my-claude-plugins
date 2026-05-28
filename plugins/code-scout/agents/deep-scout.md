---
name: deep-scout
description: |
  DEPRECATED in code-scout v2.0. Routes any invocation to the new
  `research-orchestrator` skill (deep mode). Kept as a thin shim so existing
  `Agent(subagent_type="code-scout:deep-scout")` calls keep working.
model: opus
---

# Deep Scout (deprecated stub — v2.0)

> **Migration**: Use `Skill("code-scout:research-orchestrator")` directly. The
> orchestrator detects "deep" / "thorough" / "comprehensive" keywords and
> auto-selects deep mode (multi-axis fan-out → synthesis-scout). For
> targeted axis calls, invoke `code-scout:github-scout`,
> `code-scout:hf-scout`, `code-scout:web-scout`, `code-scout:docs-scout`,
> or `code-scout:synthesis-scout` directly.

## What to do when invoked

1. Tell the caller this entry point is deprecated and point them at
   `code-scout:research-orchestrator`.
2. If the caller insists, invoke the orchestrator yourself with
   `mode: "deep"` and the original query, then return its report path.

That's it. Do not orchestrate fan-out here — the orchestrator skill owns
routing, workspace setup, and synthesis dispatch.
