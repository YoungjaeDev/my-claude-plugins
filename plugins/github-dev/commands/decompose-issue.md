---
description: Decompose Work
---

## Decompose Work

Break down large work items into manageable, independent issues. Follow project guidelines in `@CLAUDE.md`.

## Workflow

1. Check issue numbers: Run `gh issue list` to view current issue numbers
2. **Discover available components**:
   - Scan `.claude/agents/` for custom agents (read YAML frontmatter)
   - Detect test frameworks (jest.config.*, pytest.ini, vitest.config.*, pyproject.toml, etc.)
3. **Check TDD applicability** (if user hasn't specified):
   - Analyze work type: code implementation vs docs/infra/config
   - If test framework detected + code work → Ask: "Create issues with TDD approach?"
   - If no test framework → Inform: "TDD not required. (Reason: No test framework detected)"
   - If non-code work (docs/infra) → Inform: "TDD not required. (Reason: Non-code work)"
   - If TDD selected: Add `<!-- TDD: enabled -->` marker to each issue body
4. Analyze work: Understand core requirements and objectives
5. Decompose work: Split major tasks into **context-completable units** - each issue should be completable in a single Claude session without context switching. Group related features together rather than splitting by individual functions
6. Analyze dependencies: Identify prerequisite tasks
7. Suggest milestone name: Propose a milestone to group decomposed tasks
8. Check related PRs (optional): Run `gh pr list --state closed --limit 20` for similar work references (skip if none)
9. Output decomposed issues: Display issues with proposed milestone name

9.5. **Define Architecture Mapping** (for project progress tracking):
   - Analyze the decomposed issues and propose module groupings based on functional areas
   - **Interview: Architecture Layers** -- Use AskUserQuestion:
     > "프로젝트의 전체 아키텍처 레이어를 확인합니다. 아래 제안이 맞나요?"
     - Present detected/proposed layers with: layer name, technology, dependencies
     - Ask which layers are in scope for this milestone (`inScope: true`)
     - User can add/remove/rename layers
   - **Interview: Issue-Module Mapping** -- Use AskUserQuestion:
     > "이슈-모듈 매핑이 맞나요?"
     - Show each issue assigned to its proposed module
     - User can reassign issues between modules
   - Generate slug from milestone name: lowercase, spaces to hyphens, remove special chars
     - Example: `"v1.0 Auth System"` -> `"v1-0-auth-system"`
   - Save initial state file:
     ```bash
     mkdir -p .omc/state
     cat > .omc/state/project-tracking-${SLUG}.json << 'STATEEOF'
     {
       "version": "1.0.0",
       "milestoneId": null,
       "milestoneName": "<milestone-name>",
       "milestoneSlug": "<slug>",
       "repoOwner": "<owner>",
       "repoName": "<repo>",
       "createdAt": "<ISO timestamp>",
       "lastSyncedAt": null,
       "architecture": {
         "description": "<one-line architecture description>",
         "layers": [
           { "id": "<id>", "name": "<name>", "tech": "<tech>", "dependsOn": [], "inScope": false }
         ]
       },
       "modules": [
         { "id": "<id>", "name": "<name>", "layerId": "<layer-id>", "issues": [], "status": "pending", "progress": 0 }
       ],
       "issues": {
         "<number>": { "title": "<title>", "state": "open", "pr": null, "moduleId": "<module-id>" }
       },
       "diagramMarkers": {
         "start": "<!-- project-tracking-start -->",
         "end": "<!-- project-tracking-end -->"
       }
     }
     STATEEOF
     ```

10. Ask about GitHub creation: Use AskUserQuestion to let user decide on milestone and issue creation
    - Create milestone with **Type A ASCII diagram** in description:
      ```bash
      # Generate initial Type A ASCII diagram (all issues [ ] pending, progress 0%)
      # ASCII diagram format:
      #   Architecture (auto-updated: YYYY-MM-DD)
      #     [Layer1]  [Layer2]  [InScopeLayer] <--+ Milestone
      #   --- <milestoneName> (this milestone) ---
      #     [Module1]           [Module2]
      #      [ ] #N Title       [ ] #N Title
      #   Progress: >                              0/N (0%)

      RESPONSE=$(gh api repos/:owner/:repo/milestones \
        -f title="<Milestone Name>" \
        -f description="$TYPE_A_ASCII_DIAGRAM")
      MILESTONE_NUMBER=$(echo "$RESPONSE" | jq '.number')
      ```
    - Update state file with milestoneId:
      ```bash
      # Update milestoneId in project-tracking-{slug}.json
      # Set milestoneId to $MILESTONE_NUMBER
      ```
    - Assign issues with `--milestone` option
    - After issue creation, update the state file `issues` map with actual GitHub issue numbers

11. **Add issues to GitHub Project (optional)**
   - Check for existing projects: `gh project list --owner <owner> --format json`
   - If no project exists: Display "No project found. You can create one with `/gh:init-project`" and skip
   - If project exists: Ask user via AskUserQuestion whether to add issues
   - If yes: Run `gh project item-add <project-number> --owner <owner> --url <issue-url>` for each issue

## Issue Sizing Principle

### Context-Completable Units
Each issue should be designed to be **completable in a single Claude session**:

- **Group related features** rather than splitting by individual functions
- **Minimize context switching** - all necessary information should be within the issue
- **Include implementation details** - specific enough that no external lookup is needed during execution

### Sizing Guidelines

| Good (Context-Completable) | Bad (Over-Fragmented) |
|---------------------------|----------------------|
| "Add user authentication with login/logout/session" | "Add login button", "Add logout button", "Add session handling" (3 separate issues) |
| "Implement CRUD API for products" | "Add create endpoint", "Add read endpoint", "Add update endpoint", "Add delete endpoint" (4 separate issues) |
| "Setup CI/CD pipeline with test and deploy stages" | "Add test stage", "Add deploy stage" (2 separate issues) |

### Issue Content Depth
Since issues are larger, content must be **more detailed**:

1. **Implementation order** - numbered steps for execution sequence
2. **File-by-file changes** - specific modifications per file
3. **Code snippets** - key patterns or structures to implement
4. **Edge cases** - known gotchas or considerations

---

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
<!-- TDD: enabled --> (Add this marker if TDD was selected in Step 3)

**Purpose**: [Why this is needed]

**Implementation Steps** (in order):
1. [ ] Step 1 - description with specific details
2. [ ] Step 2 - description with specific details
3. [ ] Step 3 - description with specific details

**Files to modify**:
- `path/filename` - Specific change (add/modify/remove what)
- `path/filename2` - Specific change with code pattern if needed

**Key Implementation Details**:
```
// Include code snippets, patterns, or structures when helpful
// This reduces need for external lookup during execution
```

**Completion criteria**:
- [ ] Implementation complete (all tasks checked)
- [ ] Execution verified (no runtime errors)
- [ ] Tests pass (if applicable)
- [ ] Added to demo page (for UI components, if applicable)

**Dependencies**:
- [ ] None or prerequisite issue #number

**References** (optional):
- Add related PRs if available (e.g., PR #36 - brief description)
- Omit this section if none

---

## Verification Guidelines

Verification is mandatory when issue work is complete:

| Work Type | Verification Method |
|-----------|---------------------|
| Python code | `python -m py_compile file.py` + actual execution |
| TypeScript/JS | `tsc --noEmit` or build |
| API/Server | Endpoint call test |
| CLI tools | Run basic commands |
| Config files | Verify loading with related tools |

**Never mark complete if only files are created without execution verification**
