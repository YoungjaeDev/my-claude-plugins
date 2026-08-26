---
name: resolve-issue
description: Resolve a GitHub issue end-to-end — analyze the issue, create a feature branch, implement the fix (TDD when the issue is marked), run verification gates, open a PR, and drive the cr-fix review loop to convergence. Use ONLY when the user explicitly types /github-dev:resolve-issue <number> or asks to resolve or implement a specific issue. Do NOT auto-fire from incidental issue mentions — this creates a branch, commits, and opens a GitHub PR. Flags pass through to cr-fix — --skip-review, --strict, --skip-cr-fix, --cr-fix-max, --auto-merge, --codex-grace, --no-codex, --skip-minor, --no-minor-stop, --no-generalize, --cr-source.
allowed-tools: Read Write Edit Bash Glob Grep AskUserQuestion Task
---

# Resolve GitHub Issue

Act as an expert developer who systematically analyzes and resolves GitHub issues. Receive a GitHub issue number as argument and resolve the issue. Follow project guidelines in `@CLAUDE.md`.

## Prerequisites

Before starting the workflow:
- **Serena MCP**: If not already active, run `activate_project` to enable semantic code analysis tools
- **Clean state**: Ensure no uncommitted changes that could conflict with the new branch

## Flags

| Flag | Description |
|------|-------------|
| `--skip-review` | Skip 2-stage review (for trusted changes) |
| `--strict` | Treat lint failures as blocking errors |
| `--skip-cr-fix` | Skip the auto cr-fix loop after PR creation (default: cr-fix runs) |
| `--cr-fix-max <n>` | Cap iterations on the auto cr-fix loop (default: 5) |
| `--auto-merge` | Pass through to cr-fix; auto-merge the PR after convergence (default: OFF) |
| `--codex-grace <sec>` | Pass through to cr-fix; extra wait window after CodeRabbit completes for ChatGPT-Codex review comments (default: 90) |
| `--no-codex` | Pass through to cr-fix; force-disable Codex auto-detect for the run (default: auto-detect ON) |
| `--skip-minor` | Pass through to cr-fix; silently skip CR Minor/Trivial/Info severity (excluding Bug/Security) + Codex P2 to shrink the gated queue on lint-heavy PRs |
| `--no-minor-stop` | Pass through to cr-fix; disable the minor soft-stop (default ON — cr-fix stops from iter 2 when a cycle applied only low-severity fixes with nothing deferred, `final_state=minor_floor`) |
| `--no-generalize` | Pass through to cr-fix; disable bounded same-file generalization (default ON — a real + high-confidence + grep-able finding also patches sibling occurrences of the same pattern in the same file) |
| `--cr-source <mode>` | Pass through to cr-fix; review source selector. `auto` (default) falls back to local `coderabbit` CLI or Codex-only on PR-bot rate-limit. `pr-bot` / `cli` / `codex-only` lock the source. |

> **Note**: For parallel development, create worktrees manually before starting Claude sessions. See CLAUDE.md for the recommended worktree workflow.

## Workflow

1. **Analyze Issue**:
   - Run `gh issue view $ISSUE_NUMBER --json title,body,comments,milestone` to get issue title, body, labels, and milestone
   - **Check TDD marker**: Look for `<!-- TDD: enabled -->` in issue body -> Set TDD workflow flag
   - If milestone exists, run `gh issue list --milestone "<milestone-name>" --json number,title,state` to view related issues and understand overall context
   - Identify requirements precisely
   - **[NEW] Save checkpoint**: phase="analyze"

2. **Verify Plan File Alignment (If Exists)**:
   - Check if issue body or milestone description contains a plan file path
   - Common patterns: `Plan: /path/to/plan.md`, `See: .claude/plans/xxx.md`
   - If plan file exists:
     1. Read the plan file content
     2. Compare plan objectives with issue requirements
     3. Verify scope alignment (plan covers issue, no scope creep)
     4. If misaligned, ask user for clarification before proceeding
   - If no plan file, continue to next step
   - **[NEW] Save checkpoint**: phase="plan"

2.5. **Worktree context check**:
    ```bash
    if [ "$(git rev-parse --git-dir)" != "$(git rev-parse --git-common-dir)" ]; then
      echo "[info] In linked worktree — Step 3 will replace this worktree's branch with feat/<n>-<slug>. This is expected for the PR flow."
    fi
    ```
    No abort. The PR flow inside a worktree is supported.

