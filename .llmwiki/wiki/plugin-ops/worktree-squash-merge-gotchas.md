---
id: worktree-squash-merge-gotchas
aliases: [enterworktree-basefef-fresh, gh-pr-merge-delete-branch-worktree, exitworktree-ancestry-false-positive, dot-git-is-a-file-in-worktree, stacked-pr-base-delete-close, gitignored-state-is-per-worktree, post-merge-stash-parks-work]
last_verified: 2026-07-30
status: active
volatility: volatile
sources: 5
---

# Worktree lifecycle gotchas

Six git/harness gotchas that surface around worktrees and squash-merges — the first two when a worktree-based implementation branch gets squash-merged, the third whenever a script tries to answer "am I in a git repo?", the fourth when PRs are stacked on each other's branches, the last two when a cleanup run's own housekeeping moves state the next reader assumes is still in place.

## 1. `EnterWorktree` branches from `origin/<default-branch>`, not local HEAD

The default `baseRef: fresh` creates the new worktree's branch from `origin/main` at fetch time — not from whatever the current local `main` happens to be. If local `main` carries commits that were never pushed (e.g. spec/plan docs committed earlier in the same session), the freshly created worktree will not see them; files created by those commits appear missing.

Fix: from inside the worktree, `git rebase main` (or `git merge main`) to pull the local-only commits into the worktree branch before starting task work. Confirm first with `git log --oneline origin/main..main` — if it's non-empty, the worktree needs this rebase.

## 2. `gh pr merge --delete-branch` can hijack the current worktree's checkout

Running `gh pr merge <N> --squash --delete-branch` from inside the worktree that has the PR's branch checked out does more than merge and delete on GitHub: as local housekeeping, gh CLI also checks out the worktree onto the base branch (`main`) and attempts to fast-forward local `main` to match the new `origin/main`. If local `main` has diverged from `origin/main` (e.g. it still carries the local-only commits from gotcha #1, which are now folded into the new squash commit under a different parent), the fast-forward fails with `fatal: Not possible to fast-forward, aborting` — but the checkout switch to `main` has already happened.

