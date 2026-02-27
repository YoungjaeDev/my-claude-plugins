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

   Generate three diagram types from the state file data:

   ### Type A: ASCII (for Milestone description + Terminal output)

   ```
   Architecture (auto-updated: YYYY-MM-DD)

     [Layer1]         [Layer2]          [Layer3]      <--+
      Tech1            Tech2             Tech3           |
                                                         | Milestone
     [Layer4]         [Layer5]          [Layer6]      <--+ Name
                          |
                     [Layer7]

   --- <milestoneName> (this milestone) ---

     [Module1]              [Module2]             [Module3]
      [v] #N Title           [>] #N Title          [ ] #N Title
      [>] #N Title           [ ] #N Title          [ ] #N Title

   Tasks:
     [v] #N  Title (closed)
     [>] #N  Title (in progress / has PR)
     [ ] #N  Title (open)

   Progress: ====>                              X/Y (ZZ%)
   ```

   **ASCII Symbols:**
   | Symbol | Meaning |
   |--------|---------|
   | `[v]`  | Issue closed (complete) |
   | `[>]`  | Issue has PR or in progress |
   | `[ ]`  | Issue open (pending) |
   | `<--`  | Milestone scope indicator |

   ### Type B-1: Mermaid Full Architecture (for Issue/PR body)

   ````markdown
   ```mermaid
   graph TD
       subgraph arch ["Full Architecture"]
           LAYER1["LayerName<br/>Tech"]
           LAYER2["LayerName<br/>Tech"]
       end

       subgraph scope ["<milestoneName> -- this milestone"]
           MOD1["ModuleName<br/>Tech"]
           MOD2["ModuleName<br/>Tech"]
       end

       LAYER1 --> LAYER2
       LAYER2 --> MOD1
       MOD1 --> MOD2

       subgraph tasks ["Tasks"]
           T1["#N Title"]:::done
           T2["#N Title"]:::active
           T3["#N Title"]:::pending
       end

       MOD1 --- T1 & T2
       MOD2 --- T3

       classDef done fill:#2da44e,color:#fff,stroke:#2da44e
       classDef active fill:#1f6feb,color:#fff,stroke:#1f6feb
       classDef pending fill:#6e7781,color:#fff,stroke:#6e7781

       style scope fill:#ddf4ff,stroke:#54aeff,stroke-width:2px
   ```

   **Progress: X/Y (ZZ%)**
   ````

   ### Type B-2: Mermaid Focused View (for specific Issue/PR body)

   ````markdown
   ```mermaid
   graph LR
       subgraph module ["<ModuleName>"]
           T1["#N Title"]:::done
           T2["#N Title<br/>-- this issue"]:::active
       end

       subgraph deps ["Dependencies"]
           T3["#N Title"]:::active
           T4["#N Title"]:::pending
       end

       T1 --> T2
       T2 -.-> T3
       T2 -.-> T4

       classDef done fill:#2da44e,color:#fff,stroke:#2da44e
       classDef active fill:#1f6feb,color:#fff,stroke:#1f6feb,stroke-width:3px
       classDef pending fill:#6e7781,color:#fff,stroke:#6e7781
   ```

   **Milestone: <milestoneName> -- ZZ% (X/Y)**
   ````

   **Mermaid Rules:**
   - Colors: only 3 (`done=#2da44e`, `active=#1f6feb`, `pending=#6e7781`)
   - Line breaks: `<br/>` only (`\n` forbidden)
   - Node text: wrap in `"` double quotes
   - Max 20 nodes per diagram
   - subgraph ID: lowercase English (`subgraph scope ["Display Name"]`)

6. **Update GitHub** (skip if `--local`)

   a. **Milestone description** (Type A ASCII):
      ```bash
      MILESTONE_NUMBER=$(cat .omc/state/project-tracking-{slug}.json | jq -r '.milestoneId')
      # If milestoneId is null, fetch from API:
      # MILESTONE_NUMBER=$(gh api repos/:owner/:repo/milestones --jq '.[] | select(.title=="<name>") | .number')

      gh api repos/:owner/:repo/milestones/$MILESTONE_NUMBER \
        -X PATCH -f description="$TYPE_A_ASCII_DIAGRAM"
      ```

   b. **Each issue body** (Type B-2 Mermaid, marker-based replacement):
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

   c. **Open PRs** (Type B-2 Mermaid, same marker logic):
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

   <Type B-2 Mermaid diagram for this issue's module>

   <!-- project-tracking-end -->
   ```

7. **Save State File**
   - Update `lastSyncedAt` to current ISO timestamp
   - Update all issue states and module progress values
   - Save to `.omc/state/project-tracking-{slug}.json`

8. **Terminal Output**
   - Print Type A ASCII diagram to terminal
   - Show summary of changes made:
     ```
     Updated: milestone description, N issue bodies, N PR descriptions
     Changes: M issues closed since last sync, K new issues added
     ```

## State File Schema

```json
{
  "version": "1.0.0",
  "milestoneId": 5,
  "milestoneName": "v1.0 Auth System",
  "milestoneSlug": "v1-0-auth-system",
  "repoOwner": "user",
  "repoName": "my-app",
  "createdAt": "ISO timestamp",
  "lastSyncedAt": "ISO timestamp",
  "architecture": {
    "description": "Project architecture description",
    "layers": [
      {
        "id": "layer-id",
        "name": "Layer Name",
        "tech": "Technology",
        "dependsOn": [],
        "inScope": false
      }
    ]
  },
  "modules": [
    {
      "id": "module-id",
      "name": "Module Name",
      "layerId": "layer-id",
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
      "moduleId": "module-id"
    }
  },
  "diagramMarkers": {
    "start": "<!-- project-tracking-start -->",
    "end": "<!-- project-tracking-end -->"
  }
}
```

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
