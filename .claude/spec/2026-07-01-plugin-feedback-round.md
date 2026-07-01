# Feature Specification: Plugin Feedback Round (2026-07-01)

## Overview
Investigation-phase spec capturing 8 audited feedback items and their confirmed
decisions for a later implementation session. NOTHING is implemented yet — this
file is the durable output of a `/interview:interview-methodology` breadth-first
audit (7-axis Workflow `wf_fc3fc99b-a42` + a cr-fix guard agent). Every file
list below is verified against the repo at audit time.

## Confirmed Decisions (user, 2026-07-01)

| # | Item | Decision |
|---|------|----------|
| 1 | council | **DELETE entirely** (not modernize) |
| 1 | workflow-viz, notion | **DELETE** (default, not separately asked) |
| 2 | full audit | counts OK; one gap: `codex-image` missing from `settings.json` |
| 3 | code-scout MCP-missing | **ADD reactive setup-guide** (error + how-to on missing MCP) |
| 4 | brightdata-guide | **PORT** as new plugin (Claude/Codex/Hermes) |
| 5 | tally-form webhook | **ADD `--webhook` flag** to builder |
| 6 | mem0 `.mcp.json` | **NO ACTION** (mem0 already global; bundling duplicates) |
| + | codex-image dangerous mode | **KEEP `-s workspace-write`**; only add `effort high` default |
| 8 | cr-fix minor guard | **IMPLEMENT plateau-stop** (`--plateau-iter`) |

## Requirements

### P0 — Removals (single PR: 24 → 21 plugins)
Remove `plugins/{council,notion,workflow-viz}/`. All three have zero references in
`.llmwiki/`, `scripts/`, `AGENTS.md`, `.githooks/`, `.github/` (grep clean).
- [ ] Delete 3 plugin dirs.
- [ ] `CLAUDE.md`: `## Plugins (24)`→`(21)`; drop table rows (council L32, notion L45, workflow-viz L75); drop tree lines (L98/L106/L110); Codex section L135 `22 eligible`→`19 eligible`.
- [ ] `README.md`: L11 `24개`→`21개`; L13 badge `plugins-24`→`plugins-21`; drop table rows L87/L92/L100; drop `<details>` sections (council L277-287, notion L348, workflow-viz L570-579); drop settings-snippet lines L634/L641/L645; drop tree lines L739/L747/L751; L670 `22 / 24`→`19 / 21`; L672 drop `council` from the command-bearing example.
- [ ] `.claude-plugin/marketplace.json`: remove 3 entries; bump `metadata.version` (re-check vs `origin/main`, not fork point — concurrent-branch trap).
- [ ] `.claude/settings.json`: remove 3 `./plugins/<name>` entries (L8/L14/L16).
- [ ] Regen: `node scripts/sync-codex-manifests.mjs` (removes 3 `.codex-plugin/` + 3 `.agents/plugins/marketplace.json` entries; orphan guard fails otherwise) + `node scripts/sync-hermes-manifests.mjs` (no-op, none Hermes-eligible; run so `--check` passes).
- Note: **workflow-viz Stop hook** auto-rewrites the `<!-- last-updated -->` doc line each session (recorded in auto-memory `auto_regen_docs.md`). Removing it drops that auto-regen — accepted.

### P0 — codex-image `settings.json` gap (fold into removals PR or separate)
- [ ] Add `./plugins/codex-image` to `settings.json` `plugins.local` (currently 23/24; codex-image absent so it does not auto-load locally). Confirm intent first — may be deliberate on-demand.

### P1 — brightdata-guide port (new plugin: 21 → 22, or 24 → 25 if done before removals)
Source: `dandacompany/dante-skills/brightdata-guide` (MIT, Hermes-native, 4 files, no scripts).
- [ ] `plugins/brightdata-guide/.claude-plugin/plugin.json` (name, version 1.0.0, description short, license MIT).
- [ ] `plugins/brightdata-guide/skills/brightdata-guide/SKILL.md` — copy source, **TRIM description 1153→≤1024 chars** (drop the `USE FOR:` enumeration + delegate `IMPORTANT:` paragraph from description; body keeps full trigger list). **Blocking gate** — untrimmed fails `sync-codex-manifests.mjs --check` (pre-commit + CI) and Codex silently skips it.
- [ ] Copy `references/{cli-commands,mcp-setup,mcp-tools}.md` verbatim.
- [ ] Add a small tool-compat note: `terminal`↔Bash(Claude)/execute_command(Codex); state "MCP tool names are runtime-identical" (Bright Data MCP tool names are the same across runtimes).
- [ ] `HERMES_ELIGIBLE`: **YES** — add `'brightdata-guide'` to `scripts/sync-hermes-manifests.mjs:28` (only code edit).
- [ ] marketplace entry `category: "research"`; `settings.json` `plugins.local` add; CLAUDE.md/README counts + Hermes-eligible (6→7) + Codex-eligible bumps.
- [ ] `.mcp.json` bundling: **OMIT** (skill is anti-auto-config by design; CLI is built-in fallback). Optional opt-in shape if wanted later:
  ```json
  { "mcpServers": { "brightdata": { "command": "npx", "args": ["-y", "@brightdata/mcp"], "env": { "API_TOKEN": "${BRIGHTDATA_API_KEY}" } } } }
  ```
- Dependency: Bright Data account + token (`BRIGHTDATA_API_KEY` env or `bdata login`). ~5000 free credits/mo.

