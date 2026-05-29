# Wiki Log

Append-only event log for the resolved wiki root (`.llmwiki/wiki/`, or a legacy `.claude/wiki/` if that is what the repo has). Each entry under a `## YYYY-MM-DD — <one-line summary>` header. Newest first.

Every `/ingest-finding` and `/post-merge-wiki` run writes a block here **before** touching the page, so `git revert` of the resulting commit cleanly reverses both. See `ingest-finding` skill for the diff-log discipline.

---

<!-- New entries go directly under this line -->

## 2026-05-29 — post-merge #28 (post-merge-wiki)

Diff log written before applying the page edit (git-revertible). Merge SHA `62315ed` — feat(github-dev): post-merge Step 5.8 conditional wiki ingest chain.

- llm-wiki-design/post-merge-trigger.md: new page (id `post-merge-trigger`, status active, volatility stable, sources 2) — post-merge-wiki has two complementary triggers: github-dev:post-merge Step 5.8 (conditional soft-dependency, mirrors the spec-state Step 5.7 pattern, covers GitHub-UI merges) + the wiki_post_commit_hint.sh PostToolUse hook (local CLI merge commits only). `> See-also: [[curated-conservative]]`.
- index.md: added the post-merge-trigger hook under the `## llm-wiki-design` domain section; MOC `last_verified:` kept 2026-05-29.
- Evidence (in-diff, from `git show --name-only`): `plugins/github-dev/commands/post-merge.md` (Step 5.8). Complementary pre-existing source: `plugins/llm-wiki/hooks/wiki_post_commit_hint.sh`.

## 2026-05-29 — ingest v2 design record: 4 pages (ingest-finding)

Diff log written before applying the page edits (git-revertible).

- llm-wiki-design/curated-conservative.md: new page (id `curated-conservative`, status active, volatility stable, sources 2) — hub thesis: harvest the git-auditable kernel of each rohitg00-v2 idea, reject the heavyweight parts; adopted vs rejected lists.
- llm-wiki-design/neutral-llmwiki-root.md: new page (id `neutral-llmwiki-root`, status active, volatility stable, sources 2) — `.llmwiki/` neutral root defeats the codex-bridge `.claude/`->`.codex/` body-transform fork; schema stays at `.claude/rules/`; resolution order. `> Refines: [[curated-conservative]]`.
- llm-wiki-design/volatility-over-decay.md: new page (id `volatility-over-decay`, status active, volatility stable, sources 2) — discrete `volatility:` class + fixed window replaces Ebbinghaus decay; old is not stale. `> Refines: [[curated-conservative]]`, `> See-also: [[provenance-over-confidence]]`.
- llm-wiki-design/provenance-over-confidence.md: new page (id `provenance-over-confidence`, status active, volatility stable, sources 2) — `sources: N` + named `## Sources` replaces float confidence. `> Refines: [[curated-conservative]]`, `> See-also: [[volatility-over-decay]]`.
- index.md: MOC `last_verified:` set to 2026-05-29; added `## llm-wiki-design` domain section with the 4 page hooks.
- Raw evidence cited: `.llmwiki/raw/rohitg00-llm-wiki-v2-gist.md`, `.llmwiki/raw/karpathy-llm-wiki-gist.md`, `.llmwiki/raw/perplexity-llm-wiki-survey-2026-05.md`, plus `.claude/spec/2026-05-29-llm-wiki-v2.md`.

## 2026-05-29 — bootstrap llm-wiki-design domain (bootstrap-wiki)

- llm-wiki-design/: domain directory established under `.llmwiki/wiki/` (2-depth domain/page layout) to hold the v2 design record.
