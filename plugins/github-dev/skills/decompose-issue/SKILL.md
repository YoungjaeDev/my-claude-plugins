---
name: decompose-issue
description: Break a large work item, feature, or epic into independent, context-completable GitHub issues — analyze requirements, map issues onto a 10-20 node architecture workflow diagram, define dependencies, and (with explicit confirmation) create the milestone + sub-issues + a project-tracking state file. Use when the user wants to decompose / break down a big task or feature into GitHub issues, plan a milestone, or set up issue tracking for a body of work. Creates GitHub issues/milestones only after an explicit confirmation step — never silently.
---

# Decompose Work

Break down large work items into manageable, independent issues. Read the project
CLAUDE.md at runtime and follow it.

## What to decompose

There is no explicit argument string — take the work item to decompose from the
user's request and the conversation (a feature description, an epic, a milestone
goal). If it is genuinely unclear what body of work to break down, ask once.

## Safety: GitHub creation is gated

Steps 1-9.5 are local analysis and interviews. Milestone + issue creation
(Step 10) happens **only after the explicit AskUserQuestion confirmation** — show
the full proposed issue list and milestone first, and create nothing on GitHub
until the user approves.

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
5. Decompose work: Split major tasks into **context-completable units** — each issue should be completable in a single Claude session without context switching. Group related features together rather than splitting by individual functions
6. Analyze dependencies: Identify prerequisite tasks
7. Suggest milestone name: Propose a milestone to group decomposed tasks
8. Check related PRs (optional): Run `gh pr list --state closed --limit 20` for similar work references (skip if none)
9. Output decomposed issues: Display issues with proposed milestone name

9.5. **Define Architecture & Workflow Mapping** (for project progress tracking):

   #### Step A: Capture Project Workflow

   Analyze the codebase and design a **10-20 node flowchart** of the project's core workflow. Store as Mermaid in the state file, but present to the user as an ASCII diagram.

   - **Interview: Project Workflow** — Use AskUserQuestion:
     > "프로젝트의 전체 워크플로우를 다이어그램으로 정리했습니다. 수정할 부분이 있나요?"
     - Present the proposed workflow as an **ASCII diagram** (terminal cannot render Mermaid)
     - The diagram should capture the main data/control flow (not just layers)
     - Use descriptive node names for easy mapping
     - User can add/remove/rename nodes and connections
     - Target: 10-20 nodes with branches and subgroups where logical

   Example workflow (ASCII, shown to user in terminal):
   ```
   [Bot Loop] --> [scanChatList] --> <new request?>
                                       |yes --> [Pipeline]
                                       |         +--[parse]--[calculate]--[send]
                                       |no  --> <customer reply?>
                                                  |yes --> [AI Consultation]
                                                  |         +--[FAQ match]--<resolved?>
                                                  |                           |no --> [LLM escalation]
                                                  |no  --> [Push System]
                                                             +--[targets]--[filter]--[send push]
   ```

   Stored as Mermaid in state file (`architecture.mermaidSource`):
   ```mermaid
   flowchart TD
       A[Bot Loop] --> B[scanChatList]
       B --> C{new request?}
       C -->|yes| D[Pipeline]
       D --> D1[parse] --> D2[calculate] --> D3[send]
       C -->|no| E{customer reply?}
       E -->|yes| F[AI Consultation]
       F --> F1[FAQ match] --> F2{resolved?}
       F2 -->|no| F3[LLM escalation]
       E -->|no| G[Push System]
       G --> G1[targets] --> G2[filter] --> G3[send push]
   ```

   #### Step B: Select Scope Nodes

   - **Interview: Milestone Scope** — Use AskUserQuestion:
     > "이 마일스톤이 커버하는 노드를 선택해 주세요."
     - Present all node IDs from the workflow diagram
     - User selects which nodes are in scope for this milestone (`scopeNodes`)
     - These nodes will be highlighted with `:::scope` in generated diagrams

   #### Step C: Module Grouping & Issue Mapping

   - Analyze decomposed issues and propose module groupings based on workflow areas
   - **Interview: Issue-Module-Node Mapping** — Use AskUserQuestion:
     > "이슈-모듈-노드 매핑이 맞나요?"
     - Show each issue with: proposed module, mapped architecture node
     - User can reassign issues between modules or change node mappings

   #### Step D: Issue Dependencies

   - Analyze issue order and propose dependency chains
   - **Interview: Issue Dependencies** — Use AskUserQuestion:
     > "이슈 간 의존성(실행 순서)이 맞나요?"
     - Show proposed dependency graph: `#1 -> #2 -> #3`, `#2 -> #4`
     - User can add/remove dependencies
     - Dependencies are stored as `dependsOn: [issueNumber]` per issue

   #### Step E: Save State File

   - Generate slug from milestone name: lowercase, spaces to hyphens, remove special chars
     - Example: `"v1.0 Auth System"` -> `"v1-0-auth-system"`
   - Save the initial state file (schema documented in the `update-progress` skill):
     ```bash
     mkdir -p .claude/state
     cat > .claude/state/project-tracking-${SLUG}.json << 'STATEEOF'
     {
       "version": "2.0.0",
       "milestoneId": null,
       "milestoneName": "<milestone-name>",
       "milestoneSlug": "<slug>",
       "repoOwner": "<owner>",
       "repoName": "<repo>",
       "createdAt": "<ISO timestamp>",
       "lastSyncedAt": null,
       "architecture": {
         "description": "<one-line architecture description>",
         "mermaidSource": "<full Mermaid flowchart code from Step A>",
         "scopeNodes": ["<node-id-1>", "<node-id-2>"]
       },
       "modules": [
         {
           "id": "<id>",
           "name": "<name>",
           "architectureNode": "<node-id>",
           "issues": [],
           "status": "pending",
           "progress": 0
         }
       ],
       "issues": {
         "<number>": {
           "title": "<title>",
           "state": "open",
           "pr": null,
           "moduleId": "<module-id>",
           "dependsOn": [],
           "architectureNode": "<node-id>"
         }
       },
       "diagramMarkers": {
         "start": "<!-- project-tracking-start -->",
         "end": "<!-- project-tracking-end -->"
       }
     }
     STATEEOF
     ```

