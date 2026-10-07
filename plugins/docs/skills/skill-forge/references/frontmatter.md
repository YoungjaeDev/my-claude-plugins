# Skill frontmatter schema

Field-by-field rules for `SKILL.md` frontmatter in this repository. A field whose behavior
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

- **Under 1024 characters.** Codex silently skips a skill whose description exceeds this (observed;
  the cap is the Agent Skills spec's, the silent skip is documented nowhere). Claude Code truncates
  long listing text instead of skipping, at the cap its skills doc states, so the Codex loss is
  invisible from the Claude side. `scripts/check-skill-contract.mjs` blocks it at commit time.
- **Quote the value if it contains a colon-space (`: `).** Unquoted, YAML parses
  `description: Do X: then Y` as a nested mapping and the file fails to load with
  `mapping values are not allowed here`. Use double quotes or a `>-` block scalar.
- **Trigger branches first, rationale never.** Put the reaching conditions at the front. The body
  is where per-tool reasoning and the full trigger list belong.
- **Keep non-English trigger phrases in their source language.** Translating the Korean triggers in
  a `description` breaks skill matching for the users who type them.

## Optional fields: repo policy

What each field does on Claude Code is in the frontmatter reference of
<https://code.claude.com/docs/en/skills.md>; the portable set is in
<https://agentskills.io/specification.md>. Read those for behavior. This table holds only what no
doc states: the policy this repo applies.

| Field | Use here |
|---|---|
| `allowed-tools` | allowed; see the portability note below |
| `disable-model-invocation` | not in a Codex-eligible plugin |
| `argument-hint` | not in a Codex-eligible plugin; allowed, low value, in `codex-image` and `council` |
| `version` | do not add; `plugin.json` owns versions |
| `license` | no-op here |
| any other documented field | add only when you can state its runtime effect from the doc, and record that evidence |

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

Policy: do not set it to `true` in a Codex-eligible plugin (every plugin here except `codex-image`
and `council`); side-effecting skills use `agents/openai.yaml`
`policy.allow_implicit_invocation: false` instead. The policy was set because the Codex plugin
validator of that time rejected any value other than `false` or absent. Current Codex no longer ships
that validator at the old path, so the reason is `unverified` on current Codex. Keep the policy;
re-check it in a throwaway `CODEX_HOME` by adding a fixture plugin whose skill sets the field with
`codex plugin marketplace add` and seeing whether `codex plugin list` still lists it.

### `argument-hint`

It is a real skill field, not a command-only field — Claude Code documents it in the SKILL.md
frontmatter reference and shows it during autocomplete. On Codex, the authoring validator
(`skill-creator`'s `quick_validate.py`) whitelists the Agent Skills fields and would reject it;
whether the runtime loader does too is `unverified`.

The Agent Skills standard distribution paths — claude.ai skill upload, the Skills API,
`package_skill.py` — accept only the fields in <https://agentskills.io/specification.md> and reject
anything else with a hard error.

So the policy matches `disable-model-invocation`: keep it out of a Codex-eligible plugin, because
Codex's validator rejects it; it is fine in a Claude-only plugin (`codex-image`, `council`) that is
never packaged for the standard paths. Find the current uses with
`rg -l '^argument-hint:' plugins/*/skills/*/SKILL.md`.

### `version` and `license`

`version` is not a field in either reference above; check both when in doubt. Versioning belongs to
`plugin.json` plus `marketplace.json`; a `version` line in a SKILL.md is drift that will disagree
with them. Find the skills that carry `version` or `license` with
`rg -l '^(version|license):' plugins/*/skills/*/SKILL.md`; removing them is cleanup, not a
correctness fix, and is out of scope for the skill you are writing now unless you are already
editing that frontmatter.

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
