# The seven review axes

What decides each axis when judging a skill. `docs-forge:skill-audit` applies all seven to one skill; `docs-forge:skill-fleet-review` runs the pointer axis over every skill in the tree and the remaining six over a measured cohort. The axes are the same in both — only the loop cardinality differs, which is why they live here instead of in either body.

| Axis | What decides it |
|---|---|
| Frontmatter | required fields present; description under 1024 and quoted if it holds `: `; `name` kebab and equal to the directory; no field whose runtime effect nobody can state |
| Pointer | does the description encode reaching conditions, or summarize the subject? how many distinct branches; synonym padding; does any branch collide with a sibling skill |
| Structure | section order and completeness; length against the 100/200/300 targets and the 500-line hard ceiling; `references` depth exactly 1; deterministic logic left as prose instead of a script |
| Completion criteria | per step: can done be told from not-done (clarity); does the demand pull real work, or accept a glance |
| Information hierarchy | branch test — inlined content only some branches reach, or a pointer to content every run needs; co-location, and whether a split concept is duplication or scattering |
| Pruning | no-op prose, sediment, prose caching what a file or command already shows, prohibition where a positive instruction would steer better |
| Runtime contract | every silent failure in `runtime-contract.md` — bare `${CLAUDE_PLUGIN_ROOT}`, an interaction gate hardcoded to one runtime's tool, a Hermes-eligible skill with no tool mapping — plus logic that exists only on the Claude surface, and a body describing a plugin or path it no longer lives in |

An axis with nothing to say is passed, not padded.

## Tiers

- **P0** — silent failure on some runtime: does not load, does not trigger, dies at step one. Always name the runtime it breaks.
- **P1** — structure, completion criteria, or a pointer collision between siblings.
- **P2** — pruning and phrasing.

## Two thresholds that are not in conflict

`check-skill-prose.mjs` warns at **500 lines**; the Structure axis targets **100 / 200 / 300**. They measure the same thing at different authority: 500 is the repository's hard ceiling and the number CI reports, 300 is the authoring target a skill should be written toward. `measure-skills.mjs` emits the raw line count and takes no position. A skill between 300 and 500 is worth a finding; a skill over 500 is a finding the guard already made.
