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
6. **Determine execution strategy (Phase 1)**: For each decomposed issue, apply Preliminary Pattern Selection:
   - Check for specialist keywords (security, auth, UI, performance, data)
   - Analyze scope keywords from work description
   - Infer complexity from impact scope and subtask count
   - Apply complexity adjustment
   - Check TDD override
   - Record preliminary pattern
7. **Refine execution strategy (Phase 2)**: After generating file lists:
   - Count actual files to modify
   - Refine pattern based on file count thresholds
   - Document final pattern with rationale (include any Phase 2 refinement)
8. Analyze dependencies: Identify prerequisite tasks
9. Suggest milestone name: Propose a milestone to group decomposed tasks
10. Check related PRs (optional): Run `gh pr list --state closed --limit 20` for similar work references (skip if none)
11. Output decomposed issues: Display issues with proposed milestone name
12. Ask about GitHub creation: Use AskUserQuestion to let user decide on milestone and issue creation
    - Create milestone: `gh api repos/:owner/:repo/milestones -f title="Milestone Name" -f description="Description"`
    - Assign issues with `--milestone` option
13. **Add issues to GitHub Project (optional)**
   - Check for existing projects: `gh project list --owner <owner> --format json`
   - If no project exists: Display "No project found. You can create one with `/gh:init-project`" and skip
   - If project exists: Ask user via AskUserQuestion whether to add issues
   - If yes: Run `gh project item-add <project-number> --owner <owner> --url <issue-url>` for each issue
