# Wiki Log

Append-only event log for the resolved wiki root (`.llmwiki/wiki/`, or a legacy `.claude/wiki/` if that is what the repo has). Each entry under a `## YYYY-MM-DD — <one-line summary>` header. Newest first.

Every `/ingest-finding` run and every `/github-dev:post-merge` run that executes the wiki ingest step writes a block here **before** touching the page, so `git revert` of the resulting commit cleanly reverses both. (Post-merge skips the ingest — and this log — for trivial merges or when no wiki root resolves.) See `ingest-finding` skill for the diff-log discipline.

---

## 2026-07-02 — post-merge #87: ppt-master lever-alignment as 3rd skill-engine-layering dogfood (post-merge)

- plugin-ops/skill-engine-layering.md: added PR #87 as a 3rd dogfood source; new paragraph on periodic re-audit (a layer's prose can drift/gap even after initial authoring as the engine evolves — re-check against the engine's actual current source, not just at authoring time); two concrete new failure modes recorded (missing lever coverage: ppt-yeong-style's signature had no `visual_style` mapping at all; inaccurate mechanism claim: a lever was described as engine-enforced when it only applies under a different `image_usage` path); sources 3 -> 4; last_verified 2026-07-02.
- index.md: extended the skill-engine-layering hook with the periodic-re-audit facet.

## 2026-07-01 — post-merge #84: Hermes generator + midjourney removal (post-merge)

