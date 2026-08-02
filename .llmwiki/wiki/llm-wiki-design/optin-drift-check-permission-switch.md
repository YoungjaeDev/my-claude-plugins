---
id: optin-drift-check-permission-switch
aliases: [sha256-absence-as-switch, derived-layer-inside-raw, editable-vs-immutable-frontmatter, optin-hash-gate]
last_verified: 2026-08-02
status: active
volatility: stable
sources: 2
---

# An opt-in drift check is also a permission switch

`lint-wiki` Step 11 hashes a file under `.llmwiki/raw/` **only when that file's frontmatter
declares `sha256:`**; everything else is skipped, because raw frontmatter is prospective and
existing raw is never backfilled. The skip condition was written as a migration concession. It is
also, unavoidably, a per-file permission bit: a file that declares the field is immutable evidence,
and a file that omits it is hand-editable.

That makes "may a human edit this?" a property of one frontmatter field rather than of a path
allowlist, a lint exemption, or a new rule anyone has to remember.

## What it bought

`plaud-note-taking` v0.2.0 needed a readable meeting record derived from a frozen transcript, and
that record has to be hand-correctable. Putting it beside the transcript under
`.llmwiki/raw/transcripts/` looks like a raw-immutability violation. The layout works anyway:

```text
.llmwiki/raw/transcripts/
├── <slug>.transcript.txt   original, frozen
└── derived/
    ├── <slug>.corrected.md   fidelity artifact
    └── <slug>.digest.md      readable record
```

The derived files carry `derived_from:` and `ingested:` and **no `sha256:`**, so the existing drift
check passes over them by its own existing logic. No exemption list, no `derived/`-aware branch in
`lint-wiki`, nothing to keep in sync.

The alternative that was rejected: correct the transcript in place and log the edit. That trips the
drift check by design, and it destroys the thing the correction discipline stands on — a
`[정정] original → corrected (basis)` tag is only checkable while the original still exists to
check it against.

## The guarantee is one-directional — measure before claiming the pair

The tempting symmetric claim is "a derivative can be edited freely, and an edited original still
reports `DRIFT`." Only the first half holds unconditionally.

Measured by running Step 11's own `_fm_sha256` / `_body_sha256` shell against a fixture:

| file | declares `sha256:` | hand-edited | result |
|---|---|---|---|
| `derived/*.corrected.md`, `derived/*.digest.md` | no | yes | `SKIP` — no DRIFT |
| a hand-dropped `*.transcript.txt` | no | yes | `SKIP` — no DRIFT |
| a raw file with `sha256:` in frontmatter | yes | yes | `DRIFT reported` |

A transcript a user drops into `raw/` by hand carries no frontmatter at all, so the *original* is
skipped for the same reason the derivative is. The design guarantees that derivatives are editable;
it does not by itself guarantee that originals are watched. Watching an original requires giving it
the field.

## Why this generalizes

Any check that is opt-in by a declared marker splits its inputs into watched and unwatched, whether
or not the author meant to create a permission model. When a new layer needs different write rules,
look first for a marker the existing check already keys on — reusing it costs one frontmatter line
and adds no rule anyone has to learn, while a path allowlist or a lint exemption is a second thing
to keep in sync with the first.

The cost is that the switch is invisible unless it is written down: nothing in a derived file says
"the missing field is deliberate," so the intent has to live in the skill body that writes it. The
plaud skill states it at the layout section and again as a prohibition, which is what keeps a later
edit from "helpfully" adding `sha256:` and silently freezing the layer.

## Sources

1. **`llm-wiki:lint-wiki` Step 11** (`plugins/llm-wiki/skills/lint-wiki/SKILL.md`) — the body-hash
   drift scan; the `[[ -z "$stored" ]] && continue` skip on files with no frontmatter `sha256:`,
   and the accompanying note that raw frontmatter is prospective-only.
2. **PR #197 (plaud-note-taking v0.2.0, merged `69f6b06`)** — the `derived/` layout that depends on
   the skip, and the fixture run of Step 11's hash shell that produced the three-row table above
   (including the positive control: a raw file given `sha256:` and then edited reports `DRIFT`).

> Refines: [[curated-conservative]]
> See-also: [[provenance-over-confidence]]
> Evidence: plugins/llm-wiki/skills/lint-wiki/SKILL.md
> Evidence: plugins/plaud-note-taking/skills/plaud-note-taking/SKILL.md
