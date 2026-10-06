---
name: ingest
description: "Bring outside knowledge into the repo's .llmwiki: a source document (meeting notes, research, customer or vendor doc) or a platform, vendor, customer or domain fact learned while working. Saves originals under .llmwiki/raw/, then creates or updates concept pages in .llmwiki/wiki/<topic>/<concept>.md with a ## Sources section, and updates index.md and log.md. Scaffolds the wiki if the repo has none. Turns away decisions (docs/adr), terms (GLOSSARY.md) and repeated mistakes (/retro). Use on /wiki:ingest, ingest-finding, 'wiki 에 넣어줘', '위키 정리', 'ingest this doc', 'add this to the wiki'."
---

# wiki:ingest

The wiki holds **outside knowledge**: facts about things the repository does not control (platforms, vendors, customers, the domain), whether they arrived as a document or were learned while working. This skill is the only writer of concept pages; `/wiki:query` answers from them and `wiki:lint` checks them.

## Route first: is this outside knowledge?

Each kind of knowledge has one home. Before writing anything, sort the input:

| Input | Home | Action |
|-------|------|--------|
| A decision this repo made (and why) | `docs/adr/` | Say so, point at the ADR folder, stop |
| A project term and its meaning | `GLOSSARY.md` | Say so, stop |
| A mistake that keeps happening | `/retro` (turns it into an automated check) | Say so, stop |
| A fact about a platform, vendor, customer or domain | `.llmwiki/` | Continue below |

Mixed input (a meeting that produced a decision and surfaced a vendor fact) is split: ingest the fact, point the rest at its home.

## Structure

```text
.llmwiki/
├── raw/                    originals, stored as received, never edited
│   └── YYYY-MM-DD-<slug>.<ext>   (sub-folders by source are fine, e.g. raw/transcripts/)
└── wiki/
    ├── index.md            one line per concept page
    ├── log.md              what each ingest/lint run did, newest first
    └── <topic>/<concept>.md  concept pages, one level of topic folders, kebab-case names
```

If `.llmwiki/wiki/` does not exist, create the skeleton first:

```bash
mkdir -p .llmwiki/raw .llmwiki/wiki
[ -f .llmwiki/wiki/index.md ] || printf '# Wiki index\n\nOne line per concept page: `- [Title](<topic>/<concept>.md) — what it answers`.\n' > .llmwiki/wiki/index.md
[ -f .llmwiki/wiki/log.md ]   || printf '# Wiki log\n\nNewest first. Header: `## YYYY-MM-DD — <summary> (<skill>)`.\n' > .llmwiki/wiki/log.md
```

## Concept page format

```markdown
---
last_verified: YYYY-MM-DD
aliases: [other names people search for]
---

# <Concept>

<What is true now, written as current state. Link related pages with plain relative
links, e.g. [rate limits](../vendor-x/rate-limits.md).>

## Sources

- .llmwiki/raw/2026-10-01-vendor-x-call.md
- PR owner/repo#123, commit abc1234
- Measured 2026-10-02: p95 410 ms over 1k requests (command in PR owner/repo#123)
```

- `last_verified` is the day the claims were last checked against their sources. Bump it only after re-checking. `aliases` is optional.
- `## Sources` is required. It cites raw files by path, or working evidence directly (PR, commit, measurement result). A fact learned while working needs no raw file; cite the evidence.
- Links are plain markdown links between pages. There is no typed relation syntax.
- One index line per page: `- [Title](<topic>/<concept>.md) — what it answers`, grouped under `## <topic>` headings.

## Writing rules

- **Current state only.** The body says what is true now. History, PR narratives and "changed in" stories stay out; provenance lives in `## Sources`.
- **Consolidate, don't append.** Search `index.md`, page titles and `aliases` first. If a page covers the concept, edit it. Add a page only for a concept no page covers.
- **Generalize to the property, not past it.** Record the fact the case is an instance of ("vendor X rejects payloads over 8 KB"), not the one call that showed it, and keep what to check concrete.
- **Match the page's language.** Write in the language the page (or its topic folder) already uses.
- **Synthesize, never copy.** Raw stays in `raw/`; the page cites it.
- **Raw is never edited.** A changed source is a new dated raw file.

## Steps

1. **Route** the input with the table above.
2. **Save originals.** A document that arrived from outside goes under `.llmwiki/raw/` as `YYYY-MM-DD-<slug>.<ext>`, unchanged. Skip for facts learned while working.
3. **Find the pages.** Search `index.md` and page bodies; list every page the input touches (usually one primary page, sometimes a few that link to it).
4. **Log first.** Prepend to `log.md` (below its header) before editing pages, so one commit carries both and `git revert` undoes both:

   ```text
   ## YYYY-MM-DD — <one-line summary> (ingest)

   - <topic>/<concept>.md: <what changed>
   - index.md: <added/updated line>
   ```

5. **Edit pages** in the format above: update the body, add the new entries to `## Sources`, bump `last_verified`. A new page gets an index line.
6. **Convert old-format pages you touch.** A page written for the earlier wiki (frontmatter `id`/`status`/`volatility`/`sources`, lines like `> Refines: [[id]]` or `> Evidence: <path>`, no `## Sources`) is rewritten in the new format when you edit it: keep `last_verified` and `aliases`, drop the other frontmatter keys, turn relation lines into plain links in the body, and move `> Evidence:` targets into `## Sources`. Leave old pages you do not touch alone.
7. **Report** the log block and one line per page touched.

## Ask before

Use the interactive-input gate (Claude: `AskUserQuestion`; Codex: `request_user_input` when exposed, otherwise one short blocking question) before:

- deleting or merging pages,
- one ingest touching more than ~10 pages,
- picking a winner when two sources contradict each other (record both in the page until then).

Everything else (editing a page, adding a page or topic folder, updating index and log) proceeds without asking.

## Verification

- Every touched page has `## Sources` and today's `last_verified`.
- Every page in `wiki/` has exactly one `index.md` line, and every index line points at an existing page.
- `log.md` has the new entry listing every page touched.
- Nothing was written to `raw/` except new originals.
