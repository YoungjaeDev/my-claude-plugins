---
id: skill-engine-layering
aliases: [skill-on-skill-engine, bare-name-engine-reference, cross-marketplace-dependency, ppt-yeong-style-ppt-master]
last_verified: 2026-07-02
status: active
volatility: stable
sources: 5
---

# Skill-on-skill engine layering

A skill can be a thin *writing / convention layer* on top of another skill's *engine* (the implementation owner) instead of reimplementing the build itself. `ppt-yeong-style` is such a layer on the `ppt-master` engine — it owns "what to write and how", `ppt-master` owns "how to build it". The layering contract:

- **Reference the engine by bare name — never vendor or copy it.** Details the layer does not specify defer to the engine's own SKILL.md. Duplicating the engine's scripts/templates into the layer plugin forks maintenance and silently drifts from the engine.
- **"Copy" includes reproducing the engine's internal API in *prose*, not just files.** Hardcoding the engine's exact script names, dev-server ports, Strategist step ordinals, `design_spec` section numbers, or layout enum values into the layer's text drifts the moment the engine version renames them. Reference the lever *concept* + the stable contract keys (spec_lock field names like `page_rhythm` / `page_layouts` / `image_rendering`) and mark the engine's SKILL.md as the source of truth for exact values — the layer carries the *judgment* (what to combine, when), the engine owns the *mechanism*.
- **Optional dependency skills graceful-degrade** — use if installed, manual fallback if absent (e.g. `codex-image`, `interview`, `anti-slop-design`, `humanize-korean`, `design-shotgun`). The convention still holds when these are missing; only the assisted step degrades to manual.
- **A HARD engine dependency is NOT a graceful-degrade target.** When the engine lives in a *separate marketplace* (not shipped by this repo), installing the layer plugin alone does not pull the engine. A fresh install triggers the layer skill, but the build step has no engine and blocks. The layer must **stop before the build step and guide engine installation** (an explicit prerequisite-stop), not silently fail and not try to hand-substitute the whole engine.

Why this is easy to miss: in the *author's* environment the engine is already installed, so the build runs end-to-end and the gap is invisible. It only surfaces on a clean install of just the layer plugin — exactly the scenario marketplace exposure creates. The reflex to make every dependency "graceful-degrade" is wrong here: a degrade path for the core engine would mean hand-building what the engine exists to build.

- **Periodic re-audit, not just initial authoring.** The engine evolves independently of the layer, so a layer's SOT-pointer prose can go stale or incomplete *after* it was accurate at authoring time — re-verify the layer's claims against the engine's actual current source tree periodically, not only when first writing the layer. A full file-tree audit of `ppt-master` surfaced two concrete drift/gap modes in `ppt-yeong-style`, neither caught by the earlier authoring passes: (1) **missing lever coverage** — the layer's aesthetic signature had no mapping onto the engine's own `visual_style` catalog at all, so the engine's Strategist could auto-pick an unrelated stock preset instead of the intended signature; (2) **inaccurate mechanism claim** — a lever was documented as locked via the engine's `spec_lock` field when that field is only populated under one specific `image_usage` path, and the layer's own configuration routes through a different path, so the field likely never gets written. Both were caught only by re-reading the engine's actual reference files end-to-end, not by re-reading the layer's own prose.

- **Declared mirrors fan out in the same edit.** A layer often keeps hand-maintained mirrors of its SOT — a references file carrying a section's detail, a standalone injection payload ("1:1 압축판"), a README feature section. Every one of them is a sync surface: a dogfooded review cycle on such a layer produced findings that were **4/4 mirror/doc-sync gaps and 0/4 new-idea critiques** (an enum list complete in one home but missing a member in another; a new gate conflicting with a boundary documented in a different section; a fix landing in the SOT but not the standalone mirror; user docs still stating the superseded policy after the skill changed). Drift also runs in reverse — a mirror can carry a rule the SOT never had. Rule: when a rule changes, grep its key tokens across the plugin + user docs and fan the edit out to every declared mirror home **in the same commit**; reviewer re-review is the backstop that catches misses, not the mechanism that prevents them.

> See-also: [[dual-surface-command-skill-pattern]]

## Sources

- PR #72 — `plugins/ppt-yeong-style/` (writing layer on the `ppt-master` engine); merged `skills/ppt-yeong-style/SKILL.md` §엔진·의존 encodes the bare-name reference + required-engine prerequisite-stop.
- Codex P1 review on PR #72 — flagged the fresh-install build-block (`ppt-master` absent from `plugins/` and both `marketplace.json` files), motivating the prerequisite-stop guard over graceful-degrade.
- PR #74 — `ppt-yeong-style` v0.2.0 deck-review pass; the merged `references/ppt-master-craft.md` "SOT 주의" note ("이름은 hook으로만 쓰고, 동작 세부는 ppt-master에서 확인") and the SKILL.md change from the `page_rhythm`(anchor/dense/breathing) enum to a `§3b 리듬` concept-reference encode the no-reproduce-internal-API facet — a 2nd dogfood of the bare-name/no-copy contract.
- PR #87 — `ppt-yeong-style` mode/visual_style lever-alignment pass; a full re-audit of the installed `ppt-master` plugin's file tree (not just its `SKILL.md`) found the missing `visual_style` lock and the `image_usage`-scoped `spec_lock` field claim, both corrected in `references/design-language.md` + `references/ppt-master-craft.md` — a 3rd dogfood, and the first to surface the periodic-re-audit facet.
- PR #91 (merged 7be395d) — `ppt-yeong-style` layout-gate pass; all 4 applied review findings (CR+Codex) were mirror-sync gaps across `SKILL.md` / `references/ppt-master-and-qa.md` / `assets/injection-prompt.md` / `README.md`, plus the injection mirror carrying a consecutive-layout ban the SOT lacked — the declared-mirror fan-out facet's dogfood.
