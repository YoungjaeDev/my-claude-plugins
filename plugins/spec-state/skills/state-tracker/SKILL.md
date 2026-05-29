---
name: state-tracker
description: Use to read or update `.claude/state/spec.json` — the aggregate cache of spec file → linked issue/PR → core description for in-flight and completed work. Single-file entry point for "what's in progress?" at session start. Triggers — "state 갱신", "spec/issue/PR 진행", "what's in flight", "state update".
---

# state-tracker

`.claude/state/spec.json` is a one-file aggregate of the project's spec/issue/PR work pipeline. It exists so an LLM (or human) can answer "what's currently in flight, and against which spec?" with a single `Read` — no `find` over `.claude/spec/` plus per-file frontmatter parse.

> Ships with `spec-state` plugin; install via marketplace. Operates on the current repo's `.claude/state/spec.json`.

## SSOT relationship

| Source | Authority | When it wins |
|--------|-----------|--------------|
| `.claude/spec/*.md` frontmatter (`status:`) | **SSOT** | Always — the spec file is the truth |
| `.claude/state/spec.json` | **aggregate cache** | Faster lookup; if it conflicts with frontmatter, regenerate from frontmatter |

The cache is regeneratable any time via `init` (scan spec dir + frontmatter aggregate). Direct edits are allowed but rare — prefer the 4 ops below.

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

## Operations

### `read` — print current state

1. If `.claude/state/spec.json` does not exist → print empty state (`{ "in_progress": [], "completed": [] }`) and inform the user. Do NOT auto-create; ask if they want `init`.
2. Read and pretty-print. Highlight `in_progress` first.

### `init` — regenerate from spec frontmatter (one-shot)

1. Confirm with user (`AskUserQuestion`) — this overwrites the file. Default: cancel.
2. `find .claude/spec -maxdepth 1 -name '*.md' -not -name '_template.md'`.
3. For each spec file, parse YAML frontmatter (best effort):
   - `status: draft | in-progress | merged` → bucket selection
   - `## Goal` first non-empty line → `description`
   - Optional `issue:` / `pr:` keys → `linked`
4. Write `.claude/state/spec.json` with `schema: 1` and `updated_at` = now.
5. Print summary: `N in-progress, M completed`.

### `start <spec-path> [--issue N] [--pr N]` — mark a spec in-flight

1. Verify the spec file exists.
2. Set the spec's frontmatter `status: in-progress` (do not touch other frontmatter keys).
3. Append the entry to `in_progress` in `state/spec.json`. If an entry with the same `spec:` already exists, update in place (do not duplicate).
4. Update `updated_at`.

### `complete <spec-path> [--merge-sha XXXXXXX]` — move to completed

1. Find the matching `in_progress` entry. If none, abort with explanatory message (the spec may not have been tracked).
2. Move it to `completed`, set `completed_at = today (UTC YYYY-MM-DD)` and `merge_sha` (first 7 chars).
3. Set the spec's frontmatter `status: merged`.
4. Update `updated_at`.

This op is automatically called by `github-dev:post-merge` at the end of the merge workflow when `.claude/state/spec.json` exists.

## LLM autonomy boundaries

| Action | LLM alone | Needs user confirm |
|---|---|---|
| `read` | ✅ | — |
| `init` | ✅ (after confirm) | ✅ once |
| `start <spec>` | ✅ (when entering plan mode / new spec) | — |
| `complete <spec>` | ✅ (when `github-dev:post-merge` chains) | — |
| Rewrite an existing `description` field | ❌ | ✅ |
| Bulk delete `completed` entries | ❌ | ✅ |
| Schema migration | ❌ | ✅ |

## Verification

After any write:
- File parses as JSON (no trailing comma, valid types)
- `updated_at` is current ISO 8601
- `in_progress` and `completed` are disjoint by `spec:` path
- Each entry's `spec:` path actually exists on disk
- `schema: 1` present at top level

## Anti-patterns

- **Auto-create `.claude/state/spec.json` without asking** — the user may not want state tracking in this repo. `read` returns empty + suggests `init` instead.
- **Drift between state.json and spec frontmatter** — if they disagree, frontmatter wins; regenerate the cache.
- **Embed wiki audit events here** — those go in `.llmwiki/wiki/log.md`. This file tracks the work pipeline, not lore.
- **Store free-form notes** — keep `description` to one line. Detail belongs in the spec body.
