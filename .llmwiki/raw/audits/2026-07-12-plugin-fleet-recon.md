# Recon Report — Plugin-Fleet Audit + Refactor Pre-Plan (2026-07-12)

Synthesis of 8 group audits, 3 PR/compat reviews, 4 research reports. Repo: /home/hsserver/workspace/my-claude-plugins.

## 1. Deduplicated findings (ranked)

### Resolved by research — strike before planning

| ID | Was | Finding | Resolution |
|---|---|---|---|
| R-1 | P1 x7 (github-dev, brightdata-guide, interview, tcrei-prompt, ppt-yeong-style, anti-slop-design, ml-toolkit, repo-root — all `__init__.py` + generator) | 3-arg `ctx.register_skill(name, path, description)` vs "documented 2-arg" | **NOT A DEFECT.** Research 3 read upstream source: `hermes_cli/plugins.py` L1196 = `register_skill(self, name, path, description="")` — 2 required + optional 3rd. Generator is correct. Action: update `.llmwiki/wiki/plugin-ops/hermes-plugin-adapter.md` (lines 46, 136) to record the settled signature; no code change. |

### P0 — none

### P1 — active defects

| # | Plugin | File | Finding | Verified |
|---|---|---|---|---|
| 1 | codex-image | `plugins/codex-image/skills/codex-image/SKILL.md` | Heredoc prompt handoff breakable: prompt line `EOF` terminates heredoc, remaining lines execute as shell (injection demonstrated live). Fix: randomized/unique delimiter + prompt-body delimiter check in Validation section. | yes |
| 2 | github-dev | `skills/cr-fix/scripts/auto-merge-gate.sh` | Unprotected base branch: `gh api` non-zero after awk prints 404 → pipefail fires `\|\| echo 404` too → `protection_http="404\n404"` → jq --argjson fails → set -e kills script → --auto-merge silently never runs. Reproduced against live repo. | yes |
| 3 | github-dev | `skills/cr-fix/SKILL.md` (Step 2) | `codex_processed_reviews` inheritance dead: emit-final-json.sh EXIT trap always archives state file; Step 2 reads only live path, no archive fallback (post-merge Step 1.5 has one). Second run always starts `[]`. Reproduced with mock state. | yes |
| 4 | github-dev | `skills/cr-fix/SKILL.md` (Step 1) | SKILL_DIR resolver lacks `${CLAUDE_PLUGIN_ROOT}` branch + Codex-cache lookup; outside source tree resolves to nonexistent `~/.hermes/...`, parse-args.sh unreachable. Reproduced from /tmp. Resolver family — see cluster note below. | yes |
| 5 | llm-wiki | `skills/bootstrap-wiki/SKILL.md` (L10,37,52) | Bare `${CLAUDE_PLUGIN_ROOT}`, no resolver block; Codex-synced plugin, Codex 0.135 does not export the var → Step 3/6 template copies fail under Codex. Resolver family. | yes |
| 6 | ml-toolkit | `skills/gpu-parallel-pipeline/SKILL.md` (L106-113) | Resolver never consults `${CLAUDE_PLUGIN_ROOT}`; from any non-marketplace CWD falls to `~/.hermes/...`, ls exit 2 (executed). Resolver family. | yes |
| 7 | tally-form | `skills/tally-form/SKILL.md` | Repo-relative `uv run plugins/tally-form/...` invocation; from cache-installed plugin in another repo the path does not exist. Resolver family. | no |
| 8 | tcrei-prompt | `skills/tcrei-prompt/SKILL.md` | Phase 3 instructs `Task(subagent_type="claude", model="haiku")` — invalid subagent_type, invalid param, referenced "OMC verifier agent" does not exist; verification step errors/degrades every run. | no |
| 9 | github-dev + ml-toolkit | cr-fix SKILL.md, gpu-parallel-pipeline SKILL.md | Hermes fallback tiers assume `$HERMES_HOME/plugins/<name>/skills/` layout; audit measured only `$HERMES_HOME/skills/`. Note: research 3 confirms Hermes DOES scan `~/.hermes/plugins/` for plugins, so the branch is not certainly dead — needs one live-Hermes verification before rewriting. | no |
| 10 | github-dev | `skills/cr-fix/scripts/cr-commit-state.sh` | (#109 open Codex P1) `fetch_statuses`/`fetch_checkruns` map `gh api` failure to `[]` — auth/network/rate-limit indistinguishable from "no CR row"; poll spins to 1800s timeout. Fix: emit `state:"error"` on fetch failure. | review-verified |

**Resolver-family cluster (P1 #4-7, P2 #6, P3 deepwiki):** one fix pattern — copy the cross-runtime `PLUGIN_ROOT` resolver block from reference impls `project-init` / `mem0-ops` (`CLAUDE_PLUGIN_ROOT` → source-tree `plugins/<name>` → Codex cache lookup), per `.claude/rules/dual-integration.md`. Six files, one wave.

### P2

| # | Plugin | File | Finding | Verified |
|---|---|---|---|---|
| 1 | github-dev | `skills/cr-fix/scripts/fetch-cr-threads.sh` | jq error detector emits nothing when `errors` null AND `repository` null (`null // empty` → empty, jq -e exit 4) → silently emits `[]` → false "clean" convergence instead of failure. | yes |
| 2 | llm-wiki | all 5 SKILL.md | 11 refs to `references/wiki-conventions.md` but file lives at plugin root, not per-skill; dangles relatively, absent entirely under skill-level install. Fix: `${PLUGIN_ROOT}/references/...` or per-skill copy. | yes |
| 3 | github-dev | `README.md` | Root README github-dev table lists nonexistent `/github-dev:code-review`, `/github-dev:cr-wait`, `/github-dev:merge-worktree` (last not even marked deprecated). (Note: infra group's grep of README found all 33 slash refs resolving — the two greps disagree; recheck README.md L167 area once before editing.) | yes |
| 4 | project-init | `CLAUDE.md:153`, `references/new-procedure.md:324` | Both instruct `/code-scout:scout` — never existed as slash command, agent form deprecated since v2.0. Point at `Skill("code-scout:research-orchestrator")`. | yes |
| 5 | paper-search-tools | `skills/paper-search-usage/SKILL.md` | All 23 tool names documented as `mcp__paper-search__*`; live registry surfaces `mcp__plugin_paper-search-tools_paper-search__*`. Every documented name wrong on the installed path. | yes |
| 6 | e2e-harness | `skills/e2e-setup/SKILL.md` (L13,83,87,91) | Bare `${CLAUDE_PLUGIN_ROOT}/assets/...` x4, prose hint only — resolver family. | yes |
| 7 | codex-image | `skills/codex-image/SKILL.md` | `allowed-tools` frontmatter space-separated instead of comma-separated — may collapse to one unmatchable pattern, silently disabling allowlist. | no |
| 8 | rules-forge | `CLAUDE.md:82`, `assets/templates/rule-file.md:9`, `assets/templates/rule-categories.md:80` | Three refs to retired `codex-bridge-sync.md` / `plugins/codex-bridge/` (gone since 1.40.0); template grounding will Read-fail or hallucinate. | yes |
| 9 | tcrei-prompt | `skills/tcrei-prompt/references/tcrei-patterns.md` | 325-line reference never referenced by SKILL.md/CLAUDE.md — dead content. Delete or wire. | yes |
| 10 | ppt-yeong-style | `.claude-plugin/plugin.json` | Description stale vs marketplace.json (missing references/주입 페이로드/cc-common wording); versions match so --check blind. | yes |
| 11 | github-dev | `scripts/cr-commit-state.sh` | (#109 post-merge Codex P2) check-run channel exports `created_at: .started_at` → CR_SKIP_GRACE window runs from run START; queued >5min routes straight to rate_limited. Use `completed_at`. | plausible |
| 12 | repo-root | `scripts/install-skills.mjs:264-268` | `--selftest` FAILS: hardcoded 24/47 vs actual 23 skill-bearing plugins / 52 SKILL.md. Also `--help` falls to interactive mode, exits 0 masking failure. | yes |
| 13 | machine-local | `~/.codex/hooks/prompt_inject.sh`, `~/.agents/skills/` | Installed Codex hook drifted (Jun 5: old Korean block, no federation labels, no council roster); ~/.agents/skills = May 29 copies incl. retired post-merge-wiki. Ops refresh, not repo change. | yes |

### P3 (grouped)

| Theme | Items |
|---|---|
| Description drift (plugin.json vs marketplace.json, no guard) | core-config, spec-state, llm-wiki, project-init, rules-forge, slidev — same pattern; one decision: add a --check comparison or declare marketplace SoT. llm-wiki .codex-plugin description also carries stale "2.0.0 major bump" wording at 2.5.0. |
| Frontmatter version drift (nothing consumes it) | tcrei-prompt SKILL.md 1.0.0 vs 1.1.0; slidev SKILL.md 1.0.0 vs 1.2.0. Delete field or sync. |
| Repo hygiene | ml-toolkit `__pycache__/` x2; mem0-ops `.pytest_cache/` not gitignored. |
| Stale text | notebook edit-notebook bans nonexistent `search_replace`; project-init idempotent-seed.sh L22 cites retired codex-bridge; post-merge Step 10 step-range mismatch (4.6-9.5 vs 5.7-9); mem0-ops CLAUDE.md omits audit.py dependency. |
| Script robustness | cr-cli-spawn.sh `grep -c ... \|\| echo 0` → `"0\n0"` + integer-expression error (reproduced). |
| CI gaps | cr-fix fixture tests in pre-commit but not validate-codex.yml (sub-second, add one step); `.githooks/pre-commit:16` discards run-tests.sh output (#109 CR minor). |
| #107 follow-up | prompt_inject.sh L62-67: repo with `.llmwiki/wiki/log.md`-only + legacy `.claude/wiki/index.md` injects legacy MOC — diverges from llm-wiki resolver. Narrow edge, unresolved on main. |
| Verified-clean (no action) | project_state.sh hardening matches wiki page; llm-wiki 5 hooks detector sweep clean; prompt_inject dual-format correct; infra seed "README orphans" did NOT reproduce at root. |

## 2. PR verdicts + version collision

- **#107** — MERGE (moot; merged 47c796c @12:19:46Z). CI green. Follow-ups: (a) P3 legacy-MOC edge above, (b) cosmetic `.ko` slang line (never loaded, ignore). Fixed in-PR: `type -P` probe, `-f` MOC test. Translation fidelity + roster assembly verified clean.
- **#109** — MERGE (merged 75f7c9dc @12:26:36Z). 21/21 fixture tests pass at head; all 4 wiki-documented defects fixed as documented. Open follow-ups: P1 cr-commit-state error path (P1 #10), P2 CR_SKIP_GRACE started_at (P2 #11), CR minor pre-commit >/dev/null (P3).
- **Version collision** — resolved correctly and monotonic: #107 took marketplace 1.90.0 (explicit in-branch resolution commit b5372277, skipping 1.89.0 claimed by #106); #109 merged 7 min later, rebumped to 1.91.0 in its merge-main commit. github-dev 2.7.1 consistent across all four manifest surfaces.

## 3. Runtime compat matrix

| Runtime | Status | Concrete gaps |
|---|---|---|
| Claude Code | native, healthy | Resolver-family skills still work here (source-tree fallback) but break from cache installs in consumer repos (P1 #4). |
| Codex 0.144.1 | WORKS; manifests `--check` clean (23) | (a) bare `${CLAUDE_PLUGIN_ROOT}` skills fail (P1 #5-6, P2 #6); (b) installed `~/.codex/hooks/prompt_inject.sh` drifted since Jun 5; (c) `~/.agents/skills` stale May 29 copies incl. retired post-merge-wiki; (d) skills-list budget = 2% context/8k chars — short descriptions still win (current 1024 guard fine). |
| Hermes | ABSENT locally; adapters `--check` clean (14 files/7 plugins) | (a) register_skill settled — adapters fine (R-1); (b) REAL gap: Hermes plugin skills are opt-in explicit `skill_view("plugin:skill")` loads, never listed in `<available_skills>` — passive discovery assumption is wrong; document or install skill-level to `~/.hermes/skills/`; (c) in-body Hermes fallback paths unverified (P1 #9). |
| Antigravity (agy 1.1.1) | CLI responds (`pong` 7.4s); no plugin surface in this repo by design | Cheapest route if wanted: `.agents/skills/` canonical dir — `npx skills add <repo>` already resolves `.claude-plugin/marketplace.json` (vercel-labs/skills), near-zero code; also covers every universal agent at once. Alternative `agy plugin install` (Gemini-extension format) = more code, skip. Council PATH detection already works. |

## 4. Harness-restructuring shortlist (concrete failure mode named; minimal fixes only)

| Plugin:skill | Named failure mode | Minimal proposal |
|---|---|---|
| llm-wiki:ingest-finding | One-sided cross-ref: updates Supersedes on page A, forgets Superseded-by + `status: stale` on page B | Final mandatory self-check step: grep touched pages for one-sided pair tokens (inline the 2-3 relevant lint-wiki checks, scoped to this run's files). No subagent. |
| github-dev:post-merge | Silent skip/reorder of Steps 4.5-9.5 (Step 8 already needed a mandatory checkpoint after a real silent skip) | One per-run state record `.claude/state/post-merge-<PR>.json`, one status entry per step (done/skipped+reason). First adopter of the v0 envelope (section 5). |
| github-dev:cr-fix Step 9c | Two findings editing same lines in one turn; only gate is end-of-iter commit | One guard sentence: before Edit in 9c.6, check TRACK_FILE for same path, re-Read region if touched this cycle. |
| ppt-yeong-style:lecture-deck | Prose-grep hard gates (bracket glyphs, placeholder count, 4-way renumber sync) skipped on 47-slide builds — both documented past failures | Bundle one deterministic `scripts/render-qa.sh`; completion gate runs it instead of prose greps; deck-review consumes output. |
| gws-sync:gws-sync | Upload step not bound to approved diff — model re-derives file IDs and content-updates the wrong Drive file | Diff step writes approved manifest (name→fileId→action) to temp file; upload reads ONLY that manifest; mismatch vs live listing aborts. |
| translator:translate-web-article | Images silently dropped / captions misattached / partial translation reported done | Final checklist gate: source-vs-output image-ref count + section-heading diff. |
| project-init:new | Bootstrap dies mid-phase (repo created, push failed) → preflight guard refuses re-entry; recovery path undocumented | Phase 0 writes `.claude/state/project-init.json` last-completed-phase; Step 0 guard grows one branch: incomplete run → offer resume. |
| ml-toolkit:cv-notebook / cv-explorer | 20+ generated cells with undefined vars still reported "notebook created"; structure check covers order only | Single end gate: nbconvert --execute on setup+first-load cells, or py_compile concatenated code cells; else mark "unverified beyond cell N". |

**Explicitly no restructuring:** code-scout research-orchestrator (already subagent-harnessed with workspace contract), slidev, anti-slop-design, spec-state, core-config, docs-forge, rules-forge, wiring. cr-fix state design needs the archive-fallback read fix, not a new record.

## 5. State-tracking convention v0

**Location:** `.claude/state/<pipeline>-<key>.json` — one file per run, natural key (PR#, slug), completed runs rotate to `.claude/state/archive/` (existing cr-fix pattern). Machine-local values gitignored (wiring.json precedent). Never persist absolute paths.

**Schema (converged from GitHub Actions run model + LangGraph metadata + this repo's cr-fix):**

```json
{
  "schema": 1,
  "run_id": "post-merge-110",
  "status": "in_progress",          // queued | in_progress | completed
  "conclusion": null,               // success | failure | cancelled — only when completed
  "started_at": "ISO8601",
  "updated_at": "ISO8601",
  "anchor_sha": "<git sha at start>",
  "attempt": 1,
  "session_id": "<harness session>",  // ralph-loop guard: concurrent sessions must not consume each other's runs
  "steps": [ {"name": "...", "status": "done|skipped", "detail": {}} ]   // append-only
}
```

**First adopters (from state_touchpoints, ordered by pain):**
1. `github-dev:post-merge` — greenfield, fixes the silent-skip harness gap simultaneously.
2. `github-dev:cr-fix` — retrofit only: add `status`/timestamps to existing file + fix the archive-fallback read (P1 #3); do NOT rewrite its working schema.
3. `project-init:new` — enables the resume branch (section 4).
4. `gws-sync` — per-file upload status for deterministic resume.
5. Later/optional: tally-form md→formId map, resolve-issue phase checkpoints (currently prose-only), lecture-deck slot tracking, e2e-setup, ingest-finding in-flight marker. Do not do all nine in one PR.

**Coexistence with spec-state:** orthogonal layers. `spec.json` stays the aggregate cache (SoT = spec frontmatter `status:`); run files are per-execution records a single skill owns. post-merge keeps calling `complete <spec-path>`. Convention is documented once (a short `.claude/rules/state-envelope.md` + AGENTS.md mirror per dual-integration), NOT a shared library — hooks stay jq-or-less bash.

**Rejected:** version vectors, SQLite backends, UUID run ids, heartbeats, JSON-Schema validation layer.

## 6. Language-mix inventory

Counts (file-level states reported by auditors): english ~115, mixed ~30, korean ~25 (of which ~20 exempt-by-design).

**Exempt (do not touch):** ppt-yeong-style entire plugin (domain layer, explicitly by-design); humanize-korean domain content; AGENTS.md review guidelines (Codex loads verbatim); ml-toolkit `insights-ko.md` x2 + ml-dev-principles Korean body (working-discipline for Korean user); gradio i18n examples; Korean trigger phrases inside `description` frontmatter (routing signal); translator Korean example outputs.

**English-refactor worklist (ranked by consumer surface):**
1. project-init: `CLAUDE.md` (korean), `references/codex-review-discovery.md`, `references/gh-repo-create-flow.md` (korean), `commands/new.md` + `references/new-procedure.md` (mixed).
2. slidev: 8 mixed reference files (animations/components/glow-background/layouts/setup-guide/slidev-syntax + create-slide SKILL.md examples).
3. docs-forge: `DEPLOY_DOC_PATTERNS.md` (korean), `MOC_PATTERNS.md` (mixed).
4. gws-sync: SKILL.md + CLAUDE.md (korean) — ASK: Korean-user-facing Drive tool, may be deliberate.
5. tally-form: SKILL.md + 6 references (korean) — ASK: presets are Korean-domain (dev-survey/lecture-consultation); SKILL.md mechanics could go English, presets stay.
6. mem0-ops CLAUDE.md (korean); anti-slop-design SKILL.md + 3 refs (Korean body) — ASK: copy rules target Korean output.
7. Trivial sweeps: notebook `사용 금지` phrase, code-scout agent-routing.md 66 chars, ml-toolkit trace Korean, rules-forge/write-rules mixed examples.

Items 4-6 need one AskUserQuestion in the plan (exemption boundary is a user call, not inferable).

## 7. Research adoption / rejection

**Adopt (≤10, each sourced):**
1. Settle register_skill in wiki as 2+optional-3rd — hermes-agent source `hermes_cli/plugins.py` L1196.
2. Centralize per-runtime tool mapping in one `references/<harness>-tools.md` instead of repeating compat tables in every skill body — obra/superpowers `docs/porting-to-a-new-harness.md` invariant 1. (Migrate gradually; do not rip out existing tables in one pass.)
3. Extend pre-commit/`--check`: 500-line SKILL.md ceiling warning + one-level-deep references rule alongside the existing 1024-char guard — platform.claude.com skill best-practices (official numbers).
4. State envelope v0 (section 5) — GitHub Actions status/conclusion split + ralph-loop session_id + LangGraph pending-writes principle.
5. Fail-open hook discipline audit: every hook exits 0 on infra error, blocks only by explicit decision — hookify design; llm-wiki hooks already verified conforming, keep as checklist for new hooks.
6. PreToolUse `permissionDecision: deny` for destructive Bash (`git reset --hard`, force push, rm -rf outside temp) — one ~30-line shared script; mechanizes CLAUDE.md Part 2 — code.claude.com/docs/en/hooks.md + echo-lumen cookbook. Claude-only, state so per dual-integration.
7. SessionStart `compact` matcher re-injecting the prompt_inject insight block (compaction currently loses it) — official hooks docs matcher list; one hooks.json line.
8. Antigravity/universal delivery via `.agents/skills/` + `npx skills add` (already resolves marketplace.json) — vercel-labs/skills; fixes stale `~/.agents/skills` copies at the same time.
9. Document Hermes explicit-load semantics (skill_view, no passive index) in dual-integration.md + AGENTS.md mirror — hermes-agent source.
10. One README curation/security paragraph (hooks reviewed, what CI guards check) — trailofbits/skills-curated stance.

**Reject (over-engineering):** hookify-clone rule engine in-repo; plankton multi-phase LLM fixer pipelines; repo-wide blocking Stop test-gates; per-skill eval harnesses; LangGraph version vectors / DB checkpointers; custom cross-agent registry or skills.json; per-runtime body transforms (codex-bridge stays dead); six-harness adapter dirs (add a runtime only with a real consumer); per-skill plugins; `prompt`/`agent`-type LLM hooks as gates (30-60s per tool call); UUID run ids.

## 8. Completeness gaps — what this recon did NOT cover

1. **No live Hermes execution.** register_skill settled by source read, but load path, `skill_view` resolution, bundle banner, and the in-body fallback-layout claims (P1 #9) are untested. Plan needs either a throwaway Hermes install or an explicit "unverified until Hermes exists" fence on those fixes.
2. **Skill-level install path never run.** install-skills.mjs selftest fails before doing anything; actual `npx skills` behavior (symlinks, references/ handling, marketplace resolution) unobserved. The llm-wiki references finding (P2 #2) implies a whole class — no sweep was done for other skills whose references break under skill-copy installs.
3. **Unverified findings need repro before fixing:** tcrei Task call (P1 #8), codex-image allowed-tools separator (P2 #7), tally-form path (P1 #7), README orphan-rows grep disagreement (P2 #3 vs infra P3).
4. **No SKILL.md size/token audit** against the 500-line ceiling and Codex's 2%/8k skills-list budget — Korean-heavy bodies flagged as likely violators but never measured.
5. **MCP-under-Codex naming unchecked:** paper-search prefix fix (P2 #5) verified on Claude only; the correct prefix under Codex plugin loading may differ again.
6. **Machine-local ops have no home:** Codex hook drift + stale ~/.agents/skills are not repo diffs; plan must decide where refresh procedure lives (README ops section vs a sync script) or it recurs.
7. **ppt-master upstream (engine under ppt-yeong-style) not audited** — the deepest harness candidate sits on an unexamined base.
8. **Test coverage beyond cr-fix:** cr-fix has a fixture suite; the other script-bearing plugins (project-init, mem0-ops, tally-form, gws-sync) have none — script fixes in this refactor land unregressioned unless the plan adds minimal fixtures for at least the resolver-block wave.
9. **PR ordering/bundling not decided:** per user CLAUDE.md, resolver-family + cr-fix repairs + state-envelope adopters are natural PR bundles; needs AskUserQuestion at plan time, as does the language-exemption boundary (section 6 items 4-6).
