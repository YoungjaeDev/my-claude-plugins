---
id: skill-authoring-source-grounded-then-audit
aliases: [skill-authoring-methodology, source-grounded-skill, coverage-audit, documented-vs-enforced]
last_verified: 2026-07-27
status: active
volatility: stable
sources: 4
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

## 4. Adopt from an external library — gap-fill / reflect / skip, and diff posture not rules

§1-3 are about *building* a skill; this is about *adopting* from someone else's skill library (e.g. `mattpocock/skills`). Triage each candidate three ways, and let the landing shape follow the verdict:

- **gap-filler** — does something the stack genuinely can't. Recommend **installing and using it directly**; porting cost is irrelevant, so do NOT let "it's expensive to port into our marketplace" kill it (that is the wrong axis for a tool you'll just install).
- **insight-reflection** — overlaps an existing skill but carries a mechanism worth merging into ours (a rule, a gate, a topology).
- **skip** — redundant with the stack, personal to the author, or too thin.

The non-obvious trap: **a rule-by-rule diff undersells a famous skill.** `grill-me` (a 6-line stub delegating to a one-paragraph `/grilling`) overlapped our 301-line `interview-methodology` on ~90% of its *rules* — one-question-at-a-time, recommend-an-answer, facts-vs-decisions, a confirmation gate were all already present. Its fame was the opposite default **posture**: relentless-by-default, where ours is restrained-by-default (a whole "When NOT to Interview" escape hatch that actively suppresses grilling). The value lived in the posture and defaults, not the enumerable rules, so the right adoption was a **new mode that inverts the default**, not a port of the skill. Diff the posture and the defaults, not just the rule list — then install-and-use for a real capability gap, merge the mechanism for an overlap, add a mode when only the character differs.

A fourth lane sits outside that triage, for when none of the three fit: **diverge-fork** — take ownership of the source and steer it where upstream would never go. The tell is that the wanted changes are *structural* rather than additive: a rename, cutting the author's funnel (star-prompts, update-check hooks, usage markers), collapsing a 1,400-line SKILL.md, re-designing against your own runtime contract. Two things have to be said out loud before choosing it. A fork does not make upstream updates *faster*, it makes them *zero*, so the real question is whether the skill is a core routine often enough to justify paying the ownership cost forever — "upstream is slow" is a symptom that a fork answers by deleting the dependency, not by speeding it up. And try upstream first: a doc-consistency PR into that same repo the day before showed the other half of the ledger — an external repo cannot run your review loop (its bot configuration belongs to its maintainer) and the merge runs on their clock, which is the evidence for "upstream would never take this", not an assumption about it. The rename is a free side effect rather than mere taste: it dissolves the name collision with the original, so both can stay installed side by side until the fork clears its acceptance bar.

> See-also: [[shared-source-codex-manifests]]
> Evidence: docs/superpowers/specs/2026-06-16-anti-slop-design-skill-design.md
> Evidence: docs/references/anti-slop-design-oss-synthesis.md

## Sources

- PR #63 (`feat/anti-slop-design`, merge `1ea9f41`) — anti-slop-design v0.1.0 build + ultracode coverage audit. Spec + 6-repo synthesis under `docs/`.
- PR #71 (`feat/70-anti-slop-ppt-lane`, merge `c20b26b`) — anti-slop-design v0.2.0 PPT-lane reinforcement; §3 dogfood-harvest + interview-gate discipline, distilled from a real 27-slide KCI deck build.
- PRs #154/#156/#158 — mattpocock/skills adoption batch. §4 adopt-triage + posture-diff, from comparing `grill-me`/`grilling` against `interview:interview-methodology` (landed as the relentless mode in #156; the skill now lives at `docs-forge:interview-methodology` after PR #200).
- `.claude/spec/2026-07-23-adopt-gptaku-team-skill-builder.md` — §4's diverge-fork lane, from the relentless interview that decided to fork `kkirikkiri` / `skillers-suda` into self-governed plugins, plus the Agent-Teams doc PR filed into upstream `fivetaku/kkirikkiri` the day before, which is where the external-repo review-loop limit was observed.
