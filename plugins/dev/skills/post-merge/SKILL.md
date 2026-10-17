---
name: post-merge
description: "Clean up after a PR merges: surface leftover review findings, switch to base, remove other worktrees that pass the safety filter (merged PR, clean, unlocked, no unique commits) after one confirmation, delete the merged branch, close the issues the merge left open, sync the GitHub Project status, check the repo About line, commit. Use on /dev:post-merge, 'post-merge cleanup', '머지 후 정리', or right after a PR merges. Cleanup only: lessons belong to /retro in the building session, README and CHANGELOG edits to docs:readme and docs:changelog. gh pr view is the merge signal, never git SHAs; inside a worktree it works on the main repo and prints the worktree removal command last. Not for an open PR's review feedback (/dev:review-loop)."
allowed-tools: Read Write Edit Bash Glob Grep AskUserQuestion
---

# Post-Merge

Local cleanup after a PR is merged. One run takes a merged PR from leftover-review surface → branch cleanup → issue close → repo About check → commit. It records no lessons: those go to `/retro` in the session that built the change. Follow project guidelines in `@CLAUDE.md` and `@AGENTS.md` throughout.

## Guidelines

- **Worktree mode.** post-merge runs from the main repo or from the PR's worktree. Every step works on the main repo: git calls run as `git -C "$MAIN_REPO"` and repo paths resolve under `$MAIN_REPO/`, in the steps below and in `references/`. `MAIN_REPO=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")` gives the same answer from either place, so re-derive it in any fresh shell. Inside a worktree (`IN_WT=1`) Step 1 copies the worktree's review-loop state into the main repo's archive, Step 4 leaves the branch alone (the worktree still has it checked out), and Step 11 prints the one command that removes the worktree and the branch. post-merge never removes the worktree itself: on Windows a worktree removed from inside itself is only half deleted.
- **Non-default base.** For a PR into a branch CodeRabbit does not auto-review, review-loop on the `auto` / `pr-bot` source posts `@coderabbitai review` itself, unless the repo set `reviews.auto_review.enabled: false` (`plugins/dev/skills/review-loop/SKILL.md` Step 2); Step 3 below checks out that base like any other. It also changes what the merge did to the linked issues: GitHub honours a closing keyword only on a merge into the default branch, so a non-default base leaves every one of them open with no signal on the PR page — Step 5 is what catches that, and it runs on every PR.
- **`gh` is the authoritative merge signal.** Step 1's `gh pr view ... state=MERGED` is the single source of truth for "did this land", and Step 3.5 asks gh the same question (`gh pr list --head <branch>`) for every other worktree's branch. No step decides "merged" by comparing git SHAs.
- **SHA comparison proves "nothing unique", never "merged".** `git log <base>..<branch>`, `git cherry` and `git rev-list --left-right` read as unmerged after a squash merge (base gets one new SHA) or a rebase merge (branch SHAs rewritten), so none of them answers "did it land". Step 3.5 runs `git cherry` only after gh has said merged, to show the branch holds no commit the PR did not deliver, and settles whatever cherry still lists by content: the branch's files against the PR's merge commit. If unsure content landed, diff content, not SHAs (Step 4).
- **Leftover-review surface (Step 1.5) is informational.** The run reads review-loop's state file (`.claude/state/review-loop-<PR>.json`, else the latest `.claude/state/archive/` copy, else the same under the pre-rename `cr-fix-` prefix) to surface autonomously-deferred or cap/timeout-stopped findings after the merge, but never blocks cleanup. It always prints one `leftover-reviews: …` checkpoint line so a skip can't pass unnoticed. `gh` / `jq` / `Read` only → identical under Claude and Codex.
- **Codex partial-execution.** `/docs:readme` and `/docs:changelog` (Steps 9, 9.5) are commands, which Codex does not load; under Codex do the same edit by hand from the `docs:doc-guides` skill and note it. Every other step runs identically on both runtimes.
- **Interactive input is capability-aware.** Every prompt and confirmation below, each `AskUserQuestion` mention included, is a gate rather than a tool name: `AskUserQuestion` under Claude Code, `request_user_input` under Codex where exposed, otherwise one concise blocking question asked before the irreversible action (`git rm`, `git worktree remove`, `gh repo edit`). Full policy: `AGENTS.md` → "Cross-runtime interactive input policy".
- **Run record.** Step 1 opens `.claude/state/post-merge-<PR>.json` and every step appends its outcome, so a silent skip becomes visible; Step 10 finalizes it. Mechanism, per-step skip reasons, and the finalize block: `references/run-record.md`.