- plugin-ops/hermes-plugin-adapter.md: updated for PR #84 — adapters now generator-produced (`sync-hermes-manifests.mjs`, 6 HERMES_ELIGIBLE plugins) not hand-written; `plugin.yaml` documented as 5 marketplace-derived fields with the CodeRabbit minimal-manifest decision recorded (kept 5 — drift moot post-generator, `kind: standalone` load-bearing, pilot proves extra fields don't break Hermes); `__init__.py` `yaml.safe_load` try/except hardening; tool-name table expanded (Read/Write, Glob/Grep→search_files, Skill→skill_view, image→image_generate, WebFetch/WebSearch→web_extract/browser_*, NotebookEdit→Jupyter Live Kernel); `${HERMES_SKILL_DIR}`→3-branch revert (Codex caught the var is undocumented/unset on install); version-sync now `--check`-guarded; sources 3→4 (+PR #84, +DeepWiki NousResearch/hermes-agent); last_verified 2026-07-01.
- plugin-ops/shared-source-codex-manifests.md: EXCLUDED 3-member → 2-member (midjourney plugin deleted in PR #84; core-config + codex-image remain); eligible = total − 2; install-skills line drops midjourney.
- plugin-ops/skills-install-wrapper.md: EXCLUDED list → core-config / codex-image (midjourney dropped).
- index.md: shared-source entry EXCLUDED 3→2; skills-install entry drops midjourney; hermes-plugin-adapter entry rewritten for generator-based adapters + expanded tool map + SKILL_DIR revert.
- Staging drain: consumed pending-21b7e3c3 + pending-ccadfa81 (this PR #84's sessions, lore ingested above); cleared already-curated pending-3cf343d1 (PR #72-81) + pending-5419c694 (PR #80-82) as skips (their lore was ingested by their own post-merges).

## 2026-06-30 — post-merge #83: Hermes native plugin adapter (third runtime) (ingest-finding)

- plugin-ops/hermes-plugin-adapter.md: new page (id hermes-plugin-adapter, status active, volatility stable, sources 3). Distills the third-runtime adapter pattern: the shared-source `plugins/<name>/` tree is consumed by Hermes Agent via two hand-written files in the plugin root — `plugin.yaml` (`kind: standalone`) + `__init__.py` entrypoint — installed with `hermes plugins install <owner>/<repo>/plugins/<name> --enable` (github-dev is the pilot; without them install warns). Opt-in skill loading: Hermes plugin-provided skills are NOT auto-exposed in system prompt / skills_list, so callers must `skill_view("<plugin>:<skill>")` and quickstarts cannot use bare slash/text invocation. Runtime-portable bodies extend the shared-source rule with a Claude/Codex→Hermes tool-name map (Bash→terminal, Read→read_file, Edit→patch, AskUserQuestion→clarify, Task→delegate_task, Monitor→process) + dynamic SKILL_DIR (source tree → $HERMES_HOME → ~/.hermes). Version-sync mechanics deliberately NOT restated (routed to .claude/rules/plugin-versioning.md). `> See-also:` shared-source-codex-manifests, skills-install-wrapper.
- plugin-ops/shared-source-codex-manifests.md: added `> See-also: hermes-plugin-adapter` refining the two-runtime (Claude+Codex) framing — a third runtime now consumes the same tree via a native adapter; last_verified 2026-06-30.
- index.md: added the hermes-plugin-adapter hook under plugin-ops.

## 2026-06-25 — post-merge #80: codex-image delegated-CLI bridge design (post-merge)

- plugin-ops/codex-image-bridge-design.md: new page (id codex-image-bridge-design, status active, volatility stable, sources 1). Distills how a Claude skill that delegates to an external CLI (`codex exec` for image gen) is built: (1) inherit the sub-CLI's default model — omit `-m` so it auto-tracks the latest upstream model with zero per-release pin maintenance; `--model` is opt-in only; (2) least-privilege sandbox — default `-s workspace-write` (minimal mode that can still save the PNG), `danger-full-access` / `--dangerously-bypass-approvals-and-sandbox` opt-in only (codex 0.142 exposes no `--yolo` alias for `codex exec`); (3) validate passthrough at the shell trust boundary — `--model` against `^[A-Za-z0-9._:-]+$`, enum-constrain `--reasoning`/`--sandbox` (trailing `-` in a char class is literal; a Codex P2 spuriously read it as excluding hyphens, refuted with bash ERE + python re). `> See-also: codex-image-bridge-design`→`shared-source-codex-manifests`. Evidence: plugins/codex-image/skills/codex-image/SKILL.md.
- index.md: added the codex-image-bridge-design hook under plugin-ops.
- Not graduated to insight: first occurrence (single PR #80) — fails recurs-across-2+-sessions; stays in the wiki layer.
- Routing note: the concurrent-release `metadata.version` collision (PR #77 + #80 both bumped 1.69.0→1.70.0; identical value = no git conflict, so main was left one release short → corrected to 1.71.0) is already covered by `.claude/rules/plugin-versioning.md` Don'ts; recorded there, not duplicated here.

---

## 2026-06-24 — post-merge #79: skills install wrapper (npx skills) lore + EXCLUDED install-scope (post-merge)

- plugin-ops/skills-install-wrapper.md: new page (id skills-install-wrapper, status active, volatility stable, sources 2). Distills `scripts/install-skills.mjs` wrapping `npx skills` (vercel-labs/skills): source arg `.` (reads marketplace.json, groups by plugin), skill selection via *repeated* `-s <name>` (comma fails → "No matching skills found", exit 1), codex global install lands in `~/.agents/skills/<name>/` (not `~/.codex/skills`), Hermes profile targeted by injecting `HERMES_HOME` with one spawn per (agent, profile), and the EXCLUDED-is-manifest-scoped decision (installer filters by skill count, so midjourney/codex-image ARE installable to Codex). `> See-also: skills-install-wrapper`→`shared-source-codex-manifests`. Evidence: scripts/install-skills.mjs.
- plugin-ops/shared-source-codex-manifests.md: added one clause clarifying `EXCLUDED` governs Codex *manifest eligibility*, not *install availability*, plus `> See-also: [[skills-install-wrapper]]`; last_verified 2026-06-23 → 2026-06-24 (EXCLUDED set re-confirmed against the generator this session); sources unchanged (8).
- index.md: added the skills-install-wrapper hook under plugin-ops.
- Not graduated to insight: first occurrence (single PR #79) — fails recurs-across-2+-sessions; stays in the wiki layer.

---

## 2026-06-24 — post-merge #76: cr-fix YAGNI/over-engineering judgment axis (post-merge)

- cr-fix-ops/cr-fix-yagni-over-engineering-axis.md: new page (id cr-fix-yagni-over-engineering-axis, status active, volatility stable, sources 2). Distills the Step 9c 5th axis — a real reviewer finding can still demand unrequested complexity; `over_engineering=yes` skips and overrides `fix_size` (small-safe doesn't save a pure over-engineering suggestion); cr-fix refuses *added* complexity while `ponytail-review` (optional) deletes *existing* — division of labor, bare-name optional dep. `> See-also: skill-engine-layering`. Evidence: PR #76.
- index.md: added the cr-fix-yagni-over-engineering-axis hook under cr-fix-ops.
- Not graduated to insight: first occurrence (single PR #76) — fails recurs-across-2+-sessions; stays in the wiki layer.

## 2026-06-24 — post-merge #75: core-config prompt_inject englishize + federation default off + memory_nudge retired (post-merge)

- llm-wiki-design/mem0-llmwiki-federation.md: corrected the now-stale reversibility claim — `CORE_CONFIG_FEDERATE_MEM0` default flipped 1->0, so federation labels ship OFF and `=1` opts in (was "`=0` reverts", implying default-on); marked the authority section conditional on FEDERATE=1; added `## Retiring a hook that fights the enforced memory system` (memory_nudge.sh retired — its MEMORY.md save-nudge contradicts the mem0 plugin's enforced `block_memory_write.sh` PreToolUse block). `## Sources` += mem0 plugin block_memory_write.sh; sources 2 -> 3; last_verified 2026-06-24.
- plugin-ops/prompt-inject-korean-persistence.md: noted the block was rewritten Korean->English while line 1 still mandates a Korean final reply (English wording stops the model drifting into its own English register while pinning output language); the quoted Korean directive is the original phrasing, the rule now reads in English. last_verified 2026-06-24; sources unchanged at 2.
- index.md: updated the mem0<->llmwiki federation hook — labels off by default (`=1` opts in), not "`=0` reverts".
- Not graduated to insight: federation default + memory_nudge retirement are single-PR design tweaks (fail recurs-across-2+-sessions); stay in the wiki layer.

## 2026-06-23 — post-merge #74: ppt-yeong-style v0.2.0 lore (3 pages) (post-merge)

- plugin-ops/skill-engine-layering.md: 2nd-dogfood refinement — "copy" includes reproducing the engine's internal API *in prose* (exact script names, dev-server ports, Strategist step ordinals, `design_spec` section numbers, layout enum values), not only duplicating files; reference the lever *concept* + stable spec_lock contract keys (`page_rhythm`/`page_layouts`/`image_rendering`) and mark the engine SKILL.md as SOT for exact values. Evidence: PR #74 merged ppt-master-craft.md "SOT 주의" note + SKILL.md §3b enum→concept-reference change. sources 2 -> 3; last_verified 2026-06-23. Not graduated — multi-facet wiki lore, no single crisp promotable rule.
- plugin-ops/shared-source-codex-manifests.md: added `## Skill bodies must be runtime-portable` — a shared skill body that hard-depends on a Claude-only built-in agent (e.g. `claude-code-guide`) in a command/fact-check path is unfollowable under Codex; default to a both-runtime path (official docs), make the Claude-only agent an optional enhancement. Evidence: PR #74 ppt-yeong-style SKILL.md §원칙4 fact-check path. sources 7 -> 8; last_verified 2026-06-23.
- insight/codex-skill-desc-1024.md: added `## CodeRabbit byte-count false positive` — the enforced limit is 1024 *characters* (`desc.length`); CR's description-length finding measures *bytes*, so a Korean (multibyte) description under the char cap but over 1024 bytes is flagged spuriously (ppt-yeong-style: 594 chars / 1049 bytes). Recurred PR #72 + #74 → cr-fix skips when `--check` already passes. last_verified 2026-06-23; evidence_count unchanged at 2 (graduation basis is the real-violation recurrences; the false positive is a complementary skip-rule).
- index.md: extended the skill-engine-layering + shared-source-codex-manifests hooks for the new facets.

## 2026-06-23 — stale-check enforcement covers the insight layer too (ingest-finding)

- llm-wiki-design/volatility-over-decay.md: added `## Enforcement must cover every layer that shares the contract` — the `volatility:`/`last_verified:` window applies to both `.llmwiki/wiki/` and the promoted `.llmwiki/insight/` layer; `wiki_stale_check.sh` was scanning only `.llmwiki/wiki` (insight = silent-rot blind spot), now adds `.llmwiki/insight` when the resolved root is `.llmwiki/wiki`. Generalized rule: a derived layer reusing a freshness contract must sit inside the same enforcement sweep. `## Sources` += the hook script; `> See-also: [[insight-layer-via-hook]]` + `> Evidence:` hook; sources 2 -> 3; last_verified 2026-06-23.
- index.md: volatility-over-decay hook extended to note the sweep covers wiki + insight.
- Not graduated to insight: first occurrence (single PR #73) — fails recurs-across-2+-sessions; stays in the wiki layer.

## 2026-06-23 — skill-on-skill engine layering + cross-marketplace prerequisite-stop (ingest-finding)

- plugin-ops/skill-engine-layering.md: new page (id skill-engine-layering, status active, volatility stable, sources 2). Distills the ppt-yeong-style-on-ppt-master contract — bare-name engine reference (no vendor/copy), optional deps graceful-degrade, but a HARD engine in a separate marketplace is NOT a degrade target: a fresh install of the layer alone has no engine and blocks the build, so stop-before-build + guide install (prerequisite-stop). Invisible in the author's env where the engine is already installed. `> See-also: dual-surface-command-skill-pattern`. Evidence: PR #72 merged SKILL.md §엔진·의존 + Codex P1 fresh-install block. last_verified 2026-06-23.
- index.md: added skill-engine-layering hook under plugin-ops.
- Not graduated to insight: first occurrence (single PR) — fails the recurs-across-2+-sessions criterion; stays in the wiki layer.

## 2026-06-18 — post-merge #71: dogfood-harvest skill-authoring discipline (post-merge)

- plugin-ops/skill-authoring-source-grounded-then-audit.md: added `## 3. Dogfood harvest — interview-gate generic vs project-specific`. A reference skill can grow from your own dogfooded real-project build, not only external OSS; interview-gate each harvested learning generic (-> the shared plugin lane, marketplace-wide) vs project-specific (-> stays in the origin repo) before merging, else the shared plugin is polluted for every other caller. anti-slop-design v0.2.0 PPT lane reflected only the generic slice (color mono / presentation register / build-vs-validation scope + render-validation traps) distilled from a real 27-slide KCI 발표 덱 build; project-specific deck rules stayed in the source repo. Added PR #71 source; sources 1 -> 2; last_verified 2026-06-18.

## 2026-06-17 — harness-engineering principles from the Naver Financial E2E talk (ingest-finding)

- e2e-harness-ops/harness-engineering-principles.md: new page (sources 2 — the talk transcript + the e2e-harness build). Transferable design rationale behind `e2e-harness`: verification is the bottleneck; AI-era bugs cluster at component boundaries (units pass, composed flow breaks); test code = sensor (run) + spec (read); the self-improvement loop (guide before + sensor after) is the delegation criterion; onboard the official agents like a new hire; independent tests via API state-setup; mock by call-site; flake-at-authoring; thinking is delegable but understanding is not; the harness evolves with the model. `> See-also: playwright-ai-harness`.
- insight/harness-loop-guide-sensor.md: promoted the loop principle to insight (promoted_from harness-engineering-principles, evidence_count 2 = talk + e2e-harness build) — "build a self-improvement loop: guide before, sensor after; that question is the delegation criterion." insight/index.md hook added.
- index.md (wiki MOC): added the harness-engineering-principles hook under e2e-harness-ops.
- e2e-harness plugin (recorded for trail, not wiki): enriched e2e-author + the E2E SSOT template with the API state-setup test-independence pattern, and e2e-setup with the "onboard agents like a new hire" rationale; version 0.1.0 -> 0.1.1.

## 2026-06-17 — tally-form per-question choice/required/desc live-verified (PR #68) (ingest-finding)

- tally-form-ops/tally-api-schema-vs-live.md: added a divergence bullet — multi-select checkbox is `CHECKBOX`/`CHECKBOXES` (not `MULTI_SELECT`); `isRequired` rides on each answer block (option / `INPUT_*`), same position as MC/matrix; per-question `desc` is a `TEXT` block after the TITLE (`payload.html`→`safeHTMLSchema` round-trip); short-answer `INPUT_*` follow the lenient `groupType==type` rule. aliases += `tally-checkbox-grouptype`, `tally-required-on-option`; `## Sources` += PR #68 live verification; sources 3 -> 4. last_verified 2026-06-17.
- index.md: hook left unchanged — the existing "OpenAPI diverges from the live /forms API" hook still covers it, and index.md carries an unrelated uncommitted e2e-harness edit in the working tree that must not be bundled into this commit.

<!-- New entries go directly under this line -->

## 2026-06-17 — post-merge #66 + #67: github-dev TDD uplift + e2e-harness plugin (post-merge)

- e2e-harness-ops/playwright-ai-harness.md: new page (domain e2e-harness-ops, parallel to cr-fix-ops/tally-form-ops). Captures Playwright 1.61 `init-agents --loop=claude` actual output (prefixed `playwright-test-*` agent files, `.mcp.json` IS generated with `playwright run-test-mcp-server`, root `seed.spec.ts`, no `playwright.config`, no `copilot` loop value), headless `npx playwright trace` (1.59+) subcommands, burn-in vs CI retries, and GH Actions gotchas (native `paths:` ⊥ `labeled` event, `gh pr comment` needs `issues: write`, no official PR-comment step). sources 2 (playwright.dev + direct 1.61 execution). `> See-also: cr-cli-false-positive-generated-files`.
- index.md: added e2e-harness-ops domain + hook; bumped MOC last_verified 2026-06-10 -> 2026-06-17; rewrote the shared-source hook's stale "19 of 22 eligible" to the durable "all but 3 EXCLUDED" form.
- plugin-ops/shared-source-codex-manifests.md: replaced the hard "19 of 22" eligible count with the durable "total − 3 EXCLUDED" invariant (count shifts on every plugin add/remove); last_verified -> 2026-06-17.
- Config (not wiki, recorded here for the routing trail): added the "update the Codex-eligible count on plugin add/remove" rule to `.claude/rules/plugin-versioning.md` + its `AGENTS.md` mirror — the gap Codex P1 caught on PR #67 (total count bumped, eligible count left stale).
- Staging drain: 7 mechanical Stop-hook captures from prior sessions (PRs 36/62/63/64/65/66/67/68 etc.) skipped — those PRs' post-merge Step 8 already ingested their lore (cr-fix-ops/tally-form-ops/etc. pages exist); the #66/#67 lore is this entry. Consumed files deleted.

## 2026-06-17 — post-merge #65: tally-form v1.1.0 images/redirect — wiki update (post-merge)

- tally-form-ops/tally-api-schema-vs-live.md: consolidated the v2 image/redirect findings into the existing no-media-upload bullet — image URLs must be **https** (http blocked as mixed content on HTTPS forms), and live-confirmed that `logo` (png) + `cover` (animated gif) + inline `IMAGE` + `redirectOnCompletion` publish clean (form `QKEZog`). Extended Evidence + Sources with that form. No new section/page (consolidate-not-append); sources stays 3, last_verified 2026-06-17.

## 2026-06-17 — post-merge #64: tally-form plugin + Tally API schema-vs-live lore (post-merge)

- tally-form-ops/tally-api-schema-vs-live.md: new page + new domain (id `tally-api-schema-vs-live`, status active, volatility volatile, sources 3). Tally OpenAPI diverges from the live `/forms` contract — `groupType` lenient (input blocks accept own type, FORM_TITLE accepts TEXT; two Codex P1s false-positive), matrix single-select `maxChoices` belongs on the `MATRIX` container not `MATRIX_ROW` (live 400 on rows despite the schema listing it), no media-upload endpoint (logo/cover/IMAGE need hosted URLs — public-repo `assets/` + raw link is a host), no create-API thank-you-message field (redirect/email only, email = Pro), API + theme colors + matrix/date/time all free. Field-level specifics stay in the plugin's `references/tally-blocks.md` (not duplicated). last_verified 2026-06-17.
- index.md: new `## tally-form-ops` domain heading + 1-line hook.

## 2026-06-17 — post-merge #63: anti-slop-design skill + source-grounded/coverage-audit methodology (post-merge)

Merge `1ea9f41` (squash). New `anti-slop-design` plugin (v0.1.0): cross-agent guidance skill blocking the AI-generated look (slop) across web/PPT/dashboard/copy, source-grounded in 6 OSS repos. The plugin's WHAT lives in-repo (`plugins/anti-slop-design/skills/anti-slop-design/SKILL.md` + spec + synthesis) — NOT duplicated here. Mechanical tool-rules (YAML frontmatter colon-quote; `.claude/settings.json` `plugins.local` registration surface) routed to `.claude/rules/{dual-integration,plugin-versioning}.md` + `AGENTS.md` (NOT re-recorded here, per knowledge routing). One reusable methodology lesson lands in the wiki.

- plugin-ops/skill-authoring-source-grounded-then-audit.md: NEW page (id `skill-authoring-source-grounded-then-audit`, status active, volatility stable, sources 1) — build a reference/guidance skill from source-grounded OSS investigation (read the repos, not summaries-of-summaries — counts drift: impeccable README "27" vs registry 44, hallmark "57" vs 58), then run a COVERAGE AUDIT of the distillation whose key axis is documented-vs-enforced (anti-slop-design: 21/21 patterns in the reference taxonomy but only 19/21 in the binary ship-gate until patched). Build and verify as separate passes.
- index.md: added plugin-ops/skill-authoring-source-grounded-then-audit.md hook

## 2026-06-16 — cr-fix state-file not self-describing until emit-final-json persists final fields (ingest-finding)

- cr-fix-ops/state-file-self-describing.md: new page, status active, volatility stable, sources 1 — emit-final-json assembled final_state + auto_judge_stats into stdout only, never into the archived state file; post-merge Step 1.5 reading the archive saw final_state=unknown / defer=0 and silently hid deferred reviews. Caught by Codex P1 in the PR #62 dogfood. Fixed by persisting final fields before the archive mv. Active design contract (minor_floor / same-file generalization) deliberately NOT duplicated — it lives in cr-fix `references/`.
- index.md: added cr-fix-ops/state-file-self-describing.md hook

## 2026-06-10 — post-merge #61 (post-merge)

Merge `0d08b9e` (squash). Issue #59 (PR 2 of 2): borrow two mem0 *patterns* (not data, not runtime) into llmwiki, mem0 fully decoupled. Scanned the PR file list (`gh pr diff 61 --name-only`): `core-config/hooks/prompt_inject.sh` (authority label + CORE_CONFIG_FEDERATE_MEM0 flag), `llm-wiki/skills/lint-wiki/SKILL.md` (Step 1 dedup scoring), core-config 1.7.0→1.8.0, llm-wiki 2.2.0→2.3.0, marketplace metadata 1.54.0→1.55.0. cr-fix converged clean after iter 1 (2 real findings applied: CR Minor — PCRE-quote `$tok` with `\Q\E`; Codex P2 — map alias clusters to files; iter 2 CR clean + Codex no re-review). Mechanical facts (the flag + labels, the llm-wiki hook count 3→5 straggler) routed to `plugins/core-config/CLAUDE.md` + `plugins/llm-wiki/CLAUDE.md` (NOT re-recorded here). One design-lore finding lands in the wiki.

- llm-wiki-design/mem0-llmwiki-federation.md: NEW page (id `mem0-llmwiki-federation`, status active, volatility stable, sources 2) — why mem0 and llmwiki coexist by **labels only**, never runtime coupling. prompt_inject.sh labels the `.llmwiki/` pointer `[AUTHORITATIVE]` (dated/sourced wins) and emits a `[RECALL]` note placing mem0 recall as secondary — it never calls/reads mem0 (mem0 surfacing stays mem0's own hooks). Codex omits `[RECALL]` (no mem0 layer there), so durable cross-agent lore must still reach `.llmwiki/`. The borrow is conceptual: an authority *label* and (in lint-wiki) a scoring *rubric* — coarse High/Medium/Low band, never a fabricated float (provenance-over-confidence). `CORE_CONFIG_FEDERATE_MEM0=0` reverts to the plain pointer. Evidence: `plugins/core-config/hooks/prompt_inject.sh`, `plugins/llm-wiki/skills/lint-wiki/SKILL.md`.
- index.md: registered the new page under llm-wiki-design; last_verified bump.

## 2026-06-10 — post-merge #60 (post-merge)

Merge `83e075c` (squash). Issue #58: make llmwiki actually auto-trigger by splitting mechanical capture (Stop hook) from LLM curation (next SessionStart drain). Scanned the PR file list (`gh pr diff 60 --name-only`): llm-wiki gains `hooks/wiki_session_capture.sh` (Stop) + `hooks/wiki_session_start_drain.sh` (SessionStart), plugin.json hook registration 2.0.0→2.2.0, post-merge Step 8 forced-logging contract (github-dev 2.2.1→2.3.0), `.gitignore` staging entry, marketplace metadata 1.52.0→1.54.0 (two-step advance past the concurrent #56 release, per `.claude/rules/plugin-versioning.md`). Mechanical fact (llm-wiki hook count 3→5) routed to root `CLAUDE.md` (NOT re-recorded here). Two design-lore findings land in the wiki.

- llm-wiki-design/capture-curation-split.md: NEW page (id `capture-curation-split`, status active, volatility stable, sources 2) — why session-boundary auto-capture is split into a mechanical Stop hook (scans transcript for ingest signals, writes per-session `.staging/pending-<sid>.md` pointer, touches no wiki page) and an LLM curation turn (next SessionStart drain injects an `ingest-finding` directive). A shell hook can't dedup/resolve conflicts, so it only flags + points at the transcript; over-capture is safe because the `ingest-finding` dedup gate absorbs it. Honest limitation: if the next session never opens, staging accumulates (lint flags it) — fully unattended instant ingest is impossible with a shell hook alone. Evidence: `plugins/llm-wiki/hooks/wiki_session_capture.sh`, `wiki_session_start_drain.sh`.
- llm-wiki-design/post-merge-trigger.md: UPDATED (sources 3→4, last_verified→2026-06-10). Added the **forced-logging contract**: Step 8 now emits a single mandatory checkpoint on every path (`wiki-ingest: ingested N` / `no-lore (<reason>)`) — no silent skip. `WIKI_AUTOINGEST=0` disables the auto-ingest while still logging the skip. `> See-also: [[capture-curation-split]]` (the session-boundary third path, complementing the two merge paths).
- index.md: registered the new page under llm-wiki-design; last_verified bump.

## 2026-06-08 — post-merge #56 (post-merge)

Merge `6dd72e5` (squash). Issue #55 fix: cr-fix mistook the transient `success / "Review skipped: free tier disabled"` placeholder for a terminal status and dropped the real review. Scanned the PR file list (`gh pr diff 56 --name-only`): cr-fix `poll-cr-status.sh` + `pre-flight.sh` + `SKILL.md` + `references/pre-flight-rules.md`, github-dev 2.2.0→2.2.1, marketplace metadata 1.51.0→1.52.0 (two-step advance past the concurrent #54 release, per `.claude/rules/plugin-versioning.md`). This is a **code-level correction** of existing volatile lore — no new page; no config/CLAUDE.md mechanical rule (the `CR_SKIP_GRACE` knob is self-documented in the cr-fix skill; the lore home is the wiki).

- cr-fix-ops/cr-rate-limit-progressive-refill.md: UPDATED (sources 3→4, last_verified stays 2026-06-08). Added `## Code-level fix (PR #56)` section: pre-flight/poll no longer route `success / "Review skipped: free tier disabled"` straight to `rate_limited`; they hold it non-terminal for `CR_SKIP_GRACE` seconds (default 300, env-only, mirrors `EARLY_CHECK_WINDOW`). Within grace → `cr_wait` (sniff guarded so the placeholder can't re-flag); past grace → `rate_limited`; grace anchored to status `created_at` / `push_age` (a one-shot probe has no prior observation). `poll-cr-status.sh` records first-seen-skip and keeps polling until the row flips to `Review completed` or grace expires. Genuine `Review limit reached` / `rate limited` route immediately, unchanged. Resolves the page's own open note that the gate "should distinguish progressive-refill from hard-cap" and the content-empty `cr_state: success` false-clean caveat (poll now holds instead of returning premature success). Open follow-up noted (not asserted): sniffer comment-channel false-positive (#57).

## 2026-06-08 — post-merge #54 (post-merge)

Merge `582cfa6` (squash). Scanned the PR file list (`gh pr diff 54 --name-only`): docs-forge gains `/docs-forge:deploy-doc` + `/docs-forge:moc` (command + guide-skill SSOT + reference each), version 0.2.1→0.3.0, marketplace metadata 1.50.0→1.51.0, Codex manifests regenerated. Merged diff applies already-documented patterns (`[[dual-surface-command-skill-pattern]]`, `[[shared-source-codex-manifests]]`, `.claude/rules/plugin-versioning`) — no NEW lore from the diff; no config/CLAUDE.md mechanical rule needed (conventions already captured). One process finding from the 5-iter cr-fix loop ties to existing lore.

- cr-fix-ops/cr-rate-limit-progressive-refill.md: UPDATED (sources 2→3, last_verified→2026-06-08). Added a 3rd confirming dogfood instance (PR #54): a 5-push burst where CR skipped early commits (`"Review skipped: free tier disabled"`) and completed the final one (progressive refill), with Codex co-reviewing throughout. Establishes the **co-reviewer recovery path** (distinct from the PR #50 CLI fallback) and the caveat that `cr_state: success` is content-empty during the CR skip window — a false "clean" if CR is the only reviewer.

## 2026-06-05 — post-merge #50 (post-merge)

Merge `ffab9c7` (squash). Scanned the PR file list (`gh pr diff 50 --name-only`): prompt_inject.sh block strengthen + post-merge Step 4.5 ephemeral pruning + versioning. Two findings tie to lore; one existing page re-verified. The gh `{owner}/{repo}` invariant surfaced by Codex review was routed to `plugins/github-dev/CLAUDE.md` (mechanical rule) — NOT duplicated here.

- plugin-ops/prompt-inject-korean-persistence.md: NEW page (id `prompt-inject-korean-persistence`, status active, volatility stable, sources 2) — why the per-prompt block must explicitly name internal workflow / subagent / English-skill paths (ultracode, deep-research) as NOT a "별도 지시"; otherwise an English skill body downstream reads as the override the Korean-default line defers to, and the final user answer regresses to English. Evidence: `plugins/core-config/hooks/prompt_inject.sh`.
- cr-fix-ops/cr-cli-false-positive-generated-files.md: NEW page (id `cr-cli-false-positive-generated-files`, status active, volatility stable, sources 2) — the local CodeRabbit CLI flags a *correctly regenerated* `.codex-plugin/plugin.json` as "manually edited, revert + regenerate" (Major). It is a false positive: the canonical edits were in `plugin.json` + `marketplace.json` and the generator was run. `node scripts/sync-codex-manifests.mjs --check` passing proves the file is generator-consistent → skip the finding. `> See-also: [[codex-manifest-regen]]`. Evidence: `plugins/github-dev/.codex-plugin/plugin.json`.
- cr-fix-ops/cr-rate-limit-progressive-refill.md: UPDATE — PR #50 is a 2nd independent dogfood confirming `cr_desc: "Review skipped: free tier disabled"` → `gate=rate_limited` → auto→cli fallback (CLI v0.5.2 gave a full review). Added as a confirming data point; last_verified 2026-05-30 → 2026-06-05 (sources unchanged).
- index.md: registered the 2 new pages under their domains; last_verified bump.
- Evidence: `plugins/core-config/hooks/prompt_inject.sh`, `plugins/github-dev/.codex-plugin/plugin.json`, `scripts/sync-codex-manifests.mjs`.

## 2026-06-01 — insight promotion (3 entries) + body-transform dedup + code-scout id fix (ingest-finding)

Diff log written before applying the page edits (git-revertible). Full insight-layer pass over the existing wiki: promote 3 stabilized findings to `.llmwiki/insight/`, compress one duplicated narrative, fix one identity-rot id. No wiki page deleted; each insight entry condenses (never copies) its `promoted_from:` source.

- insight/codex-manifest-regen.md: new insight entry (id `codex-manifest-regen`, tier insight, promoted_from [[shared-source-codex-manifests]], evidence_count 2, volatility stable, sources 2) — rule: regenerate Codex manifests (`node scripts/sync-codex-manifests.mjs`) on any plugin skills/version/description/category change; `--check` is the CI drift gate; never hand-edit generated manifests or reintroduce a body-transform mirror.
- insight/cr-rate-limit-budget.md: new insight entry (id `cr-rate-limit-budget`, tier insight, promoted_from [[cr-rate-limit-progressive-refill]], evidence_count 2, volatility stable — stable core only; the source page stays volatile, sources 2) — rule: CR `Review skipped: free tier disabled` = progressive-refill quota exhaustion, NOT a plan downgrade; do not add a sniff cooldown; treat `--max-iter` as a CR quota budget. (The planned-v3 `--push-spacing` detail is intentionally left in the wiki, not promoted.)
- insight/plugin-cache-restart.md: new insight entry (id `plugin-cache-restart`, tier insight, promoted_from [[cache-version-pinning]], evidence_count 2, volatility stable, sources 2) — rule: a session pins each plugin's version at startup; mid-session marketplace updates are invisible until restart; during a migration window drive work from repo source, not the pinned skill; refresh via restart or `rm -rf` of the plugin cache.
- insight/index.md: registered the 3 entries under `## Entries`; last_verified 2026-06-01.
- llm-wiki-design/neutral-llmwiki-root.md: consolidation — compressed the `## Vindication` section (a full re-telling of the 275-hit body-transform audit + the same 3 examples) to a short pointer at the canonical account in [[shared-source-codex-manifests]] (`## Why the body-transform mirror was wrong`). Kept the conclusion; removed the duplicated body. last_verified 2026-06-01 (sources unchanged).
- research-harness/code-scout-vs-deep-research-boundary.md: identity-rot fix — `id: code-scout-deep-research-boundary` → `code-scout-vs-deep-research-boundary` (now matches the filename and the `code-scout-vs-deep-research` alias); no cross-page `[[ref]]` pointed at the old id. last_verified 2026-06-01.
- Evidence: `.llmwiki/wiki/plugin-ops/{shared-source-codex-manifests,cache-version-pinning}.md`, `.llmwiki/wiki/cr-fix-ops/cr-rate-limit-progressive-refill.md`, `.llmwiki/insight/index.md`.

## 2026-06-01 — post-merge #42 + #43 (post-merge-wiki)

Scanned the merge diffs `f6efe50` (#42 dual-integration rule) + `799a9bb` (#43 insight layer + prompt-inject hook) per `git show --name-only`. No new wiki page ingested — both PRs were already self-documenting:

- #43 shipped its own wiki lore in-PR: `llm-wiki-design/insight-layer-via-hook.md` (new) + `neutral-llmwiki-root.md` / `curated-conservative.md` updates + a `log.md` entry (the 2026-06-01 insight-layer entry below).
- #42's `.claude/rules/dual-integration.md` is a normative Claude↔Codex surface-sync checklist whose design rationale already lives in `plugin-ops/shared-source-codex-manifests.md` (the rule cites it at its Source-of-Truth line) + `llm-wiki-design/{neutral-llmwiki-root,insight-layer-via-hook}.md`. A dedicated page would duplicate that, so none was added.
- rules/*.md flags: none — dual-integration.md is a new rule file, not an invariant change.

## 2026-06-01 — insight layer + refine design record (ingest-finding)

Diff log written before applying the page edits (git-revertible). Captures the WS2 insight-layer migration (the `.llmwiki/insight/` promoted layer + the `.claude/rules/`-as-promotion-target retirement).

- insight/index.md: new insight MOC at `.llmwiki/insight/` (promotion criteria, `tier`/`promoted_from`/`evidence_count` frontmatter schema, non-append consolidation discipline). Separate from the wiki MOC; pointed at by the wiki `index.md` intro + the core-config prompt-inject hook.
- llm-wiki-design/insight-layer-via-hook.md: new page (id `insight-layer-via-hook`, status active, volatility stable, sources 2) — promoted insight layer at `.llmwiki/insight/` delivered via the core-config prompt-inject hook (Claude `UserPromptSubmit` + Codex `~/.codex/hooks.json`), NOT `.claude/rules/` (Codex can't read it); `.claude/rules/` retired as a wiki-promotion target; `.llmwiki/insight/` is the one justified new physical dir. `> Refines: [[neutral-llmwiki-root]]`, `> Refines: [[curated-conservative]]`, `> See-also: [[shared-source-codex-manifests]]`.
- llm-wiki-design/neutral-llmwiki-root.md: kept active (origin refreshed it via #39); added `> See-also: [[insight-layer-via-hook]]` + a refinement note that promotion of cross-agent rules moved to `.llmwiki/insight/` (the `.claude/rules/`-schema-home claim holds only for Claude auto-load). last_verified 2026-05-31 → 2026-06-01.
- llm-wiki-design/curated-conservative.md: refined the "no new dirs" bullet to carve out `.llmwiki/insight/` as the one justified exception; added `> See-also: [[insight-layer-via-hook]]`; last_verified bumped.
- index.md: added the insight-layer pointer to the intro + the insight-layer-via-hook hook under `## llm-wiki-design`.
- Evidence: `.claude/spec/2026-05-29-llm-wiki-v2.md`, `.llmwiki/insight/index.md`.

## 2026-05-31 — post-merge #41 (post-merge-wiki)

Diff log written before applying the page edits (git-revertible). Merge SHA `05bedcd` — feat: skillify deepwiki + project-init (dual-surface, 17→19 Codex-eligible).

- plugin-ops/shared-source-codex-manifests.md: updated (sources 3 → 4; last_verified stays 2026-05-31). EXCLUDED list trimmed from `{core-config, midjourney, deepwiki, project-init}` to `{core-config, midjourney}` with refreshed rationale (core-config = no Codex hook surface; midjourney = execution-model mismatch). Eligibility count "17 of 21" → "**19 of 21**". Added a paragraph explaining that `deepwiki` and `project-init` left the EXCLUDED set via the 1.41.0 dual-surface conversion (links to new `[[dual-surface-command-skill-pattern]]` page). Added `> See-also: [[dual-surface-command-skill-pattern]]` cross-ref, plus PR #41 to the Sources block.
- plugin-ops/dual-surface-command-skill-pattern.md: new page (id `dual-surface-command-skill-pattern`, status active, volatility stable, sources 4). Documents the layout (`commands/` thin pointer + `skills/<name>/SKILL.md` thin pointer + shared `references/<name>-procedure.md` body), the description-narrowing + runtime hard-guard pattern for destructive plugins (`project-init`'s `find -mindepth 1 -maxdepth 5` block that aborts on any non-`.git`, non-OS-metadata cwd entry), and the `PLUGIN_ROOT` resolver that turns `${CLAUDE_PLUGIN_ROOT}` Claude-only env into a portable 4-step resolution (caller PLUGIN_ROOT → CLAUDE_PLUGIN_ROOT → `~/.codex/plugins/cache/<marketplace>/<plugin>/<version>/` → abort). Includes the GNU `sort -V` BSD fallback discovered during cr-fix iter 2. `> Refines: [[shared-source-codex-manifests]]`, `> Evidence: plugins/project-init/references/new-procedure.md`, `> Evidence: plugins/deepwiki/skills/ask/SKILL.md`.
- index.md: added dual-surface-command-skill-pattern hook under `## plugin-ops`; updated the shared-source line with the 19/21 eligibility number.
- Evidence (in-diff, from `git show --name-only` on merge SHA 05bedcd): `scripts/sync-codex-manifests.mjs` (EXCLUDED set + comment), `.claude-plugin/marketplace.json` (metadata + deepwiki + project-init versions), `plugins/deepwiki/{skills/ask,skills/generate-llmstxt,references}/*` + `commands/{ask,generate-llmstxt}.md` + `CLAUDE.md`, `plugins/project-init/{skills/new,references}/*` + `commands/new.md` + `CLAUDE.md`, `plugins/{deepwiki,project-init}/.codex-plugin/plugin.json` (generated), `.agents/plugins/marketplace.json` (generated catalog), root `CLAUDE.md` / `AGENTS.md` / `README.md`.

## 2026-05-31 — post-merge #39 (post-merge-wiki)

Diff log written before applying the page edits (git-revertible). Merge SHA `158c438` — feat: shared-source Codex bridge (retire codex-bridge plugin).

- plugin-ops/shared-source-codex-manifests.md: new page (id `shared-source-codex-manifests`, status active, volatility stable, sources 3) — Codex 0.135 reads the same `plugins/<name>/` tree Claude does via a thin manifest generator (`scripts/sync-codex-manifests.mjs`, ~140 LOC, zero deps) instead of the retired `codex-bridge` body-transform mirror (1,214-line `sync.mjs`). Documents Codex 0.135 manifest top-level constraint (only `skills` / `hooks` / `mcpServers` / `apps` supported — `commands` and `agents` are Claude-only), the EXCLUDED set rationale (`core-config`, `midjourney`, `deepwiki`, `project-init` → 17 of 21 eligible), and the `--check` drift guard's orphan-manifest detection. `> Supersedes: (codex-bridge plugin, retired)`, `> See-also: [[neutral-llmwiki-root]]`, `> Evidence: scripts/sync-codex-manifests.mjs`, `> Evidence: ~/.codex/skills/.system/plugin-creator/references/plugin-json-spec.md`.
- llm-wiki-design/neutral-llmwiki-root.md: updated (last_verified 2026-05-29 → 2026-05-31, sources 2 → 3) — added "Vindication" subsection: the PR #39 body-transform audit found 275 `.claude/` hits across skill bodies were nearly all *legitimate authorial documentation* (llm-wiki bootstraps `.claude/rules/`, github-dev/cr-fix accepts `CONFIG_FILES="CLAUDE.md AGENTS.md"`, rules-forge explains `CLAUDE.md` semantics). The transforms themselves were corrupting authorial intent. The fix is now structural: the codex-bridge plugin (the transform source) is retired in 1.40.0; both runtimes read the same source. Neutral-root defense remains correct for any future mirror that might re-emerge. Updated status note on the bridge.
- index.md: added shared-source-codex-manifests hook under `## plugin-ops`; MOC `last_verified:` bumped to 2026-05-31.
- Evidence (in-diff, from `git show --name-only`): `scripts/sync-codex-manifests.mjs` (new generator), `plugins/codex-bridge/scripts/sync.mjs` (deleted 1,214-line transform engine), `plugins/codex-bridge/` directory (deleted in full), `.agents/plugins/marketplace.json` (generated catalog), `plugins/*/.codex-plugin/plugin.json` × 17 (generated per-plugin manifests), `AGENTS.md` / `CLAUDE.md` / `README.md` (shared-source docs).

## 2026-05-30 — post-merge #33 (post-merge-wiki)

Diff log written before applying the page edits (git-revertible). Merge SHA `bcc3939` — feat(github-dev): cr-fix v2 — pre-flight detection + autonomous judgment.

- cr-fix-ops/: new domain directory established under `.llmwiki/wiki/` to hold per-plugin cr-fix operational lore (rate-limit semantics, dogfood-derived design rationale). Distinct from `plugin-ops/` (Claude Code runtime cache) and from the cr-fix references files (active design contract).
- cr-fix-ops/cr-rate-limit-progressive-refill.md: new page (id `cr-rate-limit-progressive-refill`, status active, volatility volatile, sources 2) — `cr_desc: "Review skipped: free tier disabled"` does NOT mean the org reverted to Free plan. It signals CR trial/Pro **progressive-refill hourly quota exhaustion** per the [Fair Usage Limits Policy](https://docs.coderabbit.ai/management/plans#fair-usage-limits-policy). Reviews trickle back (not a 60-min reset). Treat `--max-iter` as a CR quota budget (default 5 = Pro 5-rev/hour). Do NOT add a sniff cooldown — use `--push-spacing` instead. Overturns the v2-development intuition. `> Evidence: plugins/github-dev/skills/cr-fix/references/lessons-from-dogfood.md`.
- index.md: added `## cr-fix-ops` domain section with the cr-rate-limit-progressive-refill hook; MOC `last_verified:` bumped to 2026-05-30.
- Evidence (in-diff, from `git show --name-only bcc3939`): `plugins/github-dev/skills/cr-fix/references/lessons-from-dogfood.md` (Lesson 5 = corrected reading after consulting CR docs) + `plugins/github-dev/skills/cr-fix/scripts/sniff-cr-rate-limit.sh` (detection implementation). External source: CR Fair Usage Policy docs.

## 2026-05-30 — post-merge #30 (post-merge-wiki)

Diff log written before applying the page edits (git-revertible). Merge SHA `fc4d994` — feat(code-scout): v2.1 — paper-scout 5th axis + insane-search tier-4 + deep-research boundary + drop deep-scout.

- research-harness/: new domain directory established under `.llmwiki/wiki/` to hold cross-plugin research harness boundary contracts (code-scout, /deep-research, paper-search-tools). Distinct from per-plugin operational lore — this domain captures **inter-harness routing rules** that span plugins.
- research-harness/code-scout-vs-deep-research-boundary.md: new page (id `code-scout-deep-research-boundary`, status active, volatility stable, sources 2) — code-scout owns the code / ML / docs / papers domain; `/deep-research` owns generic topics (politics, market, history, biographies, general policy). The `research-orchestrator` skill explicitly does **NOT** delegate to `/deep-research` even when the query is out-of-domain. The two harnesses tune their fan-out for incompatible domains; routing one through the other would mis-tune. `> Evidence: plugins/code-scout/skills/research-orchestrator/SKILL.md`.
- index.md: added `## research-harness` domain section with the code-scout-vs-deep-research-boundary hook.
- Evidence (in-diff, from `git show --name-only fc4d994`): `plugins/code-scout/skills/research-orchestrator/SKILL.md` (boundary contract authored here, frontmatter line 17-21 + body line 41).

## 2026-05-29 — post-merge #29 (post-merge-wiki)

Diff log written before applying the page edits (git-revertible). Merge SHA `2a166d5` — chore: post-v2 maintenance (docs-forge frontmatter + settings.json local).

- plugin-ops/: new domain directory established under `.llmwiki/wiki/` to hold plugin operational lore (cache, loading, version resolution), distinct from the schema-layer rules in `.claude/rules/plugin-versioning.md`.
- plugin-ops/cache-version-pinning.md: new page (id `cache-version-pinning`, status active, volatility volatile, sources 2) — the plugin cache holds multiple versions per plugin side by side; a running session pins the startup-resolved version, so a newer already-cached version is not served until restart (or via a `local` settings.json source). Folds in the v1->v2 root-resolution manifestation: a v1-pinned llm-wiki skill resolves the legacy `.claude/wiki/` and misses the neutral `.llmwiki/` root. `> See-also: [[neutral-llmwiki-root]]`, `> See-also: [[curated-conservative]]`, `> Evidence: .claude/rules/plugin-versioning.md`.
- index.md: added `## plugin-ops` domain section with the cache-version-pinning hook; MOC `last_verified:` kept 2026-05-29.
- Evidence (runtime observation): `~/.claude/plugins/cache/my-claude-plugins/<plugin>/<version>/` held `llm-wiki/{1.1.1, 1.2.0}` + `github-dev/{1.22.0, 1.23.0}` while this session served v1 (llm-wiki 1.1.1 / github-dev 1.22.0). Complementary schema-layer doc: `.claude/rules/plugin-versioning.md`.

## 2026-05-29 — post-merge #28 (post-merge-wiki)

Diff log written before applying the page edit (git-revertible). Merge SHA `62315ed` — feat(github-dev): post-merge Step 5.8 conditional wiki ingest chain.

- llm-wiki-design/post-merge-trigger.md: new page (id `post-merge-trigger`, status active, volatility stable, sources 2) — post-merge-wiki has two complementary triggers: github-dev:post-merge Step 5.8 (conditional soft-dependency, mirrors the spec-state Step 5.7 pattern, covers GitHub-UI merges) + the wiki_post_commit_hint.sh PostToolUse hook (local CLI merge commits only). `> See-also: [[curated-conservative]]`.
- index.md: added the post-merge-trigger hook under the `## llm-wiki-design` domain section; MOC `last_verified:` kept 2026-05-29.
- Evidence (in-diff, from `git show --name-only`): `plugins/github-dev/commands/post-merge.md` (Step 5.8). Complementary pre-existing source: `plugins/llm-wiki/hooks/wiki_post_commit_hint.sh`.

## 2026-05-29 — ingest v2 design record: 4 pages (ingest-finding)

Diff log written before applying the page edits (git-revertible).

- llm-wiki-design/curated-conservative.md: new page (id `curated-conservative`, status active, volatility stable, sources 2) — hub thesis: harvest the git-auditable kernel of each rohitg00-v2 idea, reject the heavyweight parts; adopted vs rejected lists.
- llm-wiki-design/neutral-llmwiki-root.md: new page (id `neutral-llmwiki-root`, status active, volatility stable, sources 2) — `.llmwiki/` neutral root defeats the codex-bridge `.claude/`->`.codex/` body-transform fork; schema stays at `.claude/rules/`; resolution order. `> Refines: [[curated-conservative]]`.
- llm-wiki-design/volatility-over-decay.md: new page (id `volatility-over-decay`, status active, volatility stable, sources 2) — discrete `volatility:` class + fixed window replaces Ebbinghaus decay; old is not stale. `> Refines: [[curated-conservative]]`, `> See-also: [[provenance-over-confidence]]`.
- llm-wiki-design/provenance-over-confidence.md: new page (id `provenance-over-confidence`, status active, volatility stable, sources 2) — `sources: N` + named `## Sources` replaces float confidence. `> Refines: [[curated-conservative]]`, `> See-also: [[volatility-over-decay]]`.
- index.md: MOC `last_verified:` set to 2026-05-29; added `## llm-wiki-design` domain section with the 4 page hooks.
- Raw evidence cited: `.llmwiki/raw/rohitg00-llm-wiki-v2-gist.md`, `.llmwiki/raw/karpathy-llm-wiki-gist.md`, `.llmwiki/raw/perplexity-llm-wiki-survey-2026-05.md`, plus `.claude/spec/2026-05-29-llm-wiki-v2.md`.

## 2026-05-29 — bootstrap llm-wiki-design domain (bootstrap-wiki)

- llm-wiki-design/: domain directory established under `.llmwiki/wiki/` (2-depth domain/page layout) to hold the v2 design record.

## 2026-06-08 — Codex 1024-char skill-description silent-skip guard (ingest-finding)

- plugin-ops/shared-source-codex-manifests.md: added `## Skill-description length guard` section (Codex 0.135 silently skips skills with `description` > 1024 chars; `--check` now validates length via SKILL_DESC_MAX before drift; 3-layer enforcement: sync-script guard + `.githooks/pre-commit` + `validate-codex.yml` CI). Updated `--check` mode bullet to note length validation. Added PR #46 source; sources 4 -> 5; last_verified 2026-06-08.
- index.md: extended the shared-source-codex-manifests hook to mention the 1024-char description guard.

## 2026-06-08 — codex-image joins EXCLUDED set (Claude->Codex bridge) (ingest-finding)

- plugin-ops/shared-source-codex-manifests.md: EXCLUDED entries 2 -> 3 (added `codex-image` with circular-bridge rationale, distinct from the schema-driven exclusion of core-config/midjourney); eligible count 19 of 21 -> 19 of 22; added PR #49 source; sources 5 -> 6; last_verified 2026-06-08.
- index.md: shared-source hook eligible count 19 of 21 -> 19 of 22.

## 2026-06-08 — graduate Codex 1024-char skill-desc limit to insight (ingest-finding)

- insight/codex-skill-desc-1024.md: new insight entry (tier insight, promoted_from shared-source-codex-manifests, evidence_count 2 — PR #46 research-orchestrator 1214 chars dropped + PR #51 post-merge skill near-miss at 1019/1024 during humanizer->humanize-korean swap). Recurrence across 2 independent PRs met the graduation bar.
- insight/index.md: added codex-skill-desc-1024 hook.
- plugin-ops/shared-source-codex-manifests.md: added PR #51 near-miss evidence to the length-guard section + `> Promoted-to:` backlink; last_verified 2026-06-08.

## 2026-06-08 — distill cr-rate-limit page from PR diary to rule + index lint cleanup (ingest-finding)

- cr-fix-ops/cr-rate-limit-progressive-refill.md: collapsed three per-PR narrative sections (`## Trial dogfood data (PR #33)` / `## Confirming dogfood (PR #50)` / `## Confirming dogfood (PR #54)`) and the `## Code-level fix (PR #56)` section into a single distilled `## The rule` (CR_SKIP_GRACE non-terminal semantics) + one `## Evidence across dogfood runs` (1 bullet per run); inline PR #56 narratives in `## Why this matters` rewritten as rule statements; `## Sources` retains PR #33/#50/#54/#56 + policy provenance; sources 4 -> 5 (PR #50 given its own citation); page dropped 8.0K -> ~5K (resolves lint Level >5KB). last_verified 2026-06-08.
- index.md: removed leftover `(<domain>/<slug>.md)` template-comment artifact (was a phantom orphan-scan hit); added 1 line allowing wiki->insight `[[insight-id]]` cross-layer refs.
