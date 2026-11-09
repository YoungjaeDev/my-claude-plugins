---
name: skill-forge
description: "Write or revise a Claude Code skill so it survives both runtimes this repo ships to (Claude Code + Codex). Owns the frontmatter schema, the writing levers behind skill prose, section structure, and the packaging contract (1024-char description cap, quoted colon-space, PLUGIN_ROOT resolver, version bump). Use when creating a new skill, splitting or renaming an existing one, rewriting a skill body, deciding what belongs in references/ versus scripts/, or asking whether a skill should exist at all. Triggers: 스킬 작성, 스킬 만들어줘, 스킬 개정, SKILL.md 작성, 스킬 구조 잡기, write a skill, author a skill, create a new skill, revise this skill, restructure SKILL.md. For auditing existing skills or other markdown use docs:md-audit."
---

# skill-forge

Write a skill that loads, triggers, and does its job on Claude Code and Codex, in a SKILL.md at or under 10KB (target 5KB). Shape and tone follow `../../references/writing-standard.md`; the rules specific to skills are in this skill's `references/`.

## Core model

A skill fails in three separable ways, each with its own fix:

- **It never loads**: a frontmatter violation, silent on Claude Code and fatal on Codex.
- **It loads but never triggers**: a description that summarizes the subject instead of encoding the reaching conditions.
- **It triggers but the run goes wrong**: vague completion criteria, material at the wrong rung of the information hierarchy, prose that changes nothing.

| Question | Read |
|---|---|
| which frontmatter fields, and what each runtime does with them | `references/frontmatter.md` |
| why a line stays or goes; how to phrase triggers and completion criteria | `references/writing-levers.md` |
| skill shape, byte budget, `scripts` vs `references` vs `assets`, naming | `references/structure.md` |
| the silent failures, the resolver block, the interaction gate, version bumps | `references/runtime-contract.md` |
| where to send the agent for a platform fact instead of copying it | `references/live-lookup.md` |

Read a reference when you reach the step that needs it, not up front. Writing a slash command, a subagent, or a plugin manifest is a different surface with a different contract, and auditing an existing skill is `docs:md-audit`.

## Procedure

1. **Establish that the skill should exist.** Two procedures called at different moments are two skills; one called at the same moment as an existing skill is a section of it. A skill that restates default behavior or wraps one command should not exist, and saying so is the cheapest outcome.
2. **Name it, then write the description.** Name: lowercase-kebab, equal to the directory, naming the object (`bootstrap-project`, not `new`). Description: trigger branches first in the words users type, what it does in one clause, a pointer away from the likeliest sibling, under 1024 characters, quoted if it holds `: `.
3. **Draft the body in the skill shape.** Goal, core model, output shape, bright lines, done condition, per `references/structure.md`. Every step ends in something observable, content only some branches reach goes behind a pointer, and every platform fact is listed with the command or URL checked this session, or why it stays encoded (`references/live-lookup.md`).
4. **Split the bundle.** `scripts/` for logic not to re-derive per run, `references/` one level deep for bulky or branch-specific material and step prose (`references/procedure.md`), `assets/` for files that end up in the output. A body that calls a bundled script carries the resolver from `references/runtime-contract.md`, never a bare `${CLAUDE_PLUGIN_ROOT}`.
5. **Prune.** Apply the five tests in `references/writing-levers.md` (single source of truth, cache, relevance, no-op, sediment) to each paragraph. Delete rather than soften, and state the target behavior rather than forbid its opposite.
6. **Measure.** Run the shape audit on the skill directory and the skill table on its plugin, as below. Resolve every `fail`, a description over 1024, `references` depth above 1, or a frontmatter key no other skill uses.
7. **Package.** Bump the plugin's `version` in `plugins/<name>/.claude-plugin/plugin.json` and the matching `.claude-plugin/marketplace.json` entry (MINOR for a new skill), plus `metadata.version`, in the same change. Without the bump, users on a cached copy never receive it.
8. **Verify.** Run the guards below, then read the new description next to its siblings and confirm no two claim the same trigger branch. No guard covers that one.

```bash
# Honor a caller-supplied PLUGIN_ROOT first — the abort message below tells the user to
# export it, and starting from CLAUDE_PLUGIN_ROOT would overwrite that escape hatch.
PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
[ -z "$PLUGIN_ROOT" ] && [ -d plugins/docs/skills ] && PLUGIN_ROOT=plugins/docs
if [ -z "$PLUGIN_ROOT" ]; then
  # Rank Codex cache candidates on the version basename, not the whole path: a plain
  # sort puts 0.9.0 above 0.10.0 and lets the marketplace directory outrank the version.
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  if sort -V </dev/null >/dev/null 2>&1; then vsort="sort -V"; else vsort="sort -t. -k1,1n -k2,2n -k3,3n"; fi
  PLUGIN_ROOT=$(ls -1d "$cache_root"/*/docs/* 2>/dev/null | awk -F/ '{print $NF "\t" $(0)}' | $vsort | tail -1 | cut -f2-)
fi
[ -d "$PLUGIN_ROOT/skills" ] || { echo "docs plugin root not found; export PLUGIN_ROOT" >&2; exit 1; }
SKILL_DIR="${SKILL_DIR:?set SKILL_DIR to the skill directory being written}"
node "$PLUGIN_ROOT/skills/md-audit/scripts/measure-skills.mjs" --md "$SKILL_DIR"
node "$PLUGIN_ROOT/skills/md-audit/scripts/measure-skills.mjs" "$(dirname "$SKILL_DIR")"
```

The guards are repository scripts, not bundled here. In a repository without them, say which check went unrun. The block ends nonzero when any guard failed, so a caller keying on the exit status cannot read a failure as a pass.

```bash
failed=0
for g in "check-skill-contract.mjs" "check-doc-consistency.mjs"; do
  s=${g%% *}; rest=${g#"$s"}
  if [ -f "scripts/$s" ]; then
    node "scripts/$s" $rest; rc=$?
    [ "$rc" -eq 0 ] || { echo "[$s exit $rc]"; failed=1; }
  else
    echo "[$s not present in this repository — unchecked]"
  fi
done
exit "$failed"
```

## Bright lines and done

| Symptom | Cause |
|---|---|
| skill works in Claude Code, absent in Codex | description over 1024 characters |
| skill has no description anywhere and never triggers | unquoted `: ` in the description, or frontmatter not starting at byte 0 |
| bundled script "not found" on Codex | bare `${CLAUDE_PLUGIN_ROOT}` instead of the resolver |
| users report the old behavior after a fix | version bump missing; their plugin cache never refreshed |
| two skills fight over the same requests | overlapping trigger branches in sibling descriptions |
| SKILL.md past 10KB | one skill covering two invocation moments, or step prose that belongs in `references/procedure.md` |
| skill passes flags or values the installed tool no longer accepts | a platform fact copied into the body instead of a pointer to `--help` or the docs |

The skill is done when the step 8 guards pass, the step 6 audit ends `md-audit: ok`, the description reads as trigger conditions, every step ends in an observable result, every platform fact is on the step 3 list with its checked source or encoded reason, and the version bump is in the same change.
