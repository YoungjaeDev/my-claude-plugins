---
id: wiki-moc
aliases: [moc, table-of-contents, llms-txt]
last_verified: 2026-06-10
---

# Wiki Map of Content (MOC)

This file is the entry point for the LLM-maintained lore layer. Every wiki page is listed below with a 1-line hook. Pages live 2-depth max under `.llmwiki/wiki/<domain>/<page>.md`.

> **For LLMs**: when answering a "why" or "how" question that isn't a code invariant, read this file first, follow the hook to the right page, and cite the wiki page (not the underlying audit md). When you discover new lore, use `/ingest-finding` to update.

> **Insight layer**: the promoted, cross-agent rules live one level up at `.llmwiki/insight/index.md` (the `core-config` prompt-inject hook points there first). Check it before this MOC; graduate findings up to it via `/ingest-finding`.

## Page frontmatter (mini-legend)

Every wiki page (not this MOC, not `log.md`) carries:

```yaml
---
id: <kebab-case-slug>          # unique page identity
aliases: [other-names]         # dedup / search keys
last_verified: YYYY-MM-DD      # bump ONLY after re-checking vs code/source
status: active                 # active | stale (stale = kept+marked, never deleted)
volatility: stable             # stable (180d window) | volatile (30d window); default stable
sources: 2                     # integer count of named provenance under ## Sources
---
```

"How sure" = source count + `last_verified` recency + presence of `> Contradicts:`. No numeric confidence floats.

## Cross-reference grammar

Pages link to each other using **typed** references only — never raw `[[wikilink]]`:

- `> Refines: [[page-id]]` — this page adds detail to another
- `> Contradicts: [[page-id]]` — points out a conflict (must be resolved before next edit)
- `> Evidence: .llmwiki/raw/<file>` — citation to immutable raw evidence (may also point at external `docs/...`)
- `> See-also: [[page-id]]` — related but independent
- `> Supersedes: [[page-id]]` — on the NEW page, points at the claim it replaces
- `> Superseded-by: [[page-id]]` — on the OLD page (paired with `status: stale`)
- `> Uses: [[page-id]]`
- `> Depends-on: [[page-id]]`
- `> Caused-by: [[page-id]]`
- `> Fixed-by: [[page-id]]`

A wiki page may cross-layer reference a promoted insight entry the same way (`[[insight-id]]`) — the id resolves in either layer.

## Maintenance ops

| Op | Skill | When |
|----|-------|------|
| Find | `query-wiki` | "Where is the lore on X?" |
| Add | `ingest-finding` | New audit md / PR result / debugging finding |
| Health check | `lint-wiki` | Identity / level / relationship / staleness audit |

All wiki edits append one line to `log.md` (`## YYYY-MM-DD — <summary>` header).

## Domains

## llm-wiki-design

The v2 design record: which rohitg00-v2 ideas were harvested vs rejected, and why.

