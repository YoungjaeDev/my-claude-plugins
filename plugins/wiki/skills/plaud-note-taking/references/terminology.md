# Project term dictionary (template)

This bundled file is an **empty template**, not the live dictionary. The live, per-project
dictionary lives in the user's project at `.claude/plaud-note-taking/terminology.md` — a stable
config path outside `.llmwiki/raw/` (which wiki treats as immutable, date-named evidence, so
a growing dictionary must not live there). The skill seeds it by copying this template on first
run, then reads and grows that copy (a plugin-cache file cannot hold a project's terms and is
wiped on cache refresh).

It is the **only** basis for a terminology `[정정]`, mirroring PLAUD's own Custom Vocabulary: a
verified map from what STT tends to produce → the correct project spelling. A term is added only
after the user confirms it, or a trusted project doc verifies it — never because it "appears a
lot" in a transcript.

## Entries

The dictionary starts **empty** for a new project — no live row ships by default. Add only
verified entries (see "How to add an entry"); the row shape is illustrated there.

| STT misrecognition (candidates) | Correct spelling | Basis |
|---|---|---|

## How to add an entry

Record all three fields. Add an entry only after the user confirms it — the skill proposes
candidates at the bottom of its corrected-note output and never edits this file on its own.

```text
| <what STT produces> | <correct spelling> | <verifying doc or user confirmation> |
```

Do **not** add people's names, client/company names, amounts, or contract terms to this table
without separate verification — those are high-cost to get wrong and default to an open question
rather than an auto-correction.
