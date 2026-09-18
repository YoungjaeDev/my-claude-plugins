---
name: lint-wiki
description: Use when the user asks to audit wiki health, or periodically (manual trigger) to catch the 4 wiki-rot failure modes — identity duplication, level flattening, monotonic relationships, and staleness. Universal — works in any repo with a `.llmwiki/wiki/` or legacy `.claude/wiki/`.
---

# lint-wiki

LLM-maintained wikis rot in predictable ways (Karpathy gist comments cite 4 failure modes after 1 month of use):

| Failure | Symptom | Lint check |
|---------|---------|------------|
| **Identity** | Two pages cover the same concept under different names | Duplicate-concept scan via id + aliases |
| **Level** | Everything piles into one big page | File size > 5KB → flag for split |
| **Relationship** | All cross-refs are flat `See: X` instead of typed | Bare `[[wikilink]]` line count > 0 → fail |
| **Staleness** | Page hasn't been re-verified within its volatility window | `last_verified:` older than the page's window (stable 180d / volatile 30d) → warn |

> Operates on the repo's wiki root, resolved in order: `.llmwiki/wiki/` (preferred) →
> `.claude/wiki/` (legacy) → `.codex/wiki/` (legacy Codex fork). The reference commands use
> `.llmwiki/wiki`; if the repo has a legacy root, substitute that path in each command.

> Ships with `wiki` plugin; install via marketplace.

## Resolving `${PLUGIN_ROOT}`

`${PLUGIN_ROOT}/references/wiki-conventions.md` (referenced below) lives at the plugin root. Codex does not export `CLAUDE_PLUGIN_ROOT`, so resolve it once before reading that file:

```bash
# --- Plugin root resolution (cross-runtime) --------------------------------
# Each branch verifies the target exists before committing; the cache branch
# walks versions high-to-low and takes the first COMPLETE one.
CHK="references/wiki-conventions.md"
PLUGIN_ROOT=""
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -e "$CLAUDE_PLUGIN_ROOT/$CHK" ] && PLUGIN_ROOT="$CLAUDE_PLUGIN_ROOT"
[ -z "$PLUGIN_ROOT" ] && [ -e "plugins/wiki/$CHK" ] && PLUGIN_ROOT="plugins/wiki"
if [ -z "$PLUGIN_ROOT" ]; then
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  while IFS= read -r d; do
    [ -e "$d/$CHK" ] && { PLUGIN_ROOT="$d"; break; }
  done < <(ls -1d "$cache_root"/*/wiki/*/ 2>/dev/null | awk -F/ '{print $(NF-1)"\t"$0}' | sort -t. -k1,1rn -k2,2rn -k3,3rn | cut -f2- | sed 's#/$##')
fi
# wiki-conventions.md is a supplementary reference — degrade quietly if unresolved (the skill handles "no wiki" itself) rather than abort.
{ [ -n "$PLUGIN_ROOT" ] && [ -e "$PLUGIN_ROOT/$CHK" ]; } || { PLUGIN_ROOT=""; echo "note: wiki wiki-conventions.md not resolved; proceeding (supplementary reference)" >&2; }
echo "PLUGIN_ROOT=$PLUGIN_ROOT"
```

## Steps

Run each scan below against the resolved wiki root. Exact commands for every step:
`references/lint-checks.md`.

