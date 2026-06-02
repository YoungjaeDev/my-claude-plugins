# Wiki Log

Append-only event log for the resolved wiki root (`.llmwiki/wiki/`, or a legacy `.claude/wiki/` if that is what the repo has). Each entry under a `## YYYY-MM-DD — <one-line summary>` header. Newest first.

Every `/ingest-finding` and `/github-dev:post-merge` run writes a block here **before** touching the page, so `git revert` of the resulting commit cleanly reverses both. See `ingest-finding` skill for the diff-log discipline.

---

<!-- New entries go directly under this line -->