10. **Ask about GitHub creation**: Use AskUserQuestion to let the user decide on milestone and issue creation (this is the create gate — create nothing before approval).
    - Create milestone with a **Markdown Table** in the description.

      > **CRITICAL — DO NOT include Mermaid in the milestone description.** GitHub milestone pages do not render Mermaid; the raw code shows as plain text. Mermaid belongs in **issue bodies** (Type M-2), never in the milestone description.

      Build `$MILESTONE_TABLE` with the required table block below (canonical spec in `../update-progress/references/diagram-spec.md` — see "Milestone Format: Markdown Table" and "Type M-2").
      You may prepend objective/scope and dependency-order summary sections required by this file's milestone guidelines.

      ```markdown
      ## <milestoneName> Progress (auto-updated: YYYY-MM-DD)

      | Status | Issue | Title | Depends On |
      |--------|-------|-------|------------|
      | [ ] | #<n1> | <title1> | - |
      | [ ] | #<n2> | <title2> | #<n1> |

      **Progress: 0/<total> (0%)**
      ```

      Then create the milestone:
      ```bash
      RESPONSE=$(gh api repos/{owner}/{repo}/milestones \
        -f title="<Milestone Name>" \
        -f description="$MILESTONE_TABLE")
      MILESTONE_NUMBER=$(echo "$RESPONSE" | jq '.number')
      ```
    - Update state file with milestoneId:
      ```bash
      STATE_FILE=".claude/state/project-tracking-${SLUG}.json"
      jq --arg mid "$MILESTONE_NUMBER" '.milestoneId = ($mid | tonumber)' "$STATE_FILE" > tmp.$$.json && mv tmp.$$.json "$STATE_FILE"
      ```
    - Assign issues with `--milestone` option
    - After issue creation, update the state file `issues` map with actual GitHub issue numbers

11. **Add issues to GitHub Project (optional)**
   - Check for existing projects: `gh project list --owner <owner> --format json`
   - If no project exists: inform the user they can create one first, then skip
   - If a project exists: Ask user via AskUserQuestion whether to add issues
   - If yes: Run `gh project item-add <project-number> --owner <owner> --url <issue-url>` for each issue

## Issue Sizing Principle

### Context-Completable Units
Each issue should be designed to be **completable in a single Claude session**:

- **Group related features** rather than splitting by individual functions
- **Minimize context switching** — all necessary information should be within the issue
- **Include implementation details** — specific enough that no external lookup is needed during execution

### Sizing Guidelines

| Good (Context-Completable) | Bad (Over-Fragmented) |
|---------------------------|----------------------|
| "Add user authentication with login/logout/session" | "Add login button", "Add logout button", "Add session handling" (3 separate issues) |
| "Implement CRUD API for products" | "Add create endpoint", "Add read endpoint", "Add update endpoint", "Add delete endpoint" (4 separate issues) |
| "Setup CI/CD pipeline with test and deploy stages" | "Add test stage", "Add deploy stage" (2 separate issues) |

### Issue Content Depth
Since issues are larger, content must be **more detailed**:

1. **Implementation order** — numbered steps for execution sequence
2. **File-by-file changes** — specific modifications per file
3. **Code snippets** — key patterns or structures to implement
4. **Edge cases** — known gotchas or considerations

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
