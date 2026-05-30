---
name: post-merge
description: Run post-merge cleanup after a PR is merged — switch to the base branch, delete the merged local branch (with confirmation), sync milestone/issue tracking, and weave PR learnings into config files (CLAUDE.md / AGENTS.md / rules / Serena memory). Use when the user says a PR was merged and wants cleanup/integration, or names a merged PR number for post-merge. Destructive (branch deletion, base checkout): always previews and confirms before deleting. Aborts if run inside a git worktree.
---

# Post-Merge Cleanup

Perform local branch cleanup and configuration updates after a PR has been merged. For worktree removal, use `/exit` with cleanup option. Read the project CLAUDE.md at runtime and follow it.

## Intent

The workflow operates on one merged PR. Infer the PR number from the user's request or the conversation context. If you cannot determine it, run `gh pr list --state merged --limit 5` to show recent merged PRs and ask the user which one to clean up.

## Workflow

1. **Identify PR**

   **Worktree guard (P0)**: post-merge must run from the main repo, not a worktree. Step 3 checks out the base branch, which collides with the original repo's checkout.

   ```bash
   if [ "$(git rev-parse --git-dir)" != "$(git rev-parse --git-common-dir)" ]; then
     MAIN_REPO=$(cd "$(git rev-parse --git-common-dir)/.." && pwd -P)
     echo "[abort] post-merge cannot run inside a worktree."
     echo "Run /exit (cleanup option), then re-run post-merge from the main repo at $MAIN_REPO"
     exit 1
   fi
   ```

   - Use PR number if it was provided
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
     2. Load state file: `.claude/state/project-tracking-{slug}.json`
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
        - See `../update-progress/references/diagram-spec.md` "Milestone Format: Markdown Table" for full format
     7. Regenerate **Type M-2 Mermaid diagram** (for each issue body in milestone):
        - Read `architecture.mermaidSource` from state file
        - Highlight the issue's `architectureNode` with `:::scope`
        - Create `context` subgraph with this issue, `deps` with `dependsOn` issues, `next` with dependent issues
        - See `../update-progress/references/diagram-spec.md` "Type M-2: Issue Context View" for full format
     8. Update milestone description:
        ```bash
        MILESTONE_NUMBER=$(cat .claude/state/project-tracking-${SLUG}.json | jq -r '.milestoneId')
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

5.7. **Update `.claude/state/spec.json`** (if present)
   - If `.claude/state/spec.json` exists at the repo root, find the entry in `in_progress` whose `linked.pr` matches the merged PR number (or `linked.issue` if no PR ref).
   - Move it to `completed` with `merge_sha` = first 7 chars of the merge commit SHA, `completed_at` = today (UTC `YYYY-MM-DD`). Also set the matching spec file's frontmatter `status: merged`.
   - If no matching entry exists, skip silently (the spec may not have been tracked, e.g., emergency hotfix).
   - The schema and update mechanics are owned by the `spec-state:state-tracker` skill — invoke that skill (e.g. its `complete <spec-path>` operation) rather than direct JSON edit if the plugin is installed; otherwise apply a direct JSON edit using the schema documented in `plugins/spec-state/skills/state-tracker/SKILL.md`.
   - Skip entirely if `.claude/state/` directory does not exist.

5.8. **Trigger wiki ingest (if a wiki layer exists)**
   - Resolve the wiki root in order: `.llmwiki/wiki/` → `.claude/wiki/` → `.codex/wiki/`. Skip silently if none resolves (llm-wiki not in use — no hard dependency).
   - Skip for trivial merges (typo / dep-bump / formatting — reuse `post-merge-wiki`'s own "Do NOT use" list).
   - Otherwise surface via `AskUserQuestion` whether to run the `llm-wiki:post-merge-wiki` skill (that skill derives + gates the ingest candidates itself). Invoke on accept; else note as a manual follow-up.
   - Skip silently if the `post-merge-wiki` skill is not installed.

6. **Integrate Learnings into Configuration Files**

   Read the PR diff (`gh pr diff <PR_NUMBER>`) and PR body to extract learnings, then weave each one into the **appropriate existing section** of the config files (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.claude/rules/*.md`) as if it were always there. Never append "Post-Merge Notes" sections — normative docs hold current rules only, no PR/issue stamps or history narrative. First run the Pre-Audit to scrub existing stamps (gated via `AskUserQuestion`), then self-check every added/modified line against the forbidden-pattern checklist before presenting a diff-style proposal.

   **Full policy** (Core Principle / forbidden patterns / `<!-- history-allowed -->` marker / section naming / writing tone / language consistency / single-source-of-truth, the Pre-Audit procedure, classification + placement tables, Modular Rule Files structure, pre-presentation stamp self-check): see `references/learnings-integration.md`.

6.4. **History Rotation** (sections marked `<!-- history-allowed max=N -->` only)

   After Step 6, for each marked section whose bullet count exceeds N: identify oldest bullets already absorbed into normative sections, present an absorption mapping via `AskUserQuestion`, and remove approved bullets (migrating any unabsorbed nuance first). Unmarked sections and `max`-less markers are skipped. Full procedure: see `references/learnings-integration.md` (Step 6.4).

6.5. **Normative Doc Size Audit**

   After Step 6, measure each normative doc (`CLAUDE.md` / `AGENTS.md` / `GEMINI.md` + one-level `.claude/rules/*.md`) with `wc -m`. Threshold is 32000 chars. If clean, emit `All normative docs within 32k; size audit clean.` and proceed. If any file exceeds it, show a size table and `AskUserQuestion` offering: split with `/rules-forge:split`, improve with the `claude-md-management:claude-md-improver` skill, both, defer, or skip. Full procedure + rationale: see `references/learnings-integration.md` (Step 6.5).

7. **Update Serena Memory (if Serena MCP available)**

   Integrate PR learnings into Serena memory as native, topically-placed content — never new `post_merge_prN.md` files or `## Post-Merge` headers. Run the Pre-Audit stamp scrub on existing memory files first (same as Step 6, gated), then `list_memories` → `read_memory` → place each learning in its best-fit existing section via `edit_memory`, self-checking for forbidden patterns first. Full mapping tables, integration rules, and good/bad examples: see `references/learnings-integration.md` (Step 7). Skip if no significant learnings or Serena unavailable.

8. **Update README.md (if needed)**

   Check if PR introduced changes that affect README:
   - New features or commands
   - Changed installation steps
   - Updated dependencies
   - Modified usage examples
   - Removed features (update feature list)

   If README exists and updates are needed:
   1. Draft the README changes
   2. Apply the `humanizer` humanize skill/command to the changed sections to remove AI-generated patterns
   3. Apply the `docs-forge` `readme` skill guidelines (CRO best practices, structure, clarity)
   4. Present the final proposal to user for confirmation before applying

   Skip if no README-relevant changes.

9. **Commit Changes (Optional)**
   - If any configuration files were modified, prompt user to confirm commit
   - If confirmed: Commit using Conventional Commits format
   - Stage only modified files: `git add CLAUDE.md AGENTS.md GEMINI.md README.md .serena/memories/ 2>/dev/null || true`

> Follow ~/.claude/CLAUDE.md and project CLAUDE.md.
