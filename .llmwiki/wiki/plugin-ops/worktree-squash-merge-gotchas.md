---
id: worktree-squash-merge-gotchas
aliases: [enterworktree-basefef-fresh, gh-pr-merge-delete-branch-worktree, exitworktree-ancestry-false-positive]
last_verified: 2026-07-02
status: active
volatility: volatile
sources: 1
---

# Worktree lifecycle gotchas around squash-merge

Two git/harness gotchas that surface specifically when a worktree-based implementation branch gets squash-merged.

## 1. `EnterWorktree` branches from `origin/<default-branch>`, not local HEAD

The default `baseRef: fresh` creates the new worktree's branch from `origin/main` at fetch time — not from whatever the current local `main` happens to be. If local `main` carries commits that were never pushed (e.g. spec/plan docs committed earlier in the same session), the freshly created worktree will not see them; files created by those commits appear missing.

Fix: from inside the worktree, `git rebase main` (or `git merge main`) to pull the local-only commits into the worktree branch before starting task work. Confirm first with `git log --oneline origin/main..main` — if it's non-empty, the worktree needs this rebase.

## 2. `gh pr merge --delete-branch` can hijack the current worktree's checkout

Running `gh pr merge <N> --squash --delete-branch` from inside the worktree that has the PR's branch checked out does more than merge and delete on GitHub: as local housekeeping, gh CLI also checks out the worktree onto the base branch (`main`) and attempts to fast-forward local `main` to match the new `origin/main`. If local `main` has diverged from `origin/main` (e.g. it still carries the local-only commits from gotcha #1, which are now folded into the new squash commit under a different parent), the fast-forward fails with `fatal: Not possible to fast-forward, aborting` — but the checkout switch to `main` has already happened.

At this point `ExitWorktree` will also refuse removal, reporting "N commit(s)" as if unmerged — an instance of the general squash-merge ancestry false-positive (a squash commit's parent chain doesn't literally contain the source branch's commits, so ordinary ancestry checks see divergence even when the content is fully present).

Fix (verified safe both times): confirm nothing is lost via **bidirectional** content diff — `git diff origin/main main --stat` and `git diff main origin/main --stat` — if the only differences are the PR's own content (nothing unique to local `main`), it is safe to `git reset --hard origin/main`, then `ExitWorktree({action: "remove", discard_changes: true})`.

> See-also: [[skill-engine-layering]] (a different squash-merge-adjacent gotcha: reproducing an engine's internal API in prose drifts across squash boundaries too, though that is a documentation-staleness issue, not a git-ancestry one)

## Sources

- PR #89 (`ppt-yeong-style` completion-gate + document-structure round) — both gotchas hit back-to-back during worktree setup and post-merge cleanup; resolved via the content-diff-then-reset/discard pattern described above.
