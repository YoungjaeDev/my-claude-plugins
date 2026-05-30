# GitHub Dev Plugin

GitHub workflow automation for Claude Code.

## Skills

All workflows are auto-triggering skills (not slash commands) — describe your
intent in natural language and Claude invokes them. They are also exported to
Codex as native `$<name>` skills.

| Skill | Description |
|-------|-------------|
| `commit-and-push` | Analyze the named files, commit with a conventional message, push |
| `create-issue-labels` | Analyze the project and create standardized issue labels |
| `decompose-issue` | Break down a large work item into sub-issues, define architecture mapping (gated GitHub creation) |
| `post-merge` | Clean up the merged branch, integrate PR learnings, sync milestone progress (destructive: previews + confirms) |
| `resolve-issue` | Resolve a GitHub issue end-to-end (review + verification + cr-fix loop; auto-merge OFF by default) |
| `update-progress` | Sync project progress to GitHub milestones/issues with diagrams (write-back gated) |
| `cr-fix` | Unified CodeRabbit + ChatGPT-Codex pipeline (multi-file skill at `skills/cr-fix/`): wait + fetch + apply + push loop until clean, with optional auto-merge (default OFF). Gates merge on branch-protection presence and on actual CR engagement. CR Refactor suggestions at Minor/Trivial/Info auto-apply; CR substantive items (Bug, Potential issue, Security, Critical/High/Major) and Codex P1/P2 are gated per-issue. CR Nitpicks and Codex P3 are silently skipped. Codex is auto-detected per PR. The skip-minor option demotes CR Minor severity (excluding Bug/Security) + Codex P2 to skip. The review source (`auto`/`pr-bot`/`cli`/`codex-only`) falls back to the local `coderabbit` CLI or Codex-only when the PR-bot is rate-limited (early-escape ~30s). |
| `release` | Create a versioned GitHub release with auto-generated changelog (previews + confirms before tagging/pushing) |

## resolve-issue options

`resolve-issue` infers these from your wording (conservative defaults):

| Option | Default | Effect |
|--------|---------|--------|
| 2-stage review | ON | Spec + quality review before PR (say "skip review" to disable) |
| Strict lint | OFF (warn) | Treat lint failures as blocking |
| Auto cr-fix loop | ON | Run cr-fix after PR creation (say "skip cr-fix" to disable) |
| cr-fix max iterations | 5 | Cap the cr-fix loop |
| **Auto-merge** | **OFF** | Only on an explicit auto-merge request; merges only after convergence |
| Codex grace window | 90s | Extra wait after CodeRabbit for ChatGPT-Codex comments |
| Codex auto-detect | ON | Disable to force-skip Codex |
| Skip minor CR severities | OFF | Shrink the gated queue on lint-heavy PRs |
| cr-fix review source | `auto` | `auto` (fallback to CLI/codex-only on rate-limit), `pr-bot`, `cli`, `codex-only` |

## Worktree Workflow (PR-based)

Use Claude Code's built-in worktree (`claude --worktree <name>`) for isolated PR work:

```bash
claude --worktree feature-auth
# inside the worktree: "resolve issue 42" -> resolve-issue skill
#   (creates branch + PR + drives cr-fix)
# after PR is merged on GitHub, exit and switch contexts:
/exit                              # cleanup option for the worktree
# in a fresh session at the main repo: "post-merge cleanup for PR <PR>"
#   -> post-merge skill (cleanup + integrate learnings)
```

**Note:** `post-merge` aborts when run from a worktree (Step 3 checks out the base branch, which conflicts with the original repo's checkout). Exit the worktree first.

## Project Progress Tracking

Tracks milestone progress with architecture diagrams synced to GitHub.

**State file**: `.claude/state/project-tracking-{slug}.json` -- created by `decompose-issue`, updated by `resolve-issue` and `post-merge`

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

## gh / jq Invariants

All commands in this plugin shell out to `gh` and `jq`. Four pitfalls that silently break new bash blocks:

- `gh ... --jq <expr>` accepts a single filter string and does NOT forward jq CLI flags (`--arg`, `--argjson`). Variable injection requires the pipe form: `gh ... | jq --arg name "$value" '...'`. Trying `gh ... --jq --arg name "$v" '...'` fails with `accepts 1 arg(s), received 4`.
- REST endpoints (`/pulls/{pr}/reviews`, `/issues/{pr}/comments`, `/commits/{sha}/statuses`) default to `per_page=30` and return paginated results. On long-lived PRs or CI-heavy SHAs the first page can be all-old or all-newest-30 — use `gh api --paginate ... | jq -s 'add // []' | jq ...` to slurp every page into a single array before filtering.
- `/commits/{sha}/statuses` (plural) returns every individual status event; `/commits/{sha}/status` (singular) collapses to one latest entry per context. The singular endpoint hides early `pending` entries, so use plural when the earliest moment a SHA was observed matters.
- Commit `committer.date` is git metadata — cherry-picks, rebases, or stale-commit pushes make it arbitrarily older than the actual push. For "when did GitHub first see this SHA" use the earliest `/statuses` `created_at`; `committer.date` is acceptable only as a last-resort fallback when no statuses exist yet.

## Task Tool 2.1.16 Syntax

This plugin uses Claude Code built-in agents with Task Tool 2.1.16:

```
Task(
  subagent_type="Explore",
  prompt="..."
)
```

### Model Selection Guide

| Task Type | Agent | Model |
|-----------|-------|-------|
| Code search | `Explore` | auto |
| Implementation | `claude` | `sonnet` |
| Complex refactoring | `claude` | `opus` |
| Test writing | `claude` | `sonnet` |
| Validation | `claude` | `haiku` |
