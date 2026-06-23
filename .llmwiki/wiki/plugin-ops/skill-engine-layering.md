---
id: skill-engine-layering
aliases: [skill-on-skill-engine, bare-name-engine-reference, cross-marketplace-dependency, ppt-yeong-style-ppt-master]
last_verified: 2026-06-23
status: active
volatility: stable
sources: 3
---

# Skill-on-skill engine layering

A skill can be a thin *writing / convention layer* on top of another skill's *engine* (the implementation owner) instead of reimplementing the build itself. `ppt-yeong-style` is such a layer on the `ppt-master` engine — it owns "what to write and how", `ppt-master` owns "how to build it". The layering contract:

- **Reference the engine by bare name — never vendor or copy it.** Details the layer does not specify defer to the engine's own SKILL.md. Duplicating the engine's scripts/templates into the layer plugin forks maintenance and silently drifts from the engine.
- **"Copy" includes reproducing the engine's internal API in *prose*, not just files.** Hardcoding the engine's exact script names, dev-server ports, Strategist step ordinals, `design_spec` section numbers, or layout enum values into the layer's text drifts the moment the engine version renames them. Reference the lever *concept* + the stable contract keys (spec_lock field names like `page_rhythm` / `page_layouts` / `image_rendering`) and mark the engine's SKILL.md as the source of truth for exact values — the layer carries the *judgment* (what to combine, when), the engine owns the *mechanism*.
- **Optional dependency skills graceful-degrade** — use if installed, manual fallback if absent (e.g. `codex-image`, `interview`, `anti-slop-design`, `humanize-korean`, `design-shotgun`). The convention still holds when these are missing; only the assisted step degrades to manual.
- **A HARD engine dependency is NOT a graceful-degrade target.** When the engine lives in a *separate marketplace* (not shipped by this repo), installing the layer plugin alone does not pull the engine. A fresh install triggers the layer skill, but the build step has no engine and blocks. The layer must **stop before the build step and guide engine installation** (an explicit prerequisite-stop), not silently fail and not try to hand-substitute the whole engine.

Why this is easy to miss: in the *author's* environment the engine is already installed, so the build runs end-to-end and the gap is invisible. It only surfaces on a clean install of just the layer plugin — exactly the scenario marketplace exposure creates. The reflex to make every dependency "graceful-degrade" is wrong here: a degrade path for the core engine would mean hand-building what the engine exists to build.

> See-also: [[dual-surface-command-skill-pattern]]

## Sources

- PR #72 — `plugins/ppt-yeong-style/` (writing layer on the `ppt-master` engine); merged `skills/ppt-yeong-style/SKILL.md` §엔진·의존 encodes the bare-name reference + required-engine prerequisite-stop.
- Codex P1 review on PR #72 — flagged the fresh-install build-block (`ppt-master` absent from `plugins/` and both `marketplace.json` files), motivating the prerequisite-stop guard over graceful-degrade.
- PR #74 — `ppt-yeong-style` v0.2.0 deck-review pass; the merged `references/ppt-master-craft.md` "SOT 주의" note ("이름은 hook으로만 쓰고, 동작 세부는 ppt-master에서 확인") and the SKILL.md change from the `page_rhythm`(anchor/dense/breathing) enum to a `§3b 리듬` concept-reference encode the no-reproduce-internal-API facet — a 2nd dogfood of the bare-name/no-copy contract.
