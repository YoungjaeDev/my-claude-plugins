---
id: insight-moc
aliases: [insight-index, insight-toc, promoted-lore]
last_verified: 2026-06-01
---

# Insight Map of Content (MOC)

The **insight layer** is the promoted, cross-agent-visible top of the wiki. It holds the small set of findings that have earned graduation from `.llmwiki/wiki/` — recurring, generalizable, costly-to-violate, and stabilized. Both Claude Code and Codex read it (it lives under the neutral `.llmwiki/` root, never `.claude/rules/` which Codex cannot read), and the `core-config` `prompt_inject.sh` hook points every prompt here *first*, before the wiki MOC.

> **For LLMs**: consult this MOC before acting on remembered guidance. Entries are extremely condensed (rule + when-to-apply + why, a few lines). Follow `> Evidence:` / `promoted_from:` down to the wiki/raw page for the full story — never inline that detail back up here.

## Why a separate layer (not `.claude/rules/`)

Wiki findings used to graduate to `.claude/rules/`, but **Codex never reads `.claude/rules/`**, so half the toolchain missed promoted rules. Insight lives at `.llmwiki/insight/` and reaches both agents through the shared prompt-injection hook instead of Claude's `paths:`-glob auto-load. See `> See-also: [[insight-layer-via-hook]]` in the wiki design record.

## Entry frontmatter

Every insight page carries (extends the wiki schema):

```yaml
---
id: <kebab-case-slug>          # unique insight identity
aliases: [other-names]         # dedup / search keys
tier: insight                  # marks this as a promoted entry (vs a wiki page)
promoted_from: [[wiki-id]]     # the wiki page(s) this was graduated from
evidence_count: 2              # distinct sessions/PRs the pattern recurred across
last_verified: YYYY-MM-DD      # bump ONLY after re-checking vs code/source
status: active                 # active | stale (stale = kept+marked, never deleted)
volatility: stable             # stable (180d window) | volatile (30d window)
sources: 2                     # integer count of named provenance under ## Sources
---
```

There is no freeform `tags:` field — the `> Evidence:` link to the source page *is* the tag.

## Promotion criteria (graduate a wiki finding only when ALL hold)

1. **Recurs across sessions** — seen in 2+ independent sessions/PRs, not a one-off.
2. **Generalizable** — applies beyond the single file/bug that surfaced it.
3. **Costly to violate** — getting it wrong breaks a build/release/reproducibility gate or wastes a review cycle.
4. **Stabilized** — settled, not under active debate or still being designed.

Do NOT promote: one-offs, undecided/contested points, things already known before the project, or reusable *procedures* (those become a skill, not an insight).

## Consolidation discipline (non-append)

Insight is the most aggressively consolidated layer. Before adding an entry: grep `id`/`aliases`/bodies for the concept; prefer **update / supersede** over a new entry; keep each entry to its rule + apply-when + why and push longer reasoning down to `> Evidence:`. Naive accumulation here is worse than in the wiki — bloat at the top defeats the point of a promoted layer.

## Entries

<!-- Graduate findings here via `/llm-wiki:ingest-finding` (its graduation step).
     One hook per entry: `- [title](<slug>.md) — rule + when-to-apply (promoted_from [[wiki-id]])` -->

- [Regenerate Codex manifests on surface change](codex-manifest-regen.md) — run `node scripts/sync-codex-manifests.mjs` after any plugin skills/version/description/category change; `--check` is the CI drift gate; never hand-edit generated manifests or reintroduce a body transform (promoted_from [[shared-source-codex-manifests]]).
- [Keep skill descriptions under 1024 chars](codex-skill-desc-1024.md) — Codex 0.135 silently drops any skill whose `description` exceeds 1024 chars (Claude has no cap, so it's invisible Claude-side); push the full trigger list into the body, not the description; `--check` + pre-commit enforce it (promoted_from [[shared-source-codex-manifests]]).
- [CR "free tier disabled" = quota refill](cr-rate-limit-budget.md) — CR `Review skipped: free tier disabled` is progressive-refill exhaustion, not a plan downgrade; no sniff cooldown; treat `--max-iter` as a CR quota budget (promoted_from [[cr-rate-limit-progressive-refill]]).
- [Plugin versions pin at session start](plugin-cache-restart.md) — a session pins each plugin's version at startup; restart to pick up a cached update; mid-migration, drive work from repo source not the pinned skill (promoted_from [[cache-version-pinning]]).
- [Never reduce AGENTS.md to a pointer](agents-md-no-import.md) — Codex has no `@import` at all (it byte-reads AGENTS.md) and Claude never reads AGENTS.md, so `@CLAUDE.md` or a prose redirect silently strips all guidance from Codex/Hermes and misses the Codex cloud reviewer entirely; keep it inline, or invert so `CLAUDE.md` imports `@AGENTS.md` (promoted_from [[agents-md-verbatim-no-import]]).
- [Build a self-improvement loop: guide before, sensor after](harness-loop-guide-sensor.md) — design harnesses for a generate→verify→fix loop, not one-shot; pair a guide (instruction/MCP/SSOT, before action) with a deterministic sensor (tests/lint/types/trace, after action); "can I give it a guide + sensor?" is the delegation criterion; thinking is delegable, understanding is not (promoted_from [[harness-engineering-principles]]).