1. **Identity scan + dedup scoring**: duplicate `id:` or `aliases:` across pages. For each cluster, score overlap High/Medium/Low and suggest merge/supersede/alias respectively (never auto-apply — you may delete load-bearing content).
2. **Level scan**: any page `*.md` over 5KB → propose split.
3. **Relationship scan**: any bare `[[wikilink]]` line (untyped) → must convert to a typed cross-ref (`> Refines:` etc., per-token meanings in `${PLUGIN_ROOT}/references/wiki-conventions.md` § Cross-reference grammar). Typed refs are never flagged.
4. **Staleness scan**: `last_verified:` older than the page's volatility window (`volatile` 30d / `stable` or absent 180d; covers `.llmwiki/insight/` too) → re-verify against current code and bump the date, or mark for review.
5. **Orphan scan**: pages not listed in `index.md`, or indexed pages that don't exist on disk → both are a flag.
6. **MOC integrity**: every `[[wikilink]]` target must resolve to an existing page.
7. **Contradictions**: any page with a `> Contradicts:` link is a flag — resolve (update or merge one side), don't leave it standing.
8. **Status/supersession integrity**: every `status: stale` page needs a `> Superseded-by:`, and every `> Supersedes:` target must itself be `status: stale`. Report-only, no auto-fix.
9. **Sources sanity** (soft): `sources: N` should roughly match the bullet count under `## Sources`. Large divergence is a flag, not a fail.
10. **Insight layer integrity** (skip if `.llmwiki/insight/` absent): `promoted_from:` must resolve to a non-stale wiki page; entries must stay under 2KB and declare `tier:` + `promoted_from:`. Beyond the mechanical checks, eyeball each entry against its source page — it must condense, not contradict or duplicate, the page.
11. **Source-drift scan**: for any `.llmwiki/raw/` file carrying a `sha256:` frontmatter field, the body hash must still match — a mismatch means the immutable file was edited, or the source URL's content moved (re-ingest as a new dated snapshot, never overwrite). Files without `sha256:` are skipped (prospective-only).
12. **Link-poverty scan**: an indexed page with zero typed cross-refs is invisible to graph traversal. Report-only — a genuinely standalone page (a domain's first page, a raw-citing leaf) can legitimately be ref-poor; the human decides.
13. **Log-rotation due**: any `## YYYY-...` entry in `log.md` predating the current year → suggest migrating that year's block to a sibling `log-YYYY.md` (manual op, logged like any other event; convention: `${PLUGIN_ROOT}/references/wiki-conventions.md` § log.md discipline).

## Output format

Produce the Markdown report per `references/output-schema.md` (schema + worked example). Report only — never auto-fix; the user reviews and triggers `/wiki:ingest-finding` for each remediation. After confirming with the user, persist it as a `## YYYY-MM-DD — <event-type> (lint-wiki)` block appended to the resolved root's `log.md` (never a separate `_audits/` directory).

## Multi-agent lint (large wikis)

For large wikis (>~30 pages), dispatch one read-only agent per `wiki/<domain>/` in parallel (each runs the scans above scoped to its domain), then merge the per-domain reports into a single Wiki Health Report. No new infrastructure; this is just a dispatch pattern for keeping the per-agent context small on big wikis. For small wikis, run all scans in a single pass.

## When to trigger

- After a big restructure (initial split, large migration)
- After 1-2 months of normal use (drift accumulates)
- Before a major PR that touches multiple wiki pages
- When the `UserPromptSubmit` soft-hint hook flags stale pages and the user asks for a sweep
- If you (LLM) feel like you've been recommending things from memory rather than wiki: your trust signal is degrading
- **Retro reminder**: if the resolved root's `log.md` oldest `## YYYY-MM-DD — <... > baseline (lint-wiki)` entry is 42 days (6 weeks) or older and no matching `week-N retro (lint-wiki)` entry exists for the same source-skill, run a retro lint. Each baseline gets exactly one retro at the 6-week mark to recalibrate thresholds (5 KB level cap, volatility-window staleness) against observed data.

## Anti-patterns

- Don't auto-merge duplicate pages without user confirmation (you may delete load-bearing content).
- Don't bump `last_verified:` without actually re-reading the page against current code. The date is a trust signal, not a checkbox.
- Don't lint inside a normal coding flow: it's a maintenance op, not a per-conversation task.

## See also

> All wiki events (lint reports, ingest summaries, post-merge ingests) accumulate in the resolved wiki root's `log.md` (e.g. `.llmwiki/wiki/log.md`) with schema header `## YYYY-MM-DD — <event-type> (<source-skill>)`.

## References

- Canonical frontmatter schema, cross-reference grammar (per-token meanings), resolution order, log.md discipline: `${PLUGIN_ROOT}/references/wiki-conventions.md`.
- Exact check commands for every step: `references/lint-checks.md`.
- Report schema + worked example: `references/output-schema.md`.