3. **Create Branch**: Create and checkout a new branch from the default branch.
   - **Detect default branch**: `git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'`
   - **Branch naming convention**: `{type}/{issue-number}-{short-description}`
     - `type`: Infer from issue labels (`bug` -> `fix`, `enhancement`/`feature` -> `feat`) or title prefix. Default to `feat` if unclear.
     - `short-description`: Slugify issue title (lowercase, spaces to hyphens, max 50 chars, remove special chars)
     - Examples: `fix/42-login-validation-error`, `feat/15-add-dark-mode`, `refactor/8-cleanup-auth`
   - **[NEW] Save checkpoint**: phase="branch"

4. **Update GitHub Project Status (Optional)**
   - Run `gh project list --owner <owner> --format json` to check for projects
   - If no projects exist, skip silently
   - If projects exist:
     - Run `gh project item-list <project-number> --owner <owner> --format json` to check if issue is in project
     - If not, add with `gh project item-add`
     - Run `gh project field-list <project-number> --owner <owner> --format json` to get Status field ID and "In Progress" option ID
     - Update Status field to "In Progress":
       ```bash
       gh project item-edit --project-id <project-id> --id <item-id> --field-id <status-field-id> --single-select-option-id <in-progress-option-id>
       ```
     - Skip if Status field does not exist

5. **Analyze Codebase (MANDATORY)**: Before writing any code, understand the affected areas:

   **Tool Selection by Scope:**
   | Scope | Approach |
   |-------|----------|
   | **Narrow** (1-2 files, specific function) | Serena: `get_symbols_overview` -> `find_symbol` -> `find_referencing_symbols` |
   | **Broad** (multiple modules, architecture) | Explorer agents in parallel (preserves main context) |

   **For broad changes**, spawn 2-3 Explorer agents simultaneously using Task Tool:

   ```
   # Structure analysis
   Task(
     subagent_type="Explore",
     prompt="Analyze architecture related to [feature]. Map file relationships and module boundaries."
   )

   # Pattern analysis
   Task(
     subagent_type="Explore",
     prompt="Find similar implementations of [feature type] in the codebase."
   )

   # Dependency analysis
   Task(
     subagent_type="Explore",
     prompt="Identify all modules that depend on [target]. List potential breaking changes."
   )
   ```

6. **Plan Resolution**: Based on analysis results, develop a concrete resolution plan and define work steps.

7. **Resolve Issue**: Implement the solution using appropriate tools:
   - **Symbolic edits** (Serena): `replace_symbol_body`, `insert_after_symbol` for precise modifications
   - **File edits**: For non-code files or complex multi-line changes
   - **Sub-agents**: For large-scale parallel modifications
   - **If TDD enabled** (marker detected in Step 1):
     - **Prefer the shared TDD skill**: If `superpowers:test-driven-development` is installed, invoke it and follow its discipline. It is the source of truth for TDD rigor (RED -> GREEN -> REFACTOR with tracer-bullet vertical slices, never refactor while RED, test behavior over implementation, mock only at boundaries, and **independent expected values** — never assert a value the test recomputed the way the code does).
     - **Fallback (skill not installed)**: `superpowers` is an external plugin and MUST NOT be a hard dependency — Codex and minimal installs may lack it, and this skill must not break there. When it is absent, degrade gracefully to these four built-in rules:
       1. **Tracer-bullet vertical slice** — one failing test -> one minimal implementation -> repeat. Do not write a batch of tests up front (no horizontal slicing).
       2. **Strict RED -> GREEN** — watch the test fail first, then write the minimum to pass. Never refactor while a test is RED.
       3. **Behavior over implementation** — assert through the public interface only; do not couple tests to internal structure.
       4. **Mock at the boundary** — stub only external collaborators (network / DB / clock / filesystem); never mock internal collaborators.
       5. **Independent expected values** — the expected value in an assertion must come from an independent source of truth (a known-good literal, a worked example, or the spec), never recomputed the way the code does (`expect(add(a, b)).toBe(a + b)` is tautological — it passes RED while the function is missing, then can never disagree with the code again).
   - **If TDD not enabled**: Implement features directly according to the plan
   - **Execution verification required**: For Python scripts, executables, or any runnable code, always execute to verify correct behavior. Do not rely solely on file existence or previous results.

   ```
   # For complex implementation
   Task(
     subagent_type="claude",
     model="opus",
     prompt="Implement [complex feature]. Ensure type safety and error handling."
   )

   # For standard implementation
   Task(
     subagent_type="claude",
     model="sonnet",
     prompt="Implement [feature] in [file]. Follow existing patterns."
   )
   ```
   - **[NEW] Save checkpoint**: phase="implement"

