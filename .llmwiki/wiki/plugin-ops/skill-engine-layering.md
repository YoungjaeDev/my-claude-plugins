---
id: skill-engine-layering
aliases: [skill-on-skill-engine, bare-name-engine-reference, cross-marketplace-dependency, ppt-yeong-style-ppt-master]
last_verified: 2026-06-23
status: active
volatility: stable
sources: 2
---

# Skill-on-skill engine layering

A skill can be a thin *writing / convention layer* on top of another skill's *engine* (the implementation owner) instead of reimplementing the build itself. `ppt-yeong-style` is such a layer on the `ppt-master` engine — it owns "what to write and how", `ppt-master` owns "how to build it". The layering contract:

- **Reference the engine by bare name — never vendor or copy it.** Details the layer does not specify defer to the engine's own SKILL.md. Duplicating the engine's scripts/templates into the layer plugin forks maintenance and silently drifts from the engine.
- **Optional dependency skills graceful-degrade** — use if installed, manual fallback if absent (e.g. `codex-image`, `interview`, `anti-slop-design`, `humanize-korean`, `design-shotgun`). The convention still holds when these are missing; only the assisted step degrades to manual.
- **A HARD engine dependency is NOT a graceful-degrade target.** When the engine lives in a *separate marketplace* (not shipped by this repo), installing the layer plugin alone does not pull the engine. A fresh install triggers the layer skill, but the build step has no engine and blocks. The layer must **stop before the build step and guide engine installation** (an explicit prerequisite-stop), not silently fail and not try to hand-substitute the whole engine.

Why this is easy to miss: in the *author's* environment the engine is already installed, so the build runs end-to-end and the gap is invisible. It only surfaces on a clean install of just the layer plugin — exactly the scenario marketplace exposure creates. The reflex to make every dependency "graceful-degrade" is wrong here: a degrade path for the core engine would mean hand-building what the engine exists to build.

> See-also: [[dual-surface-command-skill-pattern]]

## Sources

- PR #72 — `plugins/ppt-yeong-style/` (writing layer on the `ppt-master` engine); merged `skills/ppt-yeong-style/SKILL.md` §엔진·의존 encodes the bare-name reference + required-engine prerequisite-stop.
- Codex P1 review on PR #72 — flagged the fresh-install build-block (`ppt-master` absent from `plugins/` and both `marketplace.json` files), motivating the prerequisite-stop guard over graceful-degrade.
