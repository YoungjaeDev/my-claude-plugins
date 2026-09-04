# Skill frontmatter schema

Field-by-field rules for `SKILL.md` frontmatter in this repository. Verified against Claude Code
2.1.226 documentation and the Codex 0.135 plugin validator on 2026-08-10. A field whose behavior
could not be established is marked `unverified` and carries no prohibition — an unfounded ban is
worse than a missing rule.

## The two fields every skill has

### `name` — required here

- lowercase-kebab, 64 characters or fewer, identical to the directory name.
- In a plugin skill the frontmatter `name` replaces the last segment of the command, so
  `plugins/docs/skills/skill-forge/` with `name: skill-forge` is `/docs:skill-forge`.
  A `name` that disagrees with the directory produces a command nobody can predict from the tree.
- Claude Code treats `name` as optional (it defaults to the directory name). This repo requires it
  anyway: the Codex validator errors on a missing or empty `name`, so a divergence shows up as two
  different identities for one skill.

### `description` — required here

The only trigger mechanism. It is loaded every turn for every skill, so it is the one part of a
skill that always costs context. Rules:

- **Under 1024 characters.** Codex 0.135 silently skips a skill whose description exceeds this.
  Claude Code has no such limit, so the violation is invisible from the Claude side.
  `scripts/check-skill-contract.mjs` blocks it at commit time.
- **Quote the value if it contains a colon-space (`: `).** Unquoted, YAML parses
  `description: Do X: then Y` as a nested mapping and the file fails to load with
  `mapping values are not allowed here`. Use double quotes or a `>-` block scalar.
- **Trigger branches first, rationale never.** Put the reaching conditions at the front. The body
  is where per-tool reasoning and the full trigger list belong.
- **Keep non-English trigger phrases in their source language.** Translating the Korean triggers in
  a `description` breaks skill matching for the users who type them.

## Optional fields, and what each runtime does with them

| Field | Claude Code | Codex 0.135 | Use here |
|---|---|---|---|
| `allowed-tools` | pre-approves those tools for the invoking turn | ignored | allowed; see the portability note below |
| `disable-model-invocation` | supported | **validation error unless `false`** | not in a Codex-eligible plugin |
| `argument-hint` | shown in autocomplete | ignored | allowed, low value |
| `version` | not a documented field | ignored | no-op — do not add |
| `license` | accepted, no behavior | ignored | no-op here |
| everything else in the Claude table | supported | mostly ignored | decide per field, record the evidence |

### `allowed-tools`

Optional. Adding it turns the list into a portability contract: whatever you name has to exist on
every runtime that loads the skill. `AskUserQuestion` in particular has no Codex equivalent (Codex
uses `request_user_input`), so a skill that lists it needs the cross-runtime interaction gate in its
body — see `runtime-contract.md`. A skill with no interactive gate should not list the tool merely
to document the mapping.

### `disable-model-invocation`

Works in Claude Code: it removes the description from Claude's context entirely and leaves the
skill reachable only by typing `/name`. That makes it the sharpest available lever against
always-on context cost for a workflow with side effects.

It is unusable in a Codex-eligible plugin. The Codex plugin validator
(`~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py`) rejects any value other than
`false` or absent. Every plugin in this repo except `codex-image` and `council` is Codex-eligible,
so in practice: do not set it to `true` here.

`unverified` — whether the Codex **runtime loader** enforces the same rule, or only the authoring
validator does. The validator's verdict is enough to keep the field out; do not extend the claim to
"Codex skips the skill at load" without checking.

### `argument-hint`

It is a real skill field, not a command-only field — Claude Code documents it in the SKILL.md
frontmatter reference and shows it during autocomplete. Codex ignores it (its skill validator has
no allowed-key whitelist).

The one place it breaks is outside these two runtimes. The Agent Skills standard distribution
paths — claude.ai skill upload, the Skills API, `package_skill.py` — accept only `name`,
`description`, `license`, `compatibility`, `metadata`, `allowed-tools`, and reject anything else
with a hard error. The official docs use `argument-hint` as their example of that error.

So: harmless here, fatal if a skill is ever packaged for the standard paths. The two existing uses
(`codex-image:codex-image`, `council:convene`) are not on those paths and are not defects.

### `version` and `license`

`version` appears in no frontmatter reference — not Claude Code's, not the Agent Skills six-field
set. No runtime reads it. Versioning belongs to `plugin.json` plus `marketplace.json`; a `version`
line in a SKILL.md is drift that will disagree with them. Four skills currently carry `version` or
`license`; removing them is cleanup, not a correctness fix, and is out of scope for the skill you
are writing now unless you are already editing that frontmatter.

`license` is a valid Agent Skills field that Claude Code accepts without acting on. Nothing here
needs it.

## Default for a new skill in this repo

```yaml
---
name: <directory-name>
description: <trigger branches first, under 1024 chars, quoted if it contains ": ">
---
```

Add a field beyond these two only when you can say what it changes at runtime. Anything you cannot
justify that way is sediment in the one part of the skill that is always loaded.
