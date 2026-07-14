# Skill content-structure quality audit (issue #117)

**AUDIT-ONLY.** This artifact measures and grades the content structure of every plugin skill. It changes no skill. The restructure work it lists is deferred to PR #118. The only normative change shipped alongside this audit is a one-line delegation principle added to `.claude/rules/dual-integration.md` and mirrored in `AGENTS.md` (see [Delegation findings](#delegation-findings)).

## At a glance

- **52 skills measured** mechanically (no LLM): line count, body-token estimate, frontmatter description length, section count, `references/` depth, `scripts/` presence. Full table below; raw CSV in [`skill-measurements.csv`](skill-measurements.csv); regenerate with `node docs/audit/measure-skills.mjs`.
- **4 mechanical violators**: 2 over the 500-line best-practice ceiling (`slidev/create-slide` 844, `github-dev/cr-fix` 649), 2 with a `references/` subdirectory at depth 2 (`ml-toolkit/cv-explorer`, `ml-toolkit/cv-notebook`). Zero description-length violations (Codex silent-skip cap 1024), but 2 near-cap watch items (`github-dev/post-merge` 1014, `project-init/wiring` 925).
- **14 skills got a 5-axis LLM verdict** — the 4 violators plus the 10 largest by line count / body-token cost. Result: **2 grade-C** (`github-dev/resolve-issue`, `slidev/create-slide`), **12 grade-B**, no A, no D.
- **2 delegation correctness gaps** (`github-dev/resolve-issue`, `tcrei-prompt/tcrei-prompt`) put subagent dispatch on the primary path with no inline fallback — they cannot run on Codex 0.135 / Hermes, which have no agents surface. These motivate the one-line principle this PR ships.

```
                        52 skills measured (mechanical)
                                    |
              +---------------------+----------------------+
              |                                            |
      4 mechanical violators                    10 largest (line/token)
      (2 line>500, 2 ref-depth>1)                          |
              +---------------------+----------------------+
                                    |
                    14-skill LLM verdict cohort (5 axes)
                                    |
              +---------------------+----------------------+
              |                     |                      |
        2 grade-C            12 grade-B            2 INVERTED delegation
      (restructure)        (minor cleanup)      (cross-runtime correctness)
                                    |
                          restructure worklist -> PR #118
```

| Section | Question it answers |
|---|---|
| Method | How was each number produced, and who was verdicted vs skipped |
| Mechanical sweep | Per-skill measurements for all 52; which cross a threshold |
| LLM verdict table | 5-axis grade for the 14-skill cohort |
| Restructure worklist | Ranked, actionable to-do for PR #118, with a delegation-candidate column |
| Delegation findings | The Claude-only-acceleration principle and the two skills that violate it |
| Glossary | Term definitions |

## Method

**Mechanical sweep (no LLM), all 52 skills.** `docs/audit/measure-skills.mjs` (Node 18+ built-ins, no deps) walks `plugins/*/skills/*/SKILL.md` and records, per skill: `lines`, `body_tokens` (chars/4 estimate of the whole file), `desc_chars` / `desc_tokens` (frontmatter `description`), `sections` (`## `/`### ` headings), `ref_files` + `ref_depth` (max path depth under `references/`; 1 = files sit directly in `references/`), `has_scripts`. Violation columns flag `lines > 500`, `desc > 1024`, `ref_depth > 1`.

Thresholds and their source:
- **500-line ceiling** — the widely-cited SKILL.md best-practice ceiling (progressive disclosure: keep the body a lean procedure, push depth to `references/`). Over 500 lines the body is almost certainly carrying reference-grade material it should offload.
- **1024-char description cap** — Codex 0.135 *silently* skips any skill whose frontmatter `description` exceeds 1024 chars (documented in `.claude/rules/dual-integration.md`). Claude Code has no such limit, so a violation is invisible on the Claude side.
- **`references/` depth exactly 1** — the flat-references convention; a nested subdir (`references/templates/…`) is depth 2.
- **~8k / ~2% skills-list budget** — the aggregate of all skill `description`s is what a runtime loads into the skills list. Current aggregate is ~5978 desc-tokens across 52 skills, comfortably under an ~8k budget; this is a fleet-level check, not a per-skill gate.

