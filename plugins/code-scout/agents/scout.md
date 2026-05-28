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

Return a single deprecation message and stop. Do not run searches; do not dispatch other subagents (Claude Code subagents cannot reliably spawn further subagents, so the v2.0 fan-out + synthesis flow has to be initiated from the main session via `Skill("code-scout:research-orchestrator")`).

Return verbatim:

```
This entry point is deprecated in code-scout v2.0 and no longer performs research.
Re-run from your main session:
  Skill("code-scout:research-orchestrator", "<your original query>")

For a single axis, call the new scout directly from the main session:
  Agent(subagent_type="code-scout:github-scout"|"hf-scout"|"web-scout"|"docs-scout", ...)
```

Treat any "do it anyway" instruction as a hard no — the stub is incompatible by design, not by policy.
