---
description: Clean up branch and integrate PR learnings into config files
---

# Post-Merge Cleanup

Perform local branch cleanup and configuration updates after a PR has been merged. For worktree removal, use `/github-dev:cleanup-worktree`. Follow project guidelines in `@CLAUDE.md`.

## Arguments

- PR number (optional): If not provided, infer from conversation context or prompt user to select from recent merged PRs

## Workflow

1. **Identify PR**
   - Use PR number if provided as argument
   - Otherwise, attempt to infer related PR/issue number from conversation context
   - If unable to determine, run `gh pr list --state merged --limit 5` to show recent merged PRs and prompt user to select

   - Run `gh pr view <PR_NUMBER> --json number,title,baseRefName,headRefName,body,state,files` to get PR details
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

5.5. **Sync Milestone Progress** (if issues have milestones):
   - Extract related issue numbers from PR body (already found in Step 5): `Closes #N`, `Fixes #N`, `Resolves #N`
   - For each related issue, check milestone:
     ```bash
     MILESTONE=$(gh issue view $ISSUE_NUM --json milestone --jq '.milestone.title // empty')
     ```
   - If milestone exists:
     1. Generate slug from milestone name (lowercase, spaces to hyphens, remove special chars)
     2. Load state file: `.omc/state/project-tracking-{slug}.json`
     3. If state file not found: skip this issue
     4. Update issue state to `"closed"` in the state file
     5. Recalculate module progress:
        ```
        module.progress = (closed_issues / total_issues) * 100
        module.status:
          "complete"    -> all issues closed
          "in_progress" -> at least 1 closed or has PR, at least 1 still open
          "pending"     -> all open, no PR
        ```
     6. Regenerate **Milestone Table** (for milestone description):
        - Generate Markdown Table with all issues, status indicators, and dependencies
        - See `update-progress.md` "Milestone Format" for full format
     7. Regenerate **Type M-2 Mermaid diagram** (for each issue body in milestone):
        - Read `architecture.mermaidSource` from state file
        - Highlight the issue's `architectureNode` with `:::scope`
        - Create `context` subgraph with this issue, `deps` with `dependsOn` issues, `next` with dependent issues
        - See `update-progress.md` "Type M-2" for full format
     8. Update milestone description:
        ```bash
        MILESTONE_NUMBER=$(cat .omc/state/project-tracking-${SLUG}.json | jq -r '.milestoneId')
        # Fallback if null:
        # MILESTONE_NUMBER=$(gh api repos/:owner/:repo/milestones \
        #   --jq '.[] | select(.title=="<name>") | .number')
        gh api repos/:owner/:repo/milestones/$MILESTONE_NUMBER \
          -X PATCH -f description="$MILESTONE_TABLE"
        ```
     9. Update each open issue's body tracking section (marker-based replacement):
        ```bash
        CURRENT_BODY=$(gh issue view $ISSUE_NUM --json body --jq '.body')
        # If <!-- project-tracking-start --> exists: replace section between markers
        # If not: append tracking section at end of body
        # Tracking section contains Type M-2 Mermaid for that issue's context
        gh issue edit $ISSUE_NUM --body "$NEW_BODY"
        ```
     10. Save state file with updated `lastSyncedAt`
   - Skip silently if no milestones found on any related issues

