# GitHub Dev Plugin

GitHub workflow automation commands for Claude Code.

## Commands

| Command | Description |
|---------|-------------|
| `/gh:commit-and-push` | Analyze changes, commit with conventional message, push |
| `/gh:create-issue-label` | Create standardized issue labels |
| `/gh:decompose-issue` | Break down large issues into sub-tasks |
| `/gh:post-merge` | Clean up after PR merge |
| `/gh:resolve-issue` | Resolve GitHub issue end-to-end |
| `/gh:code-review` | Process CodeRabbit review feedback with auto-fix |

## Requirements

- `gh` CLI installed and authenticated
- GitHub repository with proper permissions

## Task Tool 2.1.16 Syntax

This plugin uses oh-my-claudecode agents with Task Tool 2.1.16:

```
Task(
  subagent_type="oh-my-claudecode:explore",
  model="haiku",
  prompt="..."
)
```

### Model Selection Guide

| Task Type | Agent | Model |
|-----------|-------|-------|
| Code search | `explore` | `haiku` |
| Implementation | `executor` | `sonnet` |
| Complex refactoring | `executor-high` | `opus` |
| Test writing | `executor` | `sonnet` |
| Validation | `executor-low` | `haiku` |
