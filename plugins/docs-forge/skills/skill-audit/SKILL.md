---
name: skill-audit
description: "Diagnose one existing skill against seven axes — frontmatter, pointer, structure, completion criteria, information hierarchy, pruning, runtime contract — and return a P0/P1/P2 finding list with concrete edits. Measures first with the bundled script, then judges only what the numbers and the body actually show. Use when a skill misfires, never triggers, loads on one runtime but not another, grew too long, or after absorbing a skill into a different plugin and you need to know what its body still gets wrong about its new home. Triggers — 스킬 진단, 스킬 점검, 이 스킬 감사, 스킬 문제 찾아줘, audit this skill, diagnose a skill, review SKILL.md, why does this skill not trigger. For writing or rewriting a skill use docs-forge:skill-forge; for sweeping every skill use docs-forge:skill-fleet-review."
---

# skill-audit

Diagnose one skill. Report what is wrong, at what severity, with the edit that fixes it.

## Overview

Measurement first, judgment second. Numbers settle the mechanical axes for free, which keeps the
expensive reading focused on the axes a script cannot reach: whether the description encodes real
trigger conditions, whether steps distinguish done from not-done, whether the body still describes
where it used to live.

The rules being applied belong to `docs-forge:skill-forge` and live in its bundled references. Read
them there rather than restating them; this skill is the diagnostic pass over one target.

## When to use

Audit one named skill: after writing it, after moving it between plugins, when it does not trigger,
when it loads on one runtime and not another, or when its body outgrew its job.

Do not use it to write or rewrite a skill (`docs-forge:skill-forge`), or to sweep the whole
repository (`docs-forge:skill-fleet-review`).

## Procedure

### 1. Measure

Resolve the plugin root, then measure **the tree that contains the target**. Pass that tree
explicitly: with no argument the script defaults to `plugins/` when it exists, so auditing a
skill under `.claude/skills/` in a repository that also has `plugins/` silently measures a
different tree and the target never appears in the output.

Set `TARGET_ROOT` to the directory holding the target and its siblings — `plugins/<plugin>/skills`,
`.claude/skills`, or whatever contains it. Siblings matter: the pointer axis is judged against them.

```bash
# Honor a caller-supplied PLUGIN_ROOT first — the abort message below tells the user to
# export it, and starting from CLAUDE_PLUGIN_ROOT would overwrite that escape hatch.
PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
[ -z "$PLUGIN_ROOT" ] && [ -d plugins/docs-forge/skills ] && PLUGIN_ROOT=plugins/docs-forge
if [ -z "$PLUGIN_ROOT" ]; then
  # Rank Codex cache candidates on the version basename, not the whole path: a plain
  # sort puts 0.9.0 above 0.10.0 and lets the marketplace directory outrank the version.
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  if sort -V </dev/null >/dev/null 2>&1; then vsort="sort -V"; else vsort="sort -t. -k1,1n -k2,2n -k3,3n"; fi
  PLUGIN_ROOT=$(ls -1d "$cache_root"/*/docs-forge/* 2>/dev/null | awk -F/ '{print $NF "\t" $0}' | $vsort | tail -1 | cut -f2-)
fi
[ -d "$PLUGIN_ROOT/skills" ] || { echo "docs-forge plugin root not found; export PLUGIN_ROOT" >&2; exit 1; }
TARGET_ROOT="${TARGET_ROOT:?set TARGET_ROOT to the directory containing the target skill}"
TARGET_SKILL="${TARGET_SKILL:?set TARGET_SKILL to the skill directory name being audited}"
out=$(node "$PLUGIN_ROOT/skills/skill-forge/scripts/measure-skills.mjs" "$TARGET_ROOT"); rc=$?
printf '%s\n' "$out"
[ "$rc" -eq 0 ] || { echo "measure-skills exited $rc — part of $TARGET_ROOT was unreadable, so this audit's scope is incomplete" >&2; exit 1; }
# Fail closed: a target that is not in the measurement means TARGET_ROOT points elsewhere.
# Continuing would judge the seven axes against rows belonging to other skills.
printf '%s\n' "$out" | grep -qE "(^|[[:space:]])${TARGET_SKILL}([[:space:]]|$)" \
  || { echo "no row for '$TARGET_SKILL' under $TARGET_ROOT — the root is wrong, not the skill" >&2; exit 1; }
```

The audit proceeds only past that check. Keep the target's row and its siblings' rows: siblings are
what the pointer axis is judged against.

### 2. Read the target

`Read` the SKILL.md in full, plus every bundled file it points at. `Glob` the skill directory so a
bundled file the body never mentions becomes visible; an unreferenced reference is either dead or a
missing pointer.

### 3. Judge the seven axes

`Read` the axis table and tier definitions in `../skill-forge/references/axes.md`, then work through
all seven against this skill. Record a finding only where the body gives evidence.

### 4. Tier the findings

Per the tiers in `../skill-forge/references/axes.md`: **P0** silent failure on a runtime, **P1**
structure / completion criteria / sibling pointer collision, **P2** pruning and phrasing.

### 5. Report

Emit, in this order:

1. The measurement row for the target.
2. Findings, P0 first, each as: axis, evidence (file and line), impact, and the concrete edit.
3. Anything checked and found clean, in one line — so a later reader can tell an unchecked axis
   from a passed one.
4. What could not be determined, marked `unverified`, with what would settle it.

Do not apply edits as part of the audit. Report, then let the caller choose — the P2 tier in
particular is often not worth a version bump on its own.

## Pitfalls

- **Judging the pointer axis without the siblings.** A description is only ambiguous relative to
  what else could have matched. Read the whole plugin's descriptions together.
- **Reporting a passing axis as a finding.** Padding the list to seven entries buries the P0.
- **Treating a bundled reference as unread.** Follow every pointer; a body that looks thin usually
  moved its content correctly.
- **Calling scattering "duplication".** Merging and deleting are opposite fixes; establish which
  one applies before proposing an edit.
- **Asserting a runtime behavior nobody checked.** Mark it `unverified` instead. A rule invented to
  fill a gap is worse than a documented gap.

## Verification

The audit is done when all seven axes have an explicit verdict, every finding names a file and
line, every P0 names which runtime it breaks, and any edits that were applied are accompanied by a
version bump plus regenerated manifests.
