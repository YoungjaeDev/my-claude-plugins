#!/usr/bin/env bash
# Usage: bash scripts/base-push.sh BASE REVIEWED_SHA FIX_SHA "$VERIFY_CMD"
# merge_then_main_push, after the PR merged (ADR 0006): cherry-picks the commits
# REVIEWED_SHA..FIX_SHA one by one onto origin/BASE in a throwaway worktree (each
# keeps its own message), runs VERIFY_CMD there, runs the repo's pre-commit guard
# itself, and pushes to BASE. Prints the pushed sha. Exit 1 with the reason on stderr
# and nothing pushed when there is no command, the fixes do not apply, or build/test
# or the guard fails. The caller's checkout and index are never touched.
#
# The guard runs whether or not this clone turned its hooks on: the first executable
# of <core.hooksPath>/pre-commit, the tracked .githooks/pre-commit, and git's default
# hooks/pre-commit, resolved inside the worktree (a relative core.hooksPath is
# relative to the worktree root, as git reads it). A repo with none has no guard to run.
set -euo pipefail

BASE="${1:?base branch required}"; FROM="${2:?reviewed sha required}"; TO="${3:?fix sha required}"
CMD="${4:-}"
no() { echo "base-push: $1; nothing pushed to $BASE" >&2; exit 1; }

[ -n "$CMD" ] || no "no build/test command to verify the fixes with"
git fetch -q origin "$BASE" || no "could not fetch origin/$BASE"
WT=$(mktemp -d)
trap 'git worktree remove --force "$WT" >/dev/null 2>&1 || rm -rf "$WT"; git worktree prune >/dev/null 2>&1 || true' EXIT
git worktree add -q --detach "$WT" "origin/$BASE" >/dev/null 2>&1 || no "could not check out origin/$BASE"
git -C "$WT" cherry-pick "$FROM..$TO" >/dev/null 2>&1 || no "the fixes do not apply on origin/$BASE"
(cd "$WT" && bash -c "$CMD") >&2 || no "build/test failed on origin/$BASE with the fixes"

guard=$(cd "$WT" && {
  hp=$(git config --path core.hooksPath 2>/dev/null || true)
  for h in ${hp:+"$hp/pre-commit"} .githooks/pre-commit "$(git rev-parse --git-path hooks/pre-commit)"; do
    if [ -f "$h" ] && [ -x "$h" ]; then (cd "$(dirname "$h")" && printf '%s/%s' "$(pwd)" "$(basename "$h")"); break; fi
  done
})
if [ -n "$guard" ]; then
  (cd "$WT" && "$guard") >&2 || no "the pre-commit guard refused the fixes ($guard)"
fi
# A guard or command that rewrote tracked files (a formatter) passed content the push would not carry.
git -C "$WT" diff --quiet HEAD -- || no "build/test or the pre-commit guard changed tracked files"
git -C "$WT" push -q origin "HEAD:$BASE" >&2 || no "the push was rejected"
git -C "$WT" rev-parse HEAD