## Arguments

- PR number (optional): if not provided, infer from conversation context, else `gh pr list --state merged --limit 5` and prompt the user to select.

## Workflow

### 1. Identify PR

**Worktree detection**: run first. A linked worktree's git dir differs from the common git dir; the main checkout's does not.

```bash
MAIN_REPO=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
IN_WT=0; WT_PATH=""
if [ "$(git rev-parse --absolute-git-dir)" != "$(git rev-parse --path-format=absolute --git-common-dir)" ]; then
  IN_WT=1; WT_PATH=$(git rev-parse --show-toplevel)
  echo "post-merge: worktree mode (worktree $WT_PATH, main repo $MAIN_REPO)"
fi
```

- Use the PR number argument if given; else infer from context; else `gh pr list --state merged --limit 5` and prompt.
- `gh pr view <PR_NUMBER> --json number,title,url,baseRefName,headRefName,body,state,files,mergeCommit`. `url` is what Step 5 puts in a close comment; a bare `#<PR>` is resolved in the *issue's* repository, so the comment must carry the PR's own URL rather than reconstruct one.
- Verify `state` is `MERGED`. This result is the **authoritative merge signal** (see Guidelines); no later SHA comparison.
- Capture `MERGE_SHA=$(gh pr view <PR_NUMBER> --json mergeCommit --jq '.mergeCommit.oid')`: this is **this PR's** merge commit, the run record's anchor and one of Step 5's ref sources. Take the merged **file list** from `gh pr diff <N> --name-only` (PR-scoped, merge-method-agnostic, uncapped), not from `MERGE_SHA` (a `--no-ff` merge commit shows an empty combined diff; a multi-commit rebase merge's SHA only points at the last replayed commit).

**Carry review-loop state out of the worktree** (`IN_WT=1` only). review-loop wrote its state under the worktree, which Step 11's command deletes; copy it to the main repo's archive first so Step 1.5 and later runs still find it. Each copy keeps its own prefix, `review-loop-<PR>-` or the pre-rename `cr-fix-<PR>-`, both of which Step 1.5 reads:

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

**Open the run record.** With `PR_NUMBER` + `MERGE_SHA` fixed, run the init block in `references/run-record.md` and `record_step 1 done`. That file also holds the per-step recording contract every later step follows.

### 1.5. Surface unresolved review items (informational)

A merge can land while `review-loop` still left findings unresolved: items it autonomously **deferred** (real + high-severity + too invasive for autopilot), or a loop that exited on a cap/timeout rather than converging clean. That signal sits in `review-loop`'s state file and nobody reads it. This step surfaces it **once, right after the merge is confirmed**. It is **informational: it never blocks cleanup**; it ALWAYS prints exactly one terminal status line so a skip can't pass unnoticed.

**Primary signal: the review-loop state file.** review-loop archives its live state on exit (`emit-final-json.sh` persists the final `final_state` + `auto_judge_stats` into the file, then moves `.claude/state/review-loop-<PR>.json` → `.claude/state/archive/review-loop-<PR>-<ts>.json`), so the archived copy is the usual hit and is self-describing; check the live path first, then the latest archive:

Run the block in `references/leftover-reviews.md` ("Primary signal") verbatim.

**Secondary signal (advisory): open CR review threads on the merged PR.** Top-level (non-reply) review comments are a coarse proxy for unresolved threads; it is NOT the primary gate:

Run the block in `references/leftover-reviews.md` ("Secondary signal") verbatim.

**Decide the checkpoint line.** The primary trigger is a non-empty defer list OR a `final_state` that means the loop stopped with work potentially outstanding (`iteration_cap`, `timeout`, `cli_failed`, `rate_limited`, `reviewers_unavailable`, `codex_failed`). `user_declined` always carries `defer > 0`, so the defer list catches it; `minor_floor` and `churn` reach it only through their defers (late Codex P2s included), so neither is a trigger on its own:

Run the block in `references/leftover-reviews.md` ("Decide the checkpoint line") verbatim.

