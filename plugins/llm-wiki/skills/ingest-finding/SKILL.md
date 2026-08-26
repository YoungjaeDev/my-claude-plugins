---
name: ingest-finding
description: Use after producing a new audit md, after merging a PR with non-obvious findings, or when a debugging session uncovers lore worth saving. Pulls the finding into the wiki with reversible diff-log + multi-page cross-update. Universal — works in any repo with a `.llmwiki/wiki/` or legacy `.claude/wiki/`.
---

# ingest-finding

The wiki is only useful if it stays current. Conversations end, audit mds accumulate in `.llmwiki/raw/` (or `docs/research/audits/`, or equivalent), PRs land — without an ingest step the wiki freezes. Use this skill to bring new evidence into the wiki layer.

> Operates on the repo's wiki root, resolved in order: `.llmwiki/wiki/` (preferred) →
> `.claude/wiki/` (legacy) → `.codex/wiki/` (legacy Codex fork). Examples below use
> `.llmwiki/wiki/`; substitute the legacy path if that is what the repo has.

> Ships with `llm-wiki` plugin; install via marketplace.

## Resolving `${PLUGIN_ROOT}`

`${PLUGIN_ROOT}/references/wiki-conventions.md` (referenced below) lives at the plugin root. Codex 0.135 does not export `CLAUDE_PLUGIN_ROOT`, so resolve it once before reading that file:

```bash
# --- Plugin root resolution (cross-runtime) --------------------------------
# Each branch verifies the target exists before committing; the cache branch
# walks versions high-to-low and takes the first COMPLETE one.
CHK="references/wiki-conventions.md"
PLUGIN_ROOT=""
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -e "$CLAUDE_PLUGIN_ROOT/$CHK" ] && PLUGIN_ROOT="$CLAUDE_PLUGIN_ROOT"
[ -z "$PLUGIN_ROOT" ] && [ -e "plugins/llm-wiki/$CHK" ] && PLUGIN_ROOT="plugins/llm-wiki"
if [ -z "$PLUGIN_ROOT" ]; then
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  while IFS= read -r d; do
    [ -e "$d/$CHK" ] && { PLUGIN_ROOT="$d"; break; }
  done < <(ls -1d "$cache_root"/*/llm-wiki/*/ 2>/dev/null | awk -F/ '{print $(NF-1)"\t"$0}' | sort -t. -k1,1rn -k2,2rn -k3,3rn | cut -f2- | sed 's#/$##')
fi
# wiki-conventions.md is a supplementary reference — degrade quietly if unresolved (the skill handles "no wiki" itself) rather than abort.
{ [ -n "$PLUGIN_ROOT" ] && [ -e "$PLUGIN_ROOT/$CHK" ]; } || { PLUGIN_ROOT=""; echo "note: llm-wiki wiki-conventions.md not resolved; proceeding (supplementary reference)" >&2; }
echo "PLUGIN_ROOT=$PLUGIN_ROOT"
```

## When to use

- A new audit md just landed
- A PR resolved a tricky bug — the *cause* is non-obvious from the diff
- A debugging session uncovered behavior (e.g. provider quirk, race condition) not yet in the wiki
- An invariant changed and a rule + wiki need to be re-synced

## Core patterns

### Consolidate, don't append (governing rule)

Ingest is **not** an append operation. Before writing anything, dedup and decide whether this is an update, a supersede, or (last resort) a new page. Naive accumulation — a new page or a new paragraph for every finding — is the dominant rot mode ("naive accumulation → bloat"): the wiki swells, cross-refs go stale, and the synthesis value collapses into a junk drawer. Every ingest must leave the wiki *more consolidated*, not just *longer*.

The dedup gate, run before any add:

