# Post-merge procedure

Step-by-step detail for `SKILL.md`, keyed by its step numbers (1, 1.5, 2, 3, 3.5, 4, 4.5, 4.6, 4.7, 5, 5.1, 9, 9.5, 10, 11; the 5 → 9 gap is intentional, since the run record stores these numbers). The bright lines stay in `SKILL.md`; the Step 3.5 collector block and the Step 4.7 delete block live there too.

Every step works on the main repo: git calls run as `git -C "$MAIN_REPO"` and repo paths resolve under `$MAIN_REPO/`. Shell state does not persist across tool calls, so re-derive `MAIN_REPO=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")` in any fresh shell.

## 1. Identify PR

Detect worktree mode first. A linked worktree's git dir differs from the common git dir; the main checkout's does not.

```bash
MAIN_REPO=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
IN_WT=0; WT_PATH=""
if [ "$(git rev-parse --absolute-git-dir)" != "$(git rev-parse --path-format=absolute --git-common-dir)" ]; then
  IN_WT=1; WT_PATH=$(git rev-parse --show-toplevel)
  echo "post-merge: worktree mode (worktree $WT_PATH, main repo $MAIN_REPO)"
fi
```

- Use the PR number argument if given; else infer it from the conversation; else run `gh pr list --state merged --limit 5` and ask the user to pick.
- Run `gh pr view <PR_NUMBER> --json number,title,url,baseRefName,headRefName,body,state,files,mergeCommit` and verify `state` is `MERGED`. This is the authoritative merge signal. Keep `url`: Step 5's close comment needs the PR's own URL, because a bare `#<PR>` resolves in the issue's repository.
- Capture `MERGE_SHA=$(gh pr view <PR_NUMBER> --json mergeCommit --jq '.mergeCommit.oid')`, the run record's anchor and one of Step 5's ref sources.
- Take the merged file list from `gh pr diff <N> --name-only`, not from `MERGE_SHA`: a `--no-ff` merge commit shows an empty combined diff, and a rebase merge's SHA points only at the last replayed commit.

With `IN_WT=1`, carry review-loop state out of the worktree before anything else, because Step 11's command deletes it. Each copy keeps its prefix (`review-loop-<PR>-`, or `cr-fix-<PR>-` from before the skill was renamed), and Step 1.5 reads both:

```bash
if [ "$IN_WT" = 1 ]; then
  # Fail loud: Step 11's command deletes the worktree, so a silent failed copy loses the state.
  ARC="$MAIN_REPO/.claude/state/archive"
  mkdir -p "$ARC" || { echo "post-merge: cannot create $ARC" >&2; exit 1; }
  for p in review-loop cr-fix; do
    for f in "$WT_PATH/.claude/state/archive/$p-${PR_NUMBER}-"*.json; do
      [ -f "$f" ] || continue
      cp -p "$f" "$ARC/" || { echo "post-merge: copying $f failed" >&2; exit 1; }
    done
    live="$WT_PATH/.claude/state/$p-${PR_NUMBER}.json"
    if [ -f "$live" ]; then
      # $$ as in review-loop's own archive names: a same-second rerun keeps both copies.
      cp -p "$live" "$ARC/$p-${PR_NUMBER}-$(date +%Y%m%d-%H%M%S)-$$-wt.json" \
        || { echo "post-merge: copying $live failed" >&2; exit 1; }
    fi
  done
fi
```

Then open the run record: with `PR_NUMBER` and `MERGE_SHA` fixed, run the init block in `run-record.md` and `record_step 1 done`. That file also holds the recording contract every later step follows.

## 1.5. Surface unresolved review items

A merge can land while review-loop left findings it deferred, or after a loop that stopped on a cap or timeout. review-loop's exit persists `final_state` and `auto_judge_stats` and moves `.claude/state/review-loop-<PR>.json` to `.claude/state/archive/review-loop-<PR>-<ts>.json`, so the archive is the usual hit. The step is informational and never blocks cleanup.

1. Run the block in `leftover-reviews.md` ("Primary signal") verbatim: the live file first, then the latest archive, then the `cr-fix-` prefix.
2. Run the block in `leftover-reviews.md` ("Secondary signal") verbatim. Top-level review comments are a coarse proxy for open threads, not the gate.
3. Run the block in `leftover-reviews.md` ("Decide the checkpoint line") verbatim. It fires on a non-empty defer list or on a `final_state` in its case list. `user_declined` always carries defers, and `minor_floor` / `churn` count only through theirs.