8. **Write Tests**:
   - **If TDD enabled**: Verify test coverage meets target (tests already written in Step 7), add missing edge cases if needed
   - **If TDD not enabled**: Spawn independent sub-agents per file to write unit tests in parallel, achieving at least 80% coverage

   ```
   # Parallel test writing
   Task(
     subagent_type="claude",
     model="sonnet",
     prompt="Write unit tests for [file]. Target 80% coverage. Test happy path, edge cases, error conditions."
   )
   ```
   - **[NEW] Save checkpoint**: phase="test"

9. **Validate**: Run tests, lint checks, and build verification in parallel using independent sub-agents to validate code quality.

   ```
   # Parallel validation
   Task(
     subagent_type="claude",
     model="haiku",
     prompt="Run test suite and report pass/fail count."
   )

   Task(
     subagent_type="claude",
     model="haiku",
     prompt="Run linter and report issues."
   )
   ```

9.4. **[NEW] E2E suite (opt-in, auto-detected)**:
    - **Detect E2E presence**: look for `playwright.config.*` (`.ts`/`.js`/`.mjs`/`.cts`) or an `e2e/` test directory.
    - **If detected**: run the E2E suite (e.g. `npx playwright test`) and report pass/fail counts.
      - **Failures are warn-only — they do NOT block PR creation.** E2E is slow and environment-dependent; surface the failures (and the trace/report path if produced) for the user to triage, then continue the workflow.
    - **If not detected**: silent skip. resolve-issue does not require the `e2e-harness` plugin, a `playwright.config`, or any E2E setup to exist — it works whether or not E2E is configured (loose coupling).

9.5. **[NEW] Verification Gates**:
    - Run BUILD, TEST, LINT checks (see "Verification Gates" section)
    - Block on BUILD or TEST failure
    - Warn on LINT failure (block if --strict)

9.6. **[NEW] 2-Stage Review (unless --skip-review)**:
    - Stage 1: Spec compliance review
    - Stage 2: Code quality review
    - Maximum 3 retries, then escalate to user
    - **Save checkpoint**: phase="review"

10. **Create PR**: Create a pull request for the resolved issue.
    - **Commit only issue-relevant files**: Never use `git add -A`. Stage only files directly related to the issue.
    - **[NEW] Save checkpoint**: phase="pr"