At this point `ExitWorktree` will also refuse removal, reporting "N commit(s)" as if unmerged — an instance of the general squash-merge ancestry false-positive (a squash commit's parent chain doesn't literally contain the source branch's commits, so ordinary ancestry checks see divergence even when the content is fully present).

Fix (verified safe both times): confirm nothing is lost via **bidirectional** content diff — `git diff origin/main main --stat` and `git diff main origin/main --stat` — if the only differences are the PR's own content (nothing unique to local `main`), it is safe to `git reset --hard origin/main`, then `ExitWorktree({action: "remove", discard_changes: true})`.

The same divergence reaches the main repo without any worktree: a commit made on local `main` and never pushed rides into `origin/main` only through the PR branch's squash, so `git pull` afterwards reports "1 and 1 different commits" and refuses. The content diff is the same check, and the resolution is the same reset.

Ahead of a merge rather than after it, `git merge-tree --write-tree --name-only <branch> <base>` reports which files will conflict **without touching the working tree or the index**. It names the files, so a doc-heavy conflict (this repo's `AGENTS.md` plugin table conflicts on almost any stale branch) can be planned before the merge instead of diagnosed during it.

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

## 4. Squash-merging a base PR with `--delete-branch` auto-CLOSES stacked child PRs

Observed once (2026-07-10): PR #108 was based on PR #106's feature branch. When #106 was squash-merged with `--delete-branch`, GitHub **closed** #108 rather than retargeting its base to `main`. The head branch survives, so recovery is opening a new PR from the same head — but review threads and PR history on the closed one do not carry over.

Recorded as an observation, not a universal mechanism — GitHub's retarget-vs-close behavior may depend on merge method or timing. Until re-observed, treat "stack a PR on an unmerged PR's branch + squash-merge the base with `--delete-branch`" as a combination that can silently drop the child PR.

> See-also: [[skill-engine-layering]] (a different squash-merge-adjacent gotcha: reproducing an engine's internal API in prose drifts across squash boundaries too, though that is a documentation-staleness issue, not a git-ancestry one)

## 5. A gitignored state directory is per-worktree, so a guard that forces the main repo cannot read it

`.claude/state/` and `.llmwiki/.staging/` are gitignored, which makes them **per-working-directory**: a file one skill writes in a worktree does not exist in the main repo, and nothing about the git history reveals that.

Two rules in `github-dev` then contradict each other. Step 1 of `post-merge` **P0-aborts** when run inside a worktree (its Step 3 checks out the base branch and would collide with the main repo's checkout). Step 1.5 resolves cr-fix's run record at `.claude/state/cr-fix-<PR>.json` **relative to cwd**. So the normal flow — implement in a worktree, run cr-fix there, then post-merge from the main repo, exactly as the guard demands — leaves Step 1.5 looking in the wrong filesystem. It finds no file, takes the `else` branch (`DEFER_N=0`), and prints:

```text
leftover-reviews: none
```

over a real deferred finding. The failure has the shape this repo keeps re-learning: a step that **could not look** reports that **nothing is there** (see [[detector-cannot-look-vs-nothing-wrong]]). It is worse than a plain miss, because the checkpoint line exists precisely so a skip cannot pass unnoticed — and here the skip prints the reassuring answer.

Measured 2026-07-30 (PR #193): cr-fix wrote `final_state=iteration_cap` + one deferred finding into the worktree's `.claude/state/`; running Step 1.5's own snippet from the main repo resolved nothing. Passing the worktree path explicitly produced the correct `leftover-reviews: 1 deferred (final_state=iteration_cap)`.

The general rule: **when a guard pins *where* a skill may run, every path that skill reads must be anchored to something the guard cannot move.** A cwd-relative path under a gitignored directory is not that. Candidate anchors are the common git dir (`git rev-parse --git-common-dir`, identical from every worktree), an explicit argument, or a scan of sibling worktrees (`git worktree list`).

## 6. `post-merge` Step 2 parks your work on a branch Step 3 then leaves

Step 2 offers **stash** for uncommitted tracked changes; Step 3 immediately checks out the base branch. Nothing is lost, but the stash entry is labelled with the branch the working tree has since left (`stash@{0}: On <feature-branch>: post-merge: temp save (<file>)`), and the file now reads at its *base-branch* content with `git status` clean.

That combination is indistinguishable from "the edit was never made". The reader has no signal: the working tree is clean, the file exists, and its content is a plausible earlier version. Step 2's closing pop/apply/later prompt is the intended recovery, but it only fires if the run reaches the end — a run that stops earlier, or a user who picks "later", leaves the work reachable **only** through `git stash list`.

Measured 2026-07-30 (PR #195): `stash@{0}: On docs/claude-md-global-diet: post-merge: temp save (CLAUDE.md.global.ko)` held a 58-line rewrite while the worktree, now on `main`, showed the 274-line base version. `git reflog` carried the trail (`checkout: moving from docs/claude-md-global-diet to main`, then `pull --ff-only origin main`); the file itself carried none.

The rule: **when the branch does not match what the conversation assumed, read `git stash list` and `git reflog` before trusting the working tree.** A stash label naming a branch you are not on is the tell, and it is the only one.

> See-also: [[enterworktree-basefef-fresh]] (gotcha 1 — the same "work exists, but not where you are looking" shape, reached instead by branching from `origin/main` past unpushed local commits)

## Sources

1. **PR #89** (`ppt-yeong-style` completion-gate + document-structure round) — gotchas 1 and 2 hit back-to-back during worktree setup and post-merge cleanup; resolved via the content-diff-then-reset/discard pattern described above.
2. **PR #104** (`project-init` wiring skill) — gotcha 3, surfaced by a CodeRabbit CLI finding and confirmed by running the detector inside a real `git worktree add`: `initialized=false`, `commits=0`, and all four `git check-ignore` probes false. Fixed with `git rev-parse --is-inside-work-tree`.
3. **PR #193** (`voice-prompt` plugin) — gotcha 5, hit while running `post-merge` for that merge: cr-fix's state file sat in the `skipjack` worktree while the P0 guard required the main repo, and Step 1.5's own snippet printed `leftover-reviews: none` against a live deferred finding. Confirmed by running the snippet from both directories.
4. **Session 88102e17 (2026-07-10)** — gotcha 4: stacked PR #108 (base = #106's branch) auto-closed by GitHub when #106 squash-merged with `--delete-branch`; confirmed by `gh pr list` showing #108 CLOSED with its head branch intact.
5. **PR #195** (`CLAUDE.md.global` restructure) — gotcha 6, plus the gotcha-2 extensions: a prior `post-merge` run's Step 2 stash held the user's rewrite while the worktree sat on `main`; `git merge-tree --write-tree --name-only` named `AGENTS.md` as the sole conflict before the merge was attempted, and that was the outcome.
