---
id: skill-authoring-source-grounded-then-audit
aliases: [skill-authoring-methodology, source-grounded-skill, coverage-audit, documented-vs-enforced]
last_verified: 2026-06-18
status: active
volatility: stable
sources: 2
---

# Skill authoring: source-ground, then coverage-audit

Methodology for building a **reference/guidance skill** (a skill whose value is a distilled body of external knowledge — anti-slop rules, API conventions, taxonomies) in this marketplace. Two non-obvious disciplines, both surfaced building `anti-slop-design`.

## 1. Source-ground — read the repos, not summaries-of-summaries

A skill distilled from a chat-assistant summary (ChatGPT/Perplexity) is **2nd-hand**: it is a summary of a summary, and the numbers drift. Investigate the actual source repos / docs and verify claims against the source files, not the README prose:

- `impeccable` README said "27 patterns / 25 detections" but the registry has **44** (`grep -c`).
- `hallmark` README said "57 gates" but source has **58** (1-57 + an inserted 38a).
- A sibling skill's rules were hallucinated onto `anthropics/skills/frontend-design` by a summariser — `frontend-design` itself is font-agnostic.

The build pattern that works: deep-read each source (e.g. a fan-out workflow, one agent per repo via `gh api` + DeepWiki) → synthesize into a `docs/references/<topic>-synthesis.md` that tags convergence (a pattern named by 3+ sources is high-confidence) → distill the synthesis into the shipped skill. The synthesis file is the dated/sourced provenance; the skill body is the rule.

## 2. Coverage-audit the distillation — documented vs ENFORCED

Distilling a large synthesis into a shipped skill **drops things silently**. Run a separate coverage audit (ideally a different pass than the build — the builder misses its own gaps) that maps every convergent pattern in the synthesis to its location in the shipped skill.

The audit's key axis is **documented vs enforced**:

- *documented* = the pattern is in the reference taxonomy (with a detector + fix).
- *enforced* = the pattern is in the **binary ship-gate** the skill actually runs before delivery.

These diverge. `anti-slop-design` shipped with **21/21** convergent patterns documented but only **19/21** enforced in the Phase B binary gate — the hero-metric template and the "italic-serif top AI tell" lived in the reference yet never in the gate, so a reviewer running only the gate would pass them. A reference taxonomy that is complete is NOT the same as a gate that catches the same things; audit the gate surface explicitly, not just the docs.

## 3. Dogfood harvest — interview-gate generic vs project-specific

A reference skill can also grow from your **own dogfooded usage**, not only external OSS. When a real project build surfaces reusable patterns, harvest them — but **interview-gate genericity before merging into the shared plugin**. Triage each candidate generic (→ the plugin lane, marketplace-wide) vs project-specific (→ stays in the origin repo); shipping project-specific rules into a shared plugin pollutes it for every other caller, and the split is easy to skip.

`anti-slop-design` v0.2.0's PPT lane was harvested from a real 27-slide KCI 발표 덱 build. The interview kept only the generic slice — color restraint, audience-function register, and the build-vs-validation scope split (build execution → ppt-master; consistency + pre-delivery render-validation → anti-slop). The operational rules themselves live in the plugin's `slop-taxonomy.md` §3 / `copy-rules.md` §1; the lore here is the *harvest + genericity-gate method*, not the rules.

> See-also: [[shared-source-codex-manifests]]
> Evidence: docs/superpowers/specs/2026-06-16-anti-slop-design-skill-design.md
> Evidence: docs/references/anti-slop-design-oss-synthesis.md

## Sources

- PR #63 (`feat/anti-slop-design`, merge `1ea9f41`) — anti-slop-design v0.1.0 build + ultracode coverage audit. Spec + 6-repo synthesis under `docs/`.
- PR #71 (`feat/70-anti-slop-ppt-lane`, merge `c20b26b`) — anti-slop-design v0.2.0 PPT-lane reinforcement; §3 dogfood-harvest + interview-gate discipline, distilled from a real 27-slide KCI deck build.