- [Curated-conservative v2 upgrade](llm-wiki-design/curated-conservative.md) — hub: harvest the git-auditable kernel of each v2 idea, reject the heavyweight machinery (steal the ideas, not the plan).
- [Insight layer via hook](llm-wiki-design/insight-layer-via-hook.md) — promoted rules graduate to `.llmwiki/insight/` delivered by the shared prompt-inject hook (Claude + Codex), NOT `.claude/rules/` (Codex can't read it). Refines neutral-`.llmwiki/`-root (promotion target) + curated-conservative (the one justified new dir).
- [Neutral `.llmwiki/` root](llm-wiki-design/neutral-llmwiki-root.md) — wiki/raw move out of `.claude/` so the retired codex-bridge `.claude/`->`.codex/` body transform could never fork the wiki per-agent; schema-home claim refined by insight-layer-via-hook.
- [Volatility over decay](llm-wiki-design/volatility-over-decay.md) — a `volatility:` class with a fixed window replaces Ebbinghaus decay math; old is not stale.
- [Provenance over confidence](llm-wiki-design/provenance-over-confidence.md) — `sources: N` + a named `## Sources` list replaces fabricated float confidence.
- [Post-merge wiki trigger](llm-wiki-design/post-merge-trigger.md) — wiki ingest reaches the wiki two ways: github-dev:post-merge Step 8 (mandatory built-in, absorbed post-merge-wiki, covers workflow + GitHub-UI merges) and the wiki_post_commit_hint hook (local CLI merges only). Step 8 now force-logs `ingested N`/`no-lore` (no silent skip; `WIKI_AUTOINGEST=0` disables).
- [Capture/curation split](llm-wiki-design/capture-curation-split.md) — the session-boundary auto-trigger: a mechanical Stop-hook capture (flag + transcript pointer to `.staging/`) split from an LLM SessionStart-drain curation (dedup + ingest). A shell hook can't dedup, so over-capture is safe and curation waits one session.
- [mem0 <-> llmwiki federation](llm-wiki-design/mem0-llmwiki-federation.md) — the two memory systems federate by labels only (`.llmwiki/` = `[AUTHORITATIVE]`, mem0 = `[RECALL]`), never runtime coupling. prompt_inject.sh never calls mem0; Codex omits `[RECALL]`; `CORE_CONFIG_FEDERATE_MEM0=0` reverts. Borrow patterns, not data.

## plugin-ops

Operational lore for the plugin system itself — cache, loading, version resolution. Complements the schema-layer version contract in `.claude/rules/plugin-versioning.md`.

- [Plugin cache version-pinning](plugin-ops/cache-version-pinning.md) — the cache holds multiple versions per plugin; a session pins the startup-resolved version, so a newer already-cached version is not served until restart (or via a `local` settings.json source).
- [Shared-source Codex manifests](plugin-ops/shared-source-codex-manifests.md) — Claude and Codex 0.135 read the same `plugins/<name>/skills/` tree via a thin manifest generator (`scripts/sync-codex-manifests.mjs`); the retired `codex-bridge` body-transform mirror was wrong because its 275 audit hits were authorial intent, not stale references. 19 of 22 plugins eligible (3 EXCLUDED: core-config, midjourney, codex-image — the last a circular Claude->Codex bridge). `--check` also guards the Codex 1024-char skill-`description` cap (Codex silently skips longer ones).
- [Dual-surface command + skill pattern](plugin-ops/dual-surface-command-skill-pattern.md) — how a plugin ships both an explicit `/plugin:command` and a Codex-loadable `skill` from a single `references/<name>-procedure.md` body; documents the runtime preflight guard required for destructive plugins and the `PLUGIN_ROOT` resolver pattern that handles Codex's lack of `${CLAUDE_PLUGIN_ROOT}`.
- [prompt-inject Korean-persistence](plugin-ops/prompt-inject-korean-persistence.md) — the per-prompt block must explicitly name internal workflow / subagent / English-skill paths (ultracode, deep-research) as NOT a "별도 지시"; otherwise a downstream English skill body reads as the override the bare Korean-default line defers to, and the final user answer regresses to English.

## cr-fix-ops

Per-plugin operational lore for `github-dev:cr-fix` — rate-limit semantics, dogfood-derived design rationale that overturns intuition. Distinct from `plugin-ops/` (Claude Code runtime) and from the cr-fix references files (active design contract).

- [CR rate-limit progressive refill](cr-fix-ops/cr-rate-limit-progressive-refill.md) — `cr_desc: "Review skipped: free tier disabled"` does NOT mean the org reverted to Free plan; it signals CR trial/Pro progressive-refill quota exhaustion. Do NOT add a sniff cooldown; treat `--max-iter` as a CR quota budget (default 5 = Pro 5-rev/hour).
- [CR CLI false positive on generated files](cr-fix-ops/cr-cli-false-positive-generated-files.md) — the local CodeRabbit CLI flags a correctly-regenerated `.codex-plugin/plugin.json` as "manually edited, revert + regenerate" (Major); it is spurious — `node scripts/sync-codex-manifests.mjs --check` passing proves generator-consistency, so skip the finding instead of reverting.
- [cr-fix state file not self-describing](cr-fix-ops/state-file-self-describing.md) — `emit-final-json.sh` assembled `final_state` + `auto_judge_stats` into stdout only, never the archived state file, so `post-merge` Step 1.5 reading the archive saw `final_state=unknown` / `defer=0` and silently hid deferred reviews. Fix: persist final fields before the archive `mv` (self-describing) + consumer falls back to counting `auto_judge_log` defers. Test the real producer→archive→consumer chain, not a hand-built fixture.

## research-harness

Cross-plugin research harness boundary contracts (code-scout, `/deep-research`, paper-search-tools). Captures inter-harness routing rules that span plugins.

- [code-scout vs /deep-research boundary](research-harness/code-scout-vs-deep-research-boundary.md) — code-scout owns code / ML / docs / papers; `/deep-research` owns generic topics; `research-orchestrator` does NOT delegate to `/deep-research`. Boundary is intentional — the two harnesses tune their fan-out for incompatible domains.
