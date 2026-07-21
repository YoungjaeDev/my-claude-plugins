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
# which cr-fix needs to validate for files a fix is about to create. `cd` + `pwd -P`
# is POSIX and resolves symlinks the same way, so the containment check below keeps
# its meaning on macOS, Linux, and Git Bash alike. `..` segments are already
# rejected above, so only the parent needs resolving.
parent=$(cd "$(dirname -- "$REPO_ROOT/$P")" 2>/dev/null && pwd -P) \
  || { echo "untrusted-path: unresolvable parent: $P" >&2; exit 1; }
abs="$parent/$(basename -- "$P")"
repo_abs=$(cd "$REPO_ROOT" 2>/dev/null && pwd -P) \
  || { echo "untrusted-path: unresolvable repo root: $REPO_ROOT" >&2; exit 1; }
case "$abs" in
  "$repo_abs"/*|"$repo_abs") ;;
  *) echo "untrusted-path: resolves outside repo: $P → $abs" >&2; exit 1;;
esac
