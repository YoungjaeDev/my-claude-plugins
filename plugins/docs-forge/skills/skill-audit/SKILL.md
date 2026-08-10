---
name: skill-audit
description: "Diagnose one existing skill against seven axes — frontmatter, pointer, structure, completion criteria, information hierarchy, pruning, runtime contract — and return a P0/P1/P2 finding list with concrete edits. Measures first with the bundled script, then judges only what the numbers and the body actually show. Use when a skill misfires, never triggers, loads on one runtime but not another, grew too long, or after absorbing a skill into a different plugin and you need to know what its body still gets wrong about its new home. Triggers — 스킬 진단, 스킬 점검, 이 스킬 감사, 스킬 문제 찾아줘, audit this skill, diagnose a skill, review SKILL.md, why does this skill not trigger. For writing or rewriting a skill use docs-forge:skill-forge; for sweeping every skill use docs-forge:skill-fleet-review."
---

# skill-audit

Diagnose one skill. Report what is wrong, at what severity, with the edit that fixes it.

## Hermes Agent compatibility

`docs-forge` is Hermes-eligible, so this loads as `docs-forge:skill-audit` through the generated
adapter. The Claude/Codex tool names below map to different Hermes tools — see
[`../../references/hermes-tools.md`](../../references/hermes-tools.md) before running any step.

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

Resolve the plugin root, then measure the tree containing the target:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && [ -d plugins/docs-forge/skills ] && PLUGIN_ROOT=plugins/docs-forge
if [ -z "$PLUGIN_ROOT" ]; then
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  PLUGIN_ROOT=$(ls -1d "$cache_root"/*/docs-forge/* 2>/dev/null | sort | tail -1)
fi
[ -d "$PLUGIN_ROOT/skills" ] || { echo "docs-forge plugin root not found; export PLUGIN_ROOT" >&2; exit 1; }
node "$PLUGIN_ROOT/skills/skill-forge/scripts/measure-skills.mjs"
```

Keep the target's row and the rows of its sibling skills in the same plugin — siblings are what the
pointer axis is judged against.

### 2. Read the target

`Read` the SKILL.md in full, plus every bundled file it points at. `Glob` the skill directory so a
bundled file the body never mentions becomes visible; an unreferenced reference is either dead or a
missing pointer.

### 3. Judge the seven axes

Work through all seven. Record a finding only where the body gives evidence — an axis with nothing
to say is passed, not padded.

| Axis | What decides it |
|---|---|
| Frontmatter | required fields present; description under 1024 and quoted if it holds `: `; `name` kebab and equal to the directory; no field whose runtime effect nobody can state |
| Pointer | does the description encode reaching conditions, or summarize the subject? how many distinct branches; synonym padding; does any branch collide with a sibling skill |
| Structure | section order and completeness; length against the 100/200/300 targets; `references` depth exactly 1; deterministic logic left as prose instead of a script |
| Completion criteria | per step: can done be told from not-done (clarity); does the demand pull real work, or accept a glance |
| Information hierarchy | branch test — inlined content only some branches reach, or a pointer to content every run needs; co-location, and whether a split concept is duplication or scattering |
| Pruning | no-op prose, sediment, prose caching what a file or command already shows, prohibition where a positive instruction would steer better |
| Runtime contract | every silent failure in `../skill-forge/references/runtime-contract.md` — bare `${CLAUDE_PLUGIN_ROOT}`, an interaction gate hardcoded to one runtime's tool, a Hermes-eligible skill with no tool mapping — plus logic that exists only on the Claude surface, and a body describing a plugin or path it no longer lives in |

### 4. Tier the findings

- **P0** — causes a silent failure: the skill does not load, does not trigger, or dies at its first
  step on one of the three runtimes.
- **P1** — structure, completion criteria, or a pointer collision with a sibling. The skill runs and
  produces the wrong shape of work.
- **P2** — pruning and phrasing. Real, but nothing breaks.

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
