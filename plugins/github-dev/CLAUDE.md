# GitHub Dev Plugin

GitHub workflow automation commands for Claude Code.

## Commands

| Command | Description |
|---------|-------------|
| `/github-dev:commit-and-push` | Analyze changes, commit with conventional message, push |
| `/github-dev:create-issue-label` | Create standardized issue labels |
| `/github-dev:create-worktree` | Create worktree with proper branch naming for an issue |
| `/github-dev:decompose-issue` | Break down large issues into sub-tasks |
| `/github-dev:post-merge` | Clean up after PR merge (auto-detects worktree) |
| `/github-dev:resolve-issue` | Resolve GitHub issue end-to-end (enhanced with review, verification) |
| `/github-dev:code-review` | Process CodeRabbit review feedback with auto-fix |

## resolve-issue Flags

| Flag | Description |
|------|-------------|
| `--skip-review` | Skip 2-stage review (for trusted changes) |
| `--strict` | Treat lint failures as blocking errors |

## Recommended Worktree Workflow

For parallel development, create worktrees before starting Claude sessions (Boris Cherny's approach):

```bash
# Option 1: Use create-worktree command (auto branch naming)
/github-dev:create-worktree #42
# Output: cd ../fix-42-login-bug && claude

# Option 2: Manual creation
git worktree add ../fix-42-login-bug -b fix/42-login-bug
cd ../fix-42-login-bug && claude
```

**Branch Naming Convention:**
- `fix/{issue}-{slug}` - bug fixes
- `feat/{issue}-{slug}` - new features
- `refactor/{issue}-{slug}` - refactoring
- `docs/{issue}-{slug}` - documentation

This keeps the starting directory and working directory the same, avoiding path confusion.

**Worktree Lifecycle:**
```
create-worktree #42  →  work  →  PR merge  →  post-merge (auto cleanup)
       ↓                                            ↓
  create worktree                           if worktree detected
  auto branch naming                        prompt for removal
```

**Limitations:**
- Cannot checkout the same branch in two worktrees simultaneously
- Each worktree requires separate dependency installation (`npm install`, etc.)

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
