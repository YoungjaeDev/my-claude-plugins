# GitHub Dev Plugin

GitHub workflow automation commands for Claude Code.

## Commands

| Command | Description |
|---------|-------------|
| `/github-dev:commit-and-push` | Analyze changes, commit with conventional message, push |
| `/github-dev:create-issue-label` | Create standardized issue labels |
| `/github-dev:decompose-issue` | Break down large issues into sub-tasks, define architecture mapping |
| `/github-dev:merge-worktree` | Squash merge worktree branch to base branch with learning integration |
| `/github-dev:post-merge` | Clean up branch, integrate PR learnings, sync milestone progress |
| `/github-dev:resolve-issue` | Resolve GitHub issue end-to-end (enhanced with review, verification) |
| `/github-dev:update-progress` | Sync project progress to GitHub milestones/issues with diagrams |
| `/github-dev:code-review` | Process CodeRabbit review feedback with auto-fetch (no copy-paste) or manual paste fallback |
| `/github-dev:cr-wait` | Wait for CodeRabbit GitHub commit-status to flip from pending (background poll + Monitor) |
| `/github-dev:release` | Create versioned GitHub release with auto-generated changelog |
| `/github-dev:cleanup` | Archive or delete stale files (OMC state, build artifacts, logs, old docs, user paths) |

## resolve-issue Flags

| Flag | Description |
|------|-------------|
| `--skip-review` | Skip 2-stage review (for trusted changes) |
| `--strict` | Treat lint failures as blocking errors |

## Recommended Worktree Workflow

Use Claude Code built-in worktree support for parallel development:

```bash
# Create worktree (built-in)
claude --worktree feature-auth

# Work inside worktree, then merge back
/github-dev:merge-worktree

# Exit with cleanup (built-in)
/exit  # select cleanup option
```

**Worktree Lifecycle:**
```
claude --worktree <name>  -->  work  -->  /merge-worktree  -->  /exit (cleanup)
     (built-in)                          (squash merge +        (built-in)
                                          learning integration)
```

**Flags:**
| Flag | Description |
|------|-------------|
| `--target <branch>` | Base branch (default: auto-detect main/master) |
| `--no-squash` | Use merge --no-ff instead of squash |
| `--skip-learning` | Skip learning integration |

**Limitations:**
- Cannot checkout the same branch in two worktrees simultaneously
- Each worktree requires separate dependency installation (`npm install`, etc.)
- merge-worktree checks out the target branch in the original repo (may affect other sessions)

## Project Progress Tracking

Tracks milestone progress with architecture diagrams synced to GitHub.

**State file**: `.omc/state/project-tracking-{slug}.json` -- created by `decompose-issue`, updated by `resolve-issue` and `post-merge`

**Diagram types**:
| Type | Format | Used In |
|------|--------|---------|
| Type M-1 | ASCII (workflow + task summary) | Terminal output |
| Milestone | Markdown table (status + dependencies) | Milestone description |
| Type M-2 | Mermaid (full workflow + issue context) | Individual issue/PR body |

**Output format by medium**:
| Output Medium | Format | Reason |
|---------------|--------|--------|
| GitHub Issue/PR body | Mermaid | GitHub markdown renderer supports it |
| Milestone description | Markdown Table | GitHub milestones don't render Mermaid |
| Terminal (session output) | ASCII diagram | Terminal can't render Mermaid |
| State file (storage) | Mermaid source | Raw data for generating Issue/PR diagrams |

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
