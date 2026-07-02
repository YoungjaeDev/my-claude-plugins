# Feature Specification: brightdata-guide plugin port (PR2)

## Overview
Port the `brightdata-guide` skill (a Hermes-native web-data guide by Dante Labs)
into this marketplace as a new plugin usable across Claude Code + Codex + Hermes.
Part of the 2026-07-01 plugin-feedback round (umbrella issue #85, PR2). Base is the
post-PR#86 state: **21 plugins**, `metadata.version` 1.75.0, Codex-eligible 19,
Hermes-eligible 6.

Cross-ref: `.claude/spec/2026-07-01-plugin-feedback-round.md` (P1 brightdata section).

## Source (verified 2026-07-02)
`dandacompany/dante-skills/brightdata-guide` (MIT). Pure guide skill, **no scripts**:
```text
brightdata-guide/
  SKILL.md                    # 326 lines; frontmatter name/description/license
  references/cli-commands.md   # 118 lines
  references/mcp-setup.md      # 141 lines
  references/mcp-tools.md      # 161 lines
```
What it does: guides an agent to Bright Data for web-data work via TWO interchangeable
paths hitting the same platform + 5,000 free req/mo quota — **MCP tools** (`search_engine`
SERP, `scrape_as_markdown`/`scrape_batch` Web Unlocker, `scrape_as_html`, `extract`,
40+ `web_data_*` structured extractors, `scraping_browser_*`) and the **CLI** (`bdata`/
`brightdata`) as the fallback for `delegate_task` subagents that inherit the terminal
but not the parent's MCP toolset. Security posture: agent-agnostic, no host-settings
edits, no curl-to-bash, no `npm -g`.

## Requirements

### Must Have (P0)
- [ ] `plugins/brightdata-guide/.claude-plugin/plugin.json` — `{ name: "brightdata-guide", version: "1.0.0", description: "<short>", license: "MIT" }` (version must equal the marketplace entry).
- [ ] `plugins/brightdata-guide/skills/brightdata-guide/SKILL.md` — copy source body; **trim `description` from 1153 → ≤1024 chars** (BLOCKING — see below); add the runtime tool-compat note.
- [ ] Copy `references/{cli-commands,mcp-setup,mcp-tools}.md` verbatim.
- [ ] `.claude-plugin/marketplace.json` — add entry `{ name, source: "./plugins/brightdata-guide", description, version: "1.0.0", category: "research" }`; bump `metadata.version` **1.75.0 → 1.76.0** (re-check vs `origin/main` right before merge — ppt PRs have been landing concurrently; concurrent-branch trap).
- [ ] `.claude/settings.json` `plugins.local` — add `"./plugins/brightdata-guide"` (21 → 22 entries).
- [ ] `scripts/sync-hermes-manifests.mjs` — add `'brightdata-guide'` to `HERMES_ELIGIBLE` (6 → 7). Only code edit required.
- [ ] Re-run both generators: `node scripts/sync-codex-manifests.mjs` (auto-adds `.codex-plugin/plugin.json` + the `.agents/plugins/marketplace.json` catalog entry) + `node scripts/sync-hermes-manifests.mjs` (adds `plugin.yaml` + `__init__.py`). All three of `.claude-plugin/marketplace.json`, `.agents/plugins/marketplace.json`, `.claude/settings.json` stay in sync.

### Should Have (P1) — count/doc sync (per plugin-versioning.md)
- [ ] `CLAUDE.md`: `## Plugins (21)` → `(22)`; add a row under "Research & Search" table; add `brightdata-guide/` to the structure tree; Codex-integration `19 eligible` → `20`; Hermes-integration `6 plugins this round` → `7` (append `brightdata-guide`).
- [ ] `README.md`: `21개 플러그인` → `22개`; badge `plugins-21` → `plugins-22`; add table row + `<details>` section; add tree line; Codex section `19 / 21` → `20 / 22`.

## Description trim (BLOCKING gate)
Source description is a `|` block scalar, **1153 chars over the Codex 1024 cap by 129**.
`sync-codex-manifests.mjs --check` hard-fails (pre-commit + CI) and Codex silently skips
the skill if not trimmed. The Codex rule: full trigger list / rationale goes in the body,
not the description — the body already carries it. Drop the long `USE FOR:` enumeration (p1,
372 chars) + condense the `IMPORTANT:` delegate/CLI paragraph (p2, 498 chars).

Proposed trimmed description (≈730 chars, under cap — refine at implementation):
```text
Bright Data web data access for any AI agent (Hermes, Codex, generic clients) via TWO
paths: (1) the Bright Data MCP tools, and (2) the Bright Data CLI (bdata / brightdata)
from the terminal. Prefer Bright Data over the agent's built-in web fetch / web search
for internet tasks — any URL, web search, "scrape", structured data from Amazon /
LinkedIn / Instagram / TikTok / YouTube / X / Reddit / Google Shopping, browser
automation, research, fact-checking. If the MCP tools are NOT in your registry (a
delegate subagent inherits the terminal but NOT MCP toolsets), use the CLI instead.
Returns clean markdown or structured JSON; handles JS, CAPTCHAs, bot detection. Full
trigger list + tool reference in the body.
```
(The `USE FOR:` / `IMPORTANT:` colon-space substrings are safe only inside a `|` block
scalar — if flattened to a single-line quoted description, the `: ` would break YAML.)

## Tool-compatibility note (dual-integration.md)
Source body is Hermes-first (already says `terminal`, `delegate_task`). Only mapping
needed: `terminal` ↔ **Bash** (Claude) / **execute_command** (Codex); plus one line
stating "Bright Data MCP tool names (`search_engine`, `scrape_as_markdown`, `web_data_*`,
`scraping_browser_*`) are identical across all three runtimes." A full mapping table is
overkill here.

