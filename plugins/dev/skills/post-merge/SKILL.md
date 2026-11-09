---
name: post-merge
description: "Clean up after a PR merges: surface leftover review findings, switch to base, remove other worktrees that pass the safety filter (merged PR, clean, unlocked, no unique commits) after one confirmation, delete the merged branch and the remote branches that pass the same filter, close the issues the merge left open, sync the GitHub Project status, check the repo About line, commit. Use on /dev:post-merge, 'post-merge cleanup', '머지 후 정리', or right after a PR merges. Cleanup only: lessons belong to /retro in the building session, README and CHANGELOG edits to docs:readme and docs:changelog. gh pr view is the merge signal, never git SHAs; inside a worktree it works on the main repo and prints the worktree removal command last. Not for an open PR's review feedback (/dev:review-loop)."
allowed-tools: Read Write Edit Bash Glob Grep AskUserQuestion
---

# Post-Merge

Local cleanup after a PR is merged, in 15 numbered steps: leftover-review surface → branch and worktree cleanup → issue close → repo About check → commit. It records no lessons; those go to `/retro` in the session that built the change. Follow the project's `CLAUDE.md` and `AGENTS.md` throughout.

Read `references/procedure.md` before Step 1. It holds every step's detail and blocks, keyed by the step numbers below.

## Bright lines

- **Main repo, from anywhere**: every step works on the main repo (`git -C "$MAIN_REPO"`, paths under `$MAIN_REPO/`), whether the run starts there or in the PR's worktree (`IN_WT=1`). post-merge never removes the worktree it runs in; Step 11 prints the command instead, because on Windows a worktree removed from inside itself is only half deleted.
- **`gh` is the merge signal**: Step 1's `gh pr view ... state=MERGED` decides "did this land", and Step 3.5 asks gh the same for every other worktree's branch. No step decides "merged" by comparing git SHAs.
- **SHAs prove "nothing unique", never "merged"**: `git log <base>..<branch>`, `git cherry` and `git rev-list --left-right` read as unmerged after a squash or rebase merge. `git cherry` runs only after gh said merged, and what it still lists is settled by content against the merge commit.
- **Confirm before every irreversible action**: `git rm`, `git worktree remove`, `git push origin --delete`, `gh issue close` and `gh repo edit` each run only on what the user picked. Ask with `AskUserQuestion` on Claude Code or `request_user_input` on Codex; when neither is available, ask one short blocking question before the irreversible action.
- **Never force**: no `git branch -D`, no `git worktree remove --force`, no `git clean`, no unconditional remote delete. A refused removal is reported and left.
- **Stage only what this run wrote**: Step 10 adds the exact `RUN_TOUCHED` paths one at a time and never a directory; `git rm` deletions are already staged.
- **Leftover reviews never block**: Step 1.5 always prints exactly one checkpoint line, `leftover-reviews: <N> deferred (final_state=<X>)` or `leftover-reviews: none`.
- **Run record**: Step 1 opens `.claude/state/post-merge-<PR>.json`, every top-level step appends its outcome, and Step 10 finalizes it (`references/run-record.md`).

Codex does not load the `/docs:readme` and `/docs:changelog` commands (Steps 9, 9.5): do the same edit by hand from the `docs:doc-guides` skill and say so. Every other step runs the same on both runtimes.

## Steps

The argument is an optional PR number; without one, infer it from the conversation or pick from `gh pr list --state merged --limit 5`.