- Grep `index.md` aliases + page bodies + `id:`/`aliases:` for the concept.
- If an existing page's scope this *refines* / *contradicts* / extends → **edit that page** (or supersede it), don't add.
- Condense to the claim; push long reasoning down to `> Evidence:` (a `.llmwiki/raw/` or external citation), never inline a wall of justification.
- Only add a new page if the finding is a genuinely new top-level concept inside an existing `wiki/<domain>/`.
- **Page-creation threshold**: even then, only spawn a new page when the concept appears in **2+ independent sources**, or is a **load-bearing concept of the current decision/fix**. A single passing mention lands in an existing page's body or a `> See-also:` — not its own page (this is what keeps the "new page for every finding" rot mode shut).

### Prefer updating existing pages over adding new ones

Karpathy's original observation: **one finding usually touches 10–15 wiki pages** via cross-references, not just one. Append-only wiki growth (the "junk drawer" rot mode) appears when every new finding becomes a new page. Before adding a page:

- Grep `index.md` aliases + page bodies for the concept
- Ask "is there an existing page whose scope this *refines* or *contradicts*?" If yes, edit it
- Only add a new page if the finding introduces a new top-level concept inside an existing `wiki/<domain>/`

### Supersede over overwrite (lifecycle)

When a finding *contradicts* an existing claim that still has historical value, do NOT silently overwrite it. Preserve the lifecycle:

- Create a new page (or a new section) carrying the corrected claim, and add `> Supersedes: [[old-id]]` to it.
- Mark the old page `status: stale` in frontmatter and add `> Superseded-by: [[new-id]]` to it. Stale pages are KEPT, marked, linked, timestamped — never deleted.

For simple refinements/additions (no contradiction, or the old claim has no standalone historical value), still edit in place — that is the existing behavior.

### Reversible diff-log discipline

Silent corruption mode (LLM edits a stale page without noticing): rare but catastrophic. Mitigation — **always log the diff before applying it**:

1. Compose the wiki page change as a unified diff in your head
2. Append a `## YYYY-MM-DD — <one-line summary> (ingest-finding)` entry to the resolved root's `log.md` **first**, including the diff summary (file paths + 1-line description of each change)
3. Apply the page edit
4. If something breaks, `git revert` the commit that includes both log + page changes — both stay in sync

This is cheap and gives `git log log.md` (at the resolved root) as the single audit trail.

### Bulk ingest (multiple sources / staging markers at once)

When draining several sources at once (a SessionStart drain surfacing 2+ `.staging/` markers, or a post-merge sweep producing several findings), do NOT run the full single-finding loop per item — that re-greps and re-logs redundantly and tends to spawn duplicate pages. Batch it:

1. **Read all** sources first (every marker / audit md) before touching any page.
2. **One dedup pass** across the whole batch — cluster findings that hit the same page, and drop cross-source duplicates once (not once per source).
3. **Batch the page edits** — apply every change to a given page in a single touch.
4. **Update `index.md` once** for the whole batch.
5. **One `log.md` entry** covering the batch (list every page touched + every marker consumed), not one entry per source.

A batch-wide view is what catches "these three findings are actually the same page," and one log entry keeps `log.md` readable. Delete the consumed staging markers after the single log entry is written.

## Steps

