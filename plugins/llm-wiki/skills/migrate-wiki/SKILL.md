---
name: migrate-wiki
description: Use to migrate or upgrade an existing wiki to the v2 `.llmwiki/` layout — triggers on "migrate wiki", "upgrade wiki to v2", "consolidate .claude/wiki and .codex/wiki", "move wiki to .llmwiki". Detects legacy `.claude/wiki/` and forked `.codex/wiki/`, consolidates them under the neutral `.llmwiki/` root, and adds v2 frontmatter. Universal — works in any repo with a legacy wiki.
---

# migrate-wiki

v1 deployments keep the wiki at `.claude/wiki/`, and `codex-bridge`'s `.claude/`→`.codex/` body transform forks a per-agent copy at `.codex/wiki/`. v2 introduces a neutral `.llmwiki/` root the transform can never touch. This skill migrates legacy layouts to v2 in place: detect, consolidate, add v2 frontmatter defaults, and additive-only grammar — without re-verifying or silent-deleting anything.

> Operates on the repo's wiki roots, resolved in order: `.llmwiki/wiki/` (preferred / target) →
> `.claude/wiki/` (legacy) → `.codex/wiki/` (legacy Codex fork). Migration moves legacy content
> into `.llmwiki/wiki/`.

> Ships with `llm-wiki` plugin; install via marketplace.

## When to use

- A repo has a legacy `.claude/wiki/` and you want the v2 `.llmwiki/` layout
- A repo has both `.claude/wiki/` and a forked `.codex/wiki/` that should be consolidated
- Pages exist but lack v2 frontmatter (`status:` / `volatility:` / `sources:`)

Do NOT use:
- On a repo with no wiki at all → use `/llm-wiki:bootstrap-wiki` instead
- On a repo already fully on `.llmwiki/` with v2 frontmatter → migration is a no-op (it will report so)

## Procedure

1. **Detect**: report which wiki roots exist (`.llmwiki/wiki/`, `.claude/wiki/`, `.codex/wiki/`) and their schema state — do the pages already carry v2 frontmatter (`status:` / `volatility:` / `sources:`)? Summarize before changing anything.

2. **Consolidate (optional)**: copy per-agent legacy copies into `.llmwiki/wiki/`, deduping by `id`. On a conflict (same `id`, divergent bodies), present the divergence via `AskUserQuestion` and let the user pick — NEVER silent-delete. Keep the legacy dir (`.claude/wiki/` / `.codex/wiki/`) in place until the user explicitly confirms removal; do not auto-remove it.

3. **Add v2 frontmatter defaults** to each migrated page (only if absent — never overwrite an existing value):
   - `status: active`
   - `volatility:` inferred by heuristic on the page path / title / aliases (the keyword split tracks the general-vs-one-off distinction — recurring/architectural lore is `stable`, transient/bug lore is `volatile`):
     - matches `design|arch|architecture|decision|adr|rationale` → `stable`
     - matches `bug|debug|fix|race|quirk|transient|incident|flaky` → `volatile`
     - else → `stable`
   - `sources:` counted from the existing `## Sources` section (0 if none)

4. **Additive grammar only**: never rewrite existing cross-refs. Only add new typed refs (`> Supersedes:` / `> Superseded-by:` / `> Uses:` / `> Depends-on:` / `> Caused-by:` / `> Fixed-by:`) where clearly applicable. Leave existing `> Refines:` / `> Contradicts:` / `> Evidence:` / `> See-also:` untouched. (Per-token meanings: `references/wiki-conventions.md` § Cross-reference grammar.)

5. **Idempotent + diff-log-first**: re-running on a v2 wiki is a no-op. BEFORE applying edits, append ONE entry to the resolved root's `log.md` — `## YYYY-MM-DD — migrate v1->v2 (migrate-wiki)` — listing every page touched. This makes the whole migration git-revertible (`git revert` the commit that includes both log + page edits).

6. **Do NOT bump `last_verified:`** — migration is mechanical, not re-verification. The trust signal must reflect the last time the content was actually checked against code/source.

