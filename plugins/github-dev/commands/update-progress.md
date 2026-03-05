---
description: Sync project progress to GitHub milestones/issues
---

# Update Progress

Manually sync project progress to GitHub milestones and issues. Regenerates architecture diagrams and updates tracking sections. Follow project guidelines in `@CLAUDE.md`.

## Arguments

- Milestone name (optional): Target milestone to update. If omitted, auto-detect from `.omc/state/project-tracking-*.json`

## Flags

| Flag | Description |
|------|-------------|
| `--all` | Update all active milestones (process every state file) |
| `--local` | Skip GitHub sync, only update local state and print to terminal |

## Usage

```
/github-dev:update-progress                    # Auto-detect active milestone
/github-dev:update-progress "v1.0 Auth System" # Specific milestone
/github-dev:update-progress --all              # All active milestones
/github-dev:update-progress --local            # Local only, no GitHub sync
```

## Workflow

1. **Load State File**
   - If milestone name provided: slugify and load `.omc/state/project-tracking-{slug}.json`
   - If `--all`: scan all `.omc/state/project-tracking-*.json` files
   - If no argument: scan for state files, if exactly one found use it, if multiple ask user to select
   - If no state file found: inform user to run `/github-dev:decompose-issue` first to set up tracking

2. **Fetch Latest Issue States from GitHub**
   ```bash
   gh issue list --milestone "<milestoneName>" --state all --json number,title,state,labels --limit 100
   ```

3. **Diff Local vs GitHub State**
   - Detect newly closed issues (local=open, GitHub=closed)
   - Detect newly opened issues (local=closed, GitHub=open -- reopened)
   - Detect new issues added to milestone (not in local state)
   - For new issues not mapped to a module: ask user to assign module or create "unassigned" group

4. **Recalculate Progress**
   - For each module:
     ```
     module.progress = (closed_issues_in_module / total_issues_in_module) * 100
     module.status:
       - "complete"    : all issues closed
       - "in_progress" : at least 1 issue has PR or is closed, and at least 1 is still open
       - "pending"     : all issues open AND no PR exists
     ```
   - Overall:
     ```
     overall_progress = (total_closed_issues / total_issues) * 100
     ```

5. **Generate Diagrams**

   Generate two diagram types from the state file data. Both use the stored `mermaidSource` as base.

   ### Diagram Generation Algorithm

   1. Parse `architecture.mermaidSource` from state file
   2. For each node ID in `architecture.scopeNodes`, append `:::scope` classDef
   3. For each issue, determine status class (`done`/`active`/`pending`)
   4. Generate task list nodes grouped by module, connected by `dependsOn` arrows
   5. Apply classDef definitions at the end

   ### Type M-1: Milestone Overview (for Milestone description + Terminal)

   Renders the full project workflow with scope highlighting and a task summary.

   ````markdown
   ```mermaid
   <mermaidSource from state file, with scopeNodes highlighted>

       %% Milestone scope highlight
       classDef scope fill:#ddf4ff,stroke:#54aeff,stroke-width:3px

       %% Task status appended below architecture
       subgraph tasks ["<milestoneName> Tasks"]
           T1["#12 Push targets"]:::done
           T2["#13 Time window"]:::active
           T3["#14 Template engine"]:::pending
           T1 --> T2
           T2 --> T3
       end

       F --- tasks

       classDef done fill:#2da44e,color:#fff,stroke:#2da44e
       classDef active fill:#1f6feb,color:#fff,stroke:#1f6feb
       classDef pending fill:#6e7781,color:#fff,stroke:#6e7781
   ```

   **Progress: X/Y (ZZ%)**
   ````

   **How to build Type M-1:**
   1. Copy `architecture.mermaidSource` verbatim
   2. For each node ID in `scopeNodes`: append `:::scope` to that node's definition line
   3. Add `subgraph tasks` with all issues, applying status classDef:
      - `:::done` for closed issues
      - `:::active` for issues with PR or in progress
      - `:::pending` for open issues
   4. Add `dependsOn` arrows: if issue #13 has `dependsOn: [12]`, add `T12 --> T13`
   5. Connect task subgraph to its `architectureNode` with `---`
   6. Append all classDef definitions

   ### Type M-2: Issue Context View (for individual Issue/PR body)

   Shows the full workflow with "this issue" highlighted, plus its dependencies.

   ````markdown
   ```mermaid
   <mermaidSource from state file, with this issue's architectureNode highlighted>

       %% This issue's context
       subgraph context ["#13 Time window filter"]
           T13["#13 Time window filter<br/>-- this issue"]:::here
       end

       subgraph deps ["Dependencies"]
           T12["#12 Push targets"]:::done
       end

       subgraph next ["Blocked by this"]
           T14["#14 Template engine"]:::pending
       end

       T12 --> T13
       T13 --> T14
       F --- context

       classDef scope fill:#ddf4ff,stroke:#54aeff,stroke-width:3px
       classDef here fill:#1f6feb,color:#fff,stroke:#1f6feb,stroke-width:3px
       classDef done fill:#2da44e,color:#fff,stroke:#2da44e
       classDef active fill:#1f6feb,color:#fff,stroke:#1f6feb
       classDef pending fill:#6e7781,color:#fff,stroke:#6e7781
   ```

   **Milestone: <milestoneName> -- ZZ% (X/Y)**
   ````

   **How to build Type M-2:**
   1. Copy `architecture.mermaidSource` verbatim
   2. Highlight the current issue's `architectureNode` with `:::scope`
   3. Create `context` subgraph with just this issue node using `:::here`
   4. Create `deps` subgraph with issues this one `dependsOn`
   5. Create `next` subgraph with issues that have `dependsOn` pointing to this issue
   6. Add dependency arrows between issue nodes
   7. Connect context subgraph to its `architectureNode` with `---`

   ### Mermaid Rules

   - Colors: 4 classDefs (`scope=#ddf4ff`, `done=#2da44e`, `active=#1f6feb`, `pending=#6e7781`) + `here` (thick active)
   - Line breaks: `<br/>` only (`\n` forbidden in node text)
   - Node text: wrap in `"` double quotes
   - Max 20 nodes per diagram (architecture + tasks combined)
   - subgraph ID: lowercase English (`subgraph tasks ["Display Name"]`)
   - The `mermaidSource` is never modified -- classDef and subgraphs are appended after it

   ### Fallback: Markdown Table (if Mermaid not rendered)

   If milestone description does not render Mermaid (verify on first use), fall back to:

   ```markdown
   ## <milestoneName> Progress (auto-updated: YYYY-MM-DD)

   | Status | Issue | Title | Depends On |
   |--------|-------|-------|------------|
   | [v] | #12 | Push targets | - |
   | [>] | #13 | Time window | #12 |
   | [ ] | #14 | Template engine | #13 |

   **Progress: X/Y (ZZ%)**
   ```

