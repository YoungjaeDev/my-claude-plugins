# Merge Conflicts (Step 5a)

A PR whose base moved on can stop merging while cr-fix is still looping. GitHub then reports `mergeable: CONFLICTING`, the reviewers keep reviewing a diff that cannot land, and `--auto-merge` never fires. Step 5a resolves the conflict inside the loop instead of stopping.

Adapted from `mattpocock/skills` at `74ca5fe`, `skills/engineering/resolving-merge-conflicts/SKILL.md`.

## Trigger

```bash
MERGEABLE=$(gh pr view "$PR_NUM" --json mergeable --jq '.mergeable')
```

- `CONFLICTING`: run the procedure below.
- `MERGEABLE`: nothing to do.
- `UNKNOWN`: GitHub has not computed it yet (common right after a push). Proceed; the next iteration asks again.

## Procedure

1. **See the current state.** `git fetch origin "$BASE"`, then `git merge "origin/$BASE"`. Merge, not rebase: the PR branch is already pushed and a rebase would force-push over the review history. List the conflicting files with `git diff --name-only --diff-filter=U`.
2. **Find each side's intent.** For every conflicting hunk, read why each side changed it: `git log --merge -p -- <path>`, the commit messages, the PR or issue each commit came from. The PR's own intent is in its body and `Closes #N` issue.
3. **Resolve hunk by hunk.** Keep both intents where they are compatible. Where they are not, keep the one that matches this PR's stated goal and note the trade-off in the merge commit message. Do not invent behavior neither side had. Never run `git merge --abort`: an abandoned merge leaves the PR exactly as unmergeable as before.
4. **Re-run the checks.** Run the same build, test and lint commands as Step 11 (from `AGENTS.md`, Step 3) and fix what the merge broke. A failure sets `verification_blocking=true` exactly as in Step 11.
5. **Finish.** `git add` the resolved files, `git commit --no-edit` (append the trade-off notes, if any), and `git push`. The push triggers re-review like any Step 12 push, and the Step 2 review-request rule applies to it too.

The merge commit is the iteration's one commit, not a review-response commit: it does not count toward `applied_this_cycle`, and the loop `continue`s to the next iteration, whose Step 5 takes the new `HEAD` as `CUR_SHA`.
