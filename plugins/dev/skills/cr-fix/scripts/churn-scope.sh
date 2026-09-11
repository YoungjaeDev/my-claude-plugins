#!/usr/bin/env bash
# Usage: bash scripts/churn-scope.sh PREV_SHA BASE_REF PATH LINE
# Prints `churn` or `fresh` on stdout. Exit 0 always.
#
# A finding is CHURN when the loop, not the PR, produced the material it sits on:
#   - its line falls inside a hunk the previous iteration's commit added or changed, or
#   - its line falls outside the PR diff entirely (pre-existing code the reviewer
#     reached for after exhausting the diff).
# Everything else is `fresh`. See references/autonomous-judgment.md.
#
# PREV_SHA empty (first iteration, or no prior commit) disables the first test.
# An empty/non-numeric LINE (file-level finding) is always `fresh`: there is no
# position to compare, and defaulting to churn would silence real file-level work.
set -uo pipefail

PREV_SHA="${1:-}"; BASE_REF="${2:-}"; FPATH="${3:-}"; LINE="${4:-}"

case "$LINE" in ''|*[!0-9]*) printf 'fresh\n'; exit 0;; esac
[ -n "$FPATH" ] || { printf 'fresh\n'; exit 0; }

# Does LINE fall inside an added/changed hunk of the diff on stdin?
# `@@ -a,b +c,d @@` — field 3 is the `+c,d` side; an absent count means 1, and a
# count of 0 is a pure deletion, which owns no post-image line.
# A header git still had to quote (control characters in the name) cannot be compared
# as text; `unparsable` makes the caller fall back to `fresh` rather than claim churn.
hunk_hit() {
  awk -v want="$FPATH" -v ln="$LINE" '
    /^\+\+\+ "/     { print "unparsable"; exit }
    /^\+\+\+ /      { f=$0; sub(/^\+\+\+ /, "", f); sub(/\t.*$/, "", f); sub(/^b\//, "", f); next }
    /^@@ /          { split($3, a, ","); s=a[1]; sub(/^\+/, "", s);
                      n = (a[2] == "" ? 1 : a[2]) + 0;
                      if (f == want && n > 0 && ln+0 >= s+0 && ln+0 < s+n) { print "hit"; exit } }
  '
}

# `--no-ext-diff -U0`: a user diff driver would break the hunk grammar this parses.
# `core.quotePath=false`: otherwise a non-ASCII name arrives octal-escaped and never
# matches, which would silently mark every finding in such a file as churn.
diff_of() {
  git --no-pager -c core.quotePath=false diff --no-ext-diff -U0 "$1" -- "$FPATH" 2>/dev/null || true
}

prev_hit=""
if [ -n "$PREV_SHA" ]; then
  prev_hit=$(diff_of "${PREV_SHA}..HEAD" | hunk_hit)
  [ "$prev_hit" = unparsable ] && { printf 'fresh\n'; exit 0; }
  [ -n "$prev_hit" ] && { printf 'churn\n'; exit 0; }
fi

# Outside the PR diff. Only decidable when the base ref resolves; an unresolvable
# base (detached CI checkout, missing remote ref) must not manufacture churn, so
# the finding stays fresh.
if [ -n "$BASE_REF" ] && git rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1; then
  base_hit=$(diff_of "${BASE_REF}...HEAD" | hunk_hit)
  [ "$base_hit" = unparsable ] && { printf 'fresh\n'; exit 0; }
  if [ -z "$base_hit" ]; then
    printf 'churn\n'; exit 0
  fi
fi

printf 'fresh\n'