- **Leftover present**: after the `leftover-reviews: <N> deferred (final_state=<X>)` line, render the `$DEFERS` items as a table (`Path:Line · Severity · Reason`), and append the open-thread count when `OPEN_THREADS > 0`. Tell the user these were **not** auto-applied: review them on the PR page (`gh pr view <PR_NUMBER> --comments`) or in a follow-up; do not silently drop them.
- **None**: print `leftover-reviews: none` when no review-loop state file resolves, or it shows `defer == 0` with a non-trigger `final_state`.
- **Recurring leftover**: before printing, grep the older archives (`.claude/state/archive/review-loop-*.json` and the pre-rename `cr-fix-*.json`, excluding this PR) for the same finding. A leftover that surfaces a second time is a standing rule, not an incident — mark it `recurring` in the table and point the user at `/retro` in the building session, which turns a repeated mistake into an automated check. Do not write the rule here.

### 2. Check local changes

`git -C "$MAIN_REPO" status --porcelain` (the main repo is what Step 3 switches):
- Untracked (`??`): ignore, proceed.
- Modified/staged (`M`/`A`/`D`); prompt via `AskUserQuestion`: **stash** (`git -C "$MAIN_REPO" stash push -m "post-merge: temp save"`) / **discard** (`git -C "$MAIN_REPO" restore --staged --worktree -- .`, reverts tracked changes only; never `git clean`, so pre-existing untracked files/drafts are preserved per the rule above) / **abort**.
- If stashed, prompt at the end of the run for **pop** / **apply** / **later**.

### 3. Switch to base branch

```bash
git -C "$MAIN_REPO" fetch origin
git -C "$MAIN_REPO" checkout <baseRefName>
git -C "$MAIN_REPO" pull origin <baseRefName>
```

### 3.5. Remove other merged worktrees

Looks at every linked worktree in `git worktree list`, wherever it lives (`.claude/worktrees/`, a sibling directory, another workspace), not only this PR's. Runs after Step 3, because it checks against the freshly fetched `origin/<base>`. The collector is read-only: it prints `{main_repo, worktrees[]}`, and each entry carries `path`, `branch`, `pr`, `safe`, `reasons[]` and a `tmp` summary of the worktree's `.tmp/` files (path, bytes, mtime). With `--pr <PR_NUMBER>` the same output also carries `issues[]` and `issue_sources`, which Step 5 uses; keep the output for it.

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

A failed collection (no script, no `jq`, a `git worktree list` error) skips this step with the error in the report; it does not stop the run, and Step 5 reports the same error.

- **`safe: false`**: report the path and every reason, and leave it. The reasons are an open PR, no merged PR, a failed `gh` lookup, dirty, locked, prunable, detached, or unique commits (cherry lists commits whose content the merge commit does not have). A worktree with no upstream and its own commits lands here, never in the removal list. The worktree this session runs in is listed with reason `current session`: Step 11 prints its command.
- **`safe: true`**: read the `tmp` summary first. `git worktree remove` treats ignored files as clean and deletes them with the worktree, so `.tmp/` material is gone unless it moves first. Open the files that look like research output (a council or research run directory, notes, a report or a findings file) and propose to keep only those worth having later. Scratch output, logs, caches and anything that can be fetched again stay behind and go with the worktree. Nothing is kept by default.
- **One confirmation** through the interactive-input gate: list each safe worktree with its path, branch, PR and the `.tmp/` items you propose to keep, and let the user pick which to remove. Remove nothing they did not pick.

For each picked worktree, move the kept items first, one `REL` at a time (`REL` is the item's path under the worktree, starting with `.tmp/`, so it lands at the same layout under the main repo's `.tmp/`):

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

If any kept item of a worktree did not move, do not remove that worktree; report it. Then remove it from the main repo, without `--force`:

```bash
WT="<worktree path>"; BR="<branch>"
git -C "$MAIN_REPO" worktree remove "$WT" && git -C "$MAIN_REPO" branch -d "$BR"
```

`worktree remove` refusing (a file changed since the collection) leaves the worktree: report it, do not force. `branch -d` refusing is handled as in Step 4: report, never `-D`. This step belongs to Step 3's run-record entry.

### 4. Clean up local branch

