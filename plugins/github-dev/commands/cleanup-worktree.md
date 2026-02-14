---
description: Clean up git worktrees with optional branch and remote deletion
---

# Cleanup Worktree

Remove git worktrees and their associated branches. Supports selective, targeted, and bulk cleanup. Follow project guidelines in `@CLAUDE.md`.

## Usage

```bash
/github-dev:cleanup-worktree           # List worktrees, select which to remove
/github-dev:cleanup-worktree <branch>  # Remove worktree for specific branch
/github-dev:cleanup-worktree --all     # Remove all non-main worktrees (with confirmation)
/github-dev:cleanup-worktree --prune   # Clean dangling references only
```

## Flags

| Flag | Description |
|------|-------------|
| `--all` | Remove all non-main worktrees (prompts for confirmation) |
| `--prune` | Only run `git worktree prune` to clean dangling references |
| `--delete-remote` | Also delete the remote tracking branch |
| `--force` | Force removal even if worktree has uncommitted changes |

## Prerequisites

This command MUST be run from the **main worktree** (the original clone directory), not from inside a linked worktree. `git worktree remove` operates on the main repository's worktree metadata.

## Workflow

1. **Verify Main Worktree**
   ```bash
   # Check if current directory is the main worktree
   MAIN_WORKTREE=$(git worktree list | head -1 | awk '{print $1}')
   CURRENT_DIR=$(git rev-parse --show-toplevel)
   ```
   - If `$CURRENT_DIR` != `$MAIN_WORKTREE`: abort with error
     > "This command must be run from the main worktree (`$MAIN_WORKTREE`), not from a linked worktree."
   - Parse output to identify all worktrees and their branches
   - Identify the **main worktree** (first entry, the primary checkout) — this is never removed
   - If no non-main worktrees exist, inform user and exit

2. **Handle `--prune` Flag**
   - If `--prune` passed, run `git worktree prune` and exit
   - Report number of dangling references cleaned

3. **Select Target Worktrees**

   **If `<branch>` argument provided:**
   - Find worktree matching the branch name
   - If not found, show available worktrees and exit with error

   **If `--all` flag:**
   - Select all non-main worktrees
   - Display list and prompt user for confirmation using `AskUserQuestion`

   **If no arguments (interactive):**
   - Display numbered list of non-main worktrees with branch names and paths
   - Use `AskUserQuestion` to let user select which worktree(s) to remove

4. **Check Dirty State (per worktree)**
   ```bash
   git -C "$WORKTREE_PATH" status --porcelain
   ```
   - If clean: proceed to removal
   - If dirty (uncommitted changes):
     - Warn user: "Worktree at `$WORKTREE_PATH` has uncommitted changes"
     - Prompt with `AskUserQuestion`:
       - **Force remove**: proceed with `--force`
       - **Skip**: skip this worktree
       - **Abort**: stop entire cleanup

5. **Remove Worktree**
   ```bash
   # Normal removal
   git worktree remove "$WORKTREE_PATH"

   # Force removal (if dirty and user confirmed)
   git worktree remove --force "$WORKTREE_PATH"
   ```

   **Windows: `Permission denied` error handling**
   - If `git worktree remove` fails with "Permission denied":
     - Likely cause: another process (IDE, terminal, file explorer) has the worktree directory open
     - Prompt user with `AskUserQuestion`:
       - **Close and retry**: "Close all programs using `$WORKTREE_PATH`, then retry"
       - **Manual delete + prune**: Fall back to manual removal:
         ```bash
         rm -rf "$WORKTREE_PATH"
         git worktree prune
         ```
       - **Abort**: skip this worktree

6. **Delete Local Branch**
   ```bash
   # Safe delete (fails if unmerged)
   git branch -d "$BRANCH_NAME"
   ```
   - If fails (unmerged branch), prompt user:
     - **Force delete**: `git branch -D "$BRANCH_NAME"`
     - **Keep branch**: skip branch deletion

7. **Delete Remote Branch (if `--delete-remote`)**
   ```bash
   git push origin --delete "$BRANCH_NAME"
   ```
   - Skip silently if remote branch does not exist

8. **Prune Dangling References**
   ```bash
   git worktree prune
   ```

9. **Update Configuration and Memory (per branch)**
   - Look up associated PR:
     ```bash
     gh pr list --head "$BRANCH_NAME" --state all --json number,title,body,state --limit 1
     ```
   - If no PR found, skip this step
   - If PR found, run `gh pr view <number> --json number,title,body,baseRefName,headRefName,files` to get full details
   - **Analyze PR for documentation updates** (same as post-merge Step 6):
     - Check which configuration files exist: `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.claude/rules/*.md`
     - Content to remove: temporary instructions (`TODO: remove after #N`), resolved known issues
     - Content to add: new patterns, conventions, module-specific rules
     - Present proposal to user for confirmation before applying
   - **Update Serena memory** (if Serena MCP available):
     - Run `list_memories` to find existing memory files
     - Identify the most relevant existing file for the PR content
     - Use `edit_memory` to append learnings to the existing file
     - **NEVER create new memory files** - always update existing ones
     - Content to add: architectural decisions, new patterns, resolved issues
   - If any files were modified, commit with: `docs: update config after cleanup of <branch>`

10. **Output Summary**
   ```
   Worktree cleanup complete!

   Removed:
     - fix/42-login-bug (../fix-42-login-bug)

   Branches deleted (local): fix/42-login-bug
   Branches deleted (remote): origin/fix/42-login-bug   # if --delete-remote

   Remaining worktrees:
     /home/user/project (main) [main worktree]
   ```

## Notes

- **Must be run from the main worktree** (original clone directory), not from inside a linked worktree
- The main worktree (primary checkout) is **never** removed
- Use `--prune` periodically to clean up references from manually deleted worktree directories
- After PR merge, prefer `/github-dev:post-merge` for branch cleanup; use this command for worktree-specific removal
- This command pairs with `/github-dev:create-worktree` for the full worktree lifecycle
- **Windows**: `Permission denied` errors typically mean another process (IDE, terminal) holds a lock on the worktree directory. Close all programs using that path before retrying
