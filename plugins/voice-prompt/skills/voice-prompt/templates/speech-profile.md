# Speech profile (template)

This bundled file is an **empty template**, not the live profile. The live, per-project profile is
`.claude/voice-prompt/speech-profile.md` — a stable config path, because a plugin-cache copy is
wiped on cache refresh and cannot hold a project's terms.

Scope: only what does **not** generalize. General Korean fillers live in
`references/korean-filler.md`, and anything the repo can answer (file, branch, symbol, skill
names) is resolved by lookup, not recorded here. What is left is one speaker's recurring
mispronunciations and the domain vocabulary no lookup can settle.

The skill **proposes** entries and never writes this file on its own. Add a row only after the
user confirms it, or a trusted project document verifies it — never because a term "came up a lot".

## Domain terms

Words a repo lookup cannot resolve: company names, product names, internal jargon, external
service names.

| STT output (candidates) | Correct spelling | Basis |
|---|---|---|

## Recurring mispronunciations

Speaker-specific patterns that repeat across sessions. A row here is a shortcut for a lookup that
already succeeded several times — not a substitute for one that has not run.

| Heard as | Means | Basis |
|---|---|---|

## Personal filler additions

Only habits that are **not** general Korean speech. If a candidate would be true of Korean
speakers broadly, it belongs in `references/korean-filler.md` as a plugin change instead.

| Expression | Delete or keep | Note |
|---|---|---|

## What must not go in this file

Do not add a person's name, a client or company contact, an amount, or a contract term without
separate verification. Those are expensive to get wrong and default to a question rather than an
auto-correction. Never store credentials, phone numbers, or email addresses here.