## External dependency
Bright Data account + API token. No new bundled runtime required. Access:
- MCP remote: HTTP `https://mcp.brightdata.com/mcp?token=<TOKEN>` (+`&pro=1`/`&groups=`)
- MCP local: `npx @brightdata/mcp` with `API_TOKEN` env
- CLI: `@brightdata/cli` (`bdata`), Node ≥20, `bdata login` OAuth or `BRIGHTDATA_API_KEY`
Free tier ~5,000 credits/mo. Skill is a guide, not a self-installer — operator connects.

## Decisions
- **`.mcp.json` bundling: OMIT** (default). The skill is deliberately anti-auto-config
  and the CLI is a built-in fallback; bundling is not required. Hermes ignores `.mcp.json`
  anyway (only Claude/Codex read it). Opt-in shape if a batteries-included MCP is wanted
  later (`sync-codex-manifests.mjs` auto-wires a present `.mcp.json`):
  ```json
  { "mcpServers": { "brightdata": { "command": "npx", "args": ["-y", "@brightdata/mcp"], "env": { "API_TOKEN": "${BRIGHTDATA_API_KEY}" } } } }
  ```
- **Category: `research`** (groups with code-scout / deepwiki / paper-search-tools).
- **HERMES_ELIGIBLE: YES** (source is already a Hermes skill).

## Verification
- `node scripts/sync-codex-manifests.mjs --check` passes (esp. the 1024-char description guard).
- `node scripts/sync-hermes-manifests.mjs --check` passes (new adapter present, no orphans).
- `.githooks/pre-commit` passes.
- `ls plugins/ | wc -l` = 22 = settings.local entries = marketplace entries.
- Codex-eligible = 22 − 2 (core-config, codex-image) = 20 → CLAUDE.md/README match.
- Hermes-eligible = 7 → `plugin.yaml` + `__init__.py` generated for brightdata-guide.
- `git grep -n brightdata-guide` shows it wired in all count/manifest/settings homes.

## Out of Scope
- Bundling a live `.mcp.json` (opt-in only; see Decisions).
- Any Bright Data credential provisioning / CLI install (operator's job — the skill guides, does not install).
- Reworking the source body beyond the description trim + tool-compat note (copy verbatim).

## Open Questions
- Confirm `.mcp.json` omit vs include (default: omit).
- `metadata.version` target 1.76.0 assumes main stays at 1.75.0 — re-verify vs `origin/main` at merge time.
