---
name: show-progress
description: |
  Display current workflow progress as ASCII visualization.
  Trigger: "show progress", "workflow status", "진행 상황"
version: 1.0.0
allowed-tools:
  - Read
  - Bash
---

# Show Progress Skill

Display current system workflow progress with ASCII visualization.

## Trigger Keywords

- "show progress"
- "workflow status"
- "진행 상황"
- "진행 상태"
- "/workflow-viz:show-progress"

## Workflow

### Step 1: Load State

Read current progress from `.claude/state/workflow-progress.json`.

If file doesn't exist, show "No active workflow" message.

### Step 2: Detect Active Workflows

Check for active state files:
- `.claude/state/github-dev-*.json` (excluding archive/)

### Step 3: Generate ASCII Visualization

**System Overview Format:**

```
+===========================================================+
|              my-claude-plugins System Status              |
+===========================================================+

  [Core]              [Development]         [Research]
  +-------------+     +-------------+      +-------------+
  | core-config |     | github-dev  |      | code-scout  |
  | [ACTIVE]    |     | [ACTIVE]    |      | [IDLE]      |
  +-------------+     +-------------+      +-------------+
                      | docs-forge  |      | deepwiki    |
                      | [IDLE]      |      | [IDLE]      |
                      +-------------+      +-------------+

  Active Workflow: github-dev:resolve-issue (phase 4/9)

  Progress: [████████░░░░░░░░] 50%

  Recent Tasks:
  [done] Analyze requirements
  [done] Create plan
  [>>>>] Implementing feature
  [    ] Write tests
  [    ] Review

+===========================================================+
```

**Detailed Workflow Format (when active):**

```
+-----------------------------------------------------------+
|                  github-dev:resolve-issue                  |
|                       Issue #123                           |
+-----------------------------------------------------------+

  Phase Progress:

  [done] 1. Analyze Issue
  [done] 2. Verify Plan
  [done] 3. Create Branch
  [>>>>] 4. Implement          <-- Current
  [    ] 5. Write Tests
  [    ] 6. Validate
  [    ] 7. Review
  [    ] 8. Create PR
  [    ] 9. Cleanup

  +------------------+------------------+------------------+
  |  Phase 1-3       |  Phase 4 (NOW)   |  Phase 5-9      |
  |  [████████]      |  [████░░░░]      |  [░░░░░░░░]     |
  |  COMPLETE        |  IN PROGRESS     |  PENDING        |
  +------------------+------------------+------------------+

  Time Elapsed: 12m 34s
  Checkpoints: 3 saved

+-----------------------------------------------------------+
```

### Step 4: Output

Display the ASCII visualization directly in the response.

Include links to detailed Mermaid diagrams:
- `docs/architecture/system-overview.md`
- `docs/architecture/workflows/{plugin}.md`

## ASCII Characters Reference

| Symbol | Meaning |
|--------|---------|
| `[done]` | Phase completed |
| `[>>>>]` | Currently executing |
| `[    ]` | Pending |
| `[FAIL]` | Failed (needs attention) |
| `████` | Progress filled |
| `░░░░` | Progress empty |
| `+--+` | Box corners |
| `\|` | Box sides |
| `===` | Header separator |

## Status Indicators

| Indicator | Plugin Status |
|-----------|--------------|
| `[ACTIVE]` | Currently executing |
| `[IDLE]` | No active workflow |
| `[ERROR]` | Has errors |
| `[DONE]` | Recently completed |

## Example Output

When user says "show progress":

```
Checking workflow state...

+===========================================================+
|              my-claude-plugins System Status              |
+===========================================================+

  Currently Active: github-dev:resolve-issue #42

  +-----------------------------------------------------------+
  |  [done] analyze -> [done] plan -> [>>>>] implement -> ... |
  +-----------------------------------------------------------+

  Progress: [████████████░░░░░░░░] 60% (7/12 phases)

  Next: Write tests (phase 8)

+===========================================================+

Detailed diagrams:
- System: docs/architecture/system-overview.md
- Workflow: docs/architecture/workflows/github-dev.md
```

## Notes

- ASCII visualization is optimized for 80-column terminals
- Use box-drawing characters for clean appearance
- Update state file location if project structure changes
- Visualization is read-only; does not modify state
