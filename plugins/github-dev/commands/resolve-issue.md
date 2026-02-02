
# Resolve GitHub Issue

Act as an expert developer who systematically analyzes and resolves GitHub issues. Receive a GitHub issue number as argument and resolve the issue. Follow project guidelines in `@CLAUDE.md`.

## Workflow

1. **Analyze Issue**:
   - Run `gh issue view $ISSUE_NUMBER --json title,body,comments,milestone` to get issue title, body, labels, and milestone
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

3. **Create Branch**: Create and checkout a new branch named `issue-$ISSUE_NUMBER` from `main` or `master` branch.
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

5. **Analyze Codebase**: Use sub-agents to analyze the codebase in parallel, identifying relevant files and structure needed to resolve the issue.

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

7. **Resolve Issue**: Spawn sub-agents to modify code and implement features according to the plan.
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

8. **Write Tests**: Spawn independent sub-agents per file to write unit tests in parallel, achieving at least 80% coverage.

   ```
   # Parallel test writing
   Task(
     subagent_type="oh-my-claudecode:executor",
     model="sonnet",
     prompt="Write unit tests for [file]. Target 80% coverage. Test happy path, edge cases, error conditions."
   )
   ```

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

10. **Create PR**: Create a pull request for the resolved issue.
    - **Commit only issue-relevant files**: Never use `git add -A`. Stage only files directly related to the issue.

11. **Update Issue Checkboxes**: Mark completed checkbox items in the issue as done.

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
