#!/usr/bin/env bash
# Usage: bash scripts/stage-and-commit.sh TRACK_FILE ITER
# Reads NUL-delimited repo-relative paths from TRACK_FILE, stages those that still differ from HEAD,
# commits with conventional message. Exits 0 if nothing staged (caller checks).
# Prints "staged:N" or "noop" on stdout.
set -euo pipefail

TRACK="${1:?track file required}"
ITER="${2:?iter required}"

[ -s "$TRACK" ] || { printf 'noop\n'; exit 0; }

files=()
while IFS= read -r -d '' f; do
  [ -z "$f" ] && continue
  if git diff --name-only -z -- "$f" >/dev/null 2>&1; then
    if [ -n "$(git diff --name-only -- "$f")" ] || [ -n "$(git ls-files --others --exclude-standard -- "$f")" ]; then
      files+=("$f")
    fi
  fi
done < <(sort -zu "$TRACK")

if [ "${#files[@]}" -eq 0 ]; then printf 'noop\n'; exit 0; fi

git add -- "${files[@]}"
git commit -m "fix: apply CodeRabbit auto-fixes (cr-fix iter $ITER)"
printf 'staged:%d\n' "${#files[@]}"
