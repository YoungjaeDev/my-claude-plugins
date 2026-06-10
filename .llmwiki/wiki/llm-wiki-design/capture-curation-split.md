---
id: capture-curation-split
aliases: [session-capture-drain, stop-capture-sessionstart-drain, wiki-auto-trigger]
last_verified: 2026-06-10
status: active
volatility: stable
sources: 2
---

# Capture/curation split

llmwiki auto-ingest is split into two halves that run at **different session
boundaries** by **different actors**: a mechanical *capture* (shell hook, at
session end) and an LLM *curation* (a turn, on the next session start). The
split is the design's load-bearing idea — collapsing it back into one step is
what every naive "just auto-update the wiki on a hook" attempt gets wrong.

## The two halves

- **Capture — `wiki_session_capture.sh` (Stop hook).** At session end it scans
  the transcript for ingest signals (merge / debugging-conclusion / decision)
  and, if any cross threshold, writes a per-session pointer file
  `<wiki-root>/.staging/pending-<sid>.md`. It records *that there is something to
  ingest and where the evidence lives* (the transcript) — it does **not** touch
  any wiki page.
- **Curation — `wiki_session_start_drain.sh` (SessionStart hook).** On the next
  session it surfaces prior sessions' pending captures as a strong
  `ingest-finding` directive. An LLM turn then reads the transcript, dedups
  against existing pages, resolves conflicts, and consumes (deletes) the staging
  file.

## Why split it

A shell hook **cannot dedup or resolve conflicts** — that needs an LLM reading
the transcript against the existing wiki. So the hook deliberately does only the
half a shell is good at (detect a signal, drop a pointer) and defers all
judgment to a curation turn. Two consequences follow:

- **Over-capture is safe.** The capture side can be liberal because the
  `ingest-finding` dedup gate on the curation side absorbs duplicates, and
  staging touches no wiki page — a false capture costs one throwaway pointer
  file, never a bad edit.
- **Idempotent capture.** The per-session staging file is *regenerated* (not
  appended) across the many Stop firings, guarded by rate-limit markers
  (90s/900s via `cksum` + BSD/GNU `stat`/`date` fallbacks), so repeated Stops
  don't pile up.

## Honest limitation

Fully unattended, *instant* ingest is impossible with a shell hook alone: if the
next session never opens, the staging pointer just accumulates (the
`wiki_session_start_lint_hint` / lint flags it). The split buys autonomy at the
cost of a one-session latency — capture is immediate, curation waits for the
next turn. This is the session-boundary **third path** to the wiki, complementing
the two merge-driven paths.

## Sources

- `plugins/llm-wiki/hooks/wiki_session_capture.sh` — Stop-hook mechanical capture
  (signal scan, per-session staging pointer, idempotent regeneration).
- `plugins/llm-wiki/hooks/wiki_session_start_drain.sh` — SessionStart drain that
  injects the `ingest-finding` directive for pending captures.

> See-also: [[post-merge-trigger]]
> See-also: [[curated-conservative]]
> Evidence: plugins/llm-wiki/hooks/wiki_session_capture.sh
