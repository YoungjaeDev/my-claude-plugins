---
name: resolve-issue
description: Resolve a specific GitHub issue end-to-end — analyze the issue, create a branch, implement (TDD when marked), write tests, run verification gates + 2-stage review, open a PR, and drive the cr-fix review loop. Use when the user wants to work on / implement / fix / resolve a named GitHub issue (e.g. "resolve issue #42", "work on issue 15", "implement #8 and open a PR"). Auto-merge is OFF by default — it never merges without an explicit auto-merge request, and even then only after review convergence.
---

# Resolve GitHub Issue

Act as an expert developer who systematically analyzes and resolves a GitHub
issue. Read the project CLAUDE.md at runtime and follow it.

## Identify the issue and options

There is no explicit argument string — infer the target issue number from the
user's request or the conversation. If no issue is clearly identified, ask which
issue to resolve.

Infer behavior options from the user's wording; conservative defaults apply:

| Option | Default | Turn on when the user… |
|--------|---------|------------------------|
| 2-stage review | ON | (leave on unless they say skip review / trusted change) |
| Strict lint (block on lint) | OFF (warn only) | asks to treat lint as blocking |
| Auto cr-fix loop after PR | ON | (leave on unless they say skip cr-fix) |
| cr-fix max iterations | 5 | gives a specific cap |
| **Auto-merge** | **OFF** | **only on an explicit auto-merge request (see the guard in Step 10.5)** |
| Codex grace window | 90s | gives a specific window |
| Codex auto-detect | ON | asks to disable Codex |
| Skip minor CR severities | OFF | asks to shrink the gated queue |
| cr-fix review source | `auto` | locks to pr-bot / cli / codex-only |

> For parallel development, create worktrees manually before starting Claude sessions. See the project CLAUDE.md for the recommended worktree workflow.

## Prerequisites

- **Serena MCP**: If not already active, run `activate_project` to enable semantic code analysis tools
- **Clean state**: Ensure no uncommitted changes that could conflict with the new branch

## Workflow

1. **Analyze Issue**:
   - Run `gh issue view $ISSUE_NUMBER --json title,body,comments,milestone` to get title, body, labels, milestone
   - **Check TDD marker**: Look for `<!-- TDD: enabled -->` in the issue body → set the TDD workflow flag
   - If milestone exists, run `gh issue list --milestone "<milestone-name>" --json number,title,state` for related context
   - Identify requirements precisely
   - **Save checkpoint**: phase="analyze"

2. **Verify Plan File Alignment (If Exists)**:
   - Check if issue body or milestone description references a plan file path (`Plan: /path/to/plan.md`, `See: .claude/plans/xxx.md`)
   - If a plan file exists: read it, compare objectives with the issue, verify scope alignment (no scope creep); if misaligned, ask the user before proceeding
   - **Save checkpoint**: phase="plan"

2.5. **Worktree context check**:
    ```bash
    if [ "$(git rev-parse --git-dir)" != "$(git rev-parse --git-common-dir)" ]; then
      echo "[info] In linked worktree — Step 3 will replace this worktree's branch with feat/<n>-<slug>. This is expected for the PR flow."
    fi
    ```
    No abort. The PR flow inside a worktree is supported.

3. **Create Branch**: Create and checkout a new branch from the default branch.
   - **Detect default branch**: `git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'`
   - **Branch naming**: `{type}/{issue-number}-{short-description}`
     - `type`: infer from issue labels (`bug`→`fix`, `enhancement`/`feature`→`feat`) or title prefix; default `feat`
     - `short-description`: slugify issue title (lowercase, hyphens, max 50 chars, no special chars)
     - Examples: `fix/42-login-validation-error`, `feat/15-add-dark-mode`
   - **Save checkpoint**: phase="branch"