## LLM autonomy boundaries

| Action | LLM alone | Needs user confirm |
|---|---|---|
| Detect + report existing wiki roots and schema state | yes | — |
| Copy legacy pages into `.llmwiki/wiki/` (no id conflict) | yes (after diff log) | — |
| Add missing v2 frontmatter defaults (`status`/`volatility`/`sources`) | yes | — |
| Add a new typed cross-ref where clearly applicable | yes (typed grammar) | — |
| Append to the resolved root's `log.md` | yes (always, first) | — |
| Consolidate conflicting pages (same `id`, divergent bodies) | no | yes |
| Delete / remove a legacy `.claude/wiki/` or `.codex/wiki/` dir | no | yes |
| Rewrite an existing cross-ref | no | yes |
| Bump `last_verified:` | no (mechanical migration ≠ re-verification) | — |

## Output format

```text
## Wiki Migration — YYYY-MM-DD

Detected:
- .llmwiki/wiki/  : <present/absent, v2-frontmatter? >
- .claude/wiki/   : <present/absent, N pages, v2-frontmatter? >
- .codex/wiki/    : <present/absent, N pages>

log.md entry appended FIRST:
## YYYY-MM-DD — migrate v1->v2 (migrate-wiki)
- <domain>/<page>.md: copied from .claude/wiki, +status:active +volatility:<x> +sources:N
- ...

Conflicts (needs user confirm): <list or none>
Legacy dirs kept (not removed): <list>
```

### Worked example

Repo has `.claude/wiki/` (5 pages, no v2 frontmatter) and a forked `.codex/wiki/` (same 5 pages).

```text
## Wiki Migration — 2026-05-29

Detected:
- .llmwiki/wiki/  : absent
- .claude/wiki/   : present, 5 pages, no v2 frontmatter
- .codex/wiki/    : present, 5 pages (fork of .claude/wiki)

log.md entry appended FIRST:
## 2026-05-29 — migrate v1->v2 (migrate-wiki)
- design/layout.md: copied from .claude/wiki, +status:active +volatility:stable +sources:2
- backend/provider-x.md: copied from .claude/wiki, +status:active +volatility:volatile +sources:1
- backend/race-condition.md: copied from .claude/wiki, +status:active +volatility:volatile +sources:1
- code-map/api.md: copied from .claude/wiki, +status:active +volatility:stable +sources:0
- index.md: copied from .claude/wiki (no frontmatter change — index exempt)

Conflicts (needs user confirm): none (.codex/wiki was an exact fork)
Legacy dirs kept (not removed): .claude/wiki/, .codex/wiki/  (run removal only after user confirms)
```

## Verification

- The resolved root's `log.md` has exactly one new `## YYYY-MM-DD — migrate v1->v2 (migrate-wiki)` entry listing every page touched
- Each migrated page gained `status:` / `volatility:` / `sources:` (only where absent), and NO `last_verified:` was bumped
- No existing cross-ref was rewritten; only new typed refs were added
- Legacy `.claude/wiki/` / `.codex/wiki/` dirs are still present (removal awaits user confirm)
- Re-running the skill produces no further changes (idempotent)
- `git revert` of the migration commit cleanly undoes both the log entry and the page edits

## Anti-patterns

- **Silent-deleting a legacy or forked page** on conflict — always surface via `AskUserQuestion`.
- **Auto-removing `.claude/wiki/` / `.codex/wiki/`** — keep until the user explicitly confirms.
- **Bumping `last_verified:`** — migration is mechanical; the date stays as last actually verified.
- **Rewriting existing cross-refs** — additive grammar only.
- **Editing before the log entry** — the diff-log must land first so the migration is revertible.

## See also

> All wiki events (lint reports, ingest summaries, post-merge ingests) accumulate in the resolved wiki root's `log.md` (e.g. `.llmwiki/wiki/log.md`) with schema header `## YYYY-MM-DD — <event-type> (<source-skill>)`.

## References

- Canonical frontmatter schema, cross-reference grammar (per-token meanings), resolution order, log.md discipline: `references/wiki-conventions.md`.
