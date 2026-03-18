---
description: Squash merge worktree branch back to base branch with learning integration
---

# Merge Worktree

Squash-merge the current worktree branch into the base branch (default: main) with optional learning integration. Must be run from inside a linked worktree. Follow project guidelines in `@CLAUDE.md`.

## Usage

```bash
/github-dev:merge-worktree                     # squash merge to auto-detected main/master
/github-dev:merge-worktree --target develop     # squash merge to specific branch
/github-dev:merge-worktree --no-squash          # merge --no-ff instead of squash
/github-dev:merge-worktree --skip-learning      # skip learning integration (Phase 6)
```

## Flags

| Flag | Description |
|------|-------------|
| `--target <branch>` | Base branch to merge into (default: auto-detect main/master) |
| `--no-squash` | Use `merge --no-ff` instead of squash merge |
| `--skip-learning` | Skip Phase 6 (learning integration) |

## Workflow

### Phase 1 -- Validation

1. **Verify worktree context**
   ```bash
   # Canonical worktree detection: if git-dir differs from git-common-dir, we are in a linked worktree
   [ "$(git rev-parse --git-dir)" != "$(git rev-parse --git-common-dir)" ]
   ```
   - If equal, abort: "This command must be run from inside a linked worktree, not the main repository."

2. **Resolve original repo path (canonicalized)**
   ```bash
   ORIGINAL_REPO=$(cd "$(git rev-parse --git-common-dir)/.." && pwd -P)
   ```
   Using `cd + pwd -P` instead of `dirname` to handle both relative and absolute paths from `--git-common-dir`.

3. **Get current branch**
   ```bash
   CURRENT_BRANCH=$(git branch --show-current)
   ```

4. **Check worktree clean state**
   ```bash
   git status --porcelain
   ```
   - Clean: proceed
   - Dirty: prompt user (AskUserQuestion):
     - **Stash**: `git stash push -m "merge-worktree: temp save"`
     - **Commit**: let user commit first
     - **Abort**: stop

5. **Check original repo clean state**
   ```bash
   git -C "$ORIGINAL_REPO" status --porcelain
   ```
   - Clean: proceed
   - Dirty: warn and abort. "Original repo has uncommitted changes. Please resolve before merging."
   - This prevents contaminated commits from pre-existing staged changes.

6. **Detect target branch**
   - If `--target` provided: use it
   - Otherwise: auto-detect from original repo with fallback chain:
     ```bash
     TARGET=$(git -C "$ORIGINAL_REPO" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
       | sed 's@^refs/remotes/origin/@@') \
       || TARGET=$(git -C "$ORIGINAL_REPO" branch --list main master | head -1 | tr -d ' ')
     ```
   - If neither works, abort: "Cannot detect default branch. Use `--target <branch>` to specify."

### Phase 2 -- Research

All research commands use `git -C "$ORIGINAL_REPO"` to ensure refs are up-to-date. The worktree's local refs for the target branch may be stale.

1. **Analyze all commits since divergence**
   ```bash
   git -C "$ORIGINAL_REPO" log --oneline "$TARGET_BRANCH".."$CURRENT_BRANCH"
   ```

2. **Show target branch advancement** (reverse log)
   ```bash
   git -C "$ORIGINAL_REPO" log --oneline "$CURRENT_BRANCH".."$TARGET_BRANCH"
   ```
   If non-empty, warn: "Target branch has N new commits since this branch was created. Review before proceeding."

3. **Diff analysis**
   ```bash
   git -C "$ORIGINAL_REPO" diff "$TARGET_BRANCH"..."$CURRENT_BRANCH" --stat
   git -C "$ORIGINAL_REPO" diff "$TARGET_BRANCH"..."$CURRENT_BRANCH"
   ```

4. **Categorize changes**
   - Features, Fixes, Refactors, Tests, Docs, Config/Chore
   - Determine dominant conventional commit type for Phase 5

5. **Read key files** if diff alone is insufficient for understanding changes

### Phase 3 -- Target Branch Preparation