**LLM verdict, cohort only.** Per the measurement-first design (issue #117), the 5-axis rubric was applied only to the 4 mechanical violators plus the 10 largest skills — a 14-skill cohort — not to all 52. Three reviewer subagents (read-only, one per subset) read each SKILL.md in full and returned a per-axis grade with file-cited evidence; this document synthesizes them. The rubric axes:

- **(a) append-rot** — session-appended rule paragraphs eroding structure; is it a rule-doc or a running log? Signs: `[NEW]` stamps, decimal steps wedged between integers, dated/PR provenance inline, the same rule restated in scattered spots.
- **(b) hierarchy / progressive disclosure** — body = lean procedure; deep detail pushed to `references/` at depth 1; sections split by "when is this read".
- **(c) communicative force** — rules carry when-to-apply + why, not bare imperative lists; tables/examples used where they help.
- **(d) generality** — would the skill work outside this repo/user? No hardcoded absolute paths, usernames, or dogfood-only assumptions.
- **(e) delegation split** — is the main-body vs `scripts/` vs `references/` split right, and would any phase benefit from an OPTIONAL Claude-side subagent? Hard constraint: Codex 0.135 and Hermes have no agents surface, so subagent delegation is Claude-only acceleration — the inline cross-runtime path must stay primary, and skill logic must never move into an agent definition.

## Mechanical sweep — all 52 skills

Sorted by line count descending. `v_lines` / `v_desc` / `v_refdepth` = 1 marks a threshold crossing.

| plugin | skill | lines | body_tokens | desc_chars | desc_tokens | sections | ref_files | ref_depth | has_scripts | v_lines | v_desc | v_refdepth |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| slidev | create-slide | 844 | 5517 | 282 | 71 | 40 | 9 | 1 | 0 | 1 | 0 | 0 |
| github-dev | cr-fix | 649 | 9448 | 662 | 166 | 33 | 12 | 1 | 1 | 1 | 0 | 0 |
| github-dev | resolve-issue | 418 | 5388 | 630 | 158 | 23 | 0 | 0 | 0 | 0 | 0 | 0 |
| rules-forge | write-rules | 404 | 4445 | 518 | 130 | 16 | 0 | 0 | 0 | 0 | 0 | 0 |
| tcrei-prompt | tcrei-prompt | 368 | 2908 | 334 | 84 | 26 | 1 | 1 | 0 | 0 | 0 | 0 |
| github-dev | update-progress | 329 | 3134 | 543 | 136 | 9 | 0 | 0 | 0 | 0 | 0 | 0 |
| brightdata-guide | brightdata-guide | 325 | 4818 | 717 | 179 | 29 | 3 | 1 | 0 | 0 | 0 | 0 |
| github-dev | decompose-issue | 301 | 3356 | 581 | 145 | 13 | 0 | 0 | 0 | 0 | 0 | 0 |
| interview | interview-methodology | 292 | 3006 | 268 | 67 | 41 | 0 | 0 | 0 | 0 | 0 | 0 |
| github-dev | post-merge | 286 | 6084 | 1014 | 254 | 21 | 4 | 1 | 0 | 0 | 0 | 0 |
| llm-wiki | lint-wiki | 281 | 4639 | 278 | 70 | 11 | 0 | 0 | 0 | 0 | 0 | 0 |
| ml-toolkit | cv-explorer | 229 | 2710 | 372 | 93 | 27 | 5 | 2 | 0 | 0 | 0 | 1 |
| project-init | wiring | 222 | 5046 | 925 | 231 | 16 | 0 | 0 | 0 | 0 | 0 | 0 |
| llm-wiki | ingest-finding | 213 | 4109 | 302 | 76 | 18 | 0 | 0 | 0 | 0 | 0 | 0 |
| github-dev | release | 211 | 1927 | 562 | 141 | 7 | 0 | 0 | 0 | 0 | 0 | 0 |
| code-scout | research-orchestrator | 210 | 3093 | 896 | 224 | 20 | 2 | 1 | 0 | 0 | 0 | 0 |
| ppt-yeong-style | ppt-yeong-style | 204 | 4057 | 592 | 148 | 16 | 6 | 1 | 0 | 0 | 0 | 0 |
| tally-form | tally-form | 197 | 2600 | 727 | 182 | 17 | 5 | 1 | 1 | 0 | 0 | 0 |
| translator | translate-web-article | 195 | 1065 | 310 | 78 | 21 | 1 | 1 | 1 | 0 | 0 | 0 |
| ml-toolkit | gradio-cv-app | 183 | 1682 | 338 | 85 | 17 | 4 | 1 | 0 | 0 | 0 | 0 |
| code-scout | resource-finder | 177 | 1605 | 334 | 84 | 14 | 2 | 1 | 1 | 0 | 0 | 0 |
| codex-image | codex-image | 175 | 3452 | 468 | 117 | 8 | 0 | 0 | 0 | 0 | 0 | 0 |
| ml-toolkit | cv-notebook | 165 | 1761 | 407 | 102 | 20 | 9 | 2 | 0 | 0 | 0 | 1 |
| llm-wiki | migrate-wiki | 153 | 2312 | 379 | 95 | 14 | 0 | 0 | 0 | 0 | 0 | 0 |
| code-scout | exa-web-search | 145 | 2083 | 304 | 76 | 12 | 0 | 0 | 0 | 0 | 0 | 0 |
| ml-toolkit | gpu-parallel-pipeline | 137 | 1513 | 480 | 120 | 8 | 3 | 1 | 1 | 0 | 0 | 0 |
| anti-slop-design | anti-slop-design | 132 | 1972 | 792 | 198 | 17 | 3 | 1 | 0 | 0 | 0 | 0 |
| e2e-harness | e2e-setup | 125 | 2653 | 683 | 171 | 3 | 0 | 0 | 0 | 0 | 0 | 0 |
| github-dev | commit-and-push | 113 | 1209 | 466 | 117 | 10 | 0 | 0 | 0 | 0 | 0 | 0 |
| spec-state | state-tracker | 108 | 1196 | 300 | 75 | 10 | 0 | 0 | 0 | 0 | 0 | 0 |
| llm-wiki | bootstrap-wiki | 94 | 1895 | 256 | 64 | 4 | 0 | 0 | 0 | 0 | 0 | 0 |
| ppt-yeong-style | lecture-deck | 87 | 1308 | 365 | 91 | 10 | 1 | 1 | 0 | 0 | 0 | 0 |
| docs-forge | changelog-guide | 81 | 404 | 157 | 39 | 13 | 0 | 0 | 0 | 0 | 0 | 0 |
| paper-search-tools | paper-search-usage | 81 | 744 | 223 | 56 | 7 | 0 | 0 | 0 | 0 | 0 | 0 |
| gws-sync | gws-sync | 80 | 1267 | 380 | 95 | 6 | 1 | 1 | 0 | 0 | 0 | 0 |
| llm-wiki | query-wiki | 75 | 1616 | 350 | 88 | 7 | 0 | 0 | 0 | 0 | 0 | 0 |
| docs-forge | readme-guide | 67 | 413 | 144 | 36 | 7 | 0 | 0 | 0 | 0 | 0 | 0 |
| e2e-harness | e2e-debug | 67 | 1244 | 693 | 173 | 3 | 0 | 0 | 0 | 0 | 0 | 0 |
| ml-toolkit | ml-dev-principles | 66 | 1013 | 633 | 158 | 8 | 0 | 0 | 0 | 0 | 0 | 0 |
| project-init | new | 65 | 1191 | 723 | 181 | 3 | 0 | 0 | 0 | 0 | 0 | 0 |
| github-dev | create-issue-label | 55 | 568 | 401 | 100 | 8 | 0 | 0 | 0 | 0 | 0 | 0 |
| docs-forge | moc-guide | 52 | 578 | 225 | 56 | 7 | 0 | 0 | 0 | 0 | 0 | 0 |
| ppt-yeong-style | deck-review | 52 | 791 | 378 | 95 | 5 | 0 | 0 | 0 | 0 | 0 | 0 |
| e2e-harness | e2e-author | 51 | 1249 | 665 | 166 | 3 | 0 | 0 | 0 | 0 | 0 | 0 |
| mem0-ops | cleanup | 50 | 646 | 441 | 110 | 2 | 0 | 0 | 0 | 0 | 0 | 0 |
| notebook | edit-notebook | 48 | 358 | 217 | 54 | 6 | 0 | 0 | 0 | 0 | 0 | 0 |
| mem0-ops | doctor | 39 | 517 | 465 | 116 | 2 | 0 | 0 | 0 | 0 | 0 | 0 |
| mem0-ops | fleet-scan | 39 | 471 | 447 | 112 | 2 | 0 | 0 | 0 | 0 | 0 | 0 |
| docs-forge | deploy-doc-guide | 33 | 553 | 242 | 61 | 3 | 0 | 0 | 0 | 0 | 0 | 0 |
| paper-search-tools | setup | 26 | 218 | 203 | 51 | 3 | 0 | 0 | 0 | 0 | 0 | 0 |
| deepwiki | generate-llmstxt | 22 | 395 | 338 | 85 | 1 | 0 | 0 | 0 | 0 | 0 | 0 |
| deepwiki | ask | 20 | 487 | 473 | 118 | 1 | 0 | 0 | 0 | 0 | 0 | 0 |

Aggregate: 52 skills, 9041 total lines (median 137, max 844), ~116.7k total body-tokens (median 1682), ~5978 aggregate desc-tokens vs the ~8k skills-list budget, 17 skills with a `references/` dir.

### Threshold crossings

| Kind | Skills |
|---|---|
| Line ceiling (`lines > 500`) | `slidev/create-slide` (844), `github-dev/cr-fix` (649) |
| `references/` depth > 1 | `ml-toolkit/cv-explorer` (`templates/` 1 file), `ml-toolkit/cv-notebook` (`templates/` 5 files) |
| Description near-cap (900-1024, watch) | `github-dev/post-merge` (1014, only 10 chars of headroom), `project-init/wiring` (925) |
| Description over cap (> 1024) | none |

## LLM verdict table — 14-skill cohort

Grade key: **A** clean, **B** minor cleanup, **C** needs restructure, **D** major rework. Axis key: OK / **m** MINOR / **M** MAJOR.

| plugin/skill | append-rot | hierarchy | force | generality | delegation | grade |
|---|---|---|---|---|---|---|
| github-dev/resolve-issue | **M** | **M** | m | OK | **INVERTED** | **C** |
| slidev/create-slide | m | **M** | OK | OK | opt-in (Phase 2) | **C** |
| github-dev/cr-fix | m | m | OK | OK | opt-in (Step 9c) | B |
| github-dev/post-merge | OK | OK | OK | m (desc near-cap) | opt-in (Step 6/7) | B (A-) |
| github-dev/decompose-issue | OK | m | OK | OK | opt-in (Step 4/5) | B |
| github-dev/update-progress | OK | m | OK | OK | none | B |
| rules-forge/write-rules | OK | m | OK | OK | opt-in (SPLIT/REORG) | B |
| tcrei-prompt/tcrei-prompt | OK | OK | OK | OK | **INVERTED** | B |
| brightdata-guide/brightdata-guide | m | m | OK | OK | none (run as subagent) | B |
| interview/interview-methodology | m | m | OK | OK | none | B |
| llm-wiki/lint-wiki | m | m | OK | OK | already opt-in (correct) | B (C-) |
| ml-toolkit/cv-explorer | OK | m (ref-depth) | OK | OK | none | B |
| ml-toolkit/cv-notebook | OK | m (ref-depth) | OK | OK | none | B |
| project-init/wiring | OK | m | OK | OK | none | B |

Notable per-skill evidence (full reviewer notes distilled):

- **resolve-issue (C)** — pervasive `[NEW]` accretion stamps and decimal steps wedged between integers (append-rot MAJOR); 418 lines with zero `references/` while State Management schema, Verification Gates, and the 2-Stage Review Protocol sit inline (hierarchy MAJOR); Task-subagent dispatch is the *only* mechanism for the Explore / implement / test / review phases with no inline fallback (delegation INVERTED).
- **create-slide (C)** — 844 lines beside a 9-file `references/` the body ignores: it inlines `uno.config.ts`, scoped CSS, Code-Block/Mermaid, Animations, and two full example decks (~590 offloadable lines) that mostly already exist in `references/` (hierarchy MAJOR); the anti-AI rule is restated three times (append-rot MINOR).
- **post-merge (B, borderline A)** — clean structure and good offload; the only blemish is a 1014/1024-char description with 10 chars of headroom before Codex silently skips the whole skill.
- **tcrei-prompt (B)** — otherwise clean, but Phase 3 self-verification exists solely as a `Task(subagent_type="claude", model="haiku")` dispatch, so verification cannot run at all on Codex/Hermes (delegation INVERTED — a correctness gap, not cleanup).
- **cv-explorer / cv-notebook (B)** — both violate depth-1 via `references/templates/`. cv-explorer's is a *single* file (genuine over-nesting → flatten and drop the dir); cv-notebook's is a cohesive 5-file task-template grouping (→ flatten with a `templates-` filename prefix to keep the cluster at depth 1).
- **lint-wiki (B, borderline C)** — the header frames "the 4 wiki-rot failure modes" but the body has grown to 13 steps (append-rot MINOR); 13 heavy inline bash blocks and no bundled `scripts/` (hierarchy MINOR). Its multi-agent-lint section is a correctly-bounded opt-in delegation (inline single-pass stays primary).

## Restructure worklist (feeds PR #118)

Ranked by consumer surface (Tier 1 = core dogfood workflow invoked on nearly every PR; Tier 2 = frequent authoring/ops; Tier 3 = specialized), then by severity. **Priority** folds in hard mechanical violations and delegation correctness gaps. This is the deferred work — none of it is done in this PR.

| # | plugin/skill | tier | grade | mechanical violation | delegation-candidate | restructure action |
|---|---|---|---|---|---|---|
| 1 | github-dev/resolve-issue | 1 | C | — | INVERTED → make inline primary | Strip all `[NEW]` markers and renumber steps to sequential integers; extract State Management + Verification Gates + 2-Stage Review Protocol into `references/` (depth 1); reframe the Explore/implement/test/review subagent dispatches as OPT-IN accelerators wrapping an inline Serena/Bash path that stays primary |
| 2 | github-dev/cr-fix | 1 | B | lines 649 > 500 | opt-in (Step 9c per-finding) | Hoist the `v2 changes` changelog block + dated dogfood iter-citations into `references/lessons-from-dogfood.md`; trim inline bash comment-essays the `scripts/` already document; pull body under ~500 lines |
| 3 | github-dev/post-merge | 1 | B (A-) | desc 1014 (near-cap) | opt-in (Step 6/7 config) | Trim the description ~40-60 chars to restore Codex silent-skip headroom; no structural change needed |
| 4 | github-dev/decompose-issue | 1 | B | — | opt-in (Step 4/5 analysis) | Extract the project-tracking JSON schema + Issue Template + Milestone/Verification guidelines into `references/`, single-sourcing the schema shared with update-progress |
| 5 | github-dev/update-progress | 1 | B | — | none | Extract Diagram Generation (M-1/M-2/Mermaid Rules) + State File Schema into `references/`, single-sourcing the schema shared with decompose-issue |
| 6 | slidev/create-slide | 2 | C | lines 844 > 500 | opt-in (Phase 2 per-section) | Offload inline reference material (uno.config.ts, scoped CSS, Code-Block/Mermaid, Animations) and the two full example decks to `references/` (most already exist there); cut body to phased procedure + tables + pointers, target < 400 lines |
| 7 | tcrei-prompt/tcrei-prompt | 2 | B | — | INVERTED → make inline primary | Add an inline Phase-3 self-verification path (the 6-criterion check run in-session) as primary, keeping the haiku subagent as optional acceleration — so verification survives on the no-agents runtimes |
| 8 | rules-forge/write-rules | 2 | B | — | opt-in (SPLIT/REORG drafting) | Factor the identical 3-command Verify block (repeated across all four modes) into one shared subsection each mode references |
| 9 | interview/interview-methodology | 2 | B | — | none | Rewrite Critical Rules 3-5 to state their scope inline (deleting the "relaxed by later sections" meta-paragraph + carve-outs); offload the 5-category question bank to `references/question-bank.md` |
| 10 | brightdata-guide/brightdata-guide | 2 | B | — | none | Consolidate the repeated "ask operator to enable group + fall back to scrape_as_markdown" instruction into one canonical block the others reference |
| 11 | llm-wiki/lint-wiki | 2 | B (C-) | — | already opt-in (correct) | Reconcile the "4 failure modes" header with the 13-step body (reframe as "4 core + extended checks"); move the 13 inline bash blocks to a bundled `scripts/lint-checks.sh` so the body describes each check |
| 12 | ml-toolkit/cv-explorer | 3 | B | ref-depth 2 | none | Flatten `references/templates/exploration.md` → `references/exploration-template.md` (single-file de-nest, drop the dir); update the two body pointers |
| 13 | ml-toolkit/cv-notebook | 3 | B | ref-depth 2 | none | Flatten `references/templates/{base,classification,detection,segmentation,vlm}.md` → `references/templates-*.md` (filename prefix preserves the 5-file grouping at depth 1); update body pointers |
| 14 | project-init/wiring | 3 | B | — | none | Optional: extract the deep per-axis rationale to `references/axis-rationale.md`, leaving Steps 0-4 + verdict tables as the lean body — or explicitly accept the self-contained no-references form |

Recurring cross-skill fixes for PR #118 to batch:
- **Shared JSON schema duplication** — the project-tracking state-file schema is copied into both `decompose-issue` and `update-progress`; the extraction (#4, #5) should single-source it.
- **No-`references/` large bodies** — `resolve-issue`, `decompose-issue`, `update-progress`, `interview-methodology`, `wiring` all carry reference-grade schema/protocol/rationale inline with no `references/` dir; the same offload pattern applies to each.
- **Ref-depth flattening** — the two `templates/` violations (#12, #13) take different fixes (drop-the-dir vs prefix-and-flatten) because one is a single file and the other a legitimate grouping.

## Delegation findings

The user directive (2026-07-13) added a delegation axis and a one-line principle. This PR ships that principle; the audit surfaces where it bites.

**Principle (shipped this PR).** Added to `.claude/rules/dual-integration.md` (Claude SSOT) and mirrored in the `AGENTS.md` "멀티런타임 통합" section (Codex/Hermes-readable):

> Keep subagent delegation Claude-only acceleration. A Claude-side subagent dispatch may only wrap a skill phase whose inline cross-runtime path stays primary and complete — never move skill logic into an agent definition (Codex 0.135 and Hermes have no agents surface, so relocated logic silently vanishes for them).

**Why it matters — the two INVERTED cases.** Two skills already violate the principle by putting a subagent on the primary path:
- `github-dev/resolve-issue` — Explore, implement, test, and both review stages dispatch to `Task` subagents with no inline fallback. On Codex/Hermes those phases have nothing to run.
- `tcrei-prompt/tcrei-prompt` — Phase 3 self-verification is *only* a `Task(subagent_type="claude", model="haiku")` dispatch. On the no-agents runtimes, verification silently does not happen.

Both are correctness gaps (the skill under-delivers on a whole runtime), not style — PR #118 should reframe each so an inline path is primary and the subagent is an optional Claude-side wrapper.

**Well-formed reference.** `llm-wiki/lint-wiki`'s "Multi-agent lint (large wikis)" section is the pattern to copy: for wikis over ~30 pages it dispatches one read-only subagent per domain, while the inline single-pass path stays primary and complete for the common case. The remaining opt-in candidates in the worklist (cr-fix Step 9c, post-merge Step 6/7, decompose-issue Step 4/5, create-slide Phase 2, write-rules SPLIT/REORG) are analysis- or draft-heavy phases where a Claude-side subagent *could* be dispatched for context isolation or parallel drafting — always as a wrapper over the still-present inline path, never as the only path.

## Glossary

- **append-rot** — a rule document degrading into a chronological log as sessions bolt on `[NEW]`-stamped paragraphs, decimal steps, and dated provenance instead of integrating them into clean structure.
- **progressive disclosure** — the SKILL.md discipline of keeping the body a lean procedure and pushing deep, read-on-demand detail into `references/` files loaded only when needed.
- **references depth** — how deeply files nest under a skill's `references/` dir; the convention is exactly 1 (files directly in `references/`), and a subdirectory makes it 2.
- **body_tokens** — a rough token estimate (characters / 4) of the whole SKILL.md file; the cost a runtime pays when the skill is invoked and its body loads.
- **skills-list budget** — the aggregate token cost of every skill's frontmatter `description`, which a runtime loads into its skills list; kept within roughly 8k tokens fleet-wide.
- **INVERTED delegation** — a skill phase whose only implementation is a subagent dispatch, with no inline fallback; it silently does nothing on Codex 0.135 / Hermes, which have no agents surface.
- **opt-in delegation** — a phase that runs inline by default but *may* dispatch a Claude-side subagent as an optional accelerator, keeping the inline cross-runtime path primary.
- **consumer surface** — how heavily a skill is invoked across normal use; Tier 1 (core dogfood workflow, nearly every PR) ranks above Tier 3 (specialized) when prioritizing restructure work.
