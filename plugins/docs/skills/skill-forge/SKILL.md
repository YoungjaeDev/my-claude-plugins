---
name: skill-forge
description: "Write or revise a Claude Code skill so it survives both runtimes this repo ships to (Claude Code + Codex). Owns the frontmatter schema, the writing levers behind skill prose, section structure, and the packaging contract (1024-char description cap, quoted colon-space, PLUGIN_ROOT resolver, version bump). Use when creating a new skill, splitting or renaming an existing one, rewriting a skill body, deciding what belongs in references/ versus scripts/, or asking whether a skill should exist at all. Triggers — 스킬 작성, 스킬 만들어줘, 스킬 개정, SKILL.md 작성, 스킬 구조 잡기, write a skill, author a skill, create a new skill, revise this skill, restructure SKILL.md. For diagnosing one existing skill use docs:skill-audit; for sweeping every skill in the repo use docs:skill-fleet-review."
---

# skill-forge

Write a skill that actually loads, actually triggers, and actually reaches the person who needs it.

## Overview

A skill fails in three separable ways, and they need different fixes:

- **It never loads.** A frontmatter violation. Silent on Claude Code, fatal on Codex.
- **It loads but never triggers.** A description that describes the subject instead of encoding the
  reaching conditions.
- **It triggers but the run goes wrong.** Structure: vague completion criteria, material at the
  wrong rung of the information hierarchy, prose that changes nothing.

This skill carries the rules for all three, plus the packaging obligations that decide whether a
change reaches users at all. Everything needed is bundled: no external skill is read at any point.

## When to use

Use it when creating a new skill, rewriting a body, splitting one skill into two, renaming a skill,
deciding between `references/` and `scripts/`, or judging whether a proposed skill should exist.

Do not use it to:

- diagnose one existing skill and get a graded fix list: that is `docs:skill-audit`
- sweep every skill in the repository: that is `docs:skill-fleet-review`
- write a slash command, a subagent, or a plugin manifest: those are different surfaces with
  different contracts

## Quick reference

| Question | Read |
|---|---|
| which frontmatter fields, and what each runtime does with them | `references/frontmatter.md` |
| why a line stays or goes; how to phrase triggers and completion criteria | `references/writing-levers.md` |
| section order, length targets, `scripts` vs `references` vs `assets`, naming | `references/structure.md` |
| the silent failures, the resolver block, version bumps, manifest regeneration | `references/runtime-contract.md` |

Read a reference when you reach the step that needs it, not up front.

## Procedure

### 1. Establish that the skill should exist

Answer before writing anything:

- **What is the invocation moment?** If two procedures are called at different times, they are two
  skills regardless of shared subject matter. If a procedure is called at the same moment as an
  existing skill, it is a section of that skill.
- **Does it change behavior?** A skill restating what the model already does by default is a no-op
  that costs description tokens on every turn forever.
- **Is a script enough?** Deterministic logic belongs in a script the caller runs. A skill wrapping
  one command is a menu entry, not a capability.

Say so plainly if the answer is no. Not writing the skill is the cheapest outcome available here.

### 2. Name it, then write the description

Name: lowercase-kebab, matching the directory, naming the object rather than the verb alone
(`bootstrap-project`, not `new`). Rules and the justified exception are in `references/structure.md`.

Description, the highest-leverage text in the skill and the only part loaded every turn:

1. Lead with the trigger branches, phrased the way a user actually types them, including
   non-English phrasings where those are what people use.
2. State what the skill does in one clause.
3. Point away from the skills it is most likely to be confused with.
4. Keep it under 1024 characters, and quote the whole value if it contains a colon-space.

Read `references/frontmatter.md` for the field rules and `references/writing-levers.md` for why
synonym lists cost more than they return.

### 3. Draft the body against the section order

Follow the order in `references/structure.md` and drop every section with nothing to say. Targets:
about 100 lines simple, about 200 complex, 300 as the ceiling here.

Two checks while drafting, both from `references/writing-levers.md`:

- **Branch test**: content every run needs goes inline; content only some branches reach goes
  behind a pointer to a bundled reference.
- **Completion criteria**: each step ends in something observable. "Review the config" does not
  distinguish done from not-done; "list every key the config sets and mark the ones this change
  touches" does.

### 4. Split the bundle

`scripts/` for logic that should not be re-derived per run. `references/` for bulky or
branch-specific material, exactly one level deep. `assets/` for files that end up in the output.

A body that calls a bundled script carries the cross-runtime resolver rather than
`${CLAUDE_PLUGIN_ROOT}`: the bare variable is not exported by Codex, so the call dies at step one.
The block to copy is in `references/runtime-contract.md`.

### 5. Prune

Take the five tests in `references/writing-levers.md` (single source of truth, cache, relevance,
no-op, sediment) and apply them to each paragraph. Delete rather than soften. Prefer stating the
target behavior over forbidding its opposite; a prohibition puts the forbidden thing into context.

### 6. Measure

Run the bundled measurement script. Resolve the plugin root first:

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
  PLUGIN_ROOT=$(ls -1d "$cache_root"/*/docs/* 2>/dev/null | awk -F/ '{print $NF "\t" $0}' | $vsort | tail -1 | cut -f2-)
fi
[ -d "$PLUGIN_ROOT/skills" ] || { echo "docs plugin root not found; export PLUGIN_ROOT" >&2; exit 1; }
node "$PLUGIN_ROOT/skills/skill-forge/scripts/measure-skills.mjs"
```

Find the new skill's row. Line count over 300, description over 1024, `references` depth above 1,
or a frontmatter key no other skill uses are each a finding to resolve now.

### 7. Package

Any file under `plugins/<name>/` changing means all of these, in the same change:

1. `plugins/<name>/.claude-plugin/plugin.json` → `version` (MINOR for a new skill).
2. `.claude-plugin/marketplace.json` → the matching entry's `version`.
3. `.claude-plugin/marketplace.json` → `metadata.version` (release counter, always MINOR).

Codex reads the same `.claude-plugin` manifests natively: no generated layer to regenerate.
Skipping the bump means users on a cached copy never receive the skill. Full contract in
`references/runtime-contract.md`.

### 8. Verify

These are repository scripts, not bundled with this plugin. In a repository that does not
carry them, say which check went unrun rather than treating silence as a pass:

This is a gate, so the block ends nonzero when any guard failed. Printing the status and
returning 0 would let a run that keys on the exit code treat a failed check as a pass.

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

Then read the new description next to its sibling skills' descriptions and confirm no two claim the
same trigger branch. That one is judgment; no guard covers it.

## Pitfalls

| Symptom | Cause |
|---|---|
| skill works in Claude Code, absent in Codex | description over 1024 characters, or `disable-model-invocation: true` |
| skill has no description anywhere and never triggers | unquoted `: ` in the description, or frontmatter not starting at byte 0 |
| bundled script "not found" on Codex | bare `${CLAUDE_PLUGIN_ROOT}` instead of the resolver |
| users report the old behavior after a fix | version bump missing; their plugin cache never refreshed |
| two skills fight over the same requests | overlapping trigger branches in sibling descriptions |
| body grew past 300 lines | one skill covering two invocation moments, or an inlined reference |

## Verification

The skill is done when: the guard commands in step 8 pass, the measurement row shows nothing
out of band, the description reads as trigger conditions rather than a summary, every step ends in
an observable result, and the version bump is in the same change.
