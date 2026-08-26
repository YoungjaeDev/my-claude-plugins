# Skill structure

Where text and files go. `writing-levers.md` covers why a line stays; this file covers shape.

## Section order

Use the sections a skill actually needs, in this order. Omit any with nothing to say — an empty
heading is a promise the body does not keep.

1. `# Title` — what the skill is, one line under the heading.
2. `## Overview` — the problem and the shape of the answer, in a short paragraph.
3. `## When to use` — entry conditions, plus the conditions that mean *not* this skill. The
   negative branch is what stops a general skill from swallowing every adjacent request.
4. `## Prerequisites` — state or tools the procedure assumes. Omit when there are none.
5. `## How to run` — the invocation, including a bundled-script call if there is one.
6. `## Quick reference` — the table or checklist an experienced user comes back for.
7. `## Procedure` — numbered steps, each ending in an observable result.
8. `## Pitfalls` — the failures seen in practice, each with its symptom.
9. `## Verification` — how the caller knows the run succeeded.

A skill under about 60 lines usually collapses to Title, Overview, When to use, Procedure.

## Length

- Simple skill: around 100 lines.
- Complex skill: around 200 lines.
- 300 lines is the ceiling used for new skills in this repository.
- `scripts/check-skill-prose.mjs` warns above 500 lines. That is an upper bound on damage, not a
  target. Anything approaching it is carrying reference-grade material that belongs in
  `references/`.

Length is a symptom, not the disease. A 400-line body is usually one skill doing three jobs, or a
body that inlined a reference. Split by *invocation moment*: two procedures a person calls at
different times are two skills, even when they share subject matter.

## Bundled directories

| Directory | Holds | Loaded |
|---|---|---|
| `scripts/` | non-obvious logic the model should not re-derive each run | executed by the body |
| `references/` | bulky or branch-specific material | read on demand by the body |
| `assets/` | files that end up in the output (templates, examples) | copied or filled |

`references/` is exactly one level deep — files sit directly under it. A nested path is both a
`check-skill-prose.mjs` warning and a sign that a reference has become its own skill.

Prefer a script over prose whenever the logic is deterministic. Prose that describes an algorithm
gets re-derived, slightly differently, on every run; a script gets the same answer twice.

## Tool framing

Name the harness tools, not the shell equivalents:

- `Read`, not `cat` / `head` / `tail`
- `Grep` / `Glob`, not `grep` / `find`
- `Edit` / `Write`, not `sed` / redirection

The shell forms bypass the harness's own file tracking and, in review, read as a way around the
edit tools. Reserve `Bash` for what genuinely needs a shell: running a bundled script, invoking a
CLI, or a pipeline whose output the body then reads.

## Five quality failures

Name the failure before editing — the fixes point in different directions.

| Failure | Looks like | Fix |
|---|---|---|
| Premature completion | the run stops with the goal unmet and reports success | sharpen the completion criterion; split the sequence only if that is not enough |
| Duplication | one rule stated in two sections | delete one, point at the other |
| Sediment | a rule nobody can date, describing a workflow that changed | delete it, or re-verify and re-anchor it |
| Sprawl | one body carrying procedures called at different moments | split by invocation moment |
| No-op prose | encouragement, restated defaults, "be careful" | delete; if unsure, run once without it |

## Naming

The skill name is the pointer a person reads in a menu. Two rules:

- A bare common noun (`new`, `ask`, `setup`, `check`) says nothing once the plugin prefix scrolls
  away. Name the object: `bootstrap-project`, not `new`.
- Two skills in one plugin must not need their descriptions read to tell them apart. If the names
  do not separate them, either the names or the split is wrong.

A name that exists to avoid colliding with a command of the same name is a justified exception —
`docs-forge`'s `-guide` suffixes are that case, not drift.
