---
description: Parallel Issue Resolution
---

# Parallel Issue Resolution

Resolve multiple GitHub issues in parallel using worktree isolation.

## Usage

```bash
# Resolve specific issues
/github-dev:parallel-resolve #1 #2 #3

# Resolve all issues in a milestone
/github-dev:parallel-resolve --milestone "v2.0"

# Resolve all issues with a label
/github-dev:parallel-resolve --label "ready-for-dev"
```

## Workflow

### 1. Collect Issues

```bash
# From arguments
ISSUES="$@"

# From milestone
gh issue list --milestone "$MILESTONE" --state open --json number -q '.[].number'

# From label
gh issue list --label "$LABEL" --state open --json number -q '.[].number'
```

### 2. Detect Dependencies

Analyze issue bodies for dependency patterns:

**Dependency Indicators:**
- `depends on #N`
- `blocked by #N`
- `after #N`
- `requires #N`

```
Task(
  subagent_type="oh-my-claudecode:explore",
  model="haiku",
  prompt="Analyze dependencies for these issues:
    ${ISSUE_LIST}
    Return JSON: {
      dependencies: {1: [], 2: [1], 3: [1, 2]},
      independent: [1, 4, 5],
      sequential: [[2], [3]]
    }"
)
```

### 3. Parallel Execution

Launch independent issues in parallel (max 5 concurrent):

```
for ISSUE in $INDEPENDENT_ISSUES; do
  Task(
    subagent_type="oh-my-claudecode:executor",
    model="sonnet",
    prompt="Execute /github-dev:resolve-issue ${ISSUE} --worktree
      Work in isolated worktree (path: {type}-{issue}-{slug})
      Follow full resolve-issue workflow including 2-stage review."
  )
done
```

### 4. Sequential Execution

Dependent issues execute in order after their dependencies complete.

### 5. Progress Tracking

State file: `.omc/state/parallel-resolve-{timestamp}.json`

```json
{
  "sessionId": "parallel-{timestamp}",
  "issues": {
    "1": { "status": "complete", "prUrl": "...", "branch": "fix/1-login-bug" },
    "2": { "status": "in_progress", "worktree": "../worktrees/feat-2-add-auth", "branch": "feat/2-add-auth" },
    "3": { "status": "pending", "blockedBy": [1, 2] }
  }
}
```

### 6. Summary Report

```
Parallel Resolution Complete
============================
Total: 5 issues
Success: 4
Failed: 1

Results:
  #1 - [SUCCESS] PR #101 created
  #2 - [SUCCESS] PR #102 created
  #3 - [FAILED] Build error in src/api.ts
  #4 - [SUCCESS] PR #103 created
  #5 - [SUCCESS] PR #104 created

Failed issue #3 worktree preserved: ../worktrees/feat-3-add-api-endpoint
```

## Limitations

- Maximum 5 parallel workers (prevents resource exhaustion)
- Each worker uses its own worktree (no conflicts)
- Partial failures do not block successful issues
- Failed issue worktrees are preserved for debugging

## Flags

| Flag | Description |
|------|-------------|
| `--milestone` | Resolve all open issues in milestone |
| `--label` | Resolve all open issues with label |
| `--max-workers` | Maximum parallel workers (default: 5) |
| `--skip-review` | Skip 2-stage review for all issues |
| `--strict` | Treat lint failures as blocking |