10.5. **[NEW] Auto cr-fix loop (default ON)**:
    - Unless `--skip-cr-fix` is passed, invoke the `/github-dev:cr-fix` skill (`plugins/github-dev/skills/cr-fix/SKILL.md`) and let it run its 16-step lifecycle in this same Claude turn. Pass through the resolve-issue flags: `--cr-fix-max <n>` becomes cr-fix's `--max-iterations`; `--auto-merge`, `--codex-grace <sec>`, `--no-codex`, `--skip-minor`, `--no-minor-stop`, `--no-generalize`, `--cr-source <auto|pr-bot|cli|codex-only>` are forwarded as-is. CodeRabbit auto-review takes ~7-30 min per cycle; ChatGPT-Codex (when present) typically posts within 5 min after CR; cr-fix's wait phase uses `Bash(run_in_background) + Monitor` so token cost during waits is ~0. Codex auto-detect is enabled by default — repos without Codex installed see no behavior change. PR-bot rate-limit detection (~30s) auto-flips to local `coderabbit` CLI or Codex-only when `--cr-source=auto`.

    > **Ambiguous user phrase handling**:
    >
    > User phrases like "auto merge로", "auto merge 전까지", "끝까지", "머지까지 가줘" are ambiguous — they can mean "enroll in auto-merge queue" or "drive until merge actually completes" or "drive the loop but stop before any merge". Default interpretation: drive cr-fix to natural convergence (`final_state="clean"` AND CR engagement gate satisfied). Do NOT enroll auto-merge unless the user passes the explicit `--auto-merge` flag. If the user used such a phrase but did not pass `--auto-merge`, surface a single `AskUserQuestion` ("did you mean enroll auto-merge?" — Yes / No) before any merge action. The sankun PR #68 incident (immediate merge with CR review left dangling) was caused by interpreting an ambiguous phrase as implicit `--auto-merge`.

    - Print one banner line at start: `CR auto-fix loop starting; pass --skip-cr-fix to disable.`
    - On non-success exit:
      - `final_state` ∈ {failure, iteration_cap, user_declined, minor_floor, cr_inactive}: cr-fix emits a final JSON line via its EXIT trap (Step 16). Surface that JSON's diagnostic to the user.
      - `final_state="timeout"`: cr-fix's trap still emits the JSON line (with `final_state="timeout"` and `merged=false`), but the user-facing message should additionally mention exit code 124 if the underlying poller hit the wall-clock cap. Surface "cr-fix timed out — re-run with a larger `--cr-fix-max` or `--timeout`, or check the CodeRabbit dashboard."
      - `final_state="cr_inactive"`: CodeRabbit never engaged with the PR within the iteration budget. Surface "CodeRabbit did not review the PR; merge not attempted. Check the CodeRabbit dashboard or re-run with a larger `--cr-fix-max`."
      - `final_state="minor_floor"`: cr-fix stopped at the low-severity floor (default on; `--no-minor-stop` disables) — the last cycle applied only minor fixes with nothing deferred. Those fixes were pushed but the latest push has not been CR-re-reviewed. Surface "cr-fix stopped at minor_floor — low-severity fixes pushed, latest push not yet re-reviewed; re-run cr-fix to confirm clean or merge via GitHub UI." Pass `--no-minor-stop` to keep looping.
      - In all non-success cases, resolve-issue still considers itself complete (PR is open and reviewable). Do NOT auto-merge in any non-clean exit.
    - On `final_state="clean"` and `--auto-merge` flag set: cr-fix's Step 15 branches on branch-protection presence. With protection, `gh pr merge --auto --squash --delete-branch` queues the merge until protection requirements are met. Without protection, cr-fix prompts the user (Merge now / Skip merge / Cancel) — `--auto` would otherwise collapse to immediate merge and bypass any external review.
    - Save checkpoint: phase="cr-fix"

11. **Update Issue Checkboxes**: Mark completed checkbox items in the issue as done.

11.5. **Update Project Tracking State** (if milestone exists):
    - Check if issue has a milestone:
      ```bash
      MILESTONE=$(gh issue view $ISSUE_NUMBER --json milestone --jq '.milestone.title // empty')
      ```
    - If milestone exists:
      1. Generate slug from milestone name (lowercase, spaces to hyphens, remove special chars)
      2. Check for state file: `.claude/state/project-tracking-{slug}.json`
      3. If state file exists:
         - Load the state file
         - Update issue state to `"in_progress"` (PR created during resolve)
         - Record PR number in the issue entry (preserve existing `dependsOn` and `architectureNode`):
           ```json
           { "state": "open", "pr": <PR_NUMBER>, "moduleId": "<existing>", "dependsOn": [<existing>], "architectureNode": "<existing>" }
           ```
         - Recalculate module progress:
           ```
           module.progress = (closed_issues / total_issues) * 100
           module.status:
             "complete"    -> all issues closed
             "in_progress" -> at least 1 closed or has PR, at least 1 still open
             "pending"     -> all open, no PR
           ```
         - Save updated state file
      4. If no state file: skip silently (tracking not set up for this milestone)
    - **Note**: GitHub diagram sync is NOT performed here. Diagrams are updated in `post-merge` after the PR is merged.

12. **[NEW] Cleanup**:
    - Archive state file to `.claude/state/archive/`

> Follow ~/.claude/CLAUDE.md and project CLAUDE.md.

## Verification and Completion Criteria

**Important**: Always verify actual behavior before marking checkboxes as complete.

### Verification Principles
1. **Execution required**: Directly run code/configuration to confirm it actually works
2. **Provide evidence**: Show actual output or results that prove completion
3. **No guessing**: Explicitly mark unverified items as "unverified" or "assumed"
4. **Distinguish partial completion**: Clearly separate code written but not tested

