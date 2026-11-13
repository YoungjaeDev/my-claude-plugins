#!/usr/bin/env bash
# Usage: bash scripts/stage-and-commit.sh TRACK_FILE ITER [DIRTY_BASE]
# Reads NUL-delimited repo-relative paths from TRACK_FILE, stages those that still differ from HEAD,
# commits with conventional message. Exits 0 if nothing staged (caller checks).
# DIRTY_BASE: NUL-delimited paths already dirty before the cycle's fixes (Step 5). With
# it, every other path dirty now goes in too: a fix's regression test or fixture is
# not in TRACK_FILE, which holds only each finding's own path (PR #334).
# A new untracked file outside TRACK_FILE goes in only when it is text of 1 MB or less: a
# large or binary one is a local artifact (PR #120 in another repo committed a 24 MB zip),
# so it stays out with a warning on stderr. The commit subject follows the repo's recent
# subjects: Korean when most of the last 20 are, English otherwise.
# Prints "staged:N" or "noop" on stdout.
set -euo pipefail

# Text of 1 MB or less: the size, and no NUL byte (`tr` keeps this portable across GNU/BSD).
small_text() {
  local size; size=$(wc -c < "$1" | tr -d ' ') || return 1
  [ "$size" -le 1048576 ] && [ "$(LC_ALL=C tr -d '\000' < "$1" | wc -c | tr -d ' ')" -eq "$size" ]
}

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
    [ "$seen" = true ] && continue
    if [ -z "$(git ls-files -- "$f")" ] && ! small_text "$f"; then
      echo "stage-and-commit: left out $f (new file over 1 MB or binary)" >&2; continue
    fi
    candidates+=("$f")
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
# Lines whose subject carries a Hangul lead byte (UTF-8 0xEA-0xED), counted byte-wise so
# GNU and BSD grep agree.
subjects=$(git log -20 --format=%s 2>/dev/null)
total=$(printf '%s\n' "$subjects" | grep -c . || true)
korean=$(printf '%s\n' "$subjects" | LC_ALL=C grep -cE "$(printf '[\352-\355]')" || true)
if [ "${total:-0}" -gt 0 ] && [ $((korean * 2)) -gt "$total" ]; then
  git commit -m "fix: 리뷰 지적 반영 (review-loop iter $ITER)"
else
  git commit -m "fix: apply review findings (review-loop iter $ITER)"
fi
printf 'staged:%d\n' "${#files[@]}"
