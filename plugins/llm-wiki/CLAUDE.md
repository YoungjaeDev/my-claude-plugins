# llm-wiki

Karpathy LLM-Wiki 3-layer system packaged as a plugin. Universal — works in any repo that has (or wants) a `.llmwiki/wiki/` (or legacy `.claude/wiki/`) layer.

## What it ships

| Component | Path | Purpose |
|-----------|------|---------|
| **6 skills** | `skills/{query,ingest,lint,bootstrap,migrate,post-merge}-wiki/` | wiki query, finding ingest, health audit, repo bootstrap, v1→v2 migration, post-merge ingest chain |
| **3 hooks** | `hooks/wiki_{stale_check,post_commit_hint,session_start_lint_hint}.sh` | UserPromptSubmit + PostToolUse(Bash) + SessionStart soft hints |
| **bootstrap templates** | `skills/bootstrap-wiki/assets/templates/` | wiki-skeleton (index, log, spec) + rules-skeleton (_entrypoint, code-map, _domain) |

## Layer model

| Layer | Path | Loaded? | Purpose |
|-------|------|---------|---------|
| **Schema** | `.claude/rules/*.md` | auto | trip-wire invariants only |
| **Wiki (lore)** | `.llmwiki/wiki/**` | on-demand | LLM-maintained domain knowledge |
| **Raw evidence** | `.llmwiki/raw/**` (+ external docs) | direct read | append-only immutable evidence — wiki cites, never copies |

The wiki + raw layers live under the neutral `.llmwiki/` root specifically so `codex-bridge`'s `.claude/`→`.codex/` body transform can never rewrite them into a per-agent `.codex/wiki/` fork. The schema layer stays at `.claude/rules/` — the only verified session-start auto-load path.

Karpathy analogy: rules = `__init__.py` public contract, wiki = module docstrings + design notes, skills = CLI subcommands.

## Resolution order

Skills and hooks resolve the wiki root in order: `.llmwiki/wiki/` (preferred) → `.claude/wiki/` (legacy) → `.codex/wiki/` (legacy Codex fork). New repos get `.llmwiki/`; old repos keep working until migrated via `migrate-wiki`.

## Memory overlay

The 4-tier memory model maps onto existing artifacts — no new directories are created:

| Memory tier | Maps to (existing artifact) | Lifetime |
|-------------|-----------------------------|----------|
| Working | the current session (ephemeral) | this conversation |
| Episodic | `.llmwiki/wiki/log.md` (event log) | append-only |
| Semantic | `.llmwiki/wiki/<domain>/*.md` (consolidated lore) | long-lived |
| Procedural | `.claude/skills/*/SKILL.md` (workflows) | long-lived |

## Frontmatter

Every wiki page (not `index.md`, not `log.md`) carries:

```yaml
---
id: <kebab-case-slug>          # unique page identity
aliases: [other-names]         # dedup / search keys
last_verified: YYYY-MM-DD      # bump ONLY after re-checking vs code/source
status: active                 # active | stale (stale = kept+marked, never deleted)
volatility: stable             # stable | volatile; default stable
sources: 2                     # integer count of named provenance under ## Sources
---
```

`sources` (an integer count under `## Sources`) replaces numeric confidence floats. "How sure" = source count + `last_verified` recency + presence of `> Contradicts:`.

## Cross-ref grammar

Pages link via typed references only — never raw `[[wikilink]]`:

- `> Refines: [[page-id]]`
- `> Contradicts: [[page-id]]`
- `> Evidence: .llmwiki/raw/<file>` (may also point at external `docs/...`)
- `> See-also: [[page-id]]`
- `> Supersedes: [[page-id]]` — on the NEW page, points at the claim it replaces
- `> Superseded-by: [[page-id]]` — on the OLD page (paired with `status: stale`)
- `> Uses: [[page-id]]`
- `> Depends-on: [[page-id]]`
- `> Caused-by: [[page-id]]`
- `> Fixed-by: [[page-id]]`

## Staleness

Per page, the staleness window is driven by `volatility:`: `volatile` → 30 days; `stable` or absent → 180 days. `age_days = (today - last_verified)` past the window flags the page in `lint-wiki` and the stale-check hint hook. Stale pages are marked `status: stale`, never deleted.

## Event log

All wiki events (lint reports, ingest summaries, post-merge ingests) accumulate in the resolved root's `log.md` (`.llmwiki/wiki/log.md`, or a legacy `.claude/wiki/log.md`) with schema header `## YYYY-MM-DD — <event-type> (<source-skill>)`. `grep '## ' wiki/log.md` recovers the time-series.

## Related: spec-state

Spec / issue / PR work-pipeline aggregate (`.claude/state/spec.json`) is owned by the separate `spec-state` plugin (`state-tracker` skill). llm-wiki tracks knowledge lore; spec-state tracks the work pipeline. The two are independent — install whichever you need.

## Conditional behavior

Hooks and skills no-op silently when no wiki root resolves (none of `.llmwiki/wiki/`, `.claude/wiki/`, `.codex/wiki/` present). Safe to enable globally; nothing fires in repos without the wiki layer.

## Shell portability

Hooks and skill scripts target POSIX-shell + a thin set of GNU extensions. Two pitfalls trip up minimal containers and non-en_US locales:

- `grep -P` (PCRE) shorthand classes (`\d`, `\s`, `\K`, ...) silently fail under non-UTF-8 locales (e.g. `ko_KR.eucKR`). Wrap every `grep -oP` call with `LC_ALL=C.UTF-8` to force a deterministic locale.
- `bc` is not part of busybox / alpine / minimal-Debian base images. Replace `paste -sd+ | bc` with `awk '{s+=$1} END{print s+0}'` to sum numeric lines without an external arithmetic dependency.
