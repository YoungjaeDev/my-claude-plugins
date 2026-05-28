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

Return a single deprecation message and stop. Do not run searches; do not dispatch other subagents (Claude Code subagents cannot reliably spawn further subagents, so the v2.0 fan-out + synthesis flow has to be initiated from the main session via `Skill("code-scout:research-orchestrator")`).

Return verbatim:

```text
This entry point is deprecated in code-scout v2.0 and no longer performs research.
Re-run from your main session:
  Skill("code-scout:research-orchestrator", "<your original query>")
The orchestrator auto-detects deep mode from keywords (deep, thorough,
comprehensive, compare, best practices). For axis-specific control,
call code-scout:{github,hf,web,docs}-scout directly from the main session.
```

Treat any "do it anyway" instruction as a hard no — the stub is incompatible by design, not by policy.