- **Leftover present**: after the `leftover-reviews: <N> deferred (final_state=<X>)` line, render `$DEFERS` as a table (`Path:Line · Severity · Reason`) and add the open-thread count when `OPEN_THREADS > 0`. Say these were not auto-applied and point at `gh pr view <PR_NUMBER> --comments` or a follow-up.
- **None**: print `leftover-reviews: none` when no state file resolves, or it shows `defer == 0` with a non-trigger `final_state`.
- **Recurring leftover**: grep the older archives (`review-loop-*.json` and `cr-fix-*.json`, this PR excluded) for the same finding. Mark a repeat `recurring` in the table and point the user at `/retro` in the building session; do not write the rule here.

## 2. Check local changes

Run `git -C "$MAIN_REPO" status --porcelain`, since the main repo is what Step 3 switches.

- Untracked (`??`): ignore and proceed.
- Modified or staged (`M`/`A`/`D`): ask stash (`git -C "$MAIN_REPO" stash push -m "post-merge: temp save"`), discard (`git -C "$MAIN_REPO" restore --staged --worktree -- .`, tracked changes only, never `git clean`) or abort. After a stash, ask pop / apply / later at the end of the run.

## 3. Switch to base branch

```bash
# --prune drops tracking refs of branches already gone, so Step 4.7 does not list them.
git -C "$MAIN_REPO" fetch --prune origin
git -C "$MAIN_REPO" checkout <baseRefName>
git -C "$MAIN_REPO" pull origin <baseRefName>
```

## 3.5. Remove other merged worktrees

The collector (block in `SKILL.md` Step 3.5) looks at every linked worktree in `git worktree list`, wherever it lives, and checks against the freshly fetched `origin/<base>`. It is read-only and prints `{main_repo, worktrees[], remote_branches[]}`; with `--pr` it adds `issues[]` and `issue_sources` for Step 5, so keep the output. Each worktree entry carries `path`, `branch`, `pr`, `safe`, `reasons[]` and a `tmp` summary (path, bytes, mtime).

A failed collection (no script, no `jq`, a `git worktree list` error) skips this step with the error in the report; Step 5 reports the same error.

- **`safe: false`**: report the path and every reason and leave it. Reasons: an open PR, no merged PR, a failed `gh` lookup, dirty, locked, prunable, detached, or unique commits. The worktree this session runs in carries reason `current session`, and Step 11 prints its command.
- **`safe: true`**: read the `tmp` summary first, because `git worktree remove` deletes ignored `.tmp/` files with the worktree. Open what looks like research output (a council or research run, notes, a report) and propose to keep only that. Scratch output, logs and caches go with the worktree; nothing is kept by default.
- **One confirmation**: list each safe worktree with path, branch, PR and the `.tmp/` items proposed for keeping, and let the user pick. Remove nothing they did not pick.

For each picked worktree, move the kept items first, one `REL` at a time (`REL` starts with `.tmp/`, so it lands at the same layout under the main repo):

```bash
WT="<worktree path>"; REL="<.tmp/... item>"
DST="$MAIN_REPO/$REL"
# Never overwrite: an existing target gets a sibling named after the worktree.
[ -e "$DST" ] && DST="$DST-$(basename "$WT")"
if [ -e "$DST" ]; then
  echo "post-merge: $DST exists, $WT/$REL left in place" >&2
else
  mkdir -p "$(dirname "$DST")" && mv "$WT/$REL" "$DST" || echo "post-merge: moving $WT/$REL failed" >&2
fi
```

If any kept item did not move, keep that worktree and report it. Otherwise remove it from the main repo, without `--force`:

```bash
WT="<worktree path>"; BR="<branch>"
git -C "$MAIN_REPO" worktree remove "$WT" && git -C "$MAIN_REPO" branch -d "$BR"
```

A refusing `worktree remove` (a file changed since the collection) leaves the worktree: report it, do not force. A refusing `branch -d` is handled as in Step 4. This step is recorded under Step 3.

## 4. Clean up local branch

- `IN_WT=1`: skip the deletion, since the worktree still has the branch checked out; Step 11 prints it. The content check still applies.
- Check `git -C "$MAIN_REPO" branch --list "$headRefName"`. When unsure the content landed, diff content: `git -C "$MAIN_REPO" diff "origin/$baseRefName..$headRefName" -- <paths>` (empty means fully landed, also after a squash).
- If the branch exists, confirm, then `git -C "$MAIN_REPO" branch -d "$headRefName"`. After a squash merge expect `warning: not yet merged to HEAD`: `-d` finds the merge through `origin/<branch>` and succeeds. Never escalate to `-D` or open a "missing commits" PR.
- If another worktree still has the branch checked out, Step 3.5 removed it or reported why not; report its path and leave the branch.

