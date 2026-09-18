---
name: decompose-issue
description: "Break a large work item into context-completable GitHub sub-issues, define a 10-20 node architecture and workflow mapping, propose a milestone, and create the issues with gh. Also owns the repository issue-label taxonomy — on 'create issue labels', '라벨 만들어줘', or a label-taxonomy setup request, run only the Labels step and stop. Use ONLY when the user explicitly types /dev:decompose-issue, asks to decompose or break down work into issues, or asks for issue labels. Do NOT auto-fire from incidental mentions of issues or planning — this creates GitHub issues, a milestone, and a project-tracking state file. Detects TDD applicability, captures dependencies, and writes .claude/state/project-tracking-{slug}.json for the milestone and diagram pipeline."
allowed-tools: Read Write Edit Bash Glob Grep AskUserQuestion
---

# Decompose Issue

Break a large work item into manageable, independent GitHub issues, map them onto the project's architecture, and create them with a milestone. Follow project guidelines in `@CLAUDE.md`.

Vertical-slice sizing and the decision-forward issue template are adapted from mattpocock/skills `to-tickets/SKILL.md` (commit `74ca5fe`).

## Guidelines

- **Interactive input is capability-aware.** Every confirmation below runs through a gate, not one hardcoded tool; read each `AskUserQuestion` mention as this gate. Claude Code uses `AskUserQuestion`. Codex uses `request_user_input` when that tool is exposed; when it is not, ask ONE concise blocking question only where a wrong assumption would be costly (creating GitHub issues), otherwise proceed on a documented safe default and state the assumption. Full policy: `AGENTS.md` → "Cross-runtime interactive input policy".
- **The state file schema is owned elsewhere.** `../post-merge/references/update-progress.md` holds the `project-tracking-{slug}.json` schema, its field reference, the slug rule, and the milestone/diagram formats. This skill writes the file; it does not restate the schema.

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
   - If TDD selected: Add `<!-- TDD: enabled -->` marker to each issue body, and confirm the test
     seam per issue now (see "Decide seams and open decisions before creating issues" below) so the
     issue body carries an agreed seam instead of leaving it for `resolve-issue` to ask about.

3.5. **Check E2E applicability** (only when the work has a critical user flow — skip silently
   otherwise, do not ask on every issue):
   - If a critical user flow is in scope → ask through the interactive-input gate: "이 흐름에 E2E
     테스트가 필요한가요?" naming the flow.
   - If approved: record the target flow and a pointer to `dev:e2e-author` in the issue body's
     "결정 사항" section.
   - If no E2E harness exists in the repo (no `playwright.config.*`, no `e2e/` directory): add a
     blocking prerequisite issue for `dev:e2e-setup` instead of assuming one exists.
4. Analyze work: Understand core requirements and objectives
5. Decompose work: Split major tasks into **context-completable units** - each issue should be completable in a single Claude session without context switching. Group related features together rather than splitting by individual functions
6. Analyze dependencies: Identify prerequisite tasks
7. Suggest milestone name: Propose a milestone to group decomposed tasks
8. Check related PRs (optional): Run `gh pr list --state closed --limit 20` for similar work references (skip if none)
9. Output decomposed issues: Display issues with proposed milestone name

9.5. **Define Architecture & Workflow Mapping** (for project progress tracking):

   #### Step A: Capture Project Workflow

   Analyze the codebase and design a **10-20 node flowchart** of the project's core workflow. Store as Mermaid in the state file, but present to the user as an ASCII diagram.

   - **Interview: Project Workflow** -- Use the interactive-input gate (Claude `AskUserQuestion`):
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

   - **Interview: Milestone Scope** -- Use the interactive-input gate:
     > "이 마일스톤이 커버하는 노드를 선택해 주세요."
     - Present all node IDs from the workflow diagram
     - User selects which nodes are in scope for this milestone (`scopeNodes`)
     - These nodes will be highlighted with `:::scope` in generated diagrams

   #### Step C: Module Grouping & Issue Mapping

   - Analyze decomposed issues and propose module groupings based on workflow areas
   - **Interview: Issue-Module-Node Mapping** -- Use the interactive-input gate:
     > "이슈-모듈-노드 매핑이 맞나요?"
     - Show each issue with: proposed module, mapped architecture node
     - User can reassign issues between modules or change node mappings

   #### Step D: Issue Dependencies

   - Analyze issue order and propose dependency chains
   - **Interview: Issue Dependencies** -- Use the interactive-input gate:
     > "이슈 간 의존성(실행 순서)이 맞나요?"
     - Show proposed dependency graph: `#1 -> #2 -> #3`, `#2 -> #4`
     - User can add/remove dependencies
     - Dependencies are stored as `dependsOn: [issueNumber]` per issue

   #### Step E: Save State File

   Write `.claude/state/project-tracking-${SLUG}.json` in the shape defined by
   `../post-merge/references/update-progress.md` ("State File Schema", "Schema Field Reference",
   "Slug Generation"). At creation time:

   - `version` is `"2.0.0"`; `milestoneId` and `lastSyncedAt` are `null` until Step 10 creates the
     milestone; `issues` is filled in after the issues exist on GitHub.
   - `architecture.mermaidSource` is the full Mermaid flowchart from Step A, `scopeNodes` the Step B
     selection, `modules[]` the Step C grouping, and `issues[].dependsOn` the Step D edges.
   - `diagramMarkers` carries the `<!-- project-tracking-start -->` / `<!-- project-tracking-end -->`
     pair that `post-merge` replaces between.

   ```bash
   mkdir -p .claude/state
   ```

