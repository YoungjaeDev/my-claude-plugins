---
name: lint-wiki
description: Use when the user asks to audit wiki health, or periodically (manual trigger) to catch the 4 wiki-rot failure modes — identity duplication, level flattening, monotonic relationships, and staleness. Universal — works in any repo with `.claude/wiki/`.
---

# lint-wiki

LLM-maintained wikis rot in predictable ways (Karpathy gist comments cite 4 failure modes after 1 month of use):

| Failure | Symptom | Lint check |
|---------|---------|------------|
| **Identity** | Two pages cover the same concept under different names | Duplicate-concept scan via id + aliases |
| **Level** | Everything piles into one big page | File size > 5KB → flag for split |
| **Relationship** | All cross-refs are flat `See: X` instead of typed | Raw `[[wikilink]]` count > 0 → fail |
| **Staleness** | Page hasn't been re-verified in months | `last_verified:` > 60 days → warn |

> Ships with `llm-wiki` plugin; install via marketplace. Operates on the current repo's `.claude/wiki/`.

## Steps

1. **Identity scan** (duplicate concepts):
   ```bash
   grep -rh "^id:" .claude/wiki/ | sort | uniq -d
   grep -rh "^aliases:" .claude/wiki/ | tr ',' '\n' | sort | uniq -d
   ```
   For any duplicate, propose merge or alias.

2. **Level scan** (pages too big):
   ```bash
   find .claude/wiki -name '*.md' -size +5k -print
   ```
   For pages > 5KB, propose split.

3. **Relationship scan** (untyped cross-refs):
   ```bash
   rg -nP '^\[\[' .claude/wiki/ || echo "OK"
   ```
   Any hits → must convert to typed `> Refines:` / `> Contradicts:` / `> Evidence:` / `> See-also:`.

4. **Staleness scan** (`last_verified:` > 60 days):
   ```bash
   today=$(date +%s)
   while IFS= read -r f; do
     d=$(grep -oP '^last_verified:\s*\K\d{4}-\d{2}-\d{2}' "$f" || true)
     [[ -z "$d" ]] && continue
     age_days=$(( (today - $(date -d "$d" +%s)) / 86400 ))
     [[ $age_days -gt 60 ]] && printf '%s (%d days)\n' "$f" "$age_days"
   done < <(find .claude/wiki -name '*.md' -not -name 'index.md' -not -name 'log.md')
   ```
   For each stale page, either re-verify against current code and bump the date, or mark for review.

5. **Orphan scan** (pages not in index, indexed pages that don't exist):
   ```bash
   diff <(find .claude/wiki -name '*.md' -not -name 'index.md' -not -name 'log.md' | sort) \
        <(grep -oP '\(\K[^)]+\.md' .claude/wiki/index.md | sed 's|^|.claude/wiki/|' | sort)
   ```

6. **MOC integrity** (cross-refs to non-existent pages):
   ```bash
   rg -oP '\[\[\K[^\]]+' .claude/wiki/ | sort -u
   # For each, confirm matching page exists
   ```

7. **Contradictions**: any page with a `> Contradicts:` link is a flag — those should be resolved (one of the two pages updated or merged), not left standing.

## Output

Produce a Markdown report:

```
## Wiki Health Report — YYYY-MM-DD

- Identity: <n duplicates / clean>
- Level: <n pages > 5KB>
- Relationship: <n raw wikilinks / clean>
- Staleness: <n pages > 60 days>
- Orphans: <list>
- Broken refs: <list>
- Open contradictions: <list>
```

Report only — do not auto-fix. User reviews and triggers `/llm-wiki:ingest-finding` for each remediation.

**Persist the report**: after producing the Markdown report and confirming with the user, append a block to `.claude/wiki/log.md` with the standard schema header `## YYYY-MM-DD — <event-type> (lint-wiki)` (e.g. `## 2026-05-26 — v2 0-week baseline (lint-wiki)`). Do **not** create a separate `_audits/` directory — all wiki audit/ingest/post-merge events accumulate in `wiki/log.md` so `grep '## YYYY-MM-DD'` recovers a time-series.

## When to trigger

- After a big restructure (initial split, large migration)
- After 1-2 months of normal use (drift accumulates)
- Before a major PR that touches multiple wiki pages
- When the `UserPromptSubmit` soft-hint hook flags stale pages and the user asks for a sweep
- If you (LLM) feel like you've been recommending things from memory rather than wiki — your trust signal is degrading
- **Retro reminder**: if `wiki/log.md`'s oldest `## YYYY-MM-DD — <... > baseline (lint-wiki)` entry is 42 days (6 weeks) or older and no matching `week-N retro (lint-wiki)` entry exists for the same source-skill, run a retro lint. Each baseline gets exactly one retro at the 6-week mark to recalibrate thresholds (5 KB level cap, 60-day staleness) against observed data.

## Anti-patterns

- Don't auto-merge duplicate pages without user confirmation (you may delete load-bearing content).
- Don't bump `last_verified:` without actually re-reading the page against current code. The date is a trust signal, not a checkbox.
- Don't lint inside a normal coding flow — it's a maintenance op, not a per-conversation task.

## See also

> All wiki events (lint reports, ingest summaries, post-merge ingests) accumulate in `.claude/wiki/log.md` with schema header `## YYYY-MM-DD — <event-type> (<source-skill>)`.
