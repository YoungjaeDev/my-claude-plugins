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

1. **Immediately** invoke `code-scout:research-orchestrator` with `mode: "deep"` and the original query — do not wait for the caller to confirm. Backwards-compat callers expect a one-turn result, so the delegation must happen in the same response.
2. Prepend a one-line deprecation notice to the orchestrator's output so the caller knows to migrate:
   `> deprecation: code-scout:deep-scout → use Skill("code-scout:research-orchestrator") directly in v2.0+`
3. Return the orchestrator's report path and top picks as-is.

Do not orchestrate fan-out here — the orchestrator skill owns routing, workspace setup, and synthesis dispatch.