9.7. **Decide seams and open decisions before creating issues** (Decision 13): pull forward every
   decision `resolve-issue` would otherwise have to ask about mid-implementation — test seam,
   design decisions with more than one reasonable option, scope boundaries — and settle them now
   through the interactive-input gate while the user is still in the loop. Write what got settled
   into each issue's "결정 사항" section and whatever is still genuinely undecided into "Open
   questions". The goal is that `resolve-issue`, run from a worker subagent with no
   `AskUserQuestion`, never has to stall on a question the issue could have answered.

9.8. **Check labels** before creating anything on GitHub: run `gh label list`. If the labels this
   decomposition needs (type/area, and any complexity/priority labels referenced above) are not in
   that output, run the "Labels" section below to create them first.

10. **Ask about GitHub creation**: Use the interactive-input gate to let user decide on milestone and issue creation
    - Create milestone with **Markdown Table** in description.

      > **CRITICAL — DO NOT include Mermaid in milestone description.** GitHub milestone pages do not render Mermaid; the raw code shows as plain text. Mermaid belongs in **issue bodies** (Type M-2; see `../post-merge/references/update-progress.md` "Type M-2"), never in the milestone description.

      Build `$MILESTONE_TABLE` with the required table block below (canonical spec at `../post-merge/references/update-progress.md`, "Milestone Format").
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
      TMP=$(mktemp)
      jq --arg mid "$MILESTONE_NUMBER" '.milestoneId = ($mid | tonumber)' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
      ```
    - **Inject the TDD marker (if TDD was enabled in Step 3)**: when creating each issue, prepend `<!-- TDD: enabled -->` as the first line of the issue body (before `**Purpose**:`). This is the exact marker `resolve-issue` Step 1 detects to switch on the TDD workflow. If TDD was not selected in Step 3, omit the prepend entirely — do not write the marker.
    - Assign issues with `--milestone` option
    - After issue creation, update the state file `issues` map with actual GitHub issue numbers

11. **Add issues to GitHub Project (optional)**
   - Check for existing projects: `gh project list --owner <owner> --format json`
   - If no project exists: report "No GitHub Project found — create one on GitHub and re-run if you want the issues tracked there" and skip
   - If project exists: Ask user via the interactive-input gate whether to add issues
   - If yes: Run `gh project item-add <project-number> --owner <owner> --url <issue-url>` for each issue

## Issue Sizing Principle

### Cost model

One issue becomes one PR becomes one review cycle. An issue is not free to create: every issue this
skill opens costs its own PR and its own pass through `cr-fix` (bot review rounds, human attention,
CI minutes). Sizing is a trade-off against that cost, not a virtue to maximize in either direction —
neither "as many small issues as possible" nor "as few issues as possible" is the goal on its own.

### Context-Completable Units
Each issue should be designed to be **completable in a single Claude session**:

- **Group related features** rather than splitting by individual functions
- **Minimize context switching** - all necessary information should be within the issue
- **Specify behaviour, not implementation** - detailed enough that no external lookup is needed
  during execution, without prescribing file-level code

### Splitting criteria (Decision 7)

Split along these three axes, in order:

1. **Vertical slice per user-facing capability.** Each issue cuts a complete path through every
   layer it touches (schema, API, UI, tests) for one behaviour, not one layer across many
   behaviours. A slice is demoable or verifiable on its own once merged.
2. **Non-overlapping file ownership.** Two issues that would need to write the same file in the
   same PR belong in one issue, or must be ordered with a blocking edge — never left to race.
3. **Neither over-fragmented nor under-split.** Don't split a single cohesive behaviour into one
   issue per function or endpoint (that multiplies review cycles for no independent value). Don't
   bias toward the fewest possible issues either — a wide, blast-radius-spanning change is the
   **expand-contract exception** below, not a reason to cram unrelated behaviours into one issue.

### Sizing Guidelines

| Good (Context-Completable) | Bad (Over-Fragmented) |
|---------------------------|----------------------|
| "Add user authentication with login/logout/session" | "Add login button", "Add logout button", "Add session handling" (3 separate issues) |
| "Implement CRUD API for products" | "Add create endpoint", "Add read endpoint", "Add update endpoint", "Add delete endpoint" (4 separate issues) |
| "Setup CI/CD pipeline with test and deploy stages" | "Add test stage", "Add deploy stage" (2 separate issues) |

### Issue Content Depth (Decision 8)

Content stays behaviour-level, not implementation-level:

1. **Implementation order** - numbered steps for execution sequence, stated as outcomes
2. **File paths as a starting-point hint only** - point to where the work begins, never a
   file-by-file change list
3. **No code snippets** - patterns and structures go stale the moment the code around them moves;
   describe the decision in prose instead
4. **Edge cases** - known gotchas or considerations

### Wide Refactors: the expand-contract exception

Context-completable vertical slices are the default, but a **wide refactor** — a
mechanical change that touches many call sites of one form (a renamed API, a
changed signature, a moved type) — cannot be a single vertical slice without a
giant blast radius, and cannot be split by feature. Sequence it as
**expand -> migrate -> contract** instead:

1. **Expand** (one issue): add the new form *beside* the old so nothing breaks
   yet — both coexist.
2. **Migrate** (one issue *per batch*, each blocked by Expand): move call sites
   to the new form in batches sized by blast radius (per package, per directory).
   Each batch is its own issue so each stays context-completable and green.
3. **Contract** (one issue, blocked by *every* Migrate): delete the old form once
   no caller remains.

Keep each Migrate batch independently green — that is what lets `/dev:resolve-issue`
drive it, since resolve-issue branches each issue off the default branch and
gates BUILD/TEST before the PR. Only if a batch genuinely cannot stay green
alone, fall back to a shared **integration branch**: the Migrate batches target
it instead of the default branch, and a single **integrate-and-verify** issue
`dependsOn` *every* Migrate batch and promises green. This fallback is a manual, multi-issue branch flow —
resolve-issue's one-branch-per-issue model does not drive it, so sequence it by
hand. In that path **Contract must block on integrate-and-verify, not on the
individual Migrate issues** (`dependsOn: [<integrate-and-verify #>]`), or the old
form could be deleted before the combined migration is validated. Record every
blocking edge with `dependsOn` so the milestone dependency graph renders the
expand -> migrate -> contract order.

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

**Label-only entry**: when the user asked for labels alone ("create issue labels", a label taxonomy for the repo), run this section only — create the labels and stop without creating issues, a milestone, or a state file.

If the repository has no usable taxonomy yet, create one first: inspect `package.json`/`README`/code layout to pick areas, then create type/area/complexity labels. `--force` makes the call create-or-update, so a re-run refreshes an existing label instead of erroring, and each category keeps a stable color (an omitted `--color` gets a random one every run):

```bash
gh label create "type: feature" --color "0e8a16" --description "New feature addition" --force
gh label create "area: frontend" --color "1d76db" --description "Frontend-related work" --force
gh label create "complexity: easy" --color "7057ff" --description "Simple task" --force
```

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

**결정 사항** (settled during decomposition — Decision 13; resolve-issue must not have to ask):
- [Test seam, design decision, or scope boundary already decided, and what was decided]

**테스트 seam** (only when TDD is enabled): the public interface / boundary the tests for this
issue assert through. This is what `resolve-issue`'s TDD branch reads as the agreed seam.

**Open questions**: anything genuinely still undecided that implementation must surface, not
silently resolve on its own.

**시작점 힌트** (starting-point hints, not a file-by-file change list):
- `path/filename` - what area of the code this touches

**Completion criteria** (user-facing acceptance criteria):
- [ ] Acceptance criterion 1, stated as observable behaviour from the user's perspective
- [ ] Acceptance criterion 2

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
