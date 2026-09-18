#!/usr/bin/env bash
# Usage: bash scripts/cr-review-request.sh BASE DEFAULT_BRANCH [CONFIG]
# Prints `request` when CodeRabbit will not auto-review a PR into BASE, so cr-fix
# must post `@coderabbitai review` after each push; prints `skip` otherwise. The
# reason goes to stderr. No network: CONFIG (default .coderabbit.yaml) is read
# from disk.
#
#   BASE == DEFAULT_BRANCH                       -> skip (auto-review covers it)
#   CONFIG missing or unreadable                 -> request (safe default)
#   reviews.auto_review.enabled: false           -> skip (quota saving wins, Decision 17)
#   BASE matches a reviews.auto_review.base_branches regex -> skip
#   otherwise                                    -> request
#
# ponytail: line-based YAML reader for two keys under reviews.auto_review (flow
# `[..]` or block `- ..` lists). Anchors, multi-line strings and a `#` inside a
# pattern are not handled; use a real YAML parser if the config grows those.
set -uo pipefail

BASE="${1:?base required}"; DEFAULT="${2:?default branch required}"; CONFIG="${3:-.coderabbit.yaml}"

if [ "$BASE" = "$DEFAULT" ]; then echo "base is the default branch" >&2; echo skip; exit 0; fi
if [ ! -r "$CONFIG" ]; then echo "no readable $CONFIG" >&2; echo request; exit 0; fi

# Emits `enabled<TAB>value` and `branch<TAB>pattern` lines for reviews.auto_review.
parsed=$(awk -v q="'" '
  function strip(s) {
    sub(/[ \t]+#.*$/, "", s); gsub(/^[ \t]+|[ \t]+$/, "", s)
    if (s ~ /^".*"$/ || s ~ ("^" q ".*" q "$")) s = substr(s, 2, length(s) - 2)
    return s
  }
  /^[ \t]*(#|$)/ { next }
  {
    match($0, /^ */); ind = RLENGTH; line = substr($0, ind + 1)
    if (ind == 0) { in_rev = (line ~ /^reviews:/); in_ar = 0; in_bb = 0; next }
    if (!in_rev) next
    if (in_bb && line ~ /^-( |$)/ && ind >= bb_ind) { p = strip(substr(line, 2)); if (p != "") print "branch\t" p; next }
    in_bb = 0
    if (in_ar && ind <= ar_ind) in_ar = 0
    if (!in_ar) { if (line ~ /^auto_review:/) { in_ar = 1; ar_ind = ind }; next }
    if (line ~ /^enabled:/) { print "enabled\t" strip(substr(line, 9)); next }
    if (line ~ /^base_branches:/) {
      v = strip(substr(line, 15))
      if (v == "") { in_bb = 1; bb_ind = ind; next }
      gsub(/^\[|\]$/, "", v); n = split(v, parts, ",")
      for (i = 1; i <= n; i++) { p = strip(parts[i]); if (p != "") print "branch\t" p }
    }
  }' "$CONFIG") || { echo "could not parse $CONFIG" >&2; echo request; exit 0; }

# YAML reads false / False / FALSE alike.
if printf '%s\n' "$parsed" | grep -qi "^enabled	false$"; then
  echo "reviews.auto_review.enabled is false" >&2; echo skip; exit 0
fi

while IFS='	' read -r kind pat; do
  [ "$kind" = branch ] || continue
  # An invalid regex returns 2 from [[ =~ ]] and simply does not match.
  if [[ $BASE =~ $pat ]]; then echo "base matches base_branches /$pat/" >&2; echo skip; exit 0; fi
done <<EOF
$parsed
EOF

echo "base '$BASE' is not the default branch and matches no base_branches pattern" >&2
echo request
