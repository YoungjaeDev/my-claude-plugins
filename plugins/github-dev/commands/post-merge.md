---
description: Clean up branch and integrate PR learnings into config files
---

# Post-Merge Cleanup

Perform local branch cleanup and configuration updates after a PR has been merged. For worktree removal, use `/exit` with cleanup option. Follow project guidelines in `@CLAUDE.md`.

## Arguments

- PR number (optional): If not provided, infer from conversation context or prompt user to select from recent merged PRs

## Workflow

1. **Identify PR**
   - Use PR number if provided as argument
   - Otherwise, attempt to infer related PR/issue number from conversation context
   - If unable to determine, run `gh pr list --state merged --limit 5` to show recent merged PRs and prompt user to select

   - Run `gh pr view <PR_NUMBER> --json number,title,baseRefName,headRefName,body,state,files` to get PR details
   - Verify `state` is MERGED. This `gh pr view` result is the **authoritative merge signal** for the rest of this workflow — later steps MUST NOT re-verify merge state by comparing git SHAs.

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
   - **Do NOT use any SHA-level commit comparison as a merge check** — `git log <base>..<branch>`, `git cherry <base> <branch>`, `git rev-list --left-right <base>...<branch>`, and similar variants all produce false positives after **squash merge** (base gets one new SHA containing combined content; branch SHAs unchanged) AND **rebase merge** (branch SHAs are rewritten on base — none match). Trust Step 1's `gh pr view` result; the content is already in base even when SHAs diverge.
   - If unsure whether all content landed in base, compare content (not SHAs):
     ```bash
     # Content-level diff is safe for squash merges; empty output = fully landed
     git diff "origin/$baseRefName..$headRefName" -- <paths>
     ```
   - If exists, prompt user to confirm deletion
   - If confirmed: `git branch -d "$headRefName"`
     - For squash-merged branches, expect `warning: not yet merged to HEAD` — this is normal. `git branch -d` detects merge via `origin/<branch>` tracking, so the delete still succeeds. Do NOT escalate to `-D`, do NOT treat the warning as data loss, and do NOT open a new PR for "missing" commits.
   - If any worktrees remain for this branch, inform user:
     > "Worktree detected for `$headRefName`. Run `/exit` with cleanup option to remove it."

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

   > **Core Principle: No Stamps, Topical Names, Current State Only**
   >
   > Normative docs (CLAUDE.md, AGENTS.md, GEMINI.md, .claude/rules/*, Serena memory) hold the **current rules only**. Change history (provenance) is already preserved permanently in git commit messages, PR bodies, and GitHub blame -- do not duplicate it inside the docs.
   >
   > **Forbidden patterns (regex-identifiable):**
   > - `\(?#\d+\)?` -- `(#123)`, `#123` inline citations
   > - `\b(PR|pr|Pull Request) ?#?\d+\b` -- `PR #50`, `PR50`, `Pull Request 50`
   > - `\b([Ii]ssue|이슈) ?#?\d+\b` -- `Issue #65`, `이슈 #53` (Korean stamp variant retained so the regex matches both English and Korean projects)
   > - `\b(Added|Removed|Fixed|Changed|Introduced) in (PR|#)` -- historical narrative openers
   > - `## Post-Merge` -- date- or PR-based section headers
   > - `<YYYY-MM-DD>` embedded inside a section header itself
   >
   > **Section naming**: topical names only (e.g., `## Process Lifecycle`, `## Crawler Throttling`). Never include dates, PR numbers, or issue numbers in section names.
   >
   > **Writing tone**: "X is async" (current-state). NOT "X was changed to async in PR #50" (history). NOT "Previously we used Y; now we use X (#50)" (transition narrative).
   >
   > **Exception**: `Closes #N` / `Fixes #N` GitHub keywords are allowed only inside commit messages, PR bodies, and issue bodies. Forbidden inside normative docs.

   > **Content-First principle**: Refine stale/duplicate content **in place first**, consolidate duplicates next, and only delete a file when it becomes empty or orphaned. File-level deletion is the last resort, not the default.

   **Pre-Audit: Clean Existing Pollution First**

   Before integrating new learnings, scrub existing stamps out of the target files first. This is the incremental healing step that gradually undoes pollution left by prior runs.

   1. Build the target file candidate list: `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.claude/rules/*.md` -- whichever exist.
   2. For each file, grep for the Core Principle's forbidden patterns:
      ```bash
      rg -nP '(\(?#\d+\)?|\b(PR|pr) ?#?\d+\b|\b([Ii]ssue|이슈) ?#?\d+\b|\b(Added|Removed|Fixed|Changed|Introduced) in (PR|#)|## Post-Merge)' <file>
      ```
   3. If the hit count is 0, skip Pre-Audit immediately and proceed to the next step (Read the PR diff).
   4. If hits are found, report to the user:
      - Per-file hit line numbers with the quoted original text
      - A "strip-stamp, preserve meaning" rewrite proposal for each line
   5. **Rewrite principles**:
      - Strip the stamp only, preserve normative content -- `"max_pages default is 10 (#53)"` -> `"max_pages default is 10"`
      - Convert historical narrative to current-state -- `"PR #18 benchmark is no longer the safety baseline"` -> delete the line, or `"the uniform 1-2.5s benchmark is not used"` (current rule only)
      - Same issue cited across multiple places -- consolidate the content into the single best-fit section, then delete the other citations
      - Reasoning lifted from PR/issue bodies stays; only the citation goes
   6. Apply gate via `AskUserQuestion`:
      - Offer "apply all" / "pick per file" / "skip Pre-Audit"
      - Show per-file hit counts in the description
   7. Apply the approved cleanup, then proceed to integrate the new learnings.

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

   - **Pre-presentation validation (stamp self-check)**:

     Before showing the proposal to the user, self-check **every added or modified line** against the Core Principle's forbidden patterns. (`Remove:` style cleanup lines are not subject to this check -- removing stamps is the goal.)

     Validation checklist:
     - [ ] No added/modified line contains `(#N)`, `PR #N`, `Issue #N`, `이슈 #N`, or similar inline citations
     - [ ] No new section header includes a date, PR number, or issue number (`## Post-Merge`, `## 2026-04-28 Updates`, etc. forbidden)
     - [ ] Every added bullet uses current-state tone ("X is async") -- not transition tone ("X was changed to async")
     - [ ] No "Added in PR" / "Removed in PR" / "Fixed in PR" / "Introduced in PR" phrasing

     **If any check fails**: do not show the proposal -- rewrite first. Self-loop until the patterns are satisfied. Every checkbox must be ✓ at the moment the proposal is presented.

   - Present the integration proposal to user as a diff-style summary before applying:
     ```
     CLAUDE.md changes:
       Golden Rules > Don'ts: + "Never reintroduce preview branching (Dispatcher is direct-send only)"
       Key Modules > electron-admin: "4 nav tabs" -> "3 nav tabs: Dashboard / AI / Settings"
       Remove: "Post-Merge Notes (PR #130)" section (content migrated above)
     ```

7. **Update Serena Memory (if Serena MCP available)**

   > **Content-First principle**: Before appending new learnings, scan existing memory for stale or duplicate content and refine it **in place**. Only delete a memory file when its content has been fully migrated elsewhere or becomes orphaned.

   Integrate PR learnings into Serena memory as native content. Learnings should read as if they were always part of the memory -- not as appended post-merge notes.

   **Pre-Audit (clean stamps from existing memory files)**:

   Before `list_memories` -> `read_memory`, grep every memory file against the Core Principle patterns. If hits are found, run the same Step 6 Pre-Audit procedure -- get user approval, then clean (`edit_memory`). After cleanup, proceed to integrate the new learnings.

   The following patterns must be cleaned on sight (matching the "Bad" example below):
   - `## Post-Merge (date, PR #N)` headers -- distribute the content into topical sections, then delete the header
   - `post_merge_prN.md` filenames themselves -- migrate the content into a topical file, then delete the file
   - `(Issue #N)` / `(이슈 #N)` inline citations inside bullets -- strip the citation only, preserve the content

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
   - **Self-check before applying `edit_memory`**: verify the text being added does not contain Core Principle forbidden patterns (`(#N)`, `PR #N`, `이슈 #N`, "Added in PR", etc.). If it does, rewrite first, then apply.

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

→ See **Core Principle: No Stamps, Topical Names, Current State Only** at the top of Step 6.

Summary:
- Never cite a PR or issue inside a normative doc (inline, header, or footnote)
- No `## Post-Merge` style changelog sections; no `post_merge_prN.md` style PR-specific memory files
- No append-only patterns -- update existing sections in place
- No historical narrative -- write in current-state form

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
