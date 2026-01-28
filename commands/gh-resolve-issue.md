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

## Workflow

1. **Analyze Issue**:
   - Run `gh issue view $ISSUE_NUMBER --json title,body,comments,milestone` to get issue title, body, labels, and milestone
   - **Check TDD marker**: Look for `<!-- TDD: enabled -->` in issue body → Set TDD workflow flag
   - If milestone exists, run `gh issue list --milestone "<milestone-name>" --json number,title,state` to view related issues and understand overall context
   - Identify requirements precisely

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

5. **Analyze Codebase (MANDATORY)**: Before writing any code, understand the affected areas:

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

6. **Plan Resolution**: Based on analysis results, develop a concrete resolution plan and define work steps.

7. **Implementation Phase (Ralph Mode by Default)**:

   > **Ralph Mode**: By default, Steps 7a-7c run under `/oh-my-claudecode:ralph` for persistent execution until Architect verification passes. Use `--no-ralph` argument to disable.

   **Ralph Mode Verification Criteria:**
   | Check | Description |
   |-------|-------------|
   | BUILD | Build succeeds without errors |
   | TEST | All tests pass |
   | LINT | No lint errors |
   | ARCHITECT | Architect agent approval |

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

   **7b. Write Tests**:
   - **If TDD enabled**: Verify test coverage meets target (tests already written in Step 7a), add missing edge cases if needed
   - **If TDD not enabled**: Spawn independent sub-agents per file to write unit tests in parallel, achieving at least 80% coverage

   **7c. Validate**: Run tests, lint checks, and build verification in parallel using independent sub-agents to validate code quality.

   **Ralph Loop Behavior:**
   - On failure: Auto-retry with fixes until all checks pass
   - On success: Proceed to PR creation only after Architect approval
   - `--no-ralph`: Execute 7a → 7b → 7c sequentially without retry loop

8. **Create PR**: Create a pull request for the resolved issue.
    - **Commit only issue-relevant files**: Never use `git add -A`. Stage only files directly related to the issue.

9. **Update Issue Checkboxes**: Mark completed checkbox items in the issue as done.

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