### Prohibited Actions
- Reporting "expected to work" without execution
- Stating "will appear in logs" without checking logs
- Presenting assumptions as facts

---

## State Management

Session state enables workflow recovery after interruption.

### State File Location
Sessions are saved to: `.claude/state/github-dev-{issue-number}.json`

### State Schema
```json
{
  "sessionId": "github-dev-{issue-number}-{timestamp}",
  "command": "resolve-issue",
  "issueNumber": 123,
  "phase": "analyze|branch|implement|test|review|commit|pr",
  "branchName": "feat/123-add-dark-mode",
  "branchType": "feat|fix|refactor|docs|chore",
  "startedAt": "ISO timestamp",
  "lastCheckpoint": "ISO timestamp",
  "checkpoints": [
    { "phase": "analyze", "status": "complete", "timestamp": "ISO" },
    { "phase": "implement", "status": "in_progress", "timestamp": "ISO" }
  ]
}
```

### Checkpoint Save (after each phase)
```bash
mkdir -p .claude/state
cat > .claude/state/github-dev-${ISSUE_NUMBER}.json << 'EOF'
{... state JSON ...}
EOF
```

### Cleanup (on successful completion)
```bash
mkdir -p .claude/state/archive
mv .claude/state/github-dev-${ISSUE_NUMBER}.json \
   .claude/state/archive/github-dev-${ISSUE_NUMBER}-$(date +%Y%m%d).json
```

---

## Verification Gates

Quality gates that must pass before commit.

### Check Types
| Check | Purpose | Required |
|-------|---------|----------|
| BUILD | Compilation success | Yes |
| TEST | All tests pass | Yes |
| LINT | No linting errors | No (warning only) |
| TYPE_CHECK | Type errors resolved | No (warning only) |

### Project Type Detection
| Detection File | Project Type | Commands |
|----------------|--------------|----------|
| `package.json` | Node.js | `npm run build`, `npm test`, `npm run lint` |
| `pyproject.toml` or `setup.py` | Python | `pytest`, `ruff check .` |
| `Cargo.toml` | Rust | `cargo build`, `cargo test`, `cargo clippy` |
| `go.mod` | Go | `go build ./...`, `go test ./...` |

### Running Verification
```
Task(
  subagent_type="claude",
  model="haiku",
  prompt="Run verification checks for this project:
    1. Detect project type from config files
    2. Run BUILD command - must pass
    3. Run TEST command - must pass
    4. Run LINT command - report warnings
    5. Return JSON: {build: pass/fail, test: pass/fail, lint: pass/fail/skipped, errors: []}"
)
```

### Gate Enforcement
- BUILD failure: Block commit, report errors
- TEST failure: Block commit, report failures
- LINT failure: Warn but allow commit (unless `--strict`)

---

## 2-Stage Review Protocol

### Overview
Before PR creation, implementation passes two review stages:
1. **Spec Compliance** - Does it meet requirements?
2. **Code Quality** - Is it well implemented?

### Stage 1: Spec Compliance Review

```
Task(
  subagent_type="claude",
  model="sonnet",
  prompt="Spec compliance review for issue #${ISSUE_NUMBER}
    ## Issue Requirements
    ${ISSUE_BODY}
    ## Changed Files
    ${GIT_DIFF_STAT}
    ## Review Checklist
    1. Does implementation meet all issue requirements?
    2. Are all checkbox items in the issue addressed?
    3. Any missing functionality?
    ## Output: {verdict: PASS|FAIL, gaps: [], recommendation: string}"
)
```

### Stage 2: Code Quality Review

```
Task(
  subagent_type="claude",
  model="opus",
  prompt="Code quality review for issue #${ISSUE_NUMBER}
    ## Changed Files
    ${GIT_DIFF}
    ## Review Checklist
    1. Does code follow project conventions?
    2. Is error handling comprehensive?
    3. Are tests sufficient?
    4. Any security concerns?
    ## Output: {verdict: PASS|FAIL, issues: [], recommendation: string}"
)
```

### Review Loop
- Maximum 3 retries per stage
- On failure, fix based on specific feedback
- After 3 failures, escalate to user

### Skip Review Flag
`--skip-review`: Use for trusted changes (e.g., docs only)