- `IN_WT=1`: skip the deletion (the worktree still has the branch checked out, so `git branch -d` would refuse); Step 11 prints it. The content check below still applies.
- `git -C "$MAIN_REPO" branch --list "$headRefName"`.
- **No SHA-level merge check** (see Guidelines). If unsure content landed, diff content: `git -C "$MAIN_REPO" diff "origin/$baseRefName..$headRefName" -- <paths>` (empty = fully landed; safe for squash).
- If the branch exists, confirm deletion, then `git -C "$MAIN_REPO" branch -d "$headRefName"`.
  - For squash merges expect `warning: not yet merged to HEAD`, which is normal; `-d` detects the merge via `origin/<branch>` tracking and still succeeds. Do NOT escalate to `-D`, do NOT treat as data loss, do NOT open a "missing commits" PR.
- If another worktree (not this one) still has the branch checked out, Step 3.5 either removed it or reported why not; report its path and leave the branch.

### 4.5. Prune ephemeral artifacts merged by this PR (optional)

Some PRs merge throwaway files (one-off analysis scripts, scratch/debug output,
root clutter) useful during the work but not meant to live in the repo. After the
merge these are **tracked, committed** files on the base branch, so removing one is
a real repo change (`git rm` + commit), not local-junk cleanup. Surface only files
**added by this PR** and remove only what the user confirms; never auto-delete.

Skip silently when: the PR added no files, no candidate survives filtering, or the
user selects skip-all.

1. List PR-added files (status `added`, paginated). `{owner}/{repo}` is gh's
   current-repo placeholder: no need to set `$OWNER`/`$REPO`; `<PR_NUMBER>` is the
   merged PR from Step 1:
   `ADDED=$(gh api --paginate "repos/{owner}/{repo}/pulls/<PR_NUMBER>/files" --jq '.[] | select(.status=="added") | .filename')`
2. Filter to candidates via the heuristics + hard exclusions + the `git grep`
   reference check in `references/ephemeral-heuristics.md`. A file imported or
   referenced by any other tracked file is never a candidate.
3. Gate via `AskUserQuestion` (multi-select): each candidate with its path + reason
   ("named scratch_*", "root-level analysis script", ...). Options: pick files to
   remove / skip all. Read each candidate's head first; if it looks load-bearing,
   drop it before prompting.
4. For each confirmed file: `git -C "$MAIN_REPO" rm -- "$path"` (stages the removal immediately in the main repo's index, which Step 10 commits).
   Report each. Step 10's staged-diff gate then commits the deletion. Do NOT add
   removed paths to `RUN_TOUCHED` (Step 10's `[ -e "$p" ]` add-loop cannot stage a
   deletion; `git rm` already staged it).

Full heuristics, confidence tiers, hard exclusions, and the Step 10 staging
interaction: `references/ephemeral-heuristics.md`.

### 4.6. Surface deprecated-marker cleanup candidates (optional)

A merged PR sometimes makes previously-deprecated code removable, or lands a
deprecation pointer whose target is already gone. Scan what this PR touched for
deprecation markers and **surface** removal candidates; never auto-delete, and
never escalate to `-D`. Same confirm-only / `git rm` / Step 10 staged-diff
discipline as Step 4.5.

Skip silently when: no marker is found, or the user selects skip-all.

1. Scan the merged file list (`gh pr diff <PR_NUMBER> --name-only`) for markers
   in the **current base-branch content** (not the diff): `@deprecated`,
   `DEPRECATED`, `deprecated alias`, `Deprecated:`, doc-only "deprecated pointer"
   stubs. `git -C "$MAIN_REPO" grep -nE 'deprecated|DEPRECATED' -- <merged-files>` is enough.
2. **Distinguish intent before surfacing**: a marker the PR *added* usually means
   "deprecated but kept on purpose" (a grace-period alias); that is NOT a removal
   candidate. Only surface a marker as removable when its target is already gone,
   its grace window is documented as elapsed, or the PR body explicitly says it is
   now safe to drop. When unsure, surface it as **review-only** (show, don't
   stage).
3. Read each candidate's surrounding lines; if other tracked files still reference
   the deprecated symbol (`git grep` the name), drop it from the removal set:
   removing it would break a live caller.
4. Gate via `AskUserQuestion` (multi-select): each candidate with path + marker +
   reason. Options: pick items to clean up / skip all.
5. For each confirmed item: remove the deprecated block via `Edit` (in-file) or
   `git -C "$MAIN_REPO" rm` (whole stub file); `Edit` the `$MAIN_REPO/` path, never the worktree copy. `Edit`ed files go into `RUN_TOUCHED` (Step 10
   stages them); `git rm` already stages the deletion. Do NOT add it to
   `RUN_TOUCHED`. Report each.

### 5. Close the issues the merge left open (always runs)

Not optional and not conditional on a GitHub Project existing — 5.1 below is the optional part.

A merge does not always close what the PR body says it closes, and every way it fails is silent: the body still reads `Closes #N` and nothing on the PR page says otherwise. Two causes, both common:

- **Non-default base.** GitHub interprets a closing keyword only when the PR targets the default branch. "If the pull request targets any other branch, then these keywords are ignored, no links are created, and merging the PR has no effect on the issues." (`docs.github.com` → Linking a pull request to an issue.)
- **Auto-close disabled.** A repository can turn off "Auto-close issues with merged linked pull requests" in Settings → General → Issues. The link exists, the merge does not act on it.

A PR can also name an issue with no keyword at all (`#N` in a sentence), and a spec stays open after its last ticket closes. All of these are what Step 3.5's collector put in `issues[]`.

**Read the issue's state, not the link set.** `closingIssuesReferences` is documented as issues that *may* be closed by the PR and includes manually linked ones, so subtracting it hides an issue that is linked and still open — exactly the case this step exists to catch. The issue's own `state` is the direct signal, so the collector reads it for every ref, and keeps the link set only as a source of candidates (a sidebar link is in no text).

**What the collector did** (`scripts/collect-cleanup.sh --pr`, rules in its header). It scanned the PR body, every PR commit message and the merge commit's message, plus `closingIssuesReferences`, for `#N`, `OWNER/REPO#N` and issue URLs. It validated each ref (https and the PR's own host only for a URL, the repository qualifier kept, at most 25 refs read), dropped this PR's own number and every ref gh resolves to a pull request (issues and PRs share numbers), and read each issue's state on the PR's host. Each `issues[]` entry has `ref` (as written), `via`, `state`, `title` and `url`:

