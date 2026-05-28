# llm-wiki

Karpathy LLM-Wiki 3-layer system packaged as a plugin. Universal — works in any repo that has (or wants) a `.claude/wiki/` layer.

## What it ships

| Component | Path | Purpose |
|-----------|------|---------|
| **5 skills** | `skills/{query,ingest,lint,bootstrap,post-merge}-wiki/` | wiki query, finding ingest, health audit, repo bootstrap, post-merge ingest chain |
| **2 hooks** | `hooks/wiki_{stale_check,post_commit_hint}.sh` | UserPromptSubmit + PostToolUse(Bash) soft hints |
| **bootstrap templates** | `skills/bootstrap-wiki/assets/templates/` | wiki-skeleton (index, log, spec) + rules-skeleton (_entrypoint, code-map, _domain) |

## Layer model

| Layer | Path | Loaded? | Purpose |
|-------|------|---------|---------|
| **Schema** | `.claude/rules/*.md` | auto | trip-wire invariants only |
| **Wiki (lore)** | `.claude/wiki/**/*.md` | on-demand | LLM-maintained domain knowledge |
| **Raw evidence** | `docs/research/audits/*.md` etc. | direct read | append-only audit reports — wiki cites, never copies |

Karpathy analogy: rules = `__init__.py` public contract, wiki = module docstrings + design notes, skills = CLI subcommands.

## Cross-ref grammar

Pages link via typed references only — never raw `[[wikilink]]`:

- `> Refines: [[page-id]]`
- `> Contradicts: [[page-id]]`
- `> Evidence: docs/research/audits/<file>.md`
- `> See-also: [[page-id]]`

## Event log

All wiki events (lint reports, ingest summaries, post-merge ingests) accumulate in `.claude/wiki/log.md` with schema header `## YYYY-MM-DD — <event-type> (<source-skill>)`. `grep '## ' wiki/log.md` recovers the time-series.

## Related: spec-state

Spec / issue / PR work-pipeline aggregate (`.claude/state/spec.json`) is owned by the separate `spec-state` plugin (`state-tracker` skill). llm-wiki tracks knowledge lore; spec-state tracks the work pipeline. The two are independent — install whichever you need.

## Conditional behavior

Hooks and skills no-op silently when `.claude/wiki/` is absent. Safe to enable globally; nothing fires in repos without the wiki layer.

## Shell portability

Hooks and skill scripts target POSIX-shell + a thin set of GNU extensions. Two pitfalls trip up minimal containers and non-en_US locales:

- `grep -P` (PCRE) shorthand classes (`\d`, `\s`, `\K`, ...) silently fail under non-UTF-8 locales (e.g. `ko_KR.eucKR`). Wrap every `grep -oP` call with `LC_ALL=C.UTF-8` to force a deterministic locale.
- `bc` is not part of busybox / alpine / minimal-Debian base images. Replace `paste -sd+ | bc` with `awk '{s+=$1} END{print s+0}'` to sum numeric lines without an external arithmetic dependency.
