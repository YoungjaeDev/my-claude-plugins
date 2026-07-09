---
id: subagentstop-hook-payload
aliases: [subagent-stop-payload, agent-transcript-path, subagentstop-transcript, subagent-capture]
last_verified: 2026-07-09
status: active
volatility: volatile
sources: 1
---

# SubagentStop hook payload contract

Claude Code's `SubagentStop` hook fires when a `Task`/subagent stops. Its stdin
JSON carries the fields needed to capture the subagent's work — but the official
docs (`code.claude.com/docs/en/hooks`) are **silent on the two facts that decide
whether a capture hook reads the right transcript**, so they were verified
empirically (dispatch a real subagent, dump the hook stdin).

## The two docs-silent facts

- **`transcript_path` and `session_id` are the PARENT session's**, not the
  subagent's. A `SubagentStop` fired for a subagent reports the parent's
  `session_id` (same value the parent's `Stop` sees) and a `transcript_path`
  pointing at the parent session transcript. Scanning `transcript_path` on
  `SubagentStop` therefore duplicates what the main `Stop` capture already sees.
- **The subagent's own transcript is under `agent_transcript_path`**, at
  `<project>/subagents/agent-<agent_id>.jsonl`. It is written and present **at
  fire time** (verified: an `Explore` subagent's file was 68 KB, a
  `claude-code-guide` subagent's 116 KB, both on disk when the hook ran). An
  internal/synthetic subagent (empty `agent_type`) may have no persisted
  transcript — then the path names a missing file and a capture should no-op
  rather than fall back to the redundant parent.

## Full field set

`session_id` (parent's), `transcript_path` (parent's), `agent_transcript_path`
(subagent's own), `agent_id`, `agent_type` (the typed name — `Explore`,
`claude-code-guide`, plugin-scoped; empty for internal agents),
`last_assistant_message`, `cwd`, `hook_event_name`, `prompt_id`,
`stop_hook_active`. `matcher: ""` matches every `SubagentStop`; a type-specific
matcher (e.g. `"Explore"`) fires only for that agent type.

## Design implication (for a capture hook)

To capture the delegated-task lore the main `Stop` never sees:

1. **Prefer `agent_transcript_path`** over `transcript_path` when present — read
   the subagent's own transcript, not the parent's.
2. **Key staging files + rate-limit markers by `agent_id`** — `session_id` is the
   parent's, so an unkeyed capture collides with (overwrites / rate-limits) the
   parent `Stop` capture.
3. Wire the same capture hook to both `Stop` and `SubagentStop` (matcher `""`).

This is what `plugins/llm-wiki/hooks/wiki_session_capture.sh` does (keyed
`pending-<sid>-<agent_id>.md`). The plan that preceded the fix assumed
`agent_transcript_path` was merely an alternate *name* for the same transcript (a
fallback); the live payload disproved that — both fields exist and point at
*different* transcripts.

## Sources

- Empirical probe, 2026-07-09: a `SubagentStop` hook dumped the raw stdin for a
  real `Explore` and a `claude-code-guide` subagent dispatch; field values +
  on-disk transcript sizes observed directly. Official docs
  (`code.claude.com/docs/en/hooks`) confirm the field *names* but are silent on
  transcript target + session_id ownership.

> See-also: [[capture-curation-split]]
> Evidence: plugins/llm-wiki/hooks/wiki_session_capture.sh
