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

abs=$(realpath -m -- "$REPO_ROOT/$P")
repo_abs=$(realpath -- "$REPO_ROOT")
case "$abs" in
  "$repo_abs"/*|"$repo_abs") ;;
  *) echo "untrusted-path: resolves outside repo: $P → $abs" >&2; exit 1;;
esac
