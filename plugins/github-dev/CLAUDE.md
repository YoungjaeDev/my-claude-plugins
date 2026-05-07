# GitHub Dev Plugin

GitHub workflow automation commands for Claude Code.

## Commands

| Command | Description |
|---------|-------------|
| `/github-dev:commit-and-push` | Analyze changes, commit with conventional message, push |
| `/github-dev:create-issue-label` | Create standardized issue labels |
| `/github-dev:decompose-issue` | Break down large issues into sub-tasks, define architecture mapping |
| `/github-dev:post-merge` | Clean up branch, integrate PR learnings, sync milestone progress |
| `/github-dev:resolve-issue` | Resolve GitHub issue end-to-end (enhanced with review, verification) |
| `/github-dev:update-progress` | Sync project progress to GitHub milestones/issues with diagrams |
| `/github-dev:cr-fix` | Unified CodeRabbit + ChatGPT-Codex pipeline: wait + fetch + apply + push loop until clean, with optional auto-merge (default OFF; pass `--auto-merge` to enroll). Gates merge on branch-protection presence and on actual CR engagement. CR Refactor suggestions at Minor/Trivial/Info auto-apply; CR substantive items (Bug, Potential issue, Security, Critical/High/Major) and Codex P1/P2 are gated per-issue. CR Nitpicks and Codex P3 are silently skipped. Codex is auto-detected per PR (engaged at least once → ON; never engaged → OFF). Optional `--skip-minor` opt-in silently demotes CR Minor severity (excluding Bug/Security) + Codex P2 to skip, for lint-heavy PRs where the default gated queue is too long. |
| `/github-dev:release` | Create versioned GitHub release with auto-generated changelog |

## resolve-issue Flags

| Flag | Description |
|------|-------------|
| `--skip-review` | Skip 2-stage review (for trusted changes) |
| `--strict` | Treat lint failures as blocking errors |
| `--skip-cr-fix` | Skip the auto cr-fix loop after PR creation (default ON) |
| `--cr-fix-max <n>` | Cap iterations on the auto cr-fix loop (default: 5) |
| `--auto-merge` | Pass through to cr-fix; auto-merge after convergence (default OFF) |
| `--codex-grace <sec>` | Pass through to cr-fix; Codex grace window after CR completes (default: 90) |
| `--no-codex` | Pass through to cr-fix; force-disable Codex auto-detect for the run |
| `--skip-minor` | Pass through to cr-fix; demote CR Minor (excluding Bug/Security) + Codex P2 to skip |

## Worktree Workflow (PR-based)

Use Claude Code's built-in worktree (`claude --worktree <name>`) for isolated PR work:

```bash
claude --worktree feature-auth
# inside the worktree
/github-dev:resolve-issue 42       # creates branch + PR + drives cr-fix
# after PR is merged on GitHub, exit and switch contexts:
/exit                              # cleanup option for the worktree
# in a fresh session at the main repo
/github-dev:post-merge <PR>        # cleanup + integrate learnings
```

**Note:** `post-merge` aborts when run from a worktree (Step 3 checks out the base branch, which conflicts with the original repo's checkout). Exit the worktree first.

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