### P1 — tally-form `--webhook` flag
Tally REST API: `POST https://api.tally.so/webhooks`, **free tier**, Bearer `tly-` key (same key as form builder), event `FORM_RESPONSE`. Webhooks are the free alternative to Pro confirmation emails.
- [ ] Add `--webhook <url> [--signing-secret <s>]` (or frontmatter `webhook:`) to `build_tally_form.py`: after publish, one extra `POST /webhooks` with `{formId, url, eventTypes:["FORM_RESPONSE"], signingSecret?}`, reusing existing urllib helper/auth. ~10-15 lines, stays stdlib-only.
- [ ] Idempotency: `GET /webhooks` check-before-create so re-runs don't duplicate (verify Tally's dup behavior at build time).
- Out of scope (separate concern, do NOT bolt onto the builder): submission retrieval, analytics reads, HMAC signature verification → those belong to a sibling `tally-api` skill if ever wanted.
- Update `.llmwiki/wiki/tally-form-ops/tally-api-schema-vs-live.md` (webhooks are free, not Pro-gated like email).

### P1 — code-scout MCP-missing setup-guide (reactive)
MCP servers are not `command -v`-checkable, so this must be **reactive**: catch a failed `mcp__*` call and map it to a clear "MCP X unconfigured → setup instructions" message, instead of today's silent degrade.
- Reuse patterns: deepwiki's fallback-link contract (`references/ask-procedure.md:137`), `paper-search-tools:setup` skill (error-string-triggered), `resource-finder` error+install (`search_github.py:199-202`).
- [ ] Per required-MCP scout (exa/web, context7+deepwiki/docs, paper-search/paper), on tool-call failure emit a typed `error` that names the missing server + a one-line setup pointer (host `~/.claude/settings.json` MCP config, or `/mcp`), rather than an opaque degrade.
- insane-search already has the exemplar contract (`insane_search: not_installed` skip) — mirror its shape.
- Keep graceful degrade (don't hard-block the whole fan-out) but make the missing-MCP case *visible + actionable* per the user's ask.

### P2 — codex-image effort-high default
- [ ] Make `-c model_reasoning_effort="high"` the default in the codex-image invocation (currently omitted). Keep `-s workspace-write` (NO bypass). Keep output at `assets/generated/codex-image/`.
- [ ] Since posture is unchanged (workspace-write kept), `codex-image-bridge-design.md` needs NO security rewrite — only note effort default flipped to high if desired.

### P2 — cr-fix plateau-stop guard (v3 lesson 1)
Per `plugins/github-dev/skills/cr-fix/references/lessons-from-dogfood.md` (PR#33 apply curve `4→5→2→2→1→1→2→1` never naturally converged).
- [ ] Add `--plateau-iter <N>` (default e.g. 2): stop when N consecutive iters had ≤1 apply AND the same finding was deferred in ≥2 iters. Complements `minor_floor` (which requires `applied>0` and so can't stop a `2 apply→2 new` plateau).
- [ ] Optional (lesson 2): track `deferred_findings` in the state file; skip re-judging a finding deferred ≤3 iters ago.
- [ ] New `final_state=plateau`; excluded from `--auto-merge` like `minor_floor`.
- Update `.llmwiki/wiki/cr-fix-ops/` with the implemented guard (move from prospective → active).

## Suggested PR Bundling (implementation phase)
1. **Removals** (council + notion + workflow-viz + codex-image settings gap) — one PR, mechanical.
2. **brightdata-guide** — one PR (new plugin).
3. **tally-form `--webhook`** — one PR.
4. **code-scout MCP setup-guide** — one PR (reactive guards across scouts).
5. **codex-image effort-high** — small; can ride with (4) or standalone.
6. **cr-fix plateau-stop** — one PR (github-dev).

## Out of Scope
- council modernization (rejected in favor of delete).
- codex-image `--dangerously-bypass-approvals-and-sandbox` (rejected; workspace-write suffices for in-repo output).
- mem0 `.mcp.json` bundling (mem0 already global; would duplicate).
- tally submission/analytics/signature-verify (sibling-skill concern, not the builder).

## CLAUDE.md maintenance (decided 2026-07-01)
- **Surgical-only.** Root `CLAUDE.md` changes ride inside the removals/add PRs (count/table/tree/eligible lines) — NO `/init` regen (would clobber the hand-tuned multi-runtime / Codex-Hermes-sync / Modular-Rules structure), NO separate freshness pass this round.
- Note: exa (`mcp__exa__web_search_exa` + `web_fetch_exa`) is used by **web-scout** (tier-1, optional-with-fallback to WebSearch) — the missing-MCP setup-guide (item 3) covers exactly this degrade path.

## Open Questions
- codex-image `settings.json` absence: deliberate on-demand load, or a genuine gap to fix?
- brightdata port timing: before or after the removals (affects which count deltas apply).
- cr-fix `--plateau-iter` default value (2 proposed) and whether lesson-2 defer-dedupe ships in the same PR.
- **Deferred freshness item (not this round):** `CLAUDE.md` + `dual-integration.md` pin "Codex 0.135", but the installed CLI is codex 0.142.3 (axis D). Re-verify whether 0.142 changed the manifest surface (`skills`/`hooks`/`mcpServers`/`apps`) before updating those version references — unverified, do not blindly bump.

## Provenance
- Workflow `wf_fc3fc99b-a42` (7 axes A–G), cr-fix guard agent (axis H).
- Wiki: `codex-image-bridge-design.md`, `tally-api-schema-vs-live.md`, `cr-fix-yagni-over-engineering-axis.md`, `lessons-from-dogfood.md`, `mem0-llmwiki-federation.md`.
