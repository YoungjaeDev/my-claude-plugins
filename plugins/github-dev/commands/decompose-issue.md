## Decompose Work

Break down large work items into manageable, independent issues. Follow project guidelines in `@CLAUDE.md`.

## Workflow

1. Check issue numbers: Run `gh issue list` to view current issue numbers
2. Analyze work: Understand core requirements and objectives
3. Decompose work: Split major tasks into smaller, manageable sub-tasks or issues. **Aim for optimal count over excessive issues (keep it manageable)**
4. Analyze dependencies: Identify prerequisite tasks
5. Suggest milestone name: Propose a milestone to group decomposed tasks
6. Check related PRs (optional): Run `gh pr list --state closed --limit 20` for similar work references (skip if none)
7. Output decomposed issues: Display issues with proposed milestone name
8. Ask about GitHub creation: Use AskUserQuestion to let user decide on milestone and issue creation
   - Create milestone: `gh api repos/:owner/:repo/milestones -f title="Milestone Name" -f description="Description"`
   - Assign issues with `--milestone` option
9. **Add issues to GitHub Project (optional)**
   - Check for existing projects: `gh project list --owner <owner> --format json`
   - If no project exists: Display "No project found. You can create one with `/gh:init-project`" and skip
   - If project exists: Ask user via AskUserQuestion whether to add issues
   - If yes: Run `gh project item-add <project-number> --owner <owner> --url <issue-url>` for each issue

## Milestone Description Guidelines

Milestone description must include:
- Overall objectives and scope
- Issue processing order (dependency graph)
- Example: "Issue order: #1 -> #2 -> #3 -> #4"

## Issue Template

### Title
`[Type] Concise task description`

### Labels (Use actual repository labels)
**Note**: Before assigning labels, verify repository labels with `gh label list`.

Examples (vary by project, for reference only):
- **Type**: `type: feature`, `type: documentation`, `type: enhancement`, `type: bug`
- **Area**: `area: model/inference`, `area: model/training`, `area: dataset`, `area: detection`
- **Complexity**: `complexity: easy`, `complexity: medium`, `complexity: hard`
- **Priority**: `priority: high`, `priority: medium`, `priority: low`

### Description
**Purpose**: [Why this is needed]

**Tasks**:
- [ ] Specific requirement 1
- [ ] Specific requirement 2

**Files to modify**:
- `path/filename` - Change description

**Completion criteria**:
- [ ] Feature implementation complete
- [ ] Added to demo page (for UI components)

**Dependencies**:
- [ ] None or prerequisite issue #number

**Recommended agent** (if applicable):
- Include here if agent usage is specified in arguments

**References** (optional):
- Add related PRs if available (e.g., PR #36 - brief description)
- Omit this section if none