4. **Update GitHub Project Status (Optional)**
   - `gh project list --owner <owner> --format json`; skip silently if no projects
   - If projects exist: ensure the issue is an item (`gh project item-add` if not), then set Status to "In Progress" via `gh project item-edit` (skip if the Status field doesn't exist)

5. **Analyze Codebase (MANDATORY)**: Before writing code, understand the affected areas.

   | Scope | Approach |
   |-------|----------|
   | **Narrow** (1-2 files, specific function) | Serena: `get_symbols_overview` → `find_symbol` → `find_referencing_symbols` |
   | **Broad** (multiple modules, architecture) | Explorer agents in parallel (preserves main context) |

   For broad changes, spawn 2-3 `Explore` agents simultaneously (structure / similar-implementations / dependency-and-breaking-changes analysis).

6. **Plan Resolution**: Based on analysis, develop a concrete resolution plan and define work steps.

7. **Resolve Issue**: Implement using appropriate tools:
   - **Symbolic edits** (Serena): `replace_symbol_body`, `insert_after_symbol` for precise changes
   - **File edits**: for non-code or complex multi-line changes
   - **Sub-agents**: for large-scale parallel modifications (e.g. `Task(subagent_type="claude", model="opus"|"sonnet", ...)`)
   - **If TDD enabled** (marker in Step 1): RED (failing tests) → GREEN (minimal impl) → REFACTOR
   - **If TDD not enabled**: implement directly per the plan
   - **Execution verification required**: actually run runnable code to confirm behavior — never rely on file existence alone
   - **Save checkpoint**: phase="implement"

8. **Write Tests**:
   - If TDD enabled: verify coverage meets target (tests written in Step 7), add missing edge cases
   - If TDD not enabled: spawn independent sub-agents per file to write unit tests in parallel, targeting ≥80% coverage
   - **Save checkpoint**: phase="test"

9. **Validate**: Run tests, lint, and build in parallel via independent sub-agents.

9.5. **Verification Gates**: Run BUILD, TEST, LINT (see `references/protocols.md` → "Verification Gates"). Block on BUILD or TEST failure; warn on LINT (block only if the user asked for strict).

9.6. **2-Stage Review (unless the user asked to skip)**: Stage 1 spec compliance, Stage 2 code quality; max 3 retries then escalate (see `references/protocols.md` → "2-Stage Review Protocol"). **Save checkpoint**: phase="review".

10. **Create PR**: Open a pull request for the resolved issue.
    - **Commit only issue-relevant files**: Never use `git add -A`. Stage only files directly related to the issue.
    - **Save checkpoint**: phase="pr"

10.5. **Auto cr-fix loop (default ON)**:
    - Unless the user asked to skip it, invoke the `cr-fix` skill (`plugins/github-dev/skills/cr-fix/SKILL.md`) and let it run its lifecycle in this same turn. Forward the inferred options: the cr-fix iteration cap (→ cr-fix's `--max-iterations`), and the auto-merge / Codex-grace / no-codex / skip-minor / cr-source choices as-is. CodeRabbit auto-review takes ~7-30 min per cycle; ChatGPT-Codex (when present) typically posts within 5 min after CR; cr-fix's wait phase uses `Bash(run_in_background) + Monitor` so token cost during waits is ~0. Codex auto-detect is enabled by default — repos without Codex installed see no behavior change. PR-bot rate-limit detection (~30s) auto-flips to local `coderabbit` CLI or Codex-only when the source is `auto`.

    > **Ambiguous user phrase handling**:
    >
    > User phrases like "auto merge로", "auto merge 전까지", "끝까지", "머지까지 가줘" are ambiguous — they can mean "enroll in auto-merge queue" or "drive until merge actually completes" or "drive the loop but stop before any merge". Default interpretation: drive cr-fix to natural convergence (`final_state="clean"` AND CR engagement gate satisfied). Do NOT enroll auto-merge unless the user passes the explicit `--auto-merge` flag. If the user used such a phrase but did not pass `--auto-merge`, surface a single `AskUserQuestion` ("did you mean enroll auto-merge?" — Yes / No) before any merge action. The sankun PR #68 incident (immediate merge with CR review left dangling) was caused by interpreting an ambiguous phrase as implicit `--auto-merge`.

    - Print one banner line at start: `CR auto-fix loop starting; ask to skip cr-fix to disable.`
    - On non-success exit:
      - `final_state` ∈ {failure, iteration_cap, user_declined, cr_inactive}: cr-fix emits a final JSON line via its EXIT trap. Surface that JSON's diagnostic to the user.
      - `final_state="timeout"`: cr-fix's trap still emits the JSON line (with `final_state="timeout"` and `merged=false`); additionally mention exit code 124 if the underlying poller hit the wall-clock cap. Surface "cr-fix timed out — re-run with a larger cr-fix max or timeout, or check the CodeRabbit dashboard."
      - `final_state="cr_inactive"`: CodeRabbit never engaged within the iteration budget. Surface "CodeRabbit did not review the PR; merge not attempted."
      - In all non-success cases, resolve-issue still considers itself complete (PR is open and reviewable). Do NOT auto-merge in any non-clean exit.
    - On `final_state="clean"` and auto-merge requested: cr-fix's merge step branches on branch-protection presence. With protection, `gh pr merge --auto --squash --delete-branch` queues the merge until protection requirements are met. Without protection, cr-fix prompts the user (Merge now / Skip merge / Cancel) — `--auto` would otherwise collapse to immediate merge and bypass any external review.
    - Save checkpoint: phase="cr-fix"

11. **Update Issue Checkboxes**: Mark completed checkbox items in the issue as done.

11.5. **Update Project Tracking State** (if milestone exists):
    - Check the issue's milestone: `MILESTONE=$(gh issue view $ISSUE_NUMBER --json milestone --jq '.milestone.title // empty')`
    - If a milestone exists: slugify it, load `.claude/state/project-tracking-{slug}.json` (skip silently if absent), set the issue `state` to `"in_progress"` and record the PR number (preserving existing `dependsOn` / `architectureNode`), recalculate module progress, and save.
    - **Note**: GitHub diagram sync is NOT performed here — diagrams are updated by the `post-merge` skill after the PR is merged. (Schema documented in the `update-progress` skill.)

12. **Cleanup**: Archive the session state file to `.claude/state/archive/` (see `references/protocols.md` → "State Management").

> Read ~/.claude/CLAUDE.md and the project CLAUDE.md at runtime and follow them.

## References

- `references/protocols.md` — full Verification Gates, 2-Stage Review Protocol, and session State Management details.
