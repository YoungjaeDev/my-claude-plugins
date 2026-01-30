---
description: Resolve GitHub Issue
args:
  - name: --no-ralph
    required: false
    description: Disable ralph mode (default: ralph enabled for implementation phase)
---

# Resolve GitHub Issue

Act as an expert developer who systematically analyzes and resolves GitHub issues. Receive a GitHub issue number as argument and resolve the issue. Follow project guidelines in `@CLAUDE.md`.

## Prerequisites

Before starting the workflow:
- **Serena MCP**: If not already active, run `activate_project` to enable semantic code analysis tools
- **Clean state**: Ensure no uncommitted changes that could conflict with the new branch

## Task Tool Integration

This workflow uses Claude Code's Task Tool for progress tracking:

- **Automated task creation**: Each major phase is tracked as a task with dependency chains
- **Status transitions**: Tasks progress through `pending` → `in_progress` → `completed`
- **Persistence**: Task status survives conversation compaction and provides Ralph retry context
- **Verification**: Before completion, `TaskList()` verifies all phase tasks are completed

**Task lifecycle:**
1. Create tasks for all 7 workflow phases with dependencies
2. Update status to `in_progress` at phase start
3. Update status to `completed` at phase end
4. On Ralph retry: Reset implementation phase task to `in_progress`

## Workflow

1. **Analyze Issue**:
   - Run `gh issue view $ISSUE_NUMBER --json title,body,comments,milestone` to get issue title, body, labels, and milestone
   - **Check TDD marker**: Look for `<!-- TDD: enabled -->` in issue body → Set TDD workflow flag
   - If milestone exists, run `gh issue list --milestone "<milestone-name>" --json number,title,state` to view related issues and understand overall context
   - Identify requirements precisely
   - **Initialize Task Tracking**: Create tasks for workflow phases:
     ```
     # Step 1: Create all phase tasks
     TaskCreate(subject="[#N] Phase 1: Analyze Issue", activeForm="Analyzing issue", metadata={phase: 1, issue: N})
     TaskCreate(subject="[#N] Phase 2: Setup Branch & Project", activeForm="Setting up")
     TaskCreate(subject="[#N] Phase 3: Codebase Analysis", activeForm="Analyzing codebase")
     TaskCreate(subject="[#N] Phase 4: Implementation", activeForm="Implementing")
     TaskCreate(subject="[#N] Phase 5: Testing", activeForm="Writing tests")
     TaskCreate(subject="[#N] Phase 6: Validation", activeForm="Validating")
     TaskCreate(subject="[#N] Phase 7: PR Creation", activeForm="Creating PR")

     # Step 2: Set dependency chain (each phase blocked by previous)
     TaskUpdate(taskId="phase-2", addBlockedBy=["phase-1"])
     TaskUpdate(taskId="phase-3", addBlockedBy=["phase-2"])
     TaskUpdate(taskId="phase-4", addBlockedBy=["phase-3"])
     TaskUpdate(taskId="phase-5", addBlockedBy=["phase-4"])
     TaskUpdate(taskId="phase-6", addBlockedBy=["phase-5"])
     TaskUpdate(taskId="phase-7", addBlockedBy=["phase-6"])
     ```
   - **Note**: Task IDs are returned from TaskCreate; capture them to set dependencies
   - **Phase 1 start**: `TaskUpdate(taskId="phase-1", status="in_progress")`
   - **Phase 1 end**: `TaskUpdate(taskId="phase-1", status="completed")`

2. **Verify Plan File Alignment (If Exists)**:
   - Check if issue body or milestone description contains a plan file path
   - Common patterns: `Plan: /path/to/plan.md`, `See: .claude/plans/xxx.md`
   - If plan file exists:
     1. Read the plan file content
     2. Compare plan objectives with issue requirements
     3. Verify scope alignment (plan covers issue, no scope creep)
     4. If misaligned, ask user for clarification before proceeding
   - If no plan file, continue to next step

3. **Create Branch**: Create and checkout a new branch from `main` or `master` branch.
   - **Phase 2 start**: `TaskUpdate(taskId="phase-2-task-id", status="in_progress")`
   - **Branch naming convention**: `{type}/{issue-number}-{short-description}`
     - `type`: Infer from issue labels (`bug` -> `fix`, `enhancement`/`feature` -> `feat`) or title prefix. Default to `feat` if unclear.
     - `short-description`: Slugify issue title (lowercase, spaces to hyphens, max 50 chars, remove special chars)
     - Examples: `fix/42-login-validation-error`, `feat/15-add-dark-mode`, `refactor/8-cleanup-auth`
   - **Initialize submodules**: When using worktree, run `git submodule update --init --recursive`

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
   - **Phase 2 end**: `TaskUpdate(taskId="phase-2-task-id", status="completed")`

5. **Analyze Codebase (MANDATORY)**: Before writing any code, understand the affected areas:

   - **Phase 3 start**: `TaskUpdate(taskId="phase-3-task-id", status="in_progress")`

   **Tool Selection by Scope:**
   | Scope | Approach |
   |-------|----------|
   | **Narrow** (1-2 files, specific function) | Serena: `get_symbols_overview` → `find_symbol` → `find_referencing_symbols` |
   | **Broad** (multiple modules, architecture) | Explorer agents in parallel (preserves main context) |

   **For broad changes**, spawn 2-3 Explorer agents simultaneously:
   - **Structure agent**: Overall architecture and file relationships
   - **Pattern agent**: Similar implementations in codebase
   - **Dependency agent**: Affected modules and consumers

   **For narrow changes**, use Serena directly:
   1. `get_symbols_overview` on target file(s)
   2. `find_symbol` with `include_body=True` for specific functions
   3. `find_referencing_symbols` for impact analysis

   - **Phase 3 end**: `TaskUpdate(taskId="phase-3-task-id", status="completed")`

