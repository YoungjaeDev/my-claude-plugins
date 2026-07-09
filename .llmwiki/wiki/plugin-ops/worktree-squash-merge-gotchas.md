---
id: worktree-squash-merge-gotchas
aliases: [enterworktree-basefef-fresh, gh-pr-merge-delete-branch-worktree, exitworktree-ancestry-false-positive, dot-git-is-a-file-in-worktree]
last_verified: 2026-07-09
status: active
volatility: volatile
sources: 2
---

# Worktree lifecycle gotchas

Three git/harness gotchas that surface around worktrees — the first two specifically when a worktree-based implementation branch gets squash-merged, the third whenever a script tries to answer "am I in a git repo?".

## 1. `EnterWorktree` branches from `origin/<default-branch>`, not local HEAD

The default `baseRef: fresh` creates the new worktree's branch from `origin/main` at fetch time — not from whatever the current local `main` happens to be. If local `main` carries commits that were never pushed (e.g. spec/plan docs committed earlier in the same session), the freshly created worktree will not see them; files created by those commits appear missing.

Fix: from inside the worktree, `git rebase main` (or `git merge main`) to pull the local-only commits into the worktree branch before starting task work. Confirm first with `git log --oneline origin/main..main` — if it's non-empty, the worktree needs this rebase.

## 2. `gh pr merge --delete-branch` can hijack the current worktree's checkout

Running `gh pr merge <N> --squash --delete-branch` from inside the worktree that has the PR's branch checked out does more than merge and delete on GitHub: as local housekeeping, gh CLI also checks out the worktree onto the base branch (`main`) and attempts to fast-forward local `main` to match the new `origin/main`. If local `main` has diverged from `origin/main` (e.g. it still carries the local-only commits from gotcha #1, which are now folded into the new squash commit under a different parent), the fast-forward fails with `fatal: Not possible to fast-forward, aborting` — but the checkout switch to `main` has already happened.

At this point `ExitWorktree` will also refuse removal, reporting "N commit(s)" as if unmerged — an instance of the general squash-merge ancestry false-positive (a squash commit's parent chain doesn't literally contain the source branch's commits, so ordinary ancestry checks see divergence even when the content is fully present).

Fix (verified safe both times): confirm nothing is lost via **bidirectional** content diff — `git diff origin/main main --stat` and `git diff main origin/main --stat` — if the only differences are the PR's own content (nothing unique to local `main`), it is safe to `git reset --hard origin/main`, then `ExitWorktree({action: "remove", discard_changes: true})`.

## 3. `.git` is a FILE in a worktree, so `test -d .git` reports "not a git repo"

A linked worktree's `.git` is not a directory — it is a one-line gitdir pointer *file* (`gitdir: /path/to/.git/worktrees/<name>`). The same holds inside a submodule. Any script that gates on `[ -d .git ]` therefore concludes it is outside a repository, in a directory that is very much inside one.

The first-order symptom (a `git_initialized: false` flag) is easy to spot. The **second-order cascade is not, and is only visible by running it**: a detector whose other git probes short-circuit on that flag will return the flag's default for all of them. Measured case — a helper shaped like

```bash
ignored() { [ "$GIT_INIT" = true ] || { echo false; return; }; git check-ignore -q "$1" && echo true || echo false; }
```

reported *every* path as un-ignored inside a worktree, which turned a `.gitignore`-coverage check into a guaranteed false FAIL on its highest-severity axis (an "uncovered `.env`"). Reading the `test -d .git` line does not reveal that; running it does.

Fix: ask git, not the filesystem.

```bash
GIT_INIT=false
if [ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]; then GIT_INIT=true; fi
```

This matters here because `github-dev` drives implementation work from worktrees, so any diagnostic run under that flow takes the broken branch by default. Related trap in the same neighbourhood: `git config core.hooksPath` outside a repo silently returns the user's *global* value, so guard that lookup on the same flag — but do **not** narrow it to `--local`, since the value that actually applies is the `local > global > system` resolution.

> See-also: [[skill-engine-layering]] (a different squash-merge-adjacent gotcha: reproducing an engine's internal API in prose drifts across squash boundaries too, though that is a documentation-staleness issue, not a git-ancestry one)

## Sources

1. **PR #89** (`ppt-yeong-style` completion-gate + document-structure round) — gotchas 1 and 2 hit back-to-back during worktree setup and post-merge cleanup; resolved via the content-diff-then-reset/discard pattern described above.
2. **PR #104** (`project-init` wiring skill) — gotcha 3, surfaced by a CodeRabbit CLI finding and confirmed by running the detector inside a real `git worktree add`: `initialized=false`, `commits=0`, and all four `git check-ignore` probes false. Fixed with `git rev-parse --is-inside-work-tree`.
