# GitHub Dev Plugin

GitHub workflow automation commands for Claude Code.

## Commands

| Command | Description |
|---------|-------------|
| `/github-dev:commit-and-push` | Analyze changes, commit with conventional message, push |
| `/github-dev:create-issue-label` | Create standardized issue labels |
| `/github-dev:decompose-issue` | Break down large issues into sub-tasks |
| `/github-dev:parallel-resolve` | Resolve multiple issues in parallel using worktrees |
| `/github-dev:post-merge` | Clean up after PR merge |
| `/github-dev:resolve-issue` | Resolve GitHub issue end-to-end (enhanced with worktree, review, verification) |
| `/github-dev:code-review` | Process CodeRabbit review feedback with auto-fix |

## resolve-issue Flags

| Flag | Description |
|------|-------------|
| `--worktree` | Use isolated git worktree for implementation |
| `--skip-review` | Skip 2-stage review (for trusted changes) |
| `--strict` | Treat lint failures as blocking errors |

## parallel-resolve Flags

| Flag | Description |
|------|-------------|
| `--milestone` | Resolve all open issues in milestone |
| `--label` | Resolve all open issues with label |
| `--max-workers` | Maximum parallel workers (default: 5) |
| `--skip-review` | Skip 2-stage review for all issues |
| `--strict` | Treat lint failures as blocking |

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