1. **Checkout target branch in original repo**
   ```bash
   git -C "$ORIGINAL_REPO" checkout "$TARGET_BRANCH"
   ```
   - If checkout fails (e.g., branch doesn't exist), abort with error.
   - Phase 1 Step 5 already verified original repo is clean, so checkout should succeed.

2. **Check target branch state**
   ```bash
   git -C "$ORIGINAL_REPO" log --oneline -5 "$TARGET_BRANCH"
   ```

3. **Detect stray WIP commits**
   ```bash
   git -C "$ORIGINAL_REPO" log --oneline -20 "$TARGET_BRANCH" | grep -iE '\bwip\b|auto-commit|fixup!'
   ```
   If found: warn user with AskUserQuestion:
   - **Reset to last clean commit**: `git -C "$ORIGINAL_REPO" reset --hard <last-clean-hash>`
   - **Keep and proceed**: continue with WIP commits on target
   - **Abort**: stop

4. **Fetch + pull from remote** (if remote exists)
   ```bash
   git -C "$ORIGINAL_REPO" fetch origin
   git -C "$ORIGINAL_REPO" pull origin "$TARGET_BRANCH"
   ```
   Pull (not just fetch) ensures local target branch is up-to-date. This is safe because Phase 3 Step 1 already checked out the target branch.

### Phase 4 -- Squash Merge

Phase 3 Step 1 ensures the original repo is on `$TARGET_BRANCH`, so the merge target is correct.

**Default (squash):**
```bash
git -C "$ORIGINAL_REPO" merge --squash "$CURRENT_BRANCH"
```

**With `--no-squash` flag:**
```bash
git -C "$ORIGINAL_REPO" merge --no-ff "$CURRENT_BRANCH"
```

**On conflict:**
- Report all conflicted files with paths
- Show conflict markers for each file
- **STOP execution immediately**
- Offer rollback: `git -C "$ORIGINAL_REPO" merge --abort`
- User must resolve conflicts manually in the original repo

### Phase 5 -- Commit Message

**Squash merge (default):**

Format:
```
<type>: <summary in imperative mood, max 72 chars>

<2-4 sentence paragraph explaining what changed and WHY>

Changes:
- <grouped bullet points by category>
```

- `<type>` determined by Phase 2 dominant category (feat/fix/refactor/docs/chore/test)
- Commit via heredoc (project convention):
  ```bash
  git -C "$ORIGINAL_REPO" commit -m "$(cat <<'EOF'
  <generated message>
  EOF
  )"
  ```

**`--no-squash` merge:**

Phase 4's `merge --no-ff` already creates a merge commit with git's auto-generated message. Phase 5 is skipped for `--no-squash`. If the user wants a custom merge commit message, they can amend it manually after the command completes.

### Phase 6 -- Learning Integration

Reuses post-merge Steps 6-8 logic with one critical difference:

> **All file reads and writes MUST use absolute paths prefixed with `$ORIGINAL_REPO/`.**
> The current working directory is the linked worktree, NOT the original repository.
> Reading/writing relative paths would modify worktree copies, not the original repo files.

Examples:
- Read `$ORIGINAL_REPO/CLAUDE.md` (not `./CLAUDE.md`)
- Write to `$ORIGINAL_REPO/AGENTS.md` (not `./AGENTS.md`)
- Read `$ORIGINAL_REPO/.claude/rules/*.md` (not `./.claude/rules/*.md`)

**Steps:**

1. **Configuration file integration** (post-merge Step 6)
   - Read diff from Phase 2 results (already available, no GitHub API needed)
   - Check which config files exist in `$ORIGINAL_REPO/`: CLAUDE.md, AGENTS.md, GEMINI.md, .claude/rules/*.md
   - Classify learnings and integrate into existing sections
   - Present proposal to user for confirmation before applying
   - Follow the same classification table and anti-patterns as post-merge Step 6

2. **Serena memory update** (post-merge Step 7, if Serena MCP available)
   - Use Serena tools (these operate on the activated project, which may need re-activation for original repo)
   - Follow same rules: never create new memory files, update existing ones

3. **README.md update** (post-merge Step 8, if needed)
   - Read `$ORIGINAL_REPO/README.md`
   - Apply updates if changes introduced README-relevant content

4. **Commit documentation changes**
   - Track which files were actually modified during Steps 1-3
   - Stage ONLY modified files (do not blindly add all config files):
     ```bash
     git -C "$ORIGINAL_REPO" add <only-modified-files>
     git -C "$ORIGINAL_REPO" commit -m "$(cat <<'EOF'
     docs: integrate learnings from <CURRENT_BRANCH>
     EOF
     )"
     ```
   - If no files were modified, skip commit entirely.

**Intentional exclusion:** Milestone/project tracking sync (post-merge Step 5.5) is NOT included. There is no GitHub PR to reference for project tracking updates. Use `/github-dev:post-merge` after a GitHub PR for milestone sync.

### Phase 7 -- Verification and Guidance

1. **Show result**
   ```bash
   git -C "$ORIGINAL_REPO" log --oneline -3 "$TARGET_BRANCH"
   ```

2. **Output summary**
   ```
   Merge complete!

   Target: main
   Commit: abc1234 feat: add user authentication flow
   Strategy: squash merge
   Files changed: 12 insertions(+), 3 deletions(-)

   Worktree branch '<CURRENT_BRANCH>' still exists.
   Run /exit with cleanup option to remove this worktree.
   ```

> See [Work Guidelines](../guidelines/work-guidelines.md)

## Notes

- This command intentionally excludes milestone/project tracking sync (see post-merge Step 5.5)
- For GitHub PR-based workflow, use `/github-dev:post-merge` instead
- Worktree cleanup is handled by `/exit` with cleanup option (Claude Code built-in)
- Phase 3 checks out the target branch in the original repo, which may affect other sessions or IDEs open in that directory
