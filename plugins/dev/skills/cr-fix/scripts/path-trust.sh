#!/usr/bin/env bash
# Usage: bash scripts/path-trust.sh REPO_ROOT PATH
# Exits 0 if PATH is safe to Read/Edit within REPO_ROOT, non-zero otherwise.
# Checks: no leading /, no .. segments, no ~ expansion, realpath stays inside repo.
set -euo pipefail

REPO_ROOT="${1:?repo root required}"
P="${2:?path required}"

case "$P" in
  /*) echo "untrusted-path: absolute path: $P" >&2; exit 1;;
  '~'*) echo "untrusted-path: home-relative path: $P" >&2; exit 1;;
esac

case "$P" in
  *../*|*/..|..) echo "untrusted-path: .. segment: $P" >&2; exit 1;;
esac

# `realpath -m` is GNU-only (BSD/macOS realpath rejects it), and bare `realpath`
# is no substitute: both GNU and BSD error on a path that does not exist yet,
# which cr-fix needs to validate for files a fix is about to create.
#
# Resolving only the parent is NOT enough: if the final component is itself a
# symlink pointing outside the repo, the reconstructed path still looks in-repo
# and the containment check below passes, letting a downstream Edit write outside
# the trust boundary. So follow a final-component symlink chain too, re-resolving
# the parent each hop. `cd` + `pwd -P` + `readlink` are portable across macOS,
# Linux, and Git Bash. `..` segments are already rejected above.
resolve_path() {
  _p="$1" _n=0
  while :; do
    _d=$(dirname -- "$_p"); _b=$(basename -- "$_p")
    _d=$(cd "$_d" 2>/dev/null && pwd -P) || return 1
    _p="$_d/$_b"
    [ -L "$_p" ] || break
    _n=$((_n + 1))
    [ "$_n" -gt 40 ] && return 1   # symlink loop / excessive nesting
    _link=$(readlink -- "$_p") || return 1
    case "$_link" in
      /*) _p="$_link" ;;
      *)  _p="$_d/$_link" ;;
    esac
  done
  printf '%s\n' "$_p"
}

abs=$(resolve_path "$REPO_ROOT/$P") \
  || { echo "untrusted-path: unresolvable path: $P" >&2; exit 1; }
repo_abs=$(cd "$REPO_ROOT" 2>/dev/null && pwd -P) \
  || { echo "untrusted-path: unresolvable repo root: $REPO_ROOT" >&2; exit 1; }
case "$abs" in
  "$repo_abs"/*|"$repo_abs") ;;
  *) echo "untrusted-path: resolves outside repo: $P → $abs" >&2; exit 1;;
esac
