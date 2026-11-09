# Skill structure

Where text and files go. `writing-levers.md` covers why a line stays; this file covers shape.

## Skill shape

A SKILL.md holds five things, under headings named for what the reader does with them. Omit any
with nothing to say, since an empty heading is a promise the body does not keep.

1. `# Title` and a first paragraph: what the skill is, with a number (a budget, a count, a limit).
2. Core model: the problem and the shape of the answer, including the conditions that mean *not*
   this skill, which stop a general skill from swallowing every adjacent request.
3. Output shape: what the run produces and where.
4. Bright lines: what the run never does, each next to the step it guards.
5. Done condition: how the caller knows the run succeeded.

Step prose goes to `references/procedure.md`, keyed by step number, and SKILL.md says to read it
before the first step. Code goes to `references/run-blocks.md` or `scripts/`.

## Length

The budget is bytes of the whole file, frontmatter included: 5KB target, 10KB cap, both measured
by `docs:md-audit` (`../../../references/writing-standard.md` has the rules). Length is a symptom,
not the disease: an oversized body is usually one skill doing several jobs, or a body that inlined
a reference.

Split by *invocation moment*: two procedures a person calls at different times are two skills,
even when they share subject matter.

## Bundled directories

| Directory | Holds | Loaded |
|---|---|---|
| `scripts/` | non-obvious logic the model should not re-derive each run | executed by the body |
| `references/` | bulky or branch-specific material | read on demand by the body |
| `assets/` | files that end up in the output (templates, examples) | copied or filled |

`references/` is exactly one level deep: files sit directly under it. A nested path is a sign that
a reference has become its own skill.

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
