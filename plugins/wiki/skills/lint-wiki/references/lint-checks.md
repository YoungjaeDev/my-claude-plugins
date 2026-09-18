# lint-wiki: check commands

Full commands for each step in `SKILL.md`'s Steps list. Run against the resolved wiki root
(`.llmwiki/wiki` below; substitute a legacy root if that's what resolved).

1. **Identity scan + dedup scoring** (duplicate concepts):
   ```bash
   grep -rh "^id:" .llmwiki/wiki/ | sort | uniq -d
   grep -rh "^aliases:" .llmwiki/wiki/ | tr ',' '\n' | sort | uniq -d
   # For each duplicate id AND each duplicate alias, list the pages forming the
   # cluster (to score + remedy). BSD grep has no -P/\K/\Q\E; extract values with
   # a portable sed capture, and match a token by shell string compare (=/case) so
   # an id or alias containing regex metacharacters (. + ( ...) needs no escaping.
   dup_ids=$(LC_ALL=C.UTF-8 grep -rh '^id:' .llmwiki/wiki/ \
             | sed -n 's/^id:[[:space:]]*\([^[:space:]]*\).*/\1/p' | sort | uniq -d)
   dup_aliases=$(LC_ALL=C.UTF-8 grep -rh '^aliases:' .llmwiki/wiki/ \
                 | sed -n 's/^aliases:[[:space:]]*\[\([^]]*\)\].*/\1/p' \
                 | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
                 | grep -v '^$' | sort | uniq -d)
   for tok in $dup_ids; do
     printf '== id cluster: %s ==\n' "$tok"
     grep -rl '^id:' .llmwiki/wiki/ | while IFS= read -r f; do
       v=$(sed -n 's/^id:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$f" | head -1)
       [ "$v" = "$tok" ] && printf '%s\n' "$f"
     done
   done
   # Iterate line-by-line (not `for tok in $dup_aliases`) so an alias containing
   # spaces is not word-split, and compare parsed alias tokens by exact `=` so
   # `foo` does not match `foobar` the way a substring `case` would.
   printf '%s\n' "$dup_aliases" | while IFS= read -r tok; do
     [ -n "$tok" ] || continue
     printf '== alias cluster: %s ==\n' "$tok"   # Low-overlap row: same alias, distinct ids
     grep -rl '^aliases:' .llmwiki/wiki/ | while IFS= read -r f; do
       sed -n 's/^aliases:[[:space:]]*\[\([^]]*\)\].*/\1/p' "$f" | head -1 \
         | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
         | while IFS= read -r a; do [ "$a" = "$tok" ] && { printf '%s\n' "$f"; break; }; done
     done
   done
   ```
   For each duplicate cluster, **score the overlap and propose one concrete
   remedy**, borrowing mem0's memory-reviewer triage *pattern* (the pattern, not
   its data; no mem0 call). The score is a coarse band, never a fabricated float
   (consistent with the wiki's provenance-over-confidence rule):

   | Overlap | Signal | Suggest |
   |---------|--------|---------|
   | **High** | same `id`, or near-identical concept + overlapping body claims | **merge**: fold into the stronger page, redirect the other's aliases |
   | **Medium** | same concept, different facet / partial claim overlap | **supersede**: keep both, mark the older `status: stale` + `> Superseded-by:` the newer |
   | **Low** | shared alias but genuinely distinct concepts | **alias**: disambiguate the colliding alias (rename/scope), keep both pages |

   Report-only: surface `<cluster> — overlap: <band> — suggest: <remedy>` for the
   user; never merge/supersede/alias automatically (you may delete load-bearing
   content, see Anti-patterns).

2. **Level scan** (pages too big):
   ```bash
   find .llmwiki/wiki -name '*.md' -size +5k -print
   ```
   For pages > 5KB, propose split.

3. **Relationship scan** (untyped cross-refs):
   ```bash
   rg -nP '^\[\[' .llmwiki/wiki/ || echo "OK"
   ```
   Any hits → must convert to typed `> Refines:` / `> Contradicts:` / `> Evidence:` / `> See-also:` / `> Supersedes:` / `> Superseded-by:` / `> Uses:` / `> Depends-on:` / `> Caused-by:` / `> Fixed-by:` (per-token meanings: `${PLUGIN_ROOT}/references/wiki-conventions.md` § Cross-reference grammar). Only a bare line starting with `[[` is flagged; typed refs are never flagged.

4. **Staleness scan** (per-page volatility window: `volatile` 30d / `stable` or absent 180d; covers the promoted `.llmwiki/insight/` layer too, matching the stale-check hook):
   ```bash
   today=$(date +%s)
   while IFS= read -r f; do
     # BSD grep has no -P/\K; portable sed capture. date -d is GNU-only, so fall
     # back to BSD `date -j -f` and skip the page if neither parses (an empty
     # substitution would otherwise abort the arithmetic below).
     d=$(LC_ALL=C.UTF-8 sed -n 's/^last_verified:[[:space:]]*\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/p' "$f" | head -1)
     [[ -z "$d" ]] && continue
     vol=$(LC_ALL=C.UTF-8 sed -n 's/^volatility:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$f" | head -1)
     [[ "$vol" == "volatile" ]] && window=30 || window=180
     d_ts=$(date -d "$d" +%s 2>/dev/null || date -j -f '%Y-%m-%d' "$d" +%s 2>/dev/null) || continue
     age_days=$(( (today - d_ts) / 86400 ))
     [[ $age_days -gt $window ]] && printf '%s (%d days, %s window %dd)\n' "$f" "$age_days" "${vol:-stable}" "$window"
   done < <(find .llmwiki/wiki .llmwiki/insight -name '*.md' -not -name 'index.md' -not -name 'log.md' -not -name 'log-[0-9][0-9][0-9][0-9].md' 2>/dev/null)
   ```
   For each stale page, either re-verify against current code and bump the date, or mark for review.

5. **Orphan scan** (pages not in index, indexed pages that don't exist):
   ```bash
   diff <(find .llmwiki/wiki -name '*.md' -not -name 'index.md' -not -name 'log.md' -not -name 'log-[0-9][0-9][0-9][0-9].md' | sort) \
        <(LC_ALL=C.UTF-8 grep -oE '\([^)]+\.md' .llmwiki/wiki/index.md | sed 's|^(||; s|^|.llmwiki/wiki/|' | sort)
   ```

6. **MOC integrity** (cross-refs to non-existent pages):
   ```bash
   rg -oP '\[\[\K[^\]]+' .llmwiki/wiki/ | sort -u
   # For each, confirm matching page exists
   ```

7. **Contradictions**: any page with a `> Contradicts:` link is a flag: those should be resolved (one of the two pages updated or merged), not left standing.

8. **Status/supersession integrity** (report-only, no auto-fix):
   ```bash
   # stale pages missing a > Superseded-by: pointer
   while IFS= read -r f; do
     LC_ALL=C.UTF-8 grep -q '^status:[[:space:]]*stale' "$f" || continue
     LC_ALL=C.UTF-8 grep -q '^> Superseded-by:' "$f" || printf 'stale without Superseded-by: %s\n' "$f"
   done < <(find .llmwiki/wiki -name '*.md' -not -name 'index.md' -not -name 'log.md' -not -name 'log-[0-9][0-9][0-9][0-9].md')

   # > Supersedes: targets that are NOT status: stale (BSD grep has no -P/\K; sed capture)
   LC_ALL=C.UTF-8 grep -rh '^> Supersedes:' .llmwiki/wiki/ \
     | sed -n 's/^> Supersedes:[[:space:]]*\[\[\([^]]*\)\]\].*/\1/p' | sort -u | while IFS= read -r id; do
     [[ -z "$id" ]] && continue
     # BSD grep has no \s/\b; find the page whose id EQUALS $id by extracting the
     # value and comparing with `=` (an anchored regex would need $id escaped).
     tgt=$(grep -rl '^id:' .llmwiki/wiki/ | while IFS= read -r f; do
       [ "$(sed -n 's/^id:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$f" | head -1)" = "$id" ] && { printf '%s\n' "$f"; break; }
     done)
     [[ -z "$tgt" ]] && { printf 'Supersedes target missing: %s\n' "$id"; continue; }
     LC_ALL=C.UTF-8 grep -q '^status:[[:space:]]*stale' "$tgt" || printf 'Supersedes target not stale: %s (%s)\n' "$id" "$tgt"
   done
   ```
   Flag mismatches for the user: every `status: stale` page should have a `> Superseded-by:`, and every `> Supersedes:` should point at a page now `status: stale`.

9. **Sources sanity** (soft, report-only): the `sources: N` count should roughly match the number of entries under each page's `## Sources` section. Large divergence (e.g. `sources: 3` with one bullet under `## Sources`) is a flag, not a fail.

10. **Insight layer integrity** (the promoted `.llmwiki/insight/` layer; skip if absent):
    ```bash
    [ -d .llmwiki/insight ] || echo "no insight layer (skip)"

    # 10a. promoted_from resolves to an existing wiki page that is NOT stale
    #      (BSD grep has no -P/\K; sed capture)
    LC_ALL=C.UTF-8 grep -rh '^promoted_from:' .llmwiki/insight/ 2>/dev/null \
      | sed -n 's/^promoted_from:[[:space:]]*\[\[\([^]]*\)\]\].*/\1/p' | sort -u | while IFS= read -r id; do
      [[ -z "$id" ]] && continue
      # BSD grep has no \s/\b; match by exact id value (see the Supersedes block).
      tgt=$(grep -rl '^id:' .llmwiki/wiki/ | while IFS= read -r f; do
        [ "$(sed -n 's/^id:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$f" | head -1)" = "$id" ] && { printf '%s\n' "$f"; break; }
      done)
      [[ -z "$tgt" ]] && { printf 'promoted_from target missing: %s\n' "$id"; continue; }
      LC_ALL=C.UTF-8 grep -q '^status:[[:space:]]*stale' "$tgt" && printf 'promoted_from target is stale: %s (%s)\n' "$id" "$tgt"
    done

    # 10b. conciseness — insight entries must stay condensed (tip, not body)
    find .llmwiki/insight -name '*.md' -not -name 'index.md' -size +2k -print 2>/dev/null

    # 10c. every insight entry declares tier + promoted_from
    while IFS= read -r f; do
      LC_ALL=C.UTF-8 grep -q '^tier:[[:space:]]*insight' "$f" || printf 'insight entry missing tier: %s\n' "$f"
      LC_ALL=C.UTF-8 grep -q '^promoted_from:' "$f" || printf 'insight entry missing promoted_from: %s\n' "$f"
    done < <(find .llmwiki/insight -name '*.md' -not -name 'index.md' -not -name '_insight-template.md' 2>/dev/null)
    ```
    Report-only. Beyond the mechanical checks, eyeball each insight entry against its `promoted_from:` wiki page: the insight must *condense* the page, not contradict it, and must not restate the page's full body (dedup, the long story stays in the wiki). Flag any insight whose rule conflicts with its now-`active` source page, or that has grown into a second copy of the wiki page.

11. **Source-drift scan** (raw evidence integrity: the raw layer is immutable, so a body-hash that no longer matches the stored `sha256:` means the file was edited or the source URL's content moved):
    ```bash
    LC_ALL=C.UTF-8
    _body_sha256() {  # hash the body ONLY (below the YAML frontmatter)
      awk 'NR==1&&$0=="---"{fm=1;next} fm&&$0=="---"{fm=0;next} !fm{print}' "$1" \
        | { sha256sum 2>/dev/null || shasum -a 256; } | awk '{print $1}'
    }
    _fm_sha256() {  # read sha256 ONLY from the leading --- frontmatter block (not body text)
      awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f&&/^sha256:[[:space:]]*[^[:space:]]/{v=$0;sub(/^sha256:[[:space:]]*/,"",v);print v;exit}' "$1" 2>/dev/null
    }
    while IFS= read -r f; do
      stored=$(_fm_sha256 "$f")
      [[ -z "$stored" ]] && continue    # no sha256: in frontmatter -> skip (prospective-only; body-text sha256: ignored)
      actual=$(_body_sha256 "$f")
      [[ "$stored" != "$actual" ]] && printf 'DRIFT: %s (stored %s.. != actual %s..)\n' "$f" "${stored:0:12}" "${actual:0:12}"
    done < <(find .llmwiki/raw -type f -not -name '*.pdf' 2>/dev/null)
    ```
    `find` recurses into the raw source-type buckets (`external/ research/ transcripts/ audits/`) and scans **any-extension text raw** (`.md`, `.txt`, `.html`, ...), not just `.md`: a transcript or external doc can carry `sha256:` frontmatter too; the `sha256:`-presence guard (not the extension) is the real filter. Binary raw (`.pdf`) is excluded since it can't carry text frontmatter. Files with no `sha256:` field are skipped (frontmatter is prospective-only, existing raw is never backfilled, per raw-immutability). A DRIFT hit means either the immutable raw file was edited (a discipline break) or the same `source_url` now yields different bytes (re-ingest -> write a *new* dated snapshot, don't overwrite). Report-only.

12. **Link-poverty scan** (graph-isolated pages: Step 5's orphan scan catches index omissions, but a page can be *in* the index yet carry zero typed cross-refs, leaving it invisible to graph traversal):
    ```bash
    LC_ALL=C.UTF-8
    while IFS= read -r f; do
      n=$(LC_ALL=C.UTF-8 grep -cE '^> (Refines|Contradicts|Evidence|See-also|Supersedes|Superseded-by|Uses|Depends-on|Caused-by|Fixed-by):' "$f")
      [[ "$n" -eq 0 ]] && printf 'link-poverty: %s (0 typed cross-refs)\n' "$f"
    done < <(find .llmwiki/wiki -name '*.md' -not -name 'index.md' -not -name 'log.md' -not -name 'log-[0-9][0-9][0-9][0-9].md' 2>/dev/null)
    ```
    Flags wiki pages with no typed cross-ref line (`> Refines:` / `> See-also:` / `> Evidence:` / ...). Report-only: a genuinely standalone page (a domain's first page, a leaf citing only raw evidence) can be legitimately ref-poor; the human decides whether it should be wired into the graph.

13. **Log-rotation due** (bounded hot log: `log.md` grows monotonically; at year-turnover it should shed the prior year):
    ```bash
    LC_ALL=C.UTF-8
    cur_year=$(date +%Y)
    LC_ALL=C.UTF-8 sed -n 's/^## \([0-9]\{4\}\).*/\1/p' .llmwiki/wiki/log.md 2>/dev/null | sort -u \
      | awk -v y="$cur_year" '$1 < y {printf "log-rotation due: %s entries in log.md -> migrate to log-%s.md\n", $1, $1}'
    ```
    If any `## YYYY-...` entry predates the current year, suggest migrating that year's block into a sibling `log-YYYY.md` (newest-first preserved; `grep '## ' log*.md` still recovers the full time-series). Report-only: the migration itself is a manual / `ingest-finding` op, logged like any other event. (Convention: `${PLUGIN_ROOT}/references/wiki-conventions.md` § log.md discipline.)