- **1. Identify PR**: detect worktree mode, confirm `MERGED`, capture `MERGE_SHA`, carry worktree review-loop state to the main archive, open the run record.
- **1.5. Leftover reviews**: run the three `references/leftover-reviews.md` blocks verbatim and print the checkpoint line.
- **2. Local changes**: stash, discard (tracked only) or abort on modified files; untracked files stay.
- **3. Switch to base**: `fetch --prune`, checkout and pull `<baseRefName>`.
- **3.5. Other merged worktrees**: run the collector below, move kept `.tmp/` items, remove the picked worktrees.
- **4. Local branch**: `git branch -d` the merged branch (skipped with `IN_WT=1`).
- **4.5 / 4.6. Ephemeral files and deprecated markers** (optional): PR-added throwaways (`references/ephemeral-heuristics.md`) and dead deprecation markers, surfaced and removed only on confirmation.
- **4.7. Remote branches**: delete the picked `remote_branches[]` with the lease block below.
- **5. Issues left open** (always runs): judge each open ref against the diff, confirm once, close by `url`. **5.1** syncs the GitHub Project status when one exists.
- **9 / 9.5. README, About, CHANGELOG**: `/docs:readme` and `/docs:changelog` when warranted; print `repo-about: in sync` or `repo-about: updated`.
- **10. Commit**: commit `RUN_TOUCHED` plus staged deletions when `git diff --cached --quiet` finds something, then finalize the run record.
- **11. Worktree command** (`IN_WT=1` only): print the line below last and do not run it.

### 3.5. Collect cleanup candidates

The collector is read-only. With `--pr` it also lists the issue refs Step 5 judges, so keep its output.

```bash
# Codex exports no CLAUDE_PLUGIN_ROOT: fall back to the cached plugin dir, ranked
# on the version basename (not the whole path) so the marketplace dir cannot
# outrank the version. `|| true`: an empty cache is normal on Claude-only hosts.
CACHE_ROOT="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
if sort -V </dev/null >/dev/null 2>&1; then
  CODEX_CAND=$(ls -1d "$CACHE_ROOT"/*/dev/* 2>/dev/null \
    | awk -F/ '{print $NF "\t" $(0)}' | sort -V | tail -1 | cut -f2- || true)
else
  CODEX_CAND=$(ls -1d "$CACHE_ROOT"/*/dev/* 2>/dev/null \
    | awk -F/ '{print $NF "\t" $(0)}' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1 | cut -f2- || true)
fi
# Validate the script the next line runs, not just a directory.
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "$CLAUDE_PLUGIN_ROOT/skills/post-merge/scripts/collect-cleanup.sh" ]; then
  SKILL_DIR="$CLAUDE_PLUGIN_ROOT/skills/post-merge"
elif [ -f "plugins/dev/skills/post-merge/scripts/collect-cleanup.sh" ]; then
  SKILL_DIR="plugins/dev/skills/post-merge"
elif [ -n "$CODEX_CAND" ] && [ -f "$CODEX_CAND/skills/post-merge/scripts/collect-cleanup.sh" ]; then
  SKILL_DIR="$CODEX_CAND/skills/post-merge"
else
  echo "post-merge: collect-cleanup.sh not found under CLAUDE_PLUGIN_ROOT, the source tree, or the Codex plugin cache" >&2
  SKILL_DIR=""
fi
[ -n "$SKILL_DIR" ] && bash "$SKILL_DIR/scripts/collect-cleanup.sh" --pr "<PR_NUMBER>"
```

### 4.7. Delete merged remote branches

Delete only `safe: true` entries the user picked, one at a time, with `HEAD_SHA` set to the entry's `head` from the collector:

```bash
BR="<name>"; HEAD_SHA="<head>"
# The lease makes the delete conditional on the remote: it deletes origin/$BR only while
# it still points at the checked tip, so a push since the collection is never lost.
git -C "$MAIN_REPO" push --force-with-lease="refs/heads/$BR:$HEAD_SHA" origin --delete "$BR" \
  || echo "post-merge: origin/$BR not deleted (moved since the check, protected, or no permission): left alone" >&2
```

### 11. Print the worktree cleanup command

```bash
# %q: a quote, `$` or space in a path or branch name cannot change the pasted command.
[ "$IN_WT" = 1 ] && printf 'cd %q && git worktree remove %q && git branch -d %q\n' \
  "$MAIN_REPO" "$WT_PATH" "$headRefName"
```

## Done

- The run record is finalized (`status: completed`), and every skipped step carries the reason that fired.
- The report lists what was removed and closed, what was left with its reasons, and any collection or read error.
- With `IN_WT=1`, the Step 11 line is the last line printed.
