# Wiki Log

Append-only event log for the resolved wiki root (`.llmwiki/wiki/`, or a legacy `.claude/wiki/` if that is what the repo has). Each entry under a `## YYYY-MM-DD — <one-line summary>` header. Newest first.

Every `/ingest-finding` run and every `/github-dev:post-merge` run that executes the wiki ingest step writes a block here **before** touching the page, so `git revert` of the resulting commit cleanly reverses both. (Post-merge skips the ingest — and this log — for trivial merges or when no wiki root resolves.) See `ingest-finding` skill for the diff-log discipline.

---

<!-- New entries go directly under this line -->

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
