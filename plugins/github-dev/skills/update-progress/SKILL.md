---
name: update-progress
description: Sync a project's milestone/issue progress to GitHub — recompute module progress from current issue states, regenerate the architecture diagrams, and update milestone description + issue/PR bodies. Use when the user explicitly wants to refresh or sync project-tracking progress to GitHub milestones/issues (e.g. "update progress", "sync the milestone tracking", "refresh the progress diagrams"). Requires a `.claude/state/project-tracking-*.json` created by decompose-issue. Writes back to GitHub — preview the changes and confirm (or stay local-only) before editing remote bodies.
---

# Update Progress

Sync project progress to GitHub milestones and issues. Regenerates architecture
diagrams (per the canonical spec in `references/diagram-spec.md`) and updates
tracking sections. Read the project CLAUDE.md at runtime and follow it.

## Infer target and scope

There is no explicit argument string — infer from the user's request:

- A named milestone → load that one.
- "all milestones" / "every milestone" → process every state file.
- No target named → scan `.claude/state/project-tracking-*.json`; if exactly one
  exists, use it; if several, ask which.
- "local only" / "don't touch GitHub" / a read-only feel → run local-only (skip
  the GitHub write-back in Step 6).

## Safety: this writes back to GitHub

Step 6 edits milestone descriptions and issue/PR bodies on GitHub — visible,
shared changes. Compute the diff and **preview what will change, then confirm
before writing**, unless the user has clearly asked for a full sync. When in
doubt, do the local-only update (Steps 1-5, 7-8) and show the result first.

## Workflow

1. **Load State File**
   - Named milestone: slugify and load `.claude/state/project-tracking-{slug}.json`
   - All milestones: scan all `.claude/state/project-tracking-*.json` files
   - None named: scan; if one, use it; if several, ask
   - No state file found: tell the user to run the `decompose-issue` skill first

2. **Fetch Latest Issue States from GitHub**
   ```bash
   gh issue list --milestone "<milestoneName>" --state all --json number,title,state,labels --limit 100
   ```

3. **Diff Local vs GitHub State**
   - Newly closed issues (local=open, GitHub=closed)
   - Newly reopened issues (local=closed, GitHub=open)
   - New issues added to the milestone (not in local state)
   - For new issues not mapped to a module: ask user to assign a module or create an "unassigned" group

4. **Recalculate Progress**
   - Per module:
     ```
     module.progress = (closed_issues_in_module / total_issues_in_module) * 100
     module.status:
       - "complete"    : all issues closed
       - "in_progress" : >=1 issue has a PR or is closed, and >=1 is still open
       - "pending"     : all issues open AND no PR exists
     ```
   - Overall: `overall_progress = (total_closed_issues / total_issues) * 100`

5. **Generate Diagrams**

   Build the three diagram outputs (Type M-1 ASCII for terminal, Type M-2 Mermaid
   for issue/PR bodies, Markdown Table for the milestone description) exactly per
   the canonical spec in `references/diagram-spec.md` — the generation algorithm,
   per-type build steps, Mermaid rules, colors, and body markers all live there.

6. **Update GitHub** (skip if local-only)

   Use marker-based replacement so existing body content is preserved — only the
   section between `<!-- project-tracking-start -->` and
   `<!-- project-tracking-end -->` is replaced.

   a. **Milestone description** (Markdown Table):
      ```bash
      MILESTONE_NUMBER=$(cat .claude/state/project-tracking-{slug}.json | jq -r '.milestoneId')
      # If milestoneId is null, fetch from API:
      # MILESTONE_NUMBER=$(gh api repos/:owner/:repo/milestones --jq '.[] | select(.title=="<name>") | .number')

      gh api repos/:owner/:repo/milestones/$MILESTONE_NUMBER \
        -X PATCH -f description="$MILESTONE_TABLE"
      ```

   b. **Each issue body** (Type M-2 Mermaid, marker-based):
      ```bash
      CURRENT_BODY=$(gh issue view $ISSUE_NUM --json body --jq '.body')
      if echo "$CURRENT_BODY" | grep -q "<!-- project-tracking-start -->"; then
        NEW_BODY=$(echo "$CURRENT_BODY" | sed '/<!-- project-tracking-start -->/,/<!-- project-tracking-end -->/c\<!-- project-tracking-start -->\n'"$TRACKING_SECTION"'\n<!-- project-tracking-end -->')
      else
        NEW_BODY="$CURRENT_BODY

      <!-- project-tracking-start -->
      $TRACKING_SECTION
      <!-- project-tracking-end -->"
      fi
      gh issue edit $ISSUE_NUM --body "$NEW_BODY"
      ```

   c. **Open PRs** (Type M-2 Mermaid, same marker logic):
      ```bash
      PR_NUMBER=$(gh pr list --search "head:feat/$ISSUE_NUM" --json number --jq '.[0].number')
      if [ -n "$PR_NUMBER" ]; then
        gh pr edit $PR_NUMBER --body "$NEW_PR_BODY"
      fi
      ```

   The tracking section inserted between markers:
   ```markdown
   <!-- project-tracking-start -->
   ## Progress (auto-updated: YYYY-MM-DD)

   <Type M-2 Mermaid diagram for this issue's context>

   <!-- project-tracking-end -->
   ```

