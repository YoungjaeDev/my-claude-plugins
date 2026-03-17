# GitHub Dev Plugin

GitHub workflow automation commands for Claude Code.

## Commands

| Command | Description |
|---------|-------------|
| `/github-dev:cleanup-worktree` | Remove worktrees with optional branch and remote deletion |
| `/github-dev:commit-and-push` | Analyze changes, commit with conventional message, push |
| `/github-dev:create-issue-label` | Create standardized issue labels |
| `/github-dev:create-worktree` | Create worktree with proper branch naming for an issue |
| `/github-dev:decompose-issue` | Break down large issues into sub-tasks, define architecture mapping |
| `/github-dev:post-merge` | Clean up branch, integrate PR learnings, sync milestone progress |
| `/github-dev:resolve-issue` | Resolve GitHub issue end-to-end (enhanced with review, verification) |
| `/github-dev:update-progress` | Sync project progress to GitHub milestones/issues with diagrams |
| `/github-dev:code-review` | Process CodeRabbit review feedback with auto-fix |
| `/github-dev:release` | Create versioned GitHub release with auto-generated changelog |

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
create-worktree #42  →  work  →  PR merge  →  post-merge (branch cleanup)
       ↓                              ↓
  create worktree              cleanup-worktree (worktree removal)
  auto branch naming           can also be used independently for
                               abandoned/experimental worktrees
```

**Limitations:**
- Cannot checkout the same branch in two worktrees simultaneously
- Each worktree requires separate dependency installation (`npm install`, etc.)

## Project Progress Tracking

Tracks milestone progress with architecture diagrams synced to GitHub.

**State file**: `.omc/state/project-tracking-{slug}.json` -- created by `decompose-issue`, updated by `resolve-issue` and `post-merge`

**Diagram types**:
| Type | Format | Used In |
|------|--------|---------|
| Type M-1 | Mermaid (full workflow + task summary) | Terminal output |
| Milestone | Markdown table (status + dependencies) | Milestone description |
| Type M-2 | Mermaid (full workflow + issue context) | Individual issue/PR body |

**Architecture data**: `mermaidSource` (10-20 node workflow captured during decompose-issue) + `scopeNodes` (highlighted nodes for this milestone). Issues have `dependsOn` (execution order) and `architectureNode` (workflow position).

**Trigger points**:
| When | What happens |
|------|-------------|
| `decompose-issue` | Architecture interview, state file + initial diagram created |
| `resolve-issue` | Local state updated (issue marked in_progress) |
| `post-merge` | GitHub auto-sync (milestone desc + issue bodies updated) |
| `update-progress` | Manual full sync with `--all`, `--local` flags |

**Body markers**: `<!-- project-tracking-start -->` / `<!-- project-tracking-end -->` -- only the section between markers is replaced, preserving existing content.

**Diagram colors**: `scope=#ddf4ff` (light blue bg), `done=#2da44e` (green), `active=#1f6feb` (blue), `pending=#6e7781` (gray), `here` (thick active border)

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