- `via`: `keyword` (one of GitHub's nine closing keywords), `closingRef` (linked on the PR), `bare` (a mention with no keyword), or `spec-parent`: the issue's GitHub sub-issue parent, listed only when it is open and every child still open is in this list. Its `after` names those children.
- `state: null` with a `reason`: unresolved (another host, an invalid ref, past the cap, a failed read, a failed parent lookup). Report each one; never treat it as "not open", and never close it.
- `issue_sources`: `commits` is null when the commit scan failed, and `commits_truncated: true` means the endpoint's 250-commit ceiling cut the scan. Say so in the report rather than calling the sweep complete. `merge_commit` is `read`, `none` (no merge commit) or `failed`. `issues: null` with `issue_sources.error` means nothing was read: report the error.

The state read happens **before** the confirmation gate, on purpose. A reviewer will suggest inverting that — confirm the raw refs first, query after — and it makes the gate worse: the user would be approving references without knowing which are even open, which is the one fact the gate exists to act on. What keeps the read safe is the host pin, not deferral: every query goes to the PR's own host, over a repository the user can already read, and a read leaves no trace for anyone to see.

**Judge each `OPEN` entry before asking.** A mention is not a resolution, least of all a `bare` one. Read the issue (`gh issue view <url> --comments`) and set what it asks for against the PR's diff (`gh pr diff <PR_NUMBER>`). Propose to close it only when the diff does what the issue asks. Leave it open, and say why, when the PR does only part of it, only mentions it, or the issue is kept open on purpose (it waits for a human check, tracks a follow-up, or says so in its body or comments). A `spec-parent` is resolved when its children are: propose it only together with every child in its `after`.

**One confirmation** through the interactive-input gate for all proposed closes: each with its host, repo, number, title, `via`, and the evidence (the line of the issue and the part of the diff that match). List the unresolved refs and the ones you left open below it, with their reasons.

**Close each confirmed one by its `url`**: `gh issue close <url> --comment "Resolved by <PR url>"`. The `url` is the one gh returned for the state read, so it carries the host the read used; a bare number would send the close to `github.com` while the read came from an Enterprise server. The comment body is read **in the issue's repository**, so a bare `#<PR>` there points at that repository's own number — a different pull request, or nothing. The PR's `url` (from Step 1) resolves the same everywhere. Close a `spec-parent` last, and only if every child in its `after` closed. Do not close an issue the user did not confirm.

### 5.1. Update GitHub Project status (optional)

- `gh project list --owner <owner> --format json`. If none, skip silently. Else `gh project item-list` → `gh project field-list` → `gh project item-edit` to set Status to "Done". Skip if the issue is not in the project.
- Two scopes, not one: listing and reading a Project needs `read:project`, and `gh project item-edit` writes, which needs `project`. A token with only the read scope gets through the listing and fails on the edit, so treat a permission error there as the skip condition it is, not as a run failure. A missing Project, or a token without either scope, skips **this sub-step only** — Step 5 above already ran. It gets no `steps[]` entry of its own: `state-envelope/v0` carries one entry per top-level step and folds sub-steps into the parent, and Step 5's own entry is now always `done`, so a skipped Project can no longer be misread as a skipped issue-close check. Report which condition fired in the run output; the envelope does not need it.

### 9. README + repo About

If the PR changed features, commands, install, usage or dependencies and a README exists, run `/docs:readme` on it, show the proposal, and add the README to `RUN_TOUCHED`; otherwise skip the README.
Always compare `gh repo view --json description --jq .description` with the README's opening claim and this PR's changes; on drift propose a one-liner through the interactive-input gate and run `gh repo edit --description "<approved>"` only on approval, then print `repo-about: in sync` or `repo-about: updated`.

### 9.5. CHANGELOG (if present)

If a root `CHANGELOG.md` exists and the merge is user-visible (feature, fix, breaking change), run `/docs:changelog` and add the file to `RUN_TOUCHED`; otherwise skip silently.

### 10. Commit changes (optional)

If **any** tracked files were modified by this run (README from Step 9, `CHANGELOG.md` from Step 9.5, a Step 4.6 in-file `Edit`, **or a Step 4.5 / Step 4.6 `git rm` deletion**), confirm with the user, then commit using Conventional Commits. A prune-only run (Step 4.5 / 4.6 `git rm`'d a file and nothing else changed) must still commit, or the deletion is left uncommitted in the working tree. The `git diff --cached --quiet` check below catches the staged deletion even though it is not in `RUN_TOUCHED`.

Stage **only the exact files this run created or modified**: collect them as you go through Steps 4.6-9.5 and build that explicit list as `RUN_TOUCHED`; **never `git add` a whole directory**: a pre-existing untracked draft would otherwise be swept into this commit, and Step 2 already decided to leave untracked files alone.

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

Skip the commit only when `git -C "$MAIN_REPO" diff --cached --quiet` reports nothing staged after the `git add` (a staged-only check); `git status --porcelain` would also count pre-existing untracked files and wrongly attempt an empty-index commit.

**Finalize the run record.** Run the finalize block in `references/run-record.md` to append Step 10 and mark the envelope terminal. The record stays under gitignored `.claude/state/`; do **not** add it to `RUN_TOUCHED`.

### 11. Print the worktree cleanup command (`IN_WT=1` only)

Print this one line, filled in, as the last line of the run, and do not run it. The user runs it after leaving the worktree session; removing a worktree from inside itself only half deletes it on Windows.

```bash
# %q: a quote, `$` or space in a path or branch name cannot change the pasted command.
[ "$IN_WT" = 1 ] && printf 'cd %q && git worktree remove %q && git branch -d %q\n' \
  "$MAIN_REPO" "$WT_PATH" "$headRefName"
```

`git worktree remove` refuses a worktree with modified or untracked files, which is the check to keep: anything it names was never committed. It deletes ignored files such as `.tmp/` without asking, so move anything worth keeping to `$MAIN_REPO/.tmp/` first, as Step 3.5 does. `git branch -d` behaves as in Step 4. Step 3.5 skips this worktree (reason `current session`) and leaves it to this command.

## References

- **Unresolved review surface** (Step 1.5, review-loop state-file defer list + `final_state`, open-thread proxy): reads `.claude/state/review-loop-<PR>.json` / `.claude/state/archive/`; field schema in `plugins/dev/skills/review-loop/assets/final-output.schema.json`.
- **Leftover-review blocks** (Step 1.5 primary signal, secondary signal, checkpoint decision): `references/leftover-reviews.md`
- **Run-record envelope** (Step 1 init + recording contract + per-step skip reasons + Step 10 finalize): `references/run-record.md`; convention + schema in `.claude/rules/state-envelope.md` (concept mirror in `AGENTS.md`).
- **Ephemeral artifact pruning** (Step 4.5, heuristics, exclusions, git rm/commit interaction): `references/ephemeral-heuristics.md`

> Follow ~/.claude/CLAUDE.md and the project CLAUDE.md.
