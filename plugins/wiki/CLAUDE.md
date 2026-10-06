# wiki

Outside-knowledge wiki for any repo: facts about what the repo does not control (platforms, vendors, customers, the domain), whether they came in as a document or were learned while working. Decisions live in `docs/adr/`, terms in `GLOSSARY.md`, and repeated mistakes become `/retro` checks; the wiki takes none of those (ADR 0003).

No hooks, no scripts. Every skill is plain prose that runs the same in Claude Code and Codex.

## Skills

| Skill | Role |
|-------|------|
| `ingest` | The only writer. Saves originals to `raw/`, creates or updates concept pages, updates `index.md` and `log.md`, scaffolds the wiki if missing, routes decisions/terms/mistakes to their homes, converts old-format pages it edits. Owns the page format. |
| `lint` | Read-only health check: stale pages, broken links and Sources, orphans, index mismatch, old-format count. |
| `plaud-note-taking` | Corrects a PLAUD transcript in `raw/transcripts/`, writes `derived/` corrected + digest files, hands reusable facts to `ingest`. |

## Layout

```text
.llmwiki/
├── raw/                      originals, never edited
└── wiki/
    ├── index.md              one line per page
    ├── log.md                ingest record, newest first
    └── <topic>/<concept>.md  concept pages; ## Sources cites raw files or working evidence (PR, commit, measurement)
```

The page format is defined once, in `skills/ingest/SKILL.md`. `lint` checks against it; other skills that write pages defer to it.

## Old-format pages

Product repos may still hold pages from the earlier wiki (frontmatter `id`/`status`/`volatility`/`sources`, typed relation lines, sometimes no `## Sources`). They stay readable. `lint` counts them in one line; `ingest` rewrites a page in the new format when it next edits it. There is no bulk migration.
