---
name: lint
description: "Health-check the repo's .llmwiki: stale concept pages, broken links and Sources, orphan pages, and index.md out of sync with the pages on disk. Old-format pages are counted in one line, not flagged one by one. Read-only; fixes go through /wiki:ingest. Use on /wiki:lint, lint-wiki, 'wiki 점검', '위키 상태 확인', 'audit the wiki', 'check wiki health'."
---

# wiki:lint

Finds the ways a wiki quietly rots. Read-only: it reports, the user decides, and fixes go through `/wiki:ingest`. The page format it checks against is the one `wiki:ingest` writes (`.llmwiki/wiki/index.md`, `log.md`, `<topic>/<concept>.md` with `last_verified` frontmatter and a `## Sources` section).

If `.llmwiki/wiki/index.md` does not exist, say so and stop: there is nothing to lint, and `/wiki:ingest` creates the wiki on first use. Check the file, not the directory: `/dev:new` seeds an empty `.llmwiki/wiki/` holding only a `.gitkeep`.

## Checks

| Check | Finding |
|-------|---------|
| **Stale** | `last_verified` older than 180 days, or missing. Re-check the page against its sources, then bump the date through `/wiki:ingest`. |
| **Broken links** | A relative `.md` link (in a page or in `index.md`) whose target does not exist. |
| **Broken Sources** | A `## Sources` entry naming a `.llmwiki/...` path that does not exist. PR, commit and measurement citations are not checked mechanically. |
| **Orphans** | A page no other page links to. Report-only: a first page in a new topic is legitimately alone. Matched by file name, so a name shared across topics can hide an orphan. Old-format pages are skipped (they link by `[[id]]`, not file name). |
| **Index mismatch** | A page with no `index.md` line. (An index line pointing at a missing page shows up under broken links.) |
| **Old format** | A page with old frontmatter keys (`id`, `status`, `volatility`), an old relation line (`> Refines: [[id]]`, `> Evidence: <path>` and the rest of that set), an `[[id]]` link, or no `## Sources`. An ordinary callout such as `> Note: ...` does not count. Counted only, in one line. `/wiki:ingest` converts a page when it next edits it. Old-format pages are skipped by the Sources and orphan checks. |

## Run

From the repo root (bash 3.2 and BSD userland safe):

```bash
W=.llmwiki/wiki
cutoff=$(date -d '180 days ago' +%Y-%m-%d 2>/dev/null || date -v-180d +%Y-%m-%d)  # portability-ok: BSD date -v fallback
old=0
while IFS= read -r f; do
  rel=${f#"$W"/}
  d=$(sed -n 's/^last_verified:[[:space:]]*\([0-9-]\{10\}\).*/\1/p' "$f" | head -1)
  if [ -z "$d" ]; then echo "stale (no last_verified): $rel"
  elif awk -v a="$d" -v b="$cutoff" 'BEGIN{exit !(a<b)}'; then echo "stale ($d): $rel"; fi
  if awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {fm=0}
       fm && /^(id|status|volatility):/ {o=1}
       /^> (Refines|Contradicts|Evidence|See-also|Supersedes|Superseded-by|Uses|Depends-on|Caused-by|Fixed-by): / {o=1}
       /\[\[[a-z0-9-]+\]\]/ {o=1}
       END {exit !o}' "$f" || ! grep -q '^## Sources' "$f"; then
    old=$((old + 1))
  else
    awk '/^## Sources/{s=1;next} /^## /{s=0} s' "$f" | grep -oE '\.llmwiki/[^][ )`>,]+' \
      | while IFS= read -r p; do [ -e "$p" ] || echo "broken source: $rel -> $p"; done
    grep -rlF --include='*.md' "$(basename "$f")" "$W" \
      | grep -vxF -e "$f" -e "$W/index.md" -e "$W/log.md" | grep -q . || echo "orphan: $rel"
  fi
  grep -qF "($rel)" "$W/index.md" || echo "not in index: $rel"
done < <(find "$W" -name '*.md' ! -name index.md ! -name 'log*.md' | sort)
while IFS= read -r f; do
  dir=$(dirname "$f")
  grep -oE '\]\([^)#]+\.md' "$f" | sed 's/^](//' | while IFS= read -r l; do
    case "$l" in http*|/*) continue ;; esac
    [ -f "$dir/$l" ] || echo "broken link: ${f#"$W"/} -> $l"
  done
done < <(find "$W" -name '*.md' ! -name 'log*.md' | sort)
if [ "$old" -gt 0 ]; then echo "old format: $old pages (converted by /wiki:ingest when edited)"; fi
```

## Report

Group the output by check, one line per finding, then a one-line total. Add a suggested fix only where it is not obvious (for example, which page an orphan should be linked from). Do not edit pages, `index.md` or `log.md`.

```text
## Wiki lint — 2026-10-06 (14 pages)

- Stale: vendor-x/rate-limits.md (2026-02-11)
- Broken links: none
- Broken Sources: billing/invoices.md -> .llmwiki/raw/2026-03-02-billing-call.md
- Orphans: domain/glossary-of-units.md (link it from domain/measurements.md?)
- Index mismatch: none
- Old format: 6 pages (converted by /wiki:ingest when edited)

Total: 3 findings, 6 old-format pages.
```