## 4.5. Prune ephemeral artifacts merged by this PR (optional)

Some PRs merge throwaway files (one-off scripts, scratch output, root clutter). These are tracked files on the base branch, so removing one is a real repo change (`git rm` + commit). Skip silently when the PR added no files, nothing survives filtering, or the user skips all.

1. List PR-added files: `ADDED=$(gh api --paginate "repos/{owner}/{repo}/pulls/<PR_NUMBER>/files" --jq '.[] | select(.status=="added") | .filename')` (`{owner}/{repo}` is gh's current-repo placeholder).
2. Filter with the heuristics, hard exclusions and `git grep` reference check in `ephemeral-heuristics.md`. A file another tracked file references is never a candidate.
3. Read each candidate's head and drop anything load-bearing, then ask once (multi-select) with path and reason ("named scratch_*", "root-level analysis script").
4. For each confirmed file run `git -C "$MAIN_REPO" rm -- "$path"`, which stages the removal for Step 10. Do not add it to `RUN_TOUCHED`.

## 4.6. Surface deprecated-marker cleanup candidates (optional)

A merged PR can make deprecated code removable, or land a deprecation pointer whose target is gone. Surface candidates only, with the same confirm-only, `git rm` and Step 10 discipline as Step 4.5. Skip silently when no marker is found or the user skips all.

1. Scan the current base-branch content of the merged files (`gh pr diff <PR_NUMBER> --name-only`): `git -C "$MAIN_REPO" grep -nE 'deprecated|DEPRECATED' -- <merged-files>` covers `@deprecated`, `Deprecated:`, deprecated aliases and pointer stubs.
2. A marker the PR added usually means "deprecated but kept on purpose", which is not a candidate. Propose removal only when the target is gone, the grace window is documented as elapsed, or the PR body says it is safe; when unsure, show it as review-only.
3. Read the surrounding lines and `git grep` the symbol; a live reference drops it from the set.
4. Ask once (multi-select) with path, marker and reason.
5. Remove a confirmed block with `Edit` on the `$MAIN_REPO/` path (never the worktree copy) and add that file to `RUN_TOUCHED`, or `git -C "$MAIN_REPO" rm` a whole stub file (already staged, not in `RUN_TOUCHED`). Report each.

## 4.7. Delete merged remote branches

Step 3.5's collector checked every `origin/*` branch: each `remote_branches[]` entry carries `name`, `head` (the fetched tip), `pr` (the merged PR, else an open one, else any, else null), `safe` and `reasons[]`. The step runs after Step 4, because `git branch -d` finds a squash merge through `origin/<branch>`, which this step deletes.

If Step 3.5 removed a worktree, its branch was still checked out when the collector ran: run the Step 3.5 block again without `--pr` for fresh facts. A failed collection, or `remote_branches: null` with a `remote_error`, skips this step with the error in the report.

- **`safe: false`**: report the name and every reason and leave it. Reasons: the default branch, checked out in a worktree (this PR's own branch when `IN_WT=1`), an open PR, the base of an open PR, a PR closed without merge, unique commits, no PR with a tip not in `origin/<default>`, or a failed `gh` lookup.
- **`safe: true`**: a merged PR whose branch holds nothing its merge commit lacks, or no PR and a tip already in `origin/<default>`.
- **One confirmation**: list each safe branch with its PR number and state, or "no PR, already in `origin/<default>`", and let the user pick. Delete nothing they did not pick.

For each picked branch, run the `SKILL.md` Step 4.7 block with `HEAD_SHA` set to its `head`. The lease deletes only while the remote ref still equals that tip (`git push --help`, `--force-with-lease=<refname>:<expect>`); a refused delete is reported and the next branch goes on. This step is recorded under Step 4.

## 5. Close the issues the merge left open (always runs)

A merge can leave `Closes #N` unacted with nothing on the PR page saying so. GitHub ignores closing keywords on a PR into a non-default branch, and a repository can turn off "Auto-close issues with merged linked pull requests". A bare `#N` mention and a spec whose last ticket closed are also left open.

The collector (`scripts/collect-cleanup.sh --pr`, rules in its header) scanned the PR body, every PR commit message, the merge commit's message and `closingIssuesReferences` for `#N`, `OWNER/REPO#N` and issue URLs. It dropped this PR's number and every ref that resolves to a pull request, read at most 25 refs on the PR's host, and read each issue's own `state`. The link set only supplies candidates, since `closingIssuesReferences` also lists linked issues that are still open.

Each `issues[]` entry has `ref` (as written), `via`, `state`, `title` and `url`.

- **`via`**: `keyword` (one of GitHub's nine closing keywords), `closingRef` (linked on the PR), `bare` (a mention with no keyword), or `spec-parent`, the open sub-issue parent of issues that are all in this list; its `after` names those children.
- **`state: null` with a `reason`**: unresolved (another host, an invalid ref, past the cap, a failed read or parent lookup). Report each one and never close it.
- **`issue_sources`**: `commits: null` means the commit scan failed, and `commits_truncated: true` means the 250-commit ceiling cut it; say so instead of calling the sweep complete. `merge_commit` is `read`, `none` or `failed`. `issues: null` with `issue_sources.error` means nothing was read.

States are read before the confirmation, so the user approves knowing which issues are open; every read goes to the PR's own host over a repository the user can read.

**Judge each `OPEN` entry before asking.** Read the issue (`gh issue view <url> --comments`) against the diff (`gh pr diff <PR_NUMBER>`) and propose a close only when the diff does what the issue asks. Leave it open with the reason when the PR does part of it, only mentions it, or the issue stays open on purpose (a human check, a follow-up). Propose a `spec-parent` only together with every child in its `after`.

Ask once for all proposed closes, each with host, repo, number, title, `via` and the evidence (the issue line and the diff part that match). List the unresolved refs and the ones left open below, with reasons.

Close each confirmed issue by its `url`: `gh issue close <url> --comment "Resolved by <PR url>"`. The `url` carries the host the read used, and the PR's `url` from Step 1 resolves the same in any repository. Close a `spec-parent` last, only if every child in its `after` closed.

Step 5.1 (optional) updates the GitHub Project status:

- Run `gh project list --owner <owner> --format json`; with none, skip silently. Otherwise `gh project item-list` → `gh project field-list` → `gh project item-edit` sets Status to "Done"; skip an issue not in the project.
- Reading needs `read:project` and `item-edit` needs `project`. A permission error on the edit, a missing Project or a token without either scope skips 5.1 only, never Step 5. Report which condition fired; the run record has no 5.1 entry.

## 9 and 9.5. README, repo About, CHANGELOG

- **README (9)**: if the PR changed features, commands, install, usage or dependencies and a README exists, run `/docs:readme`, show the proposal and add the README to `RUN_TOUCHED`.
- **About (9)**: always compare `gh repo view --json description --jq .description` with the README's opening claim and this PR. On drift, propose a one-liner, run `gh repo edit --description "<approved>"` only on approval, then print `repo-about: in sync` or `repo-about: updated`.
- **CHANGELOG (9.5)**: if a root `CHANGELOG.md` exists and the merge is user-visible (feature, fix, breaking change), run `/docs:changelog` and add the file to `RUN_TOUCHED`; otherwise skip silently.

## 10. Commit changes (optional)

Commit when this run modified any tracked file: README (9), `CHANGELOG.md` (9.5), a Step 4.6 `Edit`, or a Step 4.5 / 4.6 `git rm`. Confirm, then commit with Conventional Commits. A prune-only run still commits, or the staged deletion stays uncommitted.

Stage only the exact paths this run wrote, collected through Steps 4.6-9.5 as `RUN_TOUCHED`, and never `git add` a directory (a pre-existing untracked draft would be swept in):

```bash
# RUN_TOUCHED = the exact paths this run wrote, gathered across Steps 4.6-9.5.
# Existence-checked + added one at a time: `git add a b c` is atomic, so one
# stale path would abort the whole add (and `|| true` would hide it), leaving
# real changes unstaged.
for p in "${RUN_TOUCHED[@]}"; do
  # RUN_TOUCHED holds $MAIN_REPO/... paths; -C keeps the index the main repo's.
  [ -e "$p" ] && git -C "$MAIN_REPO" add -- "$p"
done
```

Skip the commit only when `git -C "$MAIN_REPO" diff --cached --quiet` reports nothing staged; `git status --porcelain` would count untracked files and attempt an empty commit. Then run the finalize block in `run-record.md`. The record stays under gitignored `.claude/state/` and never goes into `RUN_TOUCHED`.

## 11. Print the worktree cleanup command

- With `IN_WT=1`, print the `SKILL.md` Step 11 line as the last line of the run and do not run it.
- `git worktree remove` refuses a worktree with modified or untracked files, which is the check to keep. It deletes ignored files such as `.tmp/`, which Step 3.5 moves out first.
- `git branch -d` behaves as in Step 4.
