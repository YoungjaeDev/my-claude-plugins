# The seven review axes

What decides each axis when `docs:md-audit` judges a SKILL.md. For one skill all seven apply; for a sweep the pointer axis covers every skill in the tree and the other six cover the files the measurement singles out.

| Axis | What decides it |
|---|---|
| Frontmatter | required fields present; description under 1024 and quoted if it holds `: `; `name` kebab and equal to the directory; no field whose runtime effect nobody can state |
| Pointer | does the description encode reaching conditions, or summarize the subject? how many distinct branches; synonym padding; does any branch collide with a sibling skill |
| Structure | the skill shape and byte budget in `../../../references/writing-standard.md` (10KB cap, 5KB target, whole file); `references` depth exactly 1; deterministic logic left as prose instead of a script |
| Completion criteria | per step: can done be told from not-done (clarity); does the demand pull real work, or accept a glance |
| Information hierarchy | branch test: inlined content only some branches reach, or a pointer to content every run needs; co-location, and whether a split concept is duplication or scattering |
| Pruning | no-op prose, sediment, prose caching what a file or command already shows, prohibition where a positive instruction would steer better; a platform fact (`../skill-forge/references/live-lookup.md`) copied in with no instruction to look it up live. For each one, run the lookup it should point at once and compare; the result is the evidence, and a lookup that cannot run makes the finding `unverified` |
| Runtime contract | every silent failure in `../skill-forge/references/runtime-contract.md` (bare `${CLAUDE_PLUGIN_ROOT}`, an interaction gate hardcoded to one runtime's tool), plus logic that exists only on the Claude surface, and a body describing a plugin or path it no longer lives in |

An axis with nothing to say is passed, not padded.

## Tiers

- **P0**: silent failure on some runtime: does not load, does not trigger, dies at step one. Always name the runtime it breaks. Includes a copied platform fact that no longer matches its lookup when the mismatch fails silently.
- **P1**: structure, completion criteria, or a pointer collision between siblings. Includes a copied platform fact that no longer matches its lookup and fails loudly.
- **P2**: pruning and phrasing. Includes a copied platform fact that still matches its lookup.
