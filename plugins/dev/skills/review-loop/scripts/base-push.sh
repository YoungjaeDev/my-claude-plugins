#!/usr/bin/env bash
# Usage: bash scripts/base-push.sh BASE REVIEWED_SHA FIX_SHA "$VERIFY_CMD"
# merge_then_main_push, after the PR merged (ADR 0006): applies the commits
# REVIEWED_SHA..FIX_SHA onto origin/BASE in a throwaway worktree, runs VERIFY_CMD
# there, commits with FIX_SHA's message (the pre-commit hook runs), and pushes to
# BASE. Prints the pushed sha. Exit 1 with the reason on stderr and nothing pushed
# when there is no command, the fixes do not apply, or build/test or a hook fails.
# The caller's checkout and index are never touched.
set -euo pipefail

BASE="${1:?base branch required}"; FROM="${2:?reviewed sha required}"; TO="${3:?fix sha required}"
CMD="${4:-}"
no() { echo "base-push: $1; nothing pushed to $BASE" >&2; exit 1; }

[ -n "$CMD" ] || no "no build/test command to verify the fixes with"
git fetch -q origin "$BASE" || no "could not fetch origin/$BASE"
WT=$(mktemp -d)
trap 'git worktree remove --force "$WT" >/dev/null 2>&1 || rm -rf "$WT"; git worktree prune >/dev/null 2>&1 || true' EXIT
git worktree add -q --detach "$WT" "origin/$BASE" >/dev/null 2>&1 || no "could not check out origin/$BASE"
git -C "$WT" cherry-pick --no-commit "$FROM..$TO" >/dev/null 2>&1 || no "the fixes do not apply on origin/$BASE"
(cd "$WT" && bash -c "$CMD") >&2 || no "build/test failed on origin/$BASE with the fixes"
git -C "$WT" commit -q -C "$TO" >&2 || no "the commit was refused (pre-commit guards)"
git -C "$WT" push -q origin "HEAD:$BASE" >&2 || no "the push was rejected"
git -C "$WT" rev-parse HEAD
