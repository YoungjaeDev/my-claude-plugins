---
description: Clean up branch and update CLAUDE.md after PR merge
---

# Post-Merge Cleanup

Perform branch cleanup and CLAUDE.md updates after a PR has been merged. Follow project guidelines in `@CLAUDE.md`.

## Arguments

- PR number (optional): If not provided, infer from conversation context or prompt user to select from recent merged PRs

## Workflow

1. **Identify PR**
   - Use PR number if provided as argument
   - Otherwise, attempt to infer related PR/issue number from conversation context
   - If unable to determine, run `gh pr list --state merged --limit 5` to show recent merged PRs and prompt user to select

   - Run `gh pr view <PR_NUMBER> --json number,title,baseRefName,headRefName,body,state` to get PR details
   - Verify `state` is MERGED

2. **Check Local Changes**
   - Run `git status --porcelain` to check for uncommitted changes
   - **Untracked files (`??`)**: Ignore and proceed (do not affect branch switching)
   - **Modified/Staged files (`M`, `A`, `D`, etc.)**: Prompt user for action:
     - **Stash and proceed**: `git stash push -m "post-merge: temp save"`
     - **Discard changes**: `git checkout -- . && git clean -fd`
     - **Abort**: Let user handle manually
   - **If stash selected**: After workflow completion, prompt user for stash restoration:
     - **pop**: `git stash pop` (restore and remove stash)
     - **apply**: `git stash apply` (restore and keep stash)
     - **later**: Let user handle manually

3. **Switch to Base Branch**
   - `git fetch origin`
   - `git checkout <baseRefName>`
   - `git pull origin <baseRefName>`

4. **Clean Up Issue Branch (Optional)**
   - Prompt user to confirm local branch deletion
   - If confirmed: `git branch -d <headRefName>`

5. **Update GitHub Project Status (Optional)**
   - Extract related issue numbers from PR body: search for `Closes #N`, `Fixes #N`, `Resolves #N` patterns
   - Run `gh project list --owner <owner> --format json` to check for projects
   - If no projects exist, skip silently
   - If projects exist:
     - Run `gh project item-list` to get the issue's item-id
     - Run `gh project field-list` to get Status field ID and "Done" option ID
     - Run `gh project item-edit` to set Status to "Done"
     - Skip if issue is not in project or Status field does not exist

6. **Analyze and Update Configuration Files**
   - Check which configuration files exist:
     - `CLAUDE.md` - Claude Code specific instructions
     - `AGENTS.md` - Cross-tool AI coding agent instructions (Codex, Cursor, Gemini, etc.)
     - `GEMINI.md` - Google Gemini CLI specific instructions
   - For each existing file, analyze:
     - Find temporary instructions related to resolved issue (e.g., mentions of `#<issue_number>`, `issue-<number>`)
     - Identify outdated or inaccurate information
     - Identify redundant or unnecessary content
   - Prepare update proposal for each file:
     - **To remove**: Temporary notes/instructions related to resolved issue
     - **To add**: New patterns/conventions discovered during issue resolution
     - **To modify**: Outdated or inaccurate information
   - Present proposal to user for confirmation before applying

7. **Commit Changes (Optional)**
   - If any configuration files were modified, prompt user to confirm commit
   - If confirmed: Commit using Conventional Commits format
   - Example: `git add CLAUDE.md AGENTS.md GEMINI.md 2>/dev/null || true`

> See [Work Guidelines](../guidelines/work-guidelines.md)

## Configuration File Update Guide

The following guidelines apply to CLAUDE.md, AGENTS.md, and GEMINI.md:

### Examples of Content to Remove
- Temporary notes like `TODO: remove after #123 is resolved`
- Temporary workaround descriptions for specific issues
- Known issues lists that have been resolved

### Examples of Content to Add
- Code conventions discovered during issue resolution
- Guidelines to prevent common mistakes
- Newly introduced patterns or architecture decisions

### Examples of Content to Modify
- Changed directory structure descriptions
- Updated dependency information
- Commands or configurations that are no longer valid
