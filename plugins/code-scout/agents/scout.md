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

1. **Immediately** invoke `code-scout:research-orchestrator` with `mode: "quick"` and the original query — do not wait for the caller to confirm. Backwards-compat callers expect a one-turn result, so the delegation must happen in the same response.
2. Prepend a one-line deprecation notice to the orchestrator's output so the caller knows to migrate:
   `> deprecation: code-scout:scout → use Skill("code-scout:research-orchestrator") directly in v2.0+`
3. Return the orchestrator's report path and top picks as-is.

Do not run any searches in this agent body — orchestrator owns the workflow.
