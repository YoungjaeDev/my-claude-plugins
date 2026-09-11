# Wiki Log

Append-only event log for the resolved wiki root (`.llmwiki/wiki/`, or a legacy `.claude/wiki/` if that is what the repo has). Each entry under a `## YYYY-MM-DD — <one-line summary>` header. Newest first.

Every `/ingest-finding` run and every `/dev:post-merge` run that executes the wiki ingest step writes a block here **before** touching the page, so `git revert` of the resulting commit cleanly reverses both. (Post-merge skips the ingest — and this log — for trivial merges or when no wiki root resolves.) See `ingest-finding` skill for the diff-log discipline.

---

<!-- New entries go directly under this line -->

## 2026-09-11 — review-loop churn: the stop rule shipped and still did not stop (ingest-finding)

- guards/review-loop-churn.md: rewrote the body as the distilled stop rule (whole-loop churn measurement, defer-floor dependency, enforced cap), compressed both occurrences into `## Evidence`, added PR #223 + issue #225 sources, `last_verified` 2026-09-04 -> 2026-09-11, `sources` 2 -> 4
- index.md: updated the guards hook to the broadened rule
- insight/review-loop-churn.md: graduated (4 promotion criteria met across PR #213 and PR #223)
- insight/index.md: added the entry hook

## 2026-09-04 — bootstrap (bootstrap-wiki)

Re-bootstrapped after the 2026-08 restructure removed the previous tree. Domains: plugins, guards, runtimes. Seeded three pages from the 2.30.0 consolidation work (#213, #214, #216).
