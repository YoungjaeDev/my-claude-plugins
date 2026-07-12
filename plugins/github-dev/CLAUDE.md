# GitHub Dev Plugin

GitHub workflow automation skills for Claude Code. All workflows are skills (no command surface), so `/github-dev:<name>` slash calls resolve to the skill and run under both Claude Code and Codex.

## Skills

| Skill | Description |
|---------|-------------|
| `/github-dev:commit-and-push` | Analyze changes, commit with conventional message, push |
| `/github-dev:create-issue-label` | Create standardized issue labels |
| `/github-dev:decompose-issue` | Break down large issues into sub-tasks, define architecture mapping |
| `/github-dev:post-merge` | Clean up branch, integrate PR learnings, sync milestone progress |
| `/github-dev:resolve-issue` | Resolve GitHub issue end-to-end (enhanced with review, verification) |
| `/github-dev:update-progress` | Sync project progress to GitHub milestones/issues with diagrams |
| `/github-dev:cr-fix` | Unified CodeRabbit + ChatGPT-Codex pipeline (multi-file skill at `skills/cr-fix/`): wait + fetch + apply + push loop until clean, with optional auto-merge (default OFF; pass `--auto-merge` to enroll). Gates merge on branch-protection presence and on actual CR engagement. Step 9 v2 judges each finding autonomously: the LLM validates it against local code, reassesses severity and fix size, then applies/defers/skips per the decision matrix — no per-finding AskUserQuestion gate. CR Nitpicks and Codex P3 are silently skipped. Codex is auto-detected per PR (engaged at least once → ON; never engaged → OFF). `--skip-minor` opt-in demotes CR Minor severity (excluding Bug/Security) + Codex P2 to skip. `--cr-source <auto\|pr-bot\|cli\|codex-only>` controls review source; `auto` falls back to the local `coderabbit` CLI or Codex-only when the PR-bot is rate-limited (early-escape ~30s, no more 1800s spin). Minor soft-stop (default ON, `--no-minor-stop` off): from iter 2 a cycle that applied only low-severity fixes with nothing deferred stops at `final_state=minor_floor` (not auto-merge eligible) instead of looping the low-value tail. Bounded same-file generalization (default ON, `--no-generalize` off): a real + high-confidence + grep-able finding also patches sibling occurrences of the same pattern within the same file (audit-logged, never cross-file). 2.8.0 correctness repairs: `cr-commit-state.sh` fetch failures (auth/network/rate-limit) now map to a distinct `state:"error"` channel instead of a clean `none`; `fetch-cr-threads.sh` fails loudly on a null-repository GraphQL response rather than converging false-clean on `[]`; an active `query-cr-rate-limit.sh` (`@coderabbitai rate limit`, id-anchored to its own post) resolves ambiguous passive rate-limit sniffs; check-run `created_at` prefers `completed_at`; `auto-merge-gate.sh` reads CR state through the same dual-surface reader as the rest of the loop, so `--auto-merge` works on check-run-only repos (not just commit-status repos). Fixture suite (`tests/run-tests.sh`) runs in `.githooks/pre-commit` + `validate-codex.yml`. |
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
| `--no-minor-stop` | Pass through to cr-fix; disable the minor soft-stop (default ON — stop from iter 2 on a low-severity-only cycle, `final_state=minor_floor`) |
| `--no-generalize` | Pass through to cr-fix; disable bounded same-file generalization (default ON — patch same-file siblings of a real + high-confidence + grep-able finding) |
| `--cr-source <mode>` | Pass through to cr-fix; review source: `auto` (default, fall back to CLI/codex-only on PR-bot rate-limit), `pr-bot`, `cli`, `codex-only` |

## Hermes Agent

Hermes can install only this plugin from the monorepo subdirectory:

```bash
hermes plugins install YoungjaeDev/my-claude-plugins/plugins/github-dev --enable
hermes gateway restart  # if using Hermes through a messaging gateway
```

Hermes exposes the existing workflows as namespaced plugin skills. Load them explicitly with `skill_view` or ask Hermes to load the qualified skill:

```text
skill_view("github-dev:commit-and-push")
skill_view("github-dev:resolve-issue")  # then provide the issue number in the same request
skill_view("github-dev:cr-fix")         # then provide flags such as --cr-source auto
```

Notes:
- Hermes uses `github-dev:<skill>` qualified skill names rather than Claude slash commands, and plugin-provided skills are explicit opt-in loads.
- Start a fresh Hermes session after enabling the plugin so the plugin skill registry is rebuilt.
- The skill bodies include a Hermes compatibility table mapping Claude/Codex tool terms (`Bash`, `Read`, `Edit`, `AskUserQuestion`, `Task`, `Monitor`) to Hermes tools (`terminal`, `read_file`, `patch`, `clarify`, `delegate_task`, `process`).

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

All commands in this plugin shell out to `gh` and `jq`. Five pitfalls that silently break new bash blocks:

- A `gh api` REST path in a skill body must use gh's literal `{owner}/{repo}` placeholder (auto-resolved from the current repo) — never `$OWNER/$REPO` shell vars unless that skill demonstrably sets them. A skill step that interpolates an unset `$OWNER`/`$REPO` calls `repos//pulls/...` and fails silently or returns nothing. Prefer `gh api "repos/{owner}/{repo}/pulls/<N>/files"` (or `gh pr view/diff <N>`, which carry no repo coordinates) over raw-var REST.
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
