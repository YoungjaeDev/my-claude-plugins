# llm-wiki

Karpathy LLM-Wiki 3-layer system packaged as a plugin. Universal — works in any repo that has (or wants) a `.llmwiki/wiki/` (or legacy `.claude/wiki/`) layer.

## What it ships

| Component | Path | Purpose |
|-----------|------|---------|
| **4 skills** | `skills/{ingest,lint,bootstrap}-wiki/` + `skills/plaud-note-taking/` | finding ingest, health audit, repo bootstrap, PLAUD transcript correction. (Post-merge ingest moved into `github-dev:post-merge` as a mandatory step; query-wiki and migrate-wiki were retired 2026-08 — read `index.md` directly, migrate manually per bootstrap-wiki.) |
| **5 hooks** | `hooks/wiki_{stale_check,post_commit_hint,session_start_lint_hint,session_capture,session_start_drain}.sh` | UserPromptSubmit + PostToolUse(Bash) + SessionStart soft hints, plus Stop/SubagentStop-capture + SessionStart-drain auto-ingest (capture/curation split; `session_capture` wired to both Stop and SubagentStop — the latter scans the subagent's own `agent_transcript_path`, keyed by `agent_id` so it never collides with the parent capture) |
| **plaud-note-taking** | `skills/plaud-note-taking/` | Corrects PLAUD voice-recorder Whisper transcripts against a project terminology dictionary and writes `*.corrected.md` under `.llmwiki/raw/transcripts/` (absorbed from `plaud-note-taking`) |
| **bootstrap templates** | `skills/bootstrap-wiki/assets/templates/` | wiki-skeleton (index, log, spec) + insight-skeleton (index, _insight-template) |

## Layer model

| Layer | Path | Loaded? | Purpose |
|-------|------|---------|---------|
| **Insight (promoted)** | `.llmwiki/insight/**` | via `core-config` `prompt_inject.sh` hook (Claude + Codex), every prompt | cross-agent promoted rules: recurring, generalizable, costly-to-violate, stabilized |
| **Wiki (lore)** | `.llmwiki/wiki/**` | on-demand | LLM-maintained domain knowledge |
| **Raw evidence** | `.llmwiki/raw/**` (+ external docs) | direct read | append-only immutable evidence — wiki cites, never copies |

All three layers live under the neutral `.llmwiki/` root — one copy, both agents (Claude + Codex read the same tree in place). llm-wiki no longer maintains a `.claude/rules/` schema layer: Codex never reads `.claude/rules/`, so cross-agent rules graduate to `.llmwiki/insight/` and reach both runtimes via the prompt-injection hook instead of Claude's `paths:`-glob auto-load. `.claude/rules/` stays reserved for mechanical tool-operation rules (e.g. versioning), not wiki lore. See `> See-also: [[insight-layer-via-hook]]` in `.llmwiki/wiki/llm-wiki-design/`.

Karpathy analogy: insight = `__init__.py` public contract, wiki = module docstrings + design notes, skills = CLI subcommands.

## Resolution order

Skills and hooks resolve the wiki root in order: `.llmwiki/wiki/` (preferred) → `.claude/wiki/` (legacy) → `.codex/wiki/` (legacy Codex fork). New repos get `.llmwiki/`; old repos keep working until migrated manually (see bootstrap-wiki).

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

## Raw layout

`.llmwiki/raw/` is bucketed by source-type, not dumped flat (wiki uses domain subdirs, insight stays flat — each layer's structure follows the axis on which its content actually varies):

| Bucket | Holds |
|--------|-------|
| `external/` | third-party originals (gist, paper, vendor doc, web article) |
| `research/` | our generated research (deep-research, code-scout, survey dumps) |
| `transcripts/` | conversation / recording captures (chat exports, meeting/call transcripts) |
| `audits/` | debug / audit captures (audit md, session debug notes) |

Filename `YYYY-MM-DD-<slug>.<ext>` (date = ingested day). Newly captured *text* raw (md/txt/html) carries `source_url` / `ingested` / `sha256`-of-body frontmatter; *binary* raw (pdf) is stored as-is (no inline frontmatter, outside the drift check). Existing files are moved as-is, never backfilled — immutability is *content*, not path, so a `git mv` into a bucket preserves the body hash. `lint-wiki` Step 11 drift-checks any `sha256:`-bearing file. Full spec: `references/wiki-conventions.md` § raw/ layout & frontmatter.

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

All wiki events (lint reports, ingest summaries, post-merge ingests) accumulate in the resolved root's `log.md` (`.llmwiki/wiki/log.md`, or a legacy `.claude/wiki/log.md`) with schema header `## YYYY-MM-DD — <event-type> (<source-skill>)`. `grep '## ' wiki/log.md` recovers the time-series. At year-turnover the prior year's entries migrate to a sibling `log-YYYY.md` (`grep '## ' log*.md` still recovers the full series); `lint-wiki` Step 13 flags when a rotation is due.

## Related: github-dev:state-tracker

Spec / issue / PR work-pipeline aggregate (`.claude/state/spec.json`) is owned by `github-dev:state-tracker`. llm-wiki tracks knowledge lore; state-tracker tracks the work pipeline. The two are independent concerns in separate plugins.

## MOC-first lookup (the retired query-wiki convention)

There is no lookup skill: read `<wiki-root>/index.md` first and follow its hook to the page. The plugin delivers that rule itself through the `wiki_session_start_lint_hint.sh` SessionStart hook (`[wiki-moc]` line, once per 4h per cwd whenever a wiki root resolves), so an installed copy carries it into repos whose own guidance never mentions the wiki. This repo's `AGENTS.md` and the core prompt-inject hook repeat it for their own readers.

## Codex hooks (descriptor shipped, manual wiring)

A source-controlled `hooks/codex-hooks.json` descriptor still ships with the plugin (`UserPromptSubmit` / `SessionStart` ×2 / `Stop` / `SubagentStop` / `PostToolUse:Bash`), but **nothing wires it automatically** — the generated Codex manifest layer was removed in the 2026-08 restructure, and `.claude-plugin/plugin.json`'s `hooks` field is the Claude-format inline object Codex does not consume. A Codex machine that wants these hooks registers them manually via `~/.codex/hooks.json` (then approves them with `/hooks` — Codex requires hook trust). The scripts remain Codex-ready: Codex reads model-visible context only from a `hookSpecificOutput.additionalContext` JSON envelope (plain stdout is ignored), so `wiki_stale_check.sh` (UserPromptSubmit) and `wiki_post_commit_hint.sh` (PostToolUse) take a `codex` arg that switches their output to that envelope — the Claude no-arg path stays byte-identical. The two SessionStart hints already emit the envelope, and the capture hooks are side-effect only.

## Conditional behavior

Hooks and skills no-op silently when no wiki root resolves (none of `.llmwiki/wiki/`, `.claude/wiki/`, `.codex/wiki/` present). Safe to enable globally; nothing fires in repos without the wiki layer.

## Shell portability

Hooks and skill scripts target POSIX-shell and degrade gracefully across GNU (Linux) and BSD (macOS) userlands. Pitfalls that trip up minimal containers, non-en_US locales, and macOS:

- `grep -P` (PCRE) is **absent from BSD/macOS grep entirely** — `/usr/bin/grep -oP` errors with `invalid option -- P`, so a `2>/dev/null`-suppressed extraction silently yields nothing and the hook/scan becomes a no-op. The `\K` lookbehind and `(?=…)` lookahead have no POSIX equivalent, so field extraction uses `sed -n 's/…/\1/p'` (BRE capture) or `awk`, never `grep -oP`. Note an interactive shell can mask this: Claude Code routes `grep` through a `ugrep` function that *does* accept `-P`, but hooks (child processes) and Codex get stock grep — verify any extraction under `env -i PATH=/usr/bin:/bin`. `LC_ALL=C.UTF-8` is still set on the `sed`/`sort` pipelines for deterministic ordering across locales, not to rescue `-P`. It is load-bearing on Linux. On macOS the useful property survives for a different reason than the name suggests: whether `C.UTF-8` resolves there is version-dependent and unverified here, but an unresolvable locale falls back to `C`, and byte-order determinism is exactly what these pipelines want — so the setting is correct on both platforms while the guarantee on macOS comes from the fallback, not from the locale existing. The patterns are ASCII and the Korean literals are matched as substrings (UTF-8 is self-synchronizing), so a `C` collation changes no result.
- `bc` is not part of busybox / alpine / minimal-Debian base images. Replace `paste -sd+ | bc` with `awk '{s+=$1} END{print s+0}'` to sum numeric lines without an external arithmetic dependency.
- GNU-only `stat -c %Y` / `date -d` / `md5sum` break on macOS/BSD. The hooks and skill scans use portable fallbacks: `stat -c %Y f || stat -f %m f`, `date -d "$x" +%s || date -j -f '%Y-%m-%d' "$x" +%s` (the `lint-wiki` staleness scan carries the same `date` fallback as the stale-check hook), and `cksum` (POSIX) instead of `md5sum` for the per-cwd rate-limit marker. Preserve these fallbacks when editing any hook or scan.
