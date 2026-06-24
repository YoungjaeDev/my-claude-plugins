---
id: cr-fix-yagni-over-engineering-axis
aliases: [cr-fix-over-engineering, real-is-not-apply, refuse-vs-delete-complexity, judgment-yagni-axis]
last_verified: 2026-06-24
status: active
volatility: stable
sources: 2
---

# cr-fix judgment: a real finding can still demand over-engineering — refuse it

The Step 9c autonomous judge scores each reviewer finding before acting. The trap the
original four axes left open: `is_real == real` slid straight to **apply** whenever
the change was `small-safe`. But a reviewer can be *correct* that the code does X and
still propose a speculative abstraction, defensive flexibility for a hypothetical,
premature generalization, or unrequested configurability. A *valid* finding is not a
synonym for a *good* change.

## The fifth axis overrides size

`over_engineering` (`yes`/`no`) judges the **suggestion**, not the surrounding code:
does the *fix being asked for* add complexity nobody requested? A `yes` routes to
**skip, and it overrides `fix_size`** — a pure over-engineering suggestion is dropped
even at `small-safe`. Diff size is the wrong gate (a speculative-generality edit is
cheap to apply and expensive to live with); the right gate is whether the codebase
wanted that complexity at all. This is the surgical-diff / senior-engineer test
applied to *incoming* reviewer suggestions, not just to the author's own diff.

## Refuse here, delete elsewhere — division of labor

cr-fix's surface is reviewer findings, so its YAGNI axis only ever *declines to add*
complexity a reviewer proposes; it does **not** scan for and remove over-engineering
already in the code. That opposite direction is `ponytail-review`'s job — an optional,
separately-installed skill that hunts exclusively for what to delete. cr-fix names it
bare-name + optional (no hard dependency: with ponytail absent, the refuse-only path
still stands). Pairing the two covers both directions without overloading either.

## Sources

- `plugins/github-dev/skills/cr-fix/references/autonomous-judgment.md` — the
  `over_engineering` axis definition, the decision-matrix override row, and the
  refuse-vs-delete rationale.
- `plugins/github-dev/skills/cr-fix/SKILL.md` — Step 9c.4 axis + 9c.5 matrix row +
  the Guidelines YAGNI lens.

> See-also: [[skill-engine-layering]]
