#!/usr/bin/env bash
# Usage: bash scripts/stage-and-commit.sh TRACK_FILE ITER [DIRTY_BASE]
# Reads NUL-delimited repo-relative paths from TRACK_FILE, stages those that still differ from HEAD,
# commits with conventional message. Exits 0 if nothing staged (caller checks).
# DIRTY_BASE: NUL-delimited paths already dirty before the cycle's fixes (Step 5). With
# it, every other path dirty now goes in too: a fix's regression test or fixture is
# not in TRACK_FILE, which holds only each finding's own path (PR #334).
# Prints "staged:N" or "noop" on stdout.
set -euo pipefail

TRACK="${1:?track file required}"
ITER="${2:?iter required}"
DIRTY_BASE="${3:-}"

[ -s "$TRACK" ] || { printf 'noop\n'; exit 0; }

candidates=()
while IFS= read -r -d '' f; do candidates+=("$f"); done < <(sort -zu "$TRACK")
if [ -n "$DIRTY_BASE" ] && [ -f "$DIRTY_BASE" ]; then
  base=()
  while IFS= read -r -d '' f; do base+=("$f"); done < "$DIRTY_BASE"
  while IFS= read -r -d '' f; do
    seen=false
    for b in ${base[@]+"${base[@]}"}; do [ "$b" = "$f" ] && { seen=true; break; }; done
    [ "$seen" = true ] || candidates+=("$f")
  done < <(git diff HEAD --name-only -z; git ls-files --others --exclude-standard -z)
fi

files=()
for f in ${candidates[@]+"${candidates[@]}"}; do
  [ -z "$f" ] && continue
  for g in ${files[@]+"${files[@]}"}; do [ "$g" = "$f" ] && continue 2; done
  if git diff --name-only -z -- "$f" >/dev/null 2>&1; then
    # Against HEAD, not the index: a VERIFY_CMD that stages (`git add -A`) leaves the fix there.
    if [ -n "$(git diff HEAD --name-only -- "$f")" ] || [ -n "$(git ls-files --others --exclude-standard -- "$f")" ]; then
      files+=("$f")
    fi
  fi
done

if [ "${#files[@]}" -eq 0 ]; then printf 'noop\n'; exit 0; fi

git add -- "${files[@]}"
# Reviewer-neutral: an iteration can carry CodeRabbit findings, Codex findings, or both.
git commit -m "fix: apply review findings (review-loop iter $ITER)"
printf 'staged:%d\n' "${#files[@]}"