6. **Update GitHub** (skip if `--local`)

   a. **Milestone description** (Type M-1 Mermaid):
      ```bash
      MILESTONE_NUMBER=$(cat .omc/state/project-tracking-{slug}.json | jq -r '.milestoneId')
      # If milestoneId is null, fetch from API:
      # MILESTONE_NUMBER=$(gh api repos/:owner/:repo/milestones --jq '.[] | select(.title=="<name>") | .number')

      gh api repos/:owner/:repo/milestones/$MILESTONE_NUMBER \
        -X PATCH -f description="$TYPE_M1_MERMAID_DIAGRAM"
      ```
      If Mermaid does not render in milestone description, use the Markdown Table fallback instead.

   b. **Each issue body** (Type M-2 Mermaid, marker-based replacement):
      ```bash
      # For each issue in the milestone:
      CURRENT_BODY=$(gh issue view $ISSUE_NUM --json body --jq '.body')

      # Check for existing markers
      if echo "$CURRENT_BODY" | grep -q "<!-- project-tracking-start -->"; then
        # Replace section between markers
        NEW_BODY=$(echo "$CURRENT_BODY" | sed '/<!-- project-tracking-start -->/,/<!-- project-tracking-end -->/c\<!-- project-tracking-start -->\n'"$TRACKING_SECTION"'\n<!-- project-tracking-end -->')
      else
        # Append tracking section at end
        NEW_BODY="$CURRENT_BODY

      <!-- project-tracking-start -->
      $TRACKING_SECTION
      <!-- project-tracking-end -->"
      fi

      gh issue edit $ISSUE_NUM --body "$NEW_BODY"
      ```

   c. **Open PRs** (Type M-2 Mermaid, same marker logic):
      ```bash
      # For issues with open PRs:
      PR_NUMBER=$(gh pr list --search "head:feat/$ISSUE_NUM" --json number --jq '.[0].number')
      if [ -n "$PR_NUMBER" ]; then
        # Same marker-based replacement as issues
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
   - Update `lastSyncedAt` to current ISO timestamp
   - Update all issue states and module progress values
   - Save to `.omc/state/project-tracking-{slug}.json`

8. **Terminal Output**
   - Print Type M-1 Mermaid diagram to terminal (rendered as code block)
   - Show summary of changes made:
     ```
     Updated: milestone description, N issue bodies, N PR descriptions
     Changes: M issues closed since last sync, K new issues added
     ```

## State File Schema

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
| `architecture.scopeNodes` | Root | Node IDs from mermaidSource that this milestone covers. Highlighted with `:::scope` in diagrams. |
| `modules[].architectureNode` | Module | Which mermaidSource node this module maps to. |
| `issues[].dependsOn` | Issue | Issue numbers this issue depends on. Rendered as arrows in diagrams. |
| `issues[].architectureNode` | Issue | Which mermaidSource node this issue maps to. Inherits from module if not set. |

## Slug Generation

Milestone name to slug: lowercase, spaces to hyphens, remove special characters except hyphens.

```
"v1.0 Auth System" -> "v1-0-auth-system"
"Phase 2: API Gateway" -> "phase-2-api-gateway"
```

## Error Handling

| Scenario | Action |
|----------|--------|
| No state file found | Inform user to run `/github-dev:decompose-issue` first |
| Milestone not found on GitHub | Warn and skip GitHub sync, update local only |
| API rate limit | Report error, suggest `--local` flag |
| Issue not in any module | Ask user to assign module or group as "unassigned" |
| State file version mismatch | Warn and attempt best-effort update |
