---
name: session-handoff
description: Use when the user says "session handoff", "wrap up session", "hand off", "handoff summary", "세션 정리", "핸드오프", "인수인계", or wants a structured end-of-session summary before clearing context. Produces a chat-only handoff covering decisions, shipped changes, key files, running state, verification steps, deferrals, and open questions so a fresh agent can continue seamlessly.
---

# Session Handoff

Produce a repeatable end-of-session summary so the user can clear the context and start a fresh agent without losing continuity. The next agent should be able to pick up by reading this summary alone. Invoke it as `/dev:session-handoff`.

This is a **context-handoff artifact**, not a status report. The audience is a future instance of you, not a stakeholder.

## When to invoke

User says: "session handoff", "wrap up session", "hand off", "handoff summary", "let's wrap up", "summarize before I clear", "세션 정리해줘", "인수인계", or any near-equivalent. Also invoke proactively when the user says they are about to clear the context without having run it yet.

## How to produce the summary

1. **Review the full conversation**, not just the last few turns. Handoffs miss things when they only summarize recent context.
2. **Pull state from these sources, in order.** Each source is named by what it is; use whatever surface the current runtime exposes for it.
   - Plan files referenced this session (Claude Code: `~/.claude/plans/`; otherwise the plan path the session named).
   - The task list — any in-progress or pending items (Claude Code: TodoWrite state).
   - Background work you started: background shells (their IDs are load-bearing for the next agent), subagents or teammates still running, workflows in flight.
   - Files created or modified this session — you know what you touched; do not grep to re-discover. Include `.claude/state/*.json` records a skill wrote on your behalf.
   - Remote objects created this session: branches pushed, PRs and issues opened, artifacts published (URLs).
   - Memory or wiki files written or updated (`~/.claude/projects/<project>/memory/`, `.llmwiki/`).
   - Unresolved questions — things you asked the user that never got a clear answer, or things the user asked that got deflected.
3. **Do NOT audit the filesystem.** This is synthesis of what happened in THIS session. No `git log`, no broad file sweeps. If you did not touch it this session, it does not belong here.
4. **Produce the output in chat.** Do not write a file. Do not update memory. Chat-only.

## Output template — use exactly this structure, every time

```
# Session Handoff — <one-line title of what this session was about>

## Where it started
<2-3 sentences: what the user asked for, key framing or constraints that emerged>

## Decisions locked + what shipped
- <decision or change> — <why, and where it lives (absolute path if a file, URL if remote)>
- ...

## Key files for next session
- `<absolute path>` — <why the next agent should read this first>
- Plan file: `<path>` (if a plan drove the session)
- Memory / wiki files touched: `<paths>` (if any)

## Running state
- Background processes: <shell IDs + what they are + how to kill> — or "none"
- Subagents / workflows still running: <names + what they own> — or "none"
- Dev servers / ports: <url + port> — or "none"
- Open worktrees / branches: <paths> — or "none"

## Verification — how to confirm things still work
- `<command>` — <expected outcome>
- ...

## Deferred + open questions
- Deferred: <item> — <why pushed to later>
- Open: <question needing the user's input> — <context>

## Pick up here
<1-2 sentences: the single most likely next action for a fresh agent>
```

## Hard rules

1. **Chat output only.** Never write the handoff to a file. Never update memory from this skill.
2. **Never invent state.** If a section has nothing to report, write "none" — do not omit the section. Structure stability is the whole point.
3. **Absolute paths always.** The next agent may have a different working directory.
4. **If a plan file drove the session, name it first** in "Key files" so the next agent reads it before anything else.
5. **No emojis, no hype, no "great job" summaries.** Terse and concrete — paths, commands, shell IDs, decisions. Match the tone of a seasoned engineer handing off at end-of-shift.
6. **Background work IDs are critical.** If you started any background shells, subagents, or workflows, they must appear in "Running state" with the kill or resume handle — the next agent cannot find them otherwise.
7. **Write the handoff in the language the session used with the user.** The structure and section headings stay as in the template.

## Anti-patterns — do not do these

- Summarizing the last 3 turns and calling it a handoff.
- Listing files by relative path.
- Skipping the "Running state" section because "nothing is running" — write "none" instead.
- Writing the summary to `~/.claude/handoffs/` or any file. This is chat-only by design.
- Adding a "what went well / what went poorly" retrospective. This is not a retro.
- Recommending next steps beyond the single "Pick up here" line. The next agent decides; you just hand off.
