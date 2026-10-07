#!/usr/bin/env bash
# Usage:
#   NO_BUILD=true|false bash scripts/verify-fix.sh baseline "$VERIFY_CMD"
#       -> on | baseline_failed | no_build_check | no_command
#   bash scripts/verify-fix.sh snapshot
#       -> tree id of the working tree (tracked + untracked, minus ignored)
#   bash scripts/verify-fix.sh check SNAPSHOT "$VERIFY_CMD"
#       -> pass | fail; on fail every path changed since SNAPSHOT is put back
#
# The Step 11 gate, run before the commit: baseline once at loop start, then
# snapshot before each fix and check after it, so only fixes that pass reach the
# commit. VERIFY_CMD is the repo's build + test line (from AGENTS.md), never
# reviewer text. Its output goes to stderr so stdout stays one token. The real
# index is never touched: snapshots are written through a throwaway index.
set -euo pipefail

# Tree paths are repo-relative; the loop already runs at the root (Step 2).
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# VERIFY_CMD runs on a copy of the index: a command that stages (`git add -A`) would
# otherwise stage unrelated user changes, and the next commit would carry them.
run_cmd() {
  local idx real rc=0
  idx=$(mktemp); real=$(git rev-parse --git-path index)
  if [ -f "$real" ]; then cp "$real" "$idx"; else rm -f "$idx"; fi
  GIT_INDEX_FILE="$idx" bash -c "$1" >&2 || rc=$?
  rm -f "$idx"
  return "$rc"
}

# Write the working tree as a tree object through a temp index seeded from the real one.
tree_of_worktree() {
  local idx real tree
  idx=$(mktemp)
  real=$(git rev-parse --git-path index)
  if [ -f "$real" ]; then cp "$real" "$idx"; else rm -f "$idx"; fi
  GIT_INDEX_FILE="$idx" git add -A >/dev/null 2>&1
  tree=$(GIT_INDEX_FILE="$idx" git write-tree)
  rm -f "$idx"
  printf '%s\n' "$tree"
}

case "${1:-}" in
  baseline)
    cmd="${2:-}"
    if [ "${NO_BUILD:-false}" = true ]; then echo no_build_check
    elif [ -z "$cmd" ]; then echo no_command
    elif run_cmd "$cmd"; then echo on
    else echo baseline_failed
    fi ;;
  snapshot)
    tree_of_worktree ;;
  check)
    snap="${2:?snapshot required}"; cmd="${3:?verify command required}"
    if run_cmd "$cmd"; then echo pass; exit 0; fi
    now=$(tree_of_worktree)
    idx=$(mktemp); rm -f "$idx"
    GIT_INDEX_FILE="$idx" git read-tree "$snap"
    while IFS= read -r -d '' p; do
      if git cat-file -e "$snap:$p" 2>/dev/null; then
        GIT_INDEX_FILE="$idx" git checkout-index -f -- "$p"
      else
        rm -f -- "$p"  # created by the failing fix
      fi
    done < <(git diff --no-renames --name-only -z "$snap" "$now")
    rm -f "$idx"
    echo fail ;;
  *) echo "usage: verify-fix.sh baseline|snapshot|check ..." >&2; exit 2 ;;
esac