14. **Generate Task Graph (Optional)**:
   - Ask user via AskUserQuestion: "Create Task graph for execution tracking?"
   - If yes: Generate tasks for each created issue (see [Task Graph Generation](#task-graph-generation) section below)
   - Set dependencies based on issue relationships using `TaskUpdate(taskId="...", addBlockedBy=[...])`
   - Display generated task graph summary

## Task Graph Generation

After creating GitHub issues, gh-decompose-issue can also generate a Task graph for execution tracking. This provides:

- **Automated execution order**: Tasks mirror GitHub issues with blockedBy dependencies
- **Progress tracking**: TaskList shows current state across milestone
- **Dependency visualization**: Clear view of what's blocked and what's ready
- **Integration**: Task metadata includes GitHub issue numbers for cross-referencing

### Task Creation Process

For each GitHub issue created:

1. **Create Task** with matching metadata:
   ```
   TaskCreate(
     subject="Issue #N: {issue title}",
     description="{summary of issue body}",
     activeForm="Working on #{issue-number}",
     metadata={
       githubIssue: N,
       pattern: "{execution-pattern from issue}",
       complexity: "{complexity-level from issue}"
     }
   )
   ```

2. **Set Dependencies** based on issue relationships:
   - If issue lists prerequisite `#M` in Dependencies section
   - Add `TaskUpdate(taskId="issue-N", addBlockedBy=["issue-M"])`
   - This mirrors the dependency chain from milestone description

3. **Display Summary** showing:
   - Total tasks created
   - Dependency chain visualization
   - Ready-to-execute tasks (no blockers)

### Pattern-Based Task Configuration

Task metadata captures execution strategy from issue:

| Pattern | Task Configuration |
|---------|-------------------|
| main-only | Single task, no dependencies (unless issue requires prereq) |
| sequential | Chain of tasks with linear blockedBy (if multiple issues use sequential across them) |
| parallel | Multiple tasks without blockedBy (parallel execution) |
| delegation | Parent task + specialist subtasks (captured via specialist metadata field) |

### Benefits

- **TaskList()**: Shows execution progress across entire milestone
- **Automated scheduling**: System knows what's ready vs blocked
- **Context preservation**: Task metadata links to GitHub issue for full details
- **Execution tracking**: activeForm provides current work status

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
- Task graph reference (if generated): "Task Graph: Tasks #1-#5 created with dependency chain"
  - This enables `TaskList()` to show execution progress across milestone
  - Links Task system to GitHub milestone for unified tracking

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
<!-- TDD: enabled --> ← Add this marker if TDD was selected in Step 3

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
<!-- For ralph-loop execution, ALL criteria must be verified before <promise>TASK_COMPLETE</promise> -->

**Build & Quality Gates**:
- [ ] Build passes (`npm run build` / `tsc --noEmit` / `cargo build` / equivalent)
- [ ] Lint passes (`npm run lint` / `eslint` / `ruff` / equivalent)
- [ ] Type check passes (if applicable)

**Test Verification**:
- [ ] All existing tests pass
- [ ] New tests added for new functionality (if code change)
- [ ] Test coverage maintained or improved

**Functional Verification**:
- [ ] Implementation complete (all tasks checked above)
- [ ] Execution verified (actual runtime test, not just compile)
- [ ] Edge cases handled (based on Implementation Steps)

**Ralph-Loop Checkpoint** (if executed via ralph):
- [ ] Zero pending/in_progress TODOs
- [ ] Architect verification requested and APPROVED
- [ ] No scope reduction from original requirements

**Optional** (context-dependent):
- [ ] Added to demo page (for UI components)
- [ ] Documentation updated (for API changes)
- [ ] Migration guide provided (for breaking changes)

**Dependencies**:
- [ ] None or prerequisite issue #number

**Task Tracking** (auto-generated if Task graph created):
- Task ID: `{auto-assigned by TaskCreate}`
- Blocked by: `{dependency-task-ids or "none"}`
- Pattern mapping: `{execution-pattern -> task configuration}`

**Execution strategy** (auto-detected):
- **Pattern**: [auto-selected based on Auto-Detection Algorithm]
- **Rationale**: [brief explanation, e.g., "3 files, medium complexity, TDD enabled"]
- **Delegate to**: [agent name if delegation, else "N/A"]

**Execution diagram**:
```
[Auto-generated based on pattern - see Execution Patterns section]
```

> **Manual Override**: If the auto-detected pattern is inappropriate, explicitly specify the desired pattern with justification.

**References** (optional):
- Add related PRs if available (e.g., PR #36 - brief description)
- Omit this section if none

---

## Execution Strategy Guide

### Component Discovery

Before decomposing issues, scan for available agents:
- **Agents**: `.claude/agents/*.md` (extract name, description from YAML frontmatter)

### Execution Patterns

```
Pattern A: main-only
+------+
| main |
+------+

Pattern B: sequential
+---------+     +------+
| explore | --> | main |
+---------+     +------+

Pattern C: parallel
+---------+
| explore |--+
+---------+  |  +------+
| explore |--+->| main |
+---------+  |  +------+
| explore |--+
+---------+

Pattern D: delegation
+------+     +-------------------+
| main | --> | security-reviewer |
+------+     | designer          |
             +-------------------+

Note: main can spawn subagents at any point during execution
```

### Pattern Selection

| Situation | Pattern | Example |
|-----------|---------|---------|
| Simple fix/change | main-only | Bug fix, single file change |
| Analysis then implement | sequential | New feature, refactoring |
| Complex analysis needed | parallel | Large refactor, architecture change |
| Specialized work | delegation | Security audit, UI redesign |

### Auto-Detection Algorithm

When decomposing issues, OMC MUST auto-determine the execution strategy using this 2-phase approach:

---

#### Phase 1: Preliminary Pattern Selection (During Issue Analysis)

**Step 1: Check for Specialist Needs**
| Keyword/Context in Issue | Pattern | Delegate To |
|--------------------------|---------|-------------|
| "security", "vulnerability", "CVE", "auth", "authentication", "login", "password", "encryption", "CSRF", "XSS", "CORS" | delegation | security-reviewer |
| "performance", "optimize", "profile" | delegation | architect |
| "UI", "component", "styling", "CSS" | delegation | designer |
| "data analysis", "statistics", "ML" | delegation | scientist |
| TDD marker present | sequential (minimum) | tdd-guide (coordination) |

If specialist needed → Pattern D (delegation), STOP.

**Step 2: Analyze Scope Keywords from Work Description**
| Scope Signal in Description | Preliminary Pattern |
|-----------------------------|---------------------|
| "single file", "specific function", "one method", "this line" | `main-only` |
| "module", "feature", "service", "endpoint", "component" | `sequential` |
| "multiple modules", "across", "refactor", "system-wide", "global" | `parallel` |
| No clear scope signal detected | `sequential` (default - safe middle ground) |

**Step 3: Infer Complexity (if not labeled)**

If issue has explicit `complexity:` label, use it. Otherwise, infer from signals:

| Signal Combination | Inferred Complexity |
|-------------------|---------------------|
| `impactScope: local` AND `estimatedSubtasks: 1-2` | `easy` |
| `impactScope: module` OR `estimatedSubtasks: 3-4` | `medium` |
| `impactScope: system-wide` OR `estimatedSubtasks: 5+` | `hard` |
| No clear signals | `medium` (default) |

**Impact Scope Detection:**
- `local`: Changes isolated to single function/class
- `module`: Changes span multiple files in one module/feature
- `system-wide`: Changes touch multiple modules or shared infrastructure

**Step 4: Adjust by Complexity**
| Complexity | Adjustment to Preliminary Pattern |
|------------|-----------------------------------|
| `easy` | Downgrade one level (parallel → sequential → main-only) |
| `hard` | Upgrade one level (main-only → sequential → parallel) |
| `medium` | No change |

**Step 5: TDD Override**
If TDD enabled AND pattern is `main-only` → Upgrade to `sequential` (need explore for test patterns)

---

#### Phase 2: Pattern Refinement (After File List Generated)

After "Files to Modify" lists are generated for each subtask, refine the pattern:

| Actual File Count | Refinement Action |
|-------------------|-------------------|
| 0-1 files | Confirm `main-only`, or downgrade if currently higher |
| 2-4 files | Confirm `sequential` |
| 5+ files | Escalate to `parallel` if not already |

**Conflict Resolution:**
- If Phase 2 file count contradicts Phase 1 scope keywords, **Phase 2 wins** (empirical data over heuristics)
- Document the refinement in the rationale field

---

#### Default Behavior (Explicit)

When NO signals are detected (no specialist keywords, no scope signals, no complexity indicators):
- **Default Pattern**: `sequential`
- **Default Complexity**: `medium`
- **Rationale**: Safe middle ground - provides agent coordination without parallel overhead

### Diagram in Issues

Always include an ASCII diagram in the issue body. Copy the relevant pattern from **Execution Patterns** section above.

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
