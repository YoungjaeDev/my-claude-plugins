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
- `llm-wiki` is independent — wiki lore (`.llmwiki/wiki/log.md`) tracks knowledge events; spec-state tracks the work pipeline.

## Wiring status

The write-side wiring is intentionally asymmetric:

- **`complete` is auto-wired** — `github-dev:post-merge` Step 5.7 fires `complete <spec-path>` after a merge.
- **`start` / `init` are NOT auto-wired** into `resolve-issue` / `decompose-issue`. They run manually, or as part of the `superpowers:writing-plans` chain.

Consequence: `.claude/state/spec.json` stays absent until the first `start` / `init` in a repo. This dormancy is **by design**, not a bug — the cache materializes only once a tracked spec begins, and `complete` no-ops gracefully when the file is absent (see Conditional behavior). There is no overlap with `llm-wiki`: that plugin tracks durable knowledge lore, spec-state tracks transient work-pipeline state.

## Conditional behavior

Safe to install in any repo. Skill operations no-op gracefully when `.claude/state/spec.json` (and `.claude/spec/`) are absent — `read` prints empty state, `init` requires user confirmation.