7. **Save State File**
   - Update `lastSyncedAt` to the current ISO timestamp
   - Update all issue states and module progress values
   - Save to `.claude/state/project-tracking-{slug}.json`

8. **Terminal Output**
   - Print the Type M-1 ASCII diagram
   - Summarize changes:
     ```
     Updated: milestone description, N issue bodies, N PR descriptions
     Changes: M issues closed since last sync, K new issues added
     ```

## State File Schema

This schema is the shared contract for the project-tracking system (created by
decompose-issue, updated by resolve-issue / post-merge / this skill).

```json
{
  "version": "2.0.0",
  "milestoneId": 5,
  "milestoneName": "v1.0 Auth System",
  "milestoneSlug": "v1-0-auth-system",
  "repoOwner": "user",
  "repoName": "my-app",
  "createdAt": "ISO timestamp",
  "lastSyncedAt": "ISO timestamp",
  "architecture": {
    "description": "Project architecture description",
    "mermaidSource": "flowchart TD\n    A[Bot Loop] --> B[scan]\n    B --> C{new?}\n    C -->|yes| D[pipeline]\n    C -->|no| E[AI]\n    E --> F[push]",
    "scopeNodes": ["F", "G"]
  },
  "modules": [
    {
      "id": "module-id",
      "name": "Module Name",
      "architectureNode": "F",
      "issues": [12, 13],
      "status": "pending|in_progress|complete",
      "progress": 0
    }
  ],
  "issues": {
    "12": {
      "title": "Issue title",
      "state": "open|closed",
      "pr": null,
      "moduleId": "module-id",
      "dependsOn": [11],
      "architectureNode": "F"
    }
  },
  "diagramMarkers": {
    "start": "<!-- project-tracking-start -->",
    "end": "<!-- project-tracking-end -->"
  }
}
```

### Schema Field Reference

| Field | Location | Description |
|-------|----------|-------------|
| `architecture.mermaidSource` | Root | Full project workflow as Mermaid code (10-20 nodes). Captured during decompose-issue interview. |
| `architecture.scopeNodes` | Root | Node IDs from mermaidSource that this milestone covers. Highlighted with `:::scope`. |
| `modules[].architectureNode` | Module | Which mermaidSource node this module maps to. |
| `issues[].dependsOn` | Issue | Issue numbers this issue depends on. Rendered as arrows. |
| `issues[].architectureNode` | Issue | Which mermaidSource node this issue maps to. Inherits from module if not set. |

## Slug Generation

Milestone name → slug: lowercase, spaces to hyphens, remove special characters except hyphens.

```
"v1.0 Auth System" -> "v1-0-auth-system"
"Phase 2: API Gateway" -> "phase-2-api-gateway"
```

## Error Handling

| Scenario | Action |
|----------|--------|
| No state file found | Tell the user to run the `decompose-issue` skill first |
| Milestone not found on GitHub | Warn and skip GitHub sync, update local only |
| API rate limit | Report error, suggest local-only |
| Issue not in any module | Ask user to assign a module or group as "unassigned" |
| State file version mismatch | Warn and attempt best-effort update |
