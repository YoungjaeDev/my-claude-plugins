---
id: skill-frontmatter-runtime-matrix
aliases: [disable-model-invocation-codex-reject, argument-hint-is-a-skill-field, frontmatter-name-sets-command-segment, skill-frontmatter-cross-runtime]
last_verified: 2026-08-10
status: active
volatility: volatile
sources: 4
---

# Skill frontmatter is not read the same way by the three runtimes

A field that works in Claude Code can be rejected by Codex's plugin validator, ignored by Hermes, or
fatal on a packaging path none of the three runtimes use. Three facts checked against the actual
sources on 2026-08-10, each of which had been guessed wrong somewhere in this repo.

## `disable-model-invocation` works in Claude Code and fails Codex validation

Claude Code supports it: it is in the official SKILL.md frontmatter reference, and two changelog
entries record behavior changes for it (a `/<skill>` invocation bug, and the refusal wording shown
when the model tries to invoke such a skill). Setting `true` removes the description from the
model's context entirely, which makes it the sharpest lever there is against always-on description
cost.

Codex 0.135 rejects it. Its plugin validator (`plugin-creator/scripts/validate_plugin.py`) errors
with `frontmatter field 'disable-model-invocation' must be false` on any value other than `false` or
absent. Every plugin in this repo except `codex-image` and `council` is Codex-eligible, so in
practice the field is unusable here.

`unverified`: whether the Codex **runtime loader** enforces the same rule, or only the authoring
validator does. The validator's verdict is enough to keep the field out — do not extend the claim to
"Codex skips the skill at load" without checking.

## `argument-hint` is a real skill field, and the "command-only field" belief is wrong

It appears in Claude Code's SKILL.md frontmatter reference as an optional field shown during
autocomplete. Codex ignores it — its skill validator checks `name`, `description`, and
`disable-model-invocation` and has no allowed-key whitelist for skills, so unknown keys pass. The
generated Hermes adapter reads only `description`.

The one place it is fatal is outside all three runtimes: the Agent Skills standard distribution
paths (claude.ai upload, the Skills API, `package_skill.py`) accept exactly `name`, `description`,
`license`, `compatibility`, `metadata`, `allowed-tools` and hard-error on anything else — the
official docs use `argument-hint` as their example of that error. So the field is harmless in this
repo and would break a skill only if it were ever packaged for those paths.

This corrects a claim recorded in `.claude/spec/2026-08-05-skill-forge-and-singleton-absorption.md`
D12, which called `argument-hint` a command-only field and listed the two skills carrying it as
drift to clean up. They are not defects.

## The frontmatter `name` sets a plugin skill's command segment

For a plugin skill, `name` replaces the directory name in the command's last segment:
`my-plugin/skills/review/SKILL.md` with `name: fancy` is invoked as `/my-plugin:fancy`. In a
personal or project skill it only sets the display label and the command still comes from the
directory.

The consequence is that **`name` is a public identifier, and changing it is a breaking change for
anyone who typed the old command**. When a guard flags a mismatch between `name` and its directory,
change whichever side is *not* the public identifier — in `paper-search-tools` the fix was to rename
the directory to `paper-search`, keeping `/paper-search-tools:paper-search` working, rather than
renaming `name` under a PATCH bump. The directory name is only load-bearing where something reads
it: the generated Hermes adapter registers by directory, so a mismatch splits one skill into two
identities across runtimes (`scripts/check-skill-contract.mjs` check 6 blocks it).

## Fields no runtime reads

`version` is in neither the Claude Code frontmatter reference nor the Agent Skills six-field set —
nothing reads it, and it will disagree with `plugin.json` the first time either changes. Three
skills still carry it. `license` is a valid Agent Skills field that Claude Code accepts without
acting on.

## Sources

1. Claude Code skills documentation (<https://code.claude.com/docs/en/skills>) — the SKILL.md
   frontmatter reference table, the "Using skill frontmatter outside Claude Code" section with the
   six-field spec list and the `argument-hint` error example, and "How a skill gets its command
   name".
2. `~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py` — `validate_skill_manifest`
   checks `name` / `description` non-empty and `disable-model-invocation` false-or-absent, with no
   allowed-key whitelist for skills.
3. `~/.claude/cache/changelog.md` — two entries recording `disable-model-invocation` behavior
   changes, evidence the field is live in Claude Code rather than merely documented.
4. PR #202 dogfood — the `paper-search-tools` rename reversal, decided after Codex flagged the
   public-identifier break.

> Refines: [[codex-skill-desc-1024]]
> See-also: [[hermes-plugin-adapter]]
> See-also: [[shared-source-codex-manifests]]
> Evidence: .claude/spec/2026-08-05-skill-forge-and-singleton-absorption.md