6. **Integrate Learnings into Configuration Files**

   Read the PR diff (`gh pr diff <PR_NUMBER>`) and PR body to extract learnings. Then integrate each learning into the **appropriate existing section** of configuration files.

   **CRITICAL: Never append "Post-Merge Notes" sections.** All learnings must be woven into the existing document structure as if they were always there.

   - Check which configuration files exist:
     - `CLAUDE.md` - Claude Code specific instructions
     - `AGENTS.md` - Cross-tool AI coding agent instructions
     - `GEMINI.md` - Google Gemini CLI specific instructions
     - `.claude/rules/*.md` - Modular rule files

   - **Classification and Placement** (applies to all config files):

     | Learning Type | Target Section | Action |
     |---------------|----------------|--------|
     | New constraint / invariant | Golden Rules > Immutable | Add as a new bullet |
     | New convention / best practice | Golden Rules > Do's | Add as a new bullet |
     | New prohibition / anti-pattern | Golden Rules > Don'ts | Add as a new bullet |
     | New/changed command or script | Commands | Add or update the command block |
     | Module added/removed/changed | Key Modules table | Update the row description |
     | New data file or location | Data Locations table | Add or update the row |
     | New module rule reference | Modular Rules | Add `See @path` reference |
     | Module-specific rule | `.claude/rules/[module].md` | Update or propose creation |
     | Tech stack change | Project Context | Update the tech description |
     | Test count change | Commands or relevant section | Update the count |

   - **Integration Process**:
     1. Read the current config file to understand existing structure and content
     2. For each learning, find the most specific existing section it belongs to
     3. Merge the new information naturally -- update existing descriptions rather than adding footnotes
     4. If an existing bullet or row already covers the topic, **update it in place** rather than adding a new entry
     5. Remove any outdated information that the PR supersedes (e.g., old module descriptions, removed features)

   - **Content Removal**:
     - Temporary instructions (e.g., `TODO: remove after #N`)
     - Resolved known issues
     - Workaround descriptions for fixed bugs
     - **Existing "Post-Merge Notes" sections** -- migrate their content into proper sections, then delete the notes

   - **Modular Rule Files** (.claude/rules/*.md):
     - Check if relevant module file exists
     - Propose path-specific rules with frontmatter: `paths: src/[module]/**`
     - Follow structure: Role, Key Components, Do's, Don'ts
     - **Always confirm with user before creating new rule files**

   - Present the integration proposal to user as a diff-style summary before applying:
     ```
     CLAUDE.md changes:
       Golden Rules > Don'ts: + "Never reintroduce preview branching (Dispatcher is direct-send only)"
       Key Modules > electron-admin: "4 nav tabs" -> "3 nav tabs: Dashboard / AI / Settings"
       Remove: "Post-Merge Notes (PR #130)" section (content migrated above)
     ```

7. **Update Serena Memory (if Serena MCP available)**

   Integrate PR learnings into Serena memory as native content. Learnings should read as if they were always part of the memory -- not as appended post-merge notes.

   **Procedure:**

   1. Run `list_memories` to discover existing memory files
   2. Run `read_memory` on candidate files to understand their current sections and structure
   3. Analyze PR diff and body for learnings worth preserving:
      - Architectural decisions, new patterns, resolved issues, module-specific knowledge
   4. For each learning, find the best-fit section in an existing memory file (use the mapping table below)
   5. Use `edit_memory` to add or update content within that section

   **Memory File Mapping:**

   | Learning Category | Likely Target File | Section to Update |
   |-------------------|--------------------|-------------------|
   | Architecture changes, new modules, removed features | `project_overview.md` | Architecture, Key Features, Key Files |
   | Code patterns, naming, type changes | `code_style.md` | Code Patterns, Conventions |
   | New scripts, commands | `suggested_commands.md` | Relevant command group |
   | Workflow insights, process notes | `task_completion.md` | Relevant section |

   **Integration Rules:**
   - **NEVER create new memory files** (especially not `post_merge_prN.md`)
   - **NEVER add `## Post-Merge` headers** -- `## Post-Merge (date, PR #N)` creates changelog noise, not reference material
   - Find the existing section that covers the topic and add bullets there
   - If no matching section exists, create a **topical section** named after the subject (e.g., `## Shutdown Handling`), not after the PR
   - Update outdated descriptions in place rather than keeping old text alongside new
   - If content doesn't fit any existing file, append to `project_overview.md` as catch-all

   **Example -- Good (PR #132: graceful shutdown fix):**

   Before (`task_completion.md`):
   ```
   ## Process Lifecycle
   - `start()` initializes polling loop
   - `stopPolling()` signals shutdown
   ```

   After:
   ```
   ## Process Lifecycle
   - `start()` initializes polling loop and resets `isShuttingDown` flag
   - `gracefulShutdown()` is async; awaits shutdown handlers before exit
   - `isShuttingDown` flag prevents double-shutdown race conditions
   - `pollOnce` for-loop checks `isRunning` for early abort during shutdown
   ```

   **Example -- Bad (what NOT to do):**
   ```
   ## Post-Merge (2026-02-16, PR #132)
   - Graceful shutdown race condition fixed (Issue #69)
   - `Orchestrator.gracefulShutdown()` async conversion
   - `isShuttingDown` flag for double-shutdown prevention
   ```

   Skip if no significant learnings or Serena unavailable.

8. **Update README.md (if needed)**

   Check if PR introduced changes that affect README:
   - New features or commands
   - Changed installation steps
   - Updated dependencies
   - Modified usage examples
   - Removed features (update feature list)

   If README exists and updates are needed:
   1. Draft the README changes
   2. Apply `/humanizer:humanize` to the changed sections to remove AI-generated patterns
   3. Apply `/docs-forge:readme` guidelines (CRO best practices, structure, clarity)
   4. Present the final proposal to user for confirmation before applying

   Skip if no README-relevant changes.

9. **Commit Changes (Optional)**
   - If any configuration files were modified, prompt user to confirm commit
   - If confirmed: Commit using Conventional Commits format
   - Stage only modified files: `git add CLAUDE.md AGENTS.md GEMINI.md README.md .serena/memories/ 2>/dev/null || true`

> See [Work Guidelines](../guidelines/work-guidelines.md)

## Configuration File Integration Guide

The following guidelines apply to CLAUDE.md, AGENTS.md, GEMINI.md, and `.claude/rules/*.md`:

### Expected File Structure

**Root Config (CLAUDE.md, AGENTS.md, GEMINI.md)**:
1. Project Context - Business goal + tech stack (1-2 sentences)
2. Commands - Package manager and run commands
3. Golden Rules - Immutable / Do's / Don'ts
4. Modular Rules - `See @.claude/rules/[module].md` references
5. Project-Specific - Data locations, key modules, tracking, etc.

**Modular Rules (.claude/rules/*.md)**:
```markdown
---
paths: src/[module]/**  # Optional: conditional loading
---
# [Module] Rules
Role description (1-2 lines)
## Key Components
## Do's
## Don'ts
```

### Anti-Patterns (NEVER do these)

- **Changelog-style notes**: `## Post-Merge Notes (PR #N)` sections at the bottom
- **PR-specific Serena files**: `post_merge_prN.md` memory files
- **Post-Merge headers in Serena memory**: `## Post-Merge (date, PR #N)` sections within memory files -- use topical section names instead
- **Append-only updates**: Adding new sections instead of updating existing ones
- **Footnote references**: "See PR #N for details" scattered in the document

### Correct Integration Examples

**Instead of**:
```markdown
## Post-Merge Notes (PR #130)
- Preview Mode removed. Dispatcher is direct-send only.
- Admin Nav changed from 4 tabs to 3 tabs.
```

**Do this**:
```markdown
## Golden Rules
### Don'ts
- Never reintroduce preview branching (Dispatcher is registerSendFunction() + direct-send only)

## Key Modules
| apps/electron-admin/ | Electron admin app (...3 nav tabs: Dashboard / AI / Settings...) |
```

### Examples of Content to Remove
- Temporary notes like `TODO: remove after #123 is resolved`
- Temporary workaround descriptions for specific issues
- Known issues lists that have been resolved
- Any existing `## Post-Merge Notes (PR #N)` sections (migrate content first)

### Examples of Content to Modify
- Changed directory structure descriptions
- Updated dependency information
- Commands or configurations that are no longer valid
- Module descriptions that no longer match reality
- Test counts that have changed
