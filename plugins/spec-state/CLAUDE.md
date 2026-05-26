# spec-state

Single-file aggregate cache for a repo's spec → issue → PR work pipeline. One `Read` on `.claude/state/spec.json` answers "what's currently in flight, and against which spec?" — no `find` over `.claude/spec/` plus per-file frontmatter parse.

## What it ships

| Component | Path | Purpose |
|-----------|------|---------|
| **state-tracker skill** | `skills/state-tracker/` | 4 ops on `.claude/state/spec.json`: read / init / start / complete |

No hooks. Pure on-demand skill. Safe to install globally — operations only run when invoked.

## SSOT relationship

| Source | Authority | When it wins |
|--------|-----------|--------------|
| `.claude/spec/*.md` frontmatter (`status:`) | **SSOT** | Always — the spec file is the truth |
| `.claude/state/spec.json` | **aggregate cache** | Faster lookup; if it conflicts with frontmatter, regenerate via `init` |

Cache is regeneratable any time. Direct JSON edits are allowed but rare — prefer the 4 ops.

## Schema (versioned JSON)

```json
{
  "schema": 1,
  "updated_at": "<ISO 8601>",
  "in_progress": [
    {
      "spec": ".claude/spec/<YYYY-MM-DD>-<slug>.md",
      "section": "<spec internal anchor, optional>",
      "linked": { "issue": <number or null>, "pr": <number or null> },
      "description": "<spec 'Goal' first line, or user-provided one-liner>"
    }
  ],
  "completed": [
    {
      "spec": ".claude/spec/<YYYY-MM-DD>-<slug>.md",
      "linked": { "issue": <number or null>, "pr": <number or null> },
      "description": "<same as above>",
      "completed_at": "<YYYY-MM-DD>",
      "merge_sha": "<short SHA, 7 chars>"
    }
  ]
}
```

## Relation to other plugins

- `github-dev:post-merge` auto-calls `complete <spec-path>` after a merge to update the cache.
- `llm-wiki` is independent — wiki lore (`.claude/wiki/log.md`) tracks knowledge events; spec-state tracks the work pipeline.

## Conditional behavior

Safe to install in any repo. Skill operations no-op gracefully when `.claude/state/spec.json` (and `.claude/spec/`) are absent — `read` prints empty state, `init` requires user confirmation.
