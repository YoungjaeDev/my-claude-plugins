---
description: Clean up branch and update CLAUDE.md after PR merge
---

# Post-Merge Cleanup

Perform local branch cleanup and CLAUDE.md updates after a PR has been merged. For worktree removal, use `/github-dev:cleanup-worktree`. Follow project guidelines in `@CLAUDE.md`.

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

4. **Clean Up Local Branch**
   - Check if branch exists locally: `git branch --list "$headRefName"`
   - If exists, prompt user to confirm deletion
   - If confirmed: `git branch -d "$headRefName"`
   - If any worktrees remain for this branch, inform user:
     > "Worktree detected for `$headRefName`. Run `/github-dev:cleanup-worktree` to remove it."

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
     - `AGENTS.md` - Cross-tool AI coding agent instructions
     - `GEMINI.md` - Google Gemini CLI specific instructions
     - `.claude/rules/*.md` - Modular rule files

   - **Placement Rules** (applies to all config files):

     | Content Type | Placement |
     |--------------|-----------|
     | Project-wide constraints | Golden Rules > Immutable |
     | Project-wide recommendations | Golden Rules > Do's |
     | Project-wide prohibitions | Golden Rules > Don'ts |
     | Module-specific rules | Delegate to `.claude/rules/[module].md` |
     | New commands | Commands section |
     | New module references | Modular Rules section |

   - **Content Removal**:
     - Temporary instructions (e.g., `TODO: remove after #N`)
     - Resolved known issues
     - Workaround descriptions for fixed bugs

   - **Content Addition**:
     - Module-specific rule -> propose `.claude/rules/[module].md` creation/update
     - Project-wide rule -> add to appropriate Golden Rules subsection
     - New module documented -> add `See @.claude/rules/[module].md` reference

   - **Modular Rule Files** (.claude/rules/*.md):
     - Check if relevant module file exists
     - Propose path-specific rules with frontmatter: `paths: src/[module]/**/*.py`
     - Follow structure: Role, Key Components, Do's, Don'ts
     - **Always confirm with user before creating new rule files**

   - Present proposal to user for confirmation before applying

7. **Update Serena Memory (if Serena MCP available)**
   - Run `list_memories` to find existing memory files
   - Analyze PR for learnings worth preserving:
     - Architectural decisions made
     - New patterns introduced
     - Issues resolved and how
     - Module-specific knowledge
   - Identify the most relevant existing memory file
   - Use `edit_memory` to append learnings to the existing file
   - **NEVER create new memory files** - always update existing ones
   - Skip if no significant learnings or Serena unavailable

8. **Update README.md (Optional)**
   - Check if PR introduced changes that affect README:
     - New features or commands
     - Changed installation steps
     - Updated dependencies
     - Modified usage examples
   - If README exists and updates are needed:
     - Propose specific changes to user
     - Apply only after user confirmation
   - Skip if no README-relevant changes

9. **Commit Changes (Optional)**
   - If any configuration files were modified, prompt user to confirm commit
   - If confirmed: Commit using Conventional Commits format
   - Example: `git add CLAUDE.md AGENTS.md GEMINI.md README.md 2>/dev/null || true`

> See [Work Guidelines](../guidelines/work-guidelines.md)

## Configuration File Update Guide

The following guidelines apply to CLAUDE.md, AGENTS.md, GEMINI.md, and `.claude/rules/*.md`:

### Expected File Structure

**Root Config (CLAUDE.md, AGENTS.md, GEMINI.md)**:
1. Project Context - Business goal + tech stack (1-2 sentences)
2. Commands - Package manager and run commands
3. Golden Rules - Immutable / Do's / Don'ts
4. Modular Rules - `See @.claude/rules/[module].md` references
5. Project-Specific - Data locations, tracking, etc.

**Modular Rules (.claude/rules/*.md)**:
```markdown
---
paths: src/[module]/**/*.py  # Optional: conditional loading
---
# [Module] Rules
Role description (1-2 lines)
## Key Components
## Do's
## Don'ts
```

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
