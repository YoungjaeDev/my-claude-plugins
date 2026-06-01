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
> `.claude/wiki/` (legacy) → `.codex/wiki/` (legacy Codex fork). The bash blocks below use
> `.llmwiki/wiki`; if the repo has a legacy root, substitute that path in each command.

> Ships with `llm-wiki` plugin; install via marketplace.

## Steps

1. **Identity scan** (duplicate concepts):
   ```bash
   grep -rh "^id:" .llmwiki/wiki/ | sort | uniq -d
   grep -rh "^aliases:" .llmwiki/wiki/ | tr ',' '\n' | sort | uniq -d
   ```
   For any duplicate, propose merge or alias.

2. **Level scan** (pages too big):
   ```bash
   find .llmwiki/wiki -name '*.md' -size +5k -print
   ```
   For pages > 5KB, propose split.

3. **Relationship scan** (untyped cross-refs):
   ```bash
   rg -nP '^\[\[' .llmwiki/wiki/ || echo "OK"
   ```
   Any hits → must convert to typed `> Refines:` / `> Contradicts:` / `> Evidence:` / `> See-also:` / `> Supersedes:` / `> Superseded-by:` / `> Uses:` / `> Depends-on:` / `> Caused-by:` / `> Fixed-by:`. Only a bare line starting with `[[` is flagged; typed refs are never flagged.

4. **Staleness scan** (per-page volatility window — `volatile` 30d / `stable` or absent 180d):
   ```bash
   today=$(date +%s)
   while IFS= read -r f; do
     d=$(LC_ALL=C.UTF-8 grep -oP '^last_verified:\s*\K\d{4}-\d{2}-\d{2}' "$f" || true)
     [[ -z "$d" ]] && continue
     vol=$(LC_ALL=C.UTF-8 grep -oP '^volatility:\s*\K\S+' "$f" || true)
     [[ "$vol" == "volatile" ]] && window=30 || window=180
     age_days=$(( (today - $(date -d "$d" +%s)) / 86400 ))
     [[ $age_days -gt $window ]] && printf '%s (%d days, %s window %dd)\n' "$f" "$age_days" "${vol:-stable}" "$window"
   done < <(find .llmwiki/wiki -name '*.md' -not -name 'index.md' -not -name 'log.md')
   ```
   For each stale page, either re-verify against current code and bump the date, or mark for review.

