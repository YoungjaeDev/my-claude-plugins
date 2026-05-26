---
paths: src/<domain>/**, tests/<domain>/**
---

# <domain> — invariants

Path-scoped rule. Loaded only when files matching `paths:` are in context.

This file holds **trip-wire invariants** for the `<domain>` module — things that break tests / release / reproducibility if violated. For debugging stories, provider quirks, design rationale, see `wiki/<domain>/`.

## Invariants

- TODO: list each invariant as `- **<short label>**: <one-sentence rule>. <Why it matters: which test / build gate breaks if violated>.`

## See also (wiki)

- `wiki/<domain>/...` — TODO

## Cross-refs

- `rules/_entrypoint.md` — layer model
- `rules/code-map.md` — where this module lives