6. **Plan Resolution**: Based on analysis results, develop a concrete resolution plan and define work steps.

7. **Implementation Phase (Ralph Mode by Default)**:

   - **Phase 4 start**: `TaskUpdate(taskId="phase-4-task-id", status="in_progress")`

   > **Ralph Mode**: By default, Steps 7a-7c run under `/oh-my-claudecode:ralph` for persistent execution until Architect verification passes. Use `--no-ralph` argument to disable.

   **Ralph Mode Verification Criteria:**
   | Check | Description |
   |-------|-------------|
   | BUILD | Build succeeds without errors |
   | TEST | All tests pass |
   | LINT | No lint errors |
   | ARCHITECT | Architect agent approval |

   **Ralph Mode Task Integration:**
   - On verification failure: Auto-retry with fixes, task remains `in_progress`
   - On conversation compaction: Task status persists as retry context
   - On retry: Task already marked `in_progress`, continue from last state

   **7a. Resolve Issue**: Implement the solution using appropriate tools:
   - **Symbolic edits** (Serena): `replace_symbol_body`, `insert_after_symbol` for precise modifications
   - **File edits**: For non-code files or complex multi-line changes
   - **Sub-agents**: For large-scale parallel modifications
   - **If TDD enabled** (marker detected in Step 1):
     - **Reference**: See `/oh-my-claudecode:tdd` skill for TDD enforcement
     1. 🔴 RED: Write failing tests first based on requirements
     2. 🟢 GREEN: Implement minimal code to pass tests
     3. 🔵 REFACTOR: Clean up while keeping tests green
   - **If TDD not enabled**: Implement features directly according to the plan
   - **Execution verification required**: For Python scripts, executables, or any runnable code, always execute to verify correct behavior. Do not rely solely on file existence or previous results.

   - **Phase 4 end**: `TaskUpdate(taskId="phase-4-task-id", status="completed")`

   **7b. Write Tests**:
   - **Phase 5 start**: `TaskUpdate(taskId="phase-5-task-id", status="in_progress")`
   - **If TDD enabled**: Verify test coverage meets target (tests already written in Step 7a), add missing edge cases if needed
   - **If TDD not enabled**: Spawn independent sub-agents per file to write unit tests in parallel, achieving at least 80% coverage
   - **Phase 5 end**: `TaskUpdate(taskId="phase-5-task-id", status="completed")`

   **7c. Validate**: Run tests, lint checks, and build verification in parallel using independent sub-agents to validate code quality.
   - **Phase 6 start**: `TaskUpdate(taskId="phase-6-task-id", status="in_progress")`
   - Execute validation checks
   - **Phase 6 end**: `TaskUpdate(taskId="phase-6-task-id", status="completed")`

   **Ralph Loop Behavior:**
   - On failure: Auto-retry with fixes until all checks pass
   - On success: Proceed to PR creation only after Architect approval
   - `--no-ralph`: Execute 7a → 7b → 7c sequentially without retry loop

8. **Create PR**: Create a pull request for the resolved issue.
    - **Phase 7 start**: `TaskUpdate(taskId="phase-7-task-id", status="in_progress")`
    - **Commit only issue-relevant files**: Never use `git add -A`. Stage only files directly related to the issue.
    - **Phase 7 end**: `TaskUpdate(taskId="phase-7-task-id", status="completed")`

9. **Update Issue Checkboxes**: Mark completed checkbox items in the issue as done.

> See [Work Guidelines](../guidelines/work-guidelines.md)

## Verification and Completion Criteria

**Important**: Always verify actual behavior before marking checkboxes as complete.

### Task-Based Verification

Before claiming workflow completion:
1. **Check Task Status**: Run `TaskList()` to retrieve all phase tasks
2. **Verify All Phases**: Ensure all 7 phase tasks show `status: "completed"`
3. **Incomplete Tasks**: If any task is not `completed`, identify blocking issue and continue working
4. **Final Completion**: Only claim completion when `TaskList()` shows 100% completion

**Task verification checklist:**
```
[ ] Phase 1: Analyze Issue - completed
[ ] Phase 2: Setup Branch & Project - completed
[ ] Phase 3: Codebase Analysis - completed
[ ] Phase 4: Implementation - completed
[ ] Phase 5: Testing - completed
[ ] Phase 6: Validation - completed
[ ] Phase 7: PR Creation - completed
```

### Verification Principles
1. **Execution required**: Directly run code/configuration to confirm it actually works
2. **Provide evidence**: Show actual output or results that prove completion
3. **No guessing**: Explicitly mark unverified items as "unverified" or "assumed"
4. **Distinguish partial completion**: Clearly separate code written but not tested
5. **Task status alignment**: TaskList() output must match claimed completion status

### Prohibited Actions
- Reporting "expected to work" without execution
- Stating "will appear in logs" without checking logs
- Presenting assumptions as facts
- Claiming completion without running TaskList() verification