1. **Read the source of the finding** (audit md / PR diff / debug notes). If the source is a *newly captured* raw artifact (survey, chat/meeting transcript, external doc), first save it under the matching `raw/` source-type bucket (`external/ research/ transcripts/ audits/`) with a `YYYY-MM-DD-<slug>.<ext>` filename. *Text* raw (md/txt/html) also gets `source_url`/`ingested`/`sha256` frontmatter; *binary* raw (pdf) is stored as-is with no inline frontmatter (YAML would corrupt the bytes) and stays outside the Step 11 drift check. See `${PLUGIN_ROOT}/references/wiki-conventions.md` § raw/ layout & frontmatter.
2. **Map to wiki pages**: search `index.md` + grep page bodies. Identify all pages the finding affects — usually 1 primary + 2-5 cross-ref updates. List them.
3. **Compose diff log entry**: draft the resolved root's `log.md` block now, listing every page you're about to touch.
4. **Apply changes page-by-page**:
   - **If editing an existing page**:
     - Update the relevant section.
     - Bump `last_verified: YYYY-MM-DD` in frontmatter.
     - Add the new evidence under `## Sources`, then set `sources:` to the new count of `## Sources` entries.
   - **If adding a new page** (only after step 2 confirms no existing page fits):
     - Place under correct `wiki/<domain>/` (2-depth max — don't make a new dir unless explicitly approved).
     - Use full v2 frontmatter (`id`, `aliases`, `last_verified`, `status: active`, inferred `volatility:`, `sources:`).
       - `status:` defaults to `active`.
       - Infer `volatility:`: arch/design/decision lore → `stable` (180d window); bug/debug/quirk/transient lore → `volatile` (30d window); default `stable`. `volatile` = transient/bug lore (re-verified often), `stable` = recurring/architectural (trusted longer) — but either way the body is a *rule*, not a *one-off log*.
       - `sources:` = the count of `## Sources` entries on the page.
     - End with `## Sources` citing the raw evidence (preferred path `.llmwiki/raw/<file>`, or external `docs/...`).
     - Add a one-line entry to `index.md` under the matching domain heading.
   - **If a finding contradicts a page with historical value**: apply the supersede pattern above — new page/section gets `> Supersedes: [[old-id]]`; old page gets `status: stale` + `> Superseded-by: [[new-id]]` (kept, not deleted).
5. **Update cross-refs**: any page that previously linked to or contradicted the updated page may need a touch. Use typed grammar — `> Refines:` / `> Contradicts:` / `> Evidence:` / `> See-also:` / `> Supersedes:` / `> Superseded-by:` / `> Uses:` / `> Depends-on:` / `> Caused-by:` / `> Fixed-by:` — never raw `[[wikilink]]` (per-token meanings: `${PLUGIN_ROOT}/references/wiki-conventions.md` § Cross-reference grammar).
6. **Decide whether to graduate to `.llmwiki/insight/`** (the promoted cross-agent layer — NOT `.claude/rules/`):
   - The wiki is the default home. Graduate a finding up to `.llmwiki/insight/` **only when ALL four hold**:
     1. **Recurs across sessions** — observed in 2+ independent sessions/PRs, not a one-off.
     2. **Generalizable** — applies beyond the one file/bug that surfaced it.
     3. **Costly to violate** — getting it wrong breaks a build/release/reproducibility gate or wastes a review cycle.
     4. **Stabilized** — settled, not under active debate or still being designed.
   - Do NOT graduate: one-offs, undecided/contested points, things already known going in, or reusable *procedures* (those become a skill).
   - **Why insight, not `.claude/rules/`**: Codex never reads `.claude/rules/`, so a rule promoted there is invisible to half the toolchain. Insight lives at `.llmwiki/insight/` (neutral root) and reaches both agents via the `core-config` prompt-injection hook. llm-wiki no longer promotes lore to `.claude/rules/` at all. See `.llmwiki/insight/index.md`.
   - **Insight is consolidate-first too**: dedup against existing insight entries (`id`/`aliases`/body grep) before adding; prefer update/supersede; keep each entry to rule + apply-when + why, with the long story left in the wiki page via `promoted_from:` + `> Evidence:`.
   - When graduating, write the insight entry with the insight frontmatter (`tier: insight`, `promoted_from: [[wiki-id]]`, `evidence_count: N`, plus the standard `id`/`aliases`/`last_verified`/`status`/`volatility`/`sources`), add a hook to `.llmwiki/insight/index.md`, and log it in the diff-log block like any other page touch.
   - If nothing meets the bar, insight stays out of it (lore stays in the wiki).

## LLM autonomy boundaries

| Action | LLM alone | Needs user confirm |
|---|---|---|
| Update existing page body | ✅ (after diff log) | — |
| Bump `last_verified:` after actually re-checking against code | ✅ | — |
| Add new page inside existing `wiki/<domain>/` | ✅ | — |
| Single ingest editing 10+ pages | ❌ | ✅ (confirm scope first) |
| Supersede a page (new page `> Supersedes:` + old page `status: stale` + `> Superseded-by:`) | ✅ (after diff log) | — |
| Graduate a finding to `.llmwiki/insight/` (all 4 promotion criteria met) | ✅ (after diff log) | — |
| Add new `wiki/<domain>/` directory | ❌ | ✅ |
| Delete or merge pages | ❌ | ✅ |
| Resolve a `> Contradicts:` link (pick a winner) | ❌ | ✅ |
| Cross-ref insertion/update | ✅ (typed grammar) | — |
| Append to the resolved root's `log.md` | ✅ (always) | — |

## Output format

After applying the ingest, report:

1. The `log.md` block you appended FIRST (the diff log), as it appears in the resolved root's `log.md`.
2. A one-line per-page edit summary (page → what changed → `last_verified` / `status` / `sources` after).

```text
## YYYY-MM-DD — <one-line summary> (ingest-finding)

- <domain>/<page>.md: <1-line description of the change>
- <domain>/<other-page>.md: <1-line description of the cross-ref touch>
- index.md: <added/updated 1-line hook>
```

### Worked example

Source: a debug session found provider X returns `null` on inputs > 8 KB.

`log.md` block appended first:

```text
## 2026-05-29 — provider-x null on oversize inputs (ingest-finding)

- backend/provider-x.md: new page, status: active, volatility: volatile, sources: 1
- index.md: added backend/provider-x.md hook
```

Page-edit summary:

- `backend/provider-x.md`: created (id `provider-x`, `last_verified: 2026-05-29`, `status: active`, `volatility: volatile`, `sources: 1`), documents the >8 KB `null` quirk, `> Evidence: .llmwiki/raw/2026-05-29-provider-x-debug.md`.
- `index.md`: added a 1-line hook under the `backend` heading.

## Verification

- New/edited page appears in `index.md` under correct domain heading
- `last_verified:` is today
- New pages have `status: active`, an inferred `volatility:`, and `sources:` equal to the `## Sources` count
- `## Sources` cites raw evidence (not copies it)
- Cross-references use typed grammar (`Refines:` / `Contradicts:` / `Evidence:` / `See-also:` / `Supersedes:` / `Superseded-by:` / `Uses:` / `Depends-on:` / `Caused-by:` / `Fixed-by:`), no raw `[[wikilink]]`
- Superseded pages are `status: stale` + carry `> Superseded-by:` (kept, not deleted)
- The resolved root's `log.md` has a new entry that lists *every* page touched in this ingest (not just the primary)
- The **Final self-check** (supersede pairing, below) ran on this run's touched pages and printed no `one-sided:` line

## Final self-check (MANDATORY) — supersede pairing on this run's pages

Ingest can leave a supersede **half-applied**: a new page gets `> Supersedes: [[old]]` but the old page is never flipped to `status: stale`, or a page is marked `status: stale` without a `> Superseded-by:` back-pointer. Either one-sided pair silently corrupts the lifecycle (`lint-wiki`'s "monotonic relationships" rot mode) and won't surface until a much later audit. Before declaring the ingest done, run these three lint-wiki-style checks **scoped to only this run's touched pages** — the exact file list in the log.md block, NOT the whole wiki (`lint-wiki` owns the full sweep). A silent run is the pass; any `one-sided:` line must be fixed first.

```bash
# WIKI_ROOT: resolved wiki root (.llmwiki/wiki | .claude/wiki | .codex/wiki).
# TOUCHED:   newline-separated paths of the pages THIS run created/edited
#            (the log.md block's file list) — never the whole wiki.
WIKI_ROOT="${WIKI_ROOT:-.llmwiki/wiki}"
found=$(mktemp)
printf '%s\n' "$TOUCHED" | while IFS= read -r f; do
  [ -n "$f" ] && [ -f "$f" ] || continue
  is_stale=$(LC_ALL=C.UTF-8 grep -cE '^status:[[:space:]]*stale' "$f")
  has_by=$(LC_ALL=C.UTF-8 grep -cE '^> Superseded-by:' "$f")
  # 1. a status: stale page must carry a > Superseded-by: back-pointer
  [ "$is_stale" -gt 0 ] && [ "$has_by" -eq 0 ] && \
    echo "one-sided: $f is status: stale but has no > Superseded-by:" >> "$found"
  # 2. a > Superseded-by: back-pointer requires this page be status: stale
  [ "$has_by" -gt 0 ] && [ "$is_stale" -eq 0 ] && \
    echo "one-sided: $f has > Superseded-by: but is not status: stale" >> "$found"
  # 3. every > Supersedes: [[target]] must point at a status: stale page
  LC_ALL=C.UTF-8 sed -n 's/^> Supersedes:[[:space:]]*\[\[\([^]]*\)\]\].*/\1/p' "$f" 2>/dev/null | while IFS= read -r id; do
    [ -n "$id" ] || continue
    tgt=$(LC_ALL=C.UTF-8 grep -rlE "^id:[[:space:]]*${id}\$" "$WIKI_ROOT" 2>/dev/null | head -1)
    if [ -z "$tgt" ]; then
      echo "one-sided: > Supersedes: [[$id]] in $f — target page not found" >> "$found"
    elif ! LC_ALL=C.UTF-8 grep -qE '^status:[[:space:]]*stale' "$tgt"; then
      echo "one-sided: > Supersedes: [[$id]] in $f — target $tgt not status: stale" >> "$found"
    fi
  done
done
if [ -s "$found" ]; then echo "SELF-CHECK FAIL:"; cat "$found"; else echo "self-check: supersede pairing clean on this run's pages"; fi
rm -f "$found"
```

Fix the missing half (mark the old page `status: stale` + `> Superseded-by:`, or add the `> Supersedes:` on the new page), log the fix in the same `log.md` block, then re-run until the check is silent.

## Anti-patterns

- **Copying audit-md contents verbatim** — wiki *synthesizes*; raw belongs in `.llmwiki/raw/` (or audits dir).
- **Single-page ingest** when the finding touches multiple pages → cross-refs go stale silently.
- **New page for every finding** → append-only rot ("naive accumulation → bloat"). Run the dedup gate; update/supersede existing pages first.
- **Wiki page body as PR diary** — do NOT stack a new `## PR #X did this` section onto a page for every PR that touches the topic. The body is the distilled rule / mechanism; per-PR observations compress into one `## Evidence` section (one bullet each) or move to `> Evidence:` / `## Sources`. A run of `## Confirming dogfood (PR #N)` sections is a variant of `naive accumulation → bloat` — the distilled rule drowns in one-off detail. (See `### Consolidate, don't append`. PR *citations* under `## Sources` are provenance and stay; PR *narratives* in the body do not.)
- **Silently overwriting a contradicted page with historical value** — supersede instead (new page `> Supersedes:`, old page `status: stale` + `> Superseded-by:`).
- **Promoting lore to `.claude/rules/`** — Codex can't read it. Graduate cross-agent rules to `.llmwiki/insight/` (all 4 criteria), surfaced via the prompt-injection hook.
- **Graduating one-offs to insight** — insight is the most consolidated layer; promote only recurring + generalizable + costly-to-violate + stabilized findings.
- **3rd-depth directory** without approval — wiki is 2-depth (domain/page) by design.
- **Edit without log entry first** — silent corruption risk; no audit trail.

## See also

> All wiki events (lint reports, ingest summaries, post-merge ingests) accumulate in the resolved wiki root's `log.md` (e.g. `.llmwiki/wiki/log.md`) with schema header `## YYYY-MM-DD — <event-type> (<source-skill>)`.

## References

- Canonical frontmatter schema, cross-reference grammar (per-token meanings), resolution order, log.md discipline: `${PLUGIN_ROOT}/references/wiki-conventions.md`.
