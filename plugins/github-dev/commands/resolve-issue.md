---
description: Resolve GitHub Issue
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
| `--worktree` | Use isolated git worktree for implementation |
| `--skip-review` | Skip 2-stage review (for trusted changes) |
| `--strict` | Treat lint failures as blocking errors |

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

3. **Create Branch**: Create and checkout a new branch from the default branch.
   - **Detect default branch**: `git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'`
   - **Branch naming convention**: `{type}/{issue-number}-{short-description}`
     - `type`: Infer from issue labels (`bug` -> `fix`, `enhancement`/`feature` -> `feat`) or title prefix. Default to `feat` if unclear.
     - `short-description`: Slugify issue title (lowercase, spaces to hyphens, max 50 chars, remove special chars)
     - Examples: `fix/42-login-validation-error`, `feat/15-add-dark-mode`, `refactor/8-cleanup-auth`
   - **Initialize submodules**: When using worktree, run `git submodule update --init --recursive`
   - **[NEW] Save checkpoint**: phase="branch"

3.5. **[NEW] Create Worktree (if --worktree flag)**:
   - See "Worktree Isolation" section below for details
   - Creates isolated workspace at `../worktrees/{type}-{issue}-{slug}`
   - Installs dependencies automatically

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
     subagent_type="oh-my-claudecode:explore",
     model="haiku",
     prompt="Analyze architecture related to [feature]. Map file relationships and module boundaries."
   )

   # Pattern analysis
   Task(
     subagent_type="oh-my-claudecode:explore",
     model="haiku",
     prompt="Find similar implementations of [feature type] in the codebase."
   )

   # Dependency analysis
   Task(
     subagent_type="oh-my-claudecode:explore",
     model="haiku",
     prompt="Identify all modules that depend on [target]. List potential breaking changes."
   )
   ```

6. **Plan Resolution**: Based on analysis results, develop a concrete resolution plan and define work steps.

7. **Resolve Issue**: Implement the solution using appropriate tools:
   - **Symbolic edits** (Serena): `replace_symbol_body`, `insert_after_symbol` for precise modifications
   - **File edits**: For non-code files or complex multi-line changes
   - **Sub-agents**: For large-scale parallel modifications
   - **If TDD enabled** (marker detected in Step 1):
     1. RED: Write failing tests first based on requirements
     2. GREEN: Implement minimal code to pass tests
     3. REFACTOR: Clean up while keeping tests green
   - **If TDD not enabled**: Implement features directly according to the plan
   - **Execution verification required**: For Python scripts, executables, or any runnable code, always execute to verify correct behavior. Do not rely solely on file existence or previous results.

   ```
   # For complex implementation
   Task(
     subagent_type="oh-my-claudecode:executor-high",
     model="opus",
     prompt="Implement [complex feature]. Ensure type safety and error handling."
   )

   # For standard implementation
   Task(
     subagent_type="oh-my-claudecode:executor",
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
     subagent_type="oh-my-claudecode:executor",
     model="sonnet",
     prompt="Write unit tests for [file]. Target 80% coverage. Test happy path, edge cases, error conditions."
   )
   ```
   - **[NEW] Save checkpoint**: phase="test"

9. **Validate**: Run tests, lint checks, and build verification in parallel using independent sub-agents to validate code quality.

   ```
   # Parallel validation
   Task(
     subagent_type="oh-my-claudecode:executor-low",
     model="haiku",
     prompt="Run test suite and report pass/fail count."
   )

   Task(
     subagent_type="oh-my-claudecode:executor-low",
     model="haiku",
     prompt="Run linter and report issues."
   )
   ```

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

11. **Update Issue Checkboxes**: Mark completed checkbox items in the issue as done.

12. **[NEW] Cleanup (if --worktree)**:
    - Remove worktree directory
    - Archive state file to `.omc/state/archive/`

> See [Work Guidelines](../guidelines/work-guidelines.md)

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
Sessions are saved to: `.omc/state/github-dev-{issue-number}.json`

### State Schema
```json
{
  "sessionId": "github-dev-{issue-number}-{timestamp}",
  "command": "resolve-issue",
  "issueNumber": 123,
  "phase": "analyze|branch|implement|test|review|commit|pr",
  "worktreePath": "/path/to/worktree or null",
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
mkdir -p .omc/state
cat > .omc/state/github-dev-${ISSUE_NUMBER}.json << 'EOF'
{... state JSON ...}
EOF
```

### Cleanup (on successful completion)
```bash
mkdir -p .omc/state/archive
mv .omc/state/github-dev-${ISSUE_NUMBER}.json \
   .omc/state/archive/github-dev-${ISSUE_NUMBER}-$(date +%Y%m%d).json
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
  subagent_type="oh-my-claudecode:executor-low",
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

## Worktree Isolation (--worktree flag)

### When to Use
- Large refactoring that could damage main workspace
- Parallel issue resolution (each issue gets its own worktree)
- Safely test destructive changes

### Worktree Lifecycle

**1. Pre-check**
```bash
grep -q "worktrees/" .gitignore || echo "worktrees/" >> .gitignore
```

**2. Create Worktree**
```bash
# Branch naming follows existing convention
# TYPE: Inferred from issue labels (bug->fix, enhancement->feat, default feat)
# SLUG: Slugified issue title (lowercase, spaces to hyphens, max 50 chars)
BRANCH_NAME="${TYPE}/${ISSUE_NUMBER}-${SLUG}"
WORKTREE_PATH="../worktrees/${TYPE}-${ISSUE_NUMBER}-${SLUG}"

git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME"
cd "$WORKTREE_PATH"
git submodule update --init --recursive
```

**3. Install Dependencies**
| Project | Command |
|---------|---------|
| Node.js | `npm ci` or `npm install` |
| Python | `pip install -e .` or `poetry install` |
| Rust | `cargo fetch` |
| Go | `go mod download` |

**4. Cleanup on Completion**
```bash
cd "$ORIGINAL_DIR"
git worktree remove "$WORKTREE_PATH" --force
```

### State Update
```json
{
  "worktreePath": "../worktrees/feat-123-add-dark-mode",
  "branchName": "feat/123-add-dark-mode",
  "originalDir": "/path/to/main/repo"
}
```

---

## 2-Stage Review Protocol

### Overview
Before PR creation, implementation passes two review stages:
1. **Spec Compliance** - Does it meet requirements?
2. **Code Quality** - Is it well implemented?

### Stage 1: Spec Compliance Review

```
Task(
  subagent_type="oh-my-claudecode:architect-medium",
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
  subagent_type="oh-my-claudecode:architect",
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
