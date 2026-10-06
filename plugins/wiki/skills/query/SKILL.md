---
name: query
description: "Answer a question from the repo's .llmwiki with citations: reads index.md first, then the concept pages it points at, then raw originals only when a page does not settle the question. Every claim cites the page (and raw file) it came from. When no page covers the question, says which source to bring in with /wiki:ingest. A newly synthesized answer is saved as a concept page only after the user approves, through the wiki:ingest format. Points decisions at docs/adr/ and terms at GLOSSARY.md. Read-only otherwise. Use on /wiki:query, 'wiki 에서 찾아줘', '위키에 뭐라고 돼 있어', '위키 질문', 'ask the wiki', 'what does the wiki say about'."
---

# wiki:query

Answers questions about **outside knowledge** (platforms, vendors, customers, the domain) from `.llmwiki/`, with every claim traced to a page. The page format is the one `wiki:ingest` writes; this skill reads it and never defines its own.

If `.llmwiki/wiki/` does not exist, say so and stop: there is nothing to read, and `/wiki:ingest` creates the wiki on first use.

## Route first

| Question is about | Home | Action |
|-------------------|------|--------|
| Why this repo decided something | `docs/adr/` | Point there, stop |
| What a project term means | `GLOSSARY.md` | Point there, stop |
| A fact about a platform, vendor, customer or domain | `.llmwiki/` | Continue below |

A mixed question is split: answer the outside-knowledge part, point the rest at its home.

## Steps

1. **Read `.llmwiki/wiki/index.md`.** Each line is `- [Title](<topic>/<concept>.md) — what it answers`. Pick the lines whose title or "what it answers" fits the question.
2. **Search past the index.** The index can lag the pages. Grep page titles, `aliases:` frontmatter and bodies under `.llmwiki/wiki/` for the question's key terms (and their other spellings) to catch pages the index misses.
3. **Read the candidate pages.** Follow plain relative links one hop when the linked page is needed for the answer. Note each page's `last_verified`.
4. **Go to raw only when needed.** Open a raw file listed in a page's `## Sources` when the page is silent on the exact point, the user wants the original wording, or two pages disagree. Raw files live under `.llmwiki/raw/`. Never edit them. If a cited raw file is missing, cite the page alone, say the source is gone, and suggest `/wiki:lint`.
5. **Answer** in the format below.
6. **Offer to save** (see below) only if the answer is new synthesis.

### Old-format pages

Pages from the earlier wiki are still valid sources. Read them as-is: frontmatter `sources:` and `> Evidence: <path>` lines play the role of `## Sources`; a `> Refines: [[id]]` style line points at the page whose frontmatter `id:` matches, so grep for that id. Do not rewrite them here; `wiki:ingest` converts a page when it next edits it.

## Answer format

- Lead with the answer, then the support.
- Cite each claim inline with the page path relative to `.llmwiki/wiki/`, and the raw path when you read raw: `(vendor-x/rate-limits.md)`, `(vendor-x/rate-limits.md; raw/2026-10-01-vendor-x-call.md)`.
- If a cited page's `last_verified` is older than 180 days or missing, say so next to the claim: the fact may have changed.
- If pages or sources disagree, show both with their citations and do not pick a winner.
- Anything not from the wiki (general knowledge, a guess) is labelled as such and carries no wiki citation.
- End with a `Sources read:` line listing every page and raw file opened.

## When no page covers the question

Say plainly that no page covers it. Do not fill the gap from general knowledge as if it came from the wiki. Then say what to ingest: the kind of source that would answer it (vendor documentation page, meeting notes, a customer email, a measurement with its command), and where it likely is if the conversation or repo shows it. The user brings it in with `/wiki:ingest <source>`. If a page covers the question only in part, answer that part with citations and name the source for the rest.

## Saving an answer

An answer is **new synthesis** when it combines several pages or raw files into something no single page states, or resolves a question from raw that no page covers. A restatement of one page is not; never offer to save it.

For new synthesis, ask once through the interactive-input gate: Claude uses `AskUserQuestion`; Codex uses `request_user_input` when it is exposed, otherwise one short blocking question. Offer: save as a new page, merge into an existing page (name it), or don't save. With no answer, don't save.

On approval, run `wiki:ingest` with the answer as a fact learned while working, starting at its "Find the pages" step: its format, log entry, index line and verification apply unchanged. The new page's `## Sources` lists the sources behind the pages and raw files used (raw paths, PRs, commits, measurements); the pages themselves are linked in the body. Do not write pages, `index.md` or `log.md` any other way.

## Example

```text
Q: What payload size does vendor X accept?

Vendor X rejects request bodies over 8 KB with a 413 (vendor-x/limits.md).
Batches are split client-side at 6 KB to leave room for headers (vendor-x/batching.md;
raw/2026-09-12-vendor-x-call.md). vendor-x/limits.md was last verified 2026-02-11,
over 180 days ago: the limit may have changed.

Sources read: vendor-x/limits.md, vendor-x/batching.md, raw/2026-09-12-vendor-x-call.md
```