5. **Orphan scan** (pages not in index, indexed pages that don't exist):
   ```bash
   diff <(find .llmwiki/wiki -name '*.md' -not -name 'index.md' -not -name 'log.md' | sort) \
        <(LC_ALL=C.UTF-8 grep -oP '\(\K[^)]+\.md' .llmwiki/wiki/index.md | sed 's|^|.llmwiki/wiki/|' | sort)
   ```

6. **MOC integrity** (cross-refs to non-existent pages):
   ```bash
   rg -oP '\[\[\K[^\]]+' .llmwiki/wiki/ | sort -u
   # For each, confirm matching page exists
   ```

7. **Contradictions**: any page with a `> Contradicts:` link is a flag — those should be resolved (one of the two pages updated or merged), not left standing.

8. **Status/supersession integrity** (report-only, no auto-fix):
   ```bash
   # stale pages missing a > Superseded-by: pointer
   while IFS= read -r f; do
     LC_ALL=C.UTF-8 grep -q '^status:\s*stale' "$f" || continue
     LC_ALL=C.UTF-8 grep -q '^> Superseded-by:' "$f" || printf 'stale without Superseded-by: %s\n' "$f"
   done < <(find .llmwiki/wiki -name '*.md' -not -name 'index.md' -not -name 'log.md')

   # > Supersedes: targets that are NOT status: stale
   LC_ALL=C.UTF-8 grep -rhoP '^> Supersedes:\s*\[\[\K[^\]]+' .llmwiki/wiki/ | sort -u | while IFS= read -r id; do
     [[ -z "$id" ]] && continue
     tgt=$(LC_ALL=C.UTF-8 grep -rl "^id:\s*$id\b" .llmwiki/wiki/ | head -1)
     [[ -z "$tgt" ]] && { printf 'Supersedes target missing: %s\n' "$id"; continue; }
     LC_ALL=C.UTF-8 grep -q '^status:\s*stale' "$tgt" || printf 'Supersedes target not stale: %s (%s)\n' "$id" "$tgt"
   done
   ```
   Flag mismatches for the user — every `status: stale` page should have a `> Superseded-by:`, and every `> Supersedes:` should point at a page now `status: stale`.

9. **Sources sanity** (soft, report-only): the `sources: N` count should roughly match the number of entries under each page's `## Sources` section. Large divergence (e.g. `sources: 3` with one bullet under `## Sources`) is a flag, not a fail.

10. **Insight layer integrity** (the promoted `.llmwiki/insight/` layer; skip if absent):
    ```bash
    [ -d .llmwiki/insight ] || echo "no insight layer (skip)"

    # 10a. promoted_from resolves to an existing wiki page that is NOT stale
    LC_ALL=C.UTF-8 grep -rhoP '^promoted_from:\s*\[\[\K[^\]]+' .llmwiki/insight/ 2>/dev/null | sort -u | while IFS= read -r id; do
      [[ -z "$id" ]] && continue
      tgt=$(LC_ALL=C.UTF-8 grep -rl "^id:\s*$id\b" .llmwiki/wiki/ | head -1)
      [[ -z "$tgt" ]] && { printf 'promoted_from target missing: %s\n' "$id"; continue; }
      LC_ALL=C.UTF-8 grep -q '^status:\s*stale' "$tgt" && printf 'promoted_from target is stale: %s (%s)\n' "$id" "$tgt"
    done

    # 10b. conciseness — insight entries must stay condensed (tip, not body)
    find .llmwiki/insight -name '*.md' -not -name 'index.md' -size +2k -print 2>/dev/null

    # 10c. every insight entry declares tier + promoted_from
    while IFS= read -r f; do
      LC_ALL=C.UTF-8 grep -q '^tier:\s*insight' "$f" || printf 'insight entry missing tier: %s\n' "$f"
      LC_ALL=C.UTF-8 grep -q '^promoted_from:' "$f" || printf 'insight entry missing promoted_from: %s\n' "$f"
    done < <(find .llmwiki/insight -name '*.md' -not -name 'index.md' -not -name '_template.md' 2>/dev/null)
    ```
    Report-only. Beyond the mechanical checks, eyeball each insight entry against its `promoted_from:` wiki page: the insight must *condense* the page, not contradict it, and must not restate the page's full body (dedup — the long story stays in the wiki). Flag any insight whose rule conflicts with its now-`active` source page, or that has grown into a second copy of the wiki page.

## Output format

Produce a Markdown report:

```text
## Wiki Health Report — YYYY-MM-DD

- Identity: <n duplicates / clean>
- Level: <n pages > 5KB>
- Relationship: <n bare wikilinks / clean>
- Staleness: <n pages past their volatility window>
- Status: <n status: stale pages / clean>
- Supersession: <n broken Supersedes/Superseded-by pairs / clean>
- Sources: <n pages with sources:N mismatched vs ## Sources count / clean>
- Insight: <n promoted_from unresolved / oversize / missing-frontmatter / clean | no insight layer>
- Orphans: <list>
- Broken refs: <list>
- Open contradictions: <list>
```

Report only — do not auto-fix. User reviews and triggers `/llm-wiki:ingest-finding` for each remediation.

### Worked example

```text
## Wiki Health Report — 2026-05-29

- Identity: clean
- Level: 1 page > 5KB (backend/provider-x.md, 6.2 KB → propose split)
- Relationship: clean
- Staleness: 2 past window (backend/old-quirk.md 41 days, volatile 30d window; design/layout.md 190 days, stable 180d window)
- Status: 1 stale page (backend/old-quirk.md)
- Supersession: 1 broken pair (backend/old-quirk.md is status: stale but has no > Superseded-by:)
- Sources: clean
- Insight: clean (2 entries, promoted_from resolves, all condensed)
- Orphans: none
- Broken refs: none
- Open contradictions: 1 (design/cache.md > Contradicts: [[design/cache-v2]])
```

**Persist the report**: after producing the Markdown report and confirming with the user, append a block to the resolved root's `log.md` with the standard schema header `## YYYY-MM-DD — <event-type> (lint-wiki)` (e.g. `## 2026-05-26 — v2 0-week baseline (lint-wiki)`). Do **not** create a separate `_audits/` directory — all wiki audit/ingest/post-merge events accumulate in `log.md` so `grep '## YYYY-MM-DD'` recovers a time-series.

## Multi-agent lint (large wikis)

For large wikis (>~30 pages), dispatch one read-only agent per `wiki/<domain>/` in parallel — each runs the scans above scoped to its domain — then merge the per-domain reports into a single Wiki Health Report. No new infrastructure; this is just a dispatch pattern for keeping the per-agent context small on big wikis. For small wikis, run all scans in a single pass.

## When to trigger

- After a big restructure (initial split, large migration)
- After 1-2 months of normal use (drift accumulates)
- Before a major PR that touches multiple wiki pages
- When the `UserPromptSubmit` soft-hint hook flags stale pages and the user asks for a sweep
- If you (LLM) feel like you've been recommending things from memory rather than wiki — your trust signal is degrading
- **Retro reminder**: if the resolved root's `log.md` oldest `## YYYY-MM-DD — <... > baseline (lint-wiki)` entry is 42 days (6 weeks) or older and no matching `week-N retro (lint-wiki)` entry exists for the same source-skill, run a retro lint. Each baseline gets exactly one retro at the 6-week mark to recalibrate thresholds (5 KB level cap, volatility-window staleness) against observed data.

## Anti-patterns

- Don't auto-merge duplicate pages without user confirmation (you may delete load-bearing content).
- Don't bump `last_verified:` without actually re-reading the page against current code. The date is a trust signal, not a checkbox.
- Don't lint inside a normal coding flow — it's a maintenance op, not a per-conversation task.

## See also

> All wiki events (lint reports, ingest summaries, post-merge ingests) accumulate in the resolved wiki root's `log.md` (e.g. `.llmwiki/wiki/log.md`) with schema header `## YYYY-MM-DD — <event-type> (<source-skill>)`.
