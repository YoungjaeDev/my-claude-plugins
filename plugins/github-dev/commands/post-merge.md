---
description: Clean up branch and integrate PR learnings into config files
---

# Post-Merge Cleanup

Perform local branch cleanup and configuration updates after a PR has been merged. For worktree removal, use `/exit` with cleanup option. Follow project guidelines in `@CLAUDE.md`.

## Arguments

- PR number (optional): If not provided, infer from conversation context or prompt user to select from recent merged PRs

## Workflow

1. **Identify PR**
   - Use PR number if provided as argument
   - Otherwise, attempt to infer related PR/issue number from conversation context
   - If unable to determine, run `gh pr list --state merged --limit 5` to show recent merged PRs and prompt user to select

   - Run `gh pr view <PR_NUMBER> --json number,title,baseRefName,headRefName,body,state,files` to get PR details
   - Verify `state` is MERGED. This `gh pr view` result is the **authoritative merge signal** for the rest of this workflow — later steps MUST NOT re-verify merge state by comparing git SHAs.

2. **Check Local Changes**
   - Run `git status --porcelain` to check for uncommitted changes
   - **Untracked files (`??`)**: Ignore and proceed (do not affect branch switching)
   - **Modified/Staged files (`M`, `A`, `D`, etc.)**: Prompt user for action:
     - **Stash and proceed**: `git stash push -m "post-merge: temp save"`
     - **Discard changes**: `git checkout -- . && git clean -fd`
     - **Abort**: Let user handle manually
   - **If stash selected**: After workflow completion, prompt user for stash restoration:
     - **pop**: `git stash pop` (restore and remove stash)
     - **apply**: `git stash apply` (restore and keep stash)
     - **later**: Let user handle manually

3. **Switch to Base Branch**
   - `git fetch origin`
   - `git checkout <baseRefName>`
   - `git pull origin <baseRefName>`

4. **Clean Up Local Branch**
   - Check if branch exists locally: `git branch --list "$headRefName"`
   - **Do NOT use any SHA-level commit comparison as a merge check** — `git log <base>..<branch>`, `git cherry <base> <branch>`, `git rev-list --left-right <base>...<branch>`, and similar variants all produce false positives after **squash merge** (base gets one new SHA containing combined content; branch SHAs unchanged) AND **rebase merge** (branch SHAs are rewritten on base — none match). Trust Step 1's `gh pr view` result; the content is already in base even when SHAs diverge.
   - If unsure whether all content landed in base, compare content (not SHAs):
     ```bash
     # Content-level diff is safe for squash merges; empty output = fully landed
     git diff "origin/$baseRefName..$headRefName" -- <paths>
     ```
   - If exists, prompt user to confirm deletion
   - If confirmed: `git branch -d "$headRefName"`
     - For squash-merged branches, expect `warning: not yet merged to HEAD` — this is normal. `git branch -d` detects merge via `origin/<branch>` tracking, so the delete still succeeds. Do NOT escalate to `-D`, do NOT treat the warning as data loss, and do NOT open a new PR for "missing" commits.
   - If any worktrees remain for this branch, inform user:
     > "Worktree detected for `$headRefName`. Run `/exit` with cleanup option to remove it."

5. **Update GitHub Project Status (Optional)**
   - Extract related issue numbers from PR body: search for `Closes #N`, `Fixes #N`, `Resolves #N` patterns
   - Run `gh project list --owner <owner> --format json` to check for projects
   - If no projects exist, skip silently
   - If projects exist:
     - Run `gh project item-list` to get the issue's item-id
     - Run `gh project field-list` to get Status field ID and "Done" option ID
     - Run `gh project item-edit` to set Status to "Done"
     - Skip if issue is not in project or Status field does not exist

5.5. **Sync Milestone Progress** (if issues have milestones):
   - Extract related issue numbers from PR body (already found in Step 5): `Closes #N`, `Fixes #N`, `Resolves #N`
   - For each related issue, check milestone:
     ```bash
     MILESTONE=$(gh issue view $ISSUE_NUM --json milestone --jq '.milestone.title // empty')
     ```
   - If milestone exists:
     1. Generate slug from milestone name (lowercase, spaces to hyphens, remove special chars)
     2. Load state file: `.omc/state/project-tracking-{slug}.json`
     3. If state file not found: skip this issue
     4. Update issue state to `"closed"` in the state file
     5. Recalculate module progress:
        ```
        module.progress = (closed_issues / total_issues) * 100
        module.status:
          "complete"    -> all issues closed
          "in_progress" -> at least 1 closed or has PR, at least 1 still open
          "pending"     -> all open, no PR
        ```
     6. Regenerate **Milestone Table** (for milestone description):
        - Generate Markdown Table with all issues, status indicators, and dependencies
        - See `update-progress.md` "Milestone Format" for full format
     7. Regenerate **Type M-2 Mermaid diagram** (for each issue body in milestone):
        - Read `architecture.mermaidSource` from state file
        - Highlight the issue's `architectureNode` with `:::scope`
        - Create `context` subgraph with this issue, `deps` with `dependsOn` issues, `next` with dependent issues
        - See `update-progress.md` "Type M-2" for full format
     8. Update milestone description:
        ```bash
        MILESTONE_NUMBER=$(cat .omc/state/project-tracking-${SLUG}.json | jq -r '.milestoneId')
        # Fallback if null:
        # MILESTONE_NUMBER=$(gh api repos/:owner/:repo/milestones \
        #   --jq '.[] | select(.title=="<name>") | .number')
        gh api repos/:owner/:repo/milestones/$MILESTONE_NUMBER \
          -X PATCH -f description="$MILESTONE_TABLE"
        ```
     9. Update each open issue's body tracking section (marker-based replacement):
        ```bash
        CURRENT_BODY=$(gh issue view $ISSUE_NUM --json body --jq '.body')
        # If <!-- project-tracking-start --> exists: replace section between markers
        # If not: append tracking section at end of body
        # Tracking section contains Type M-2 Mermaid for that issue's context
        gh issue edit $ISSUE_NUM --body "$NEW_BODY"
        ```
     10. Save state file with updated `lastSyncedAt`
   - Skip silently if no milestones found on any related issues

6. **Integrate Learnings into Configuration Files**

   > **Core Principle: No Stamps, Topical Names, Current State Only**
   >
   > normative doc(CLAUDE.md, AGENTS.md, GEMINI.md, .claude/rules/*, Serena memory)은 **현재 상태의 규정**만 담는다. 변경 이력(provenance)은 git commit message, PR body, GitHub blame이 이미 영구 보존하므로 doc에 중복 기재하지 않는다.
   >
   > **금지 패턴 (regex로 식별):**
   > - `\(?#\d+\)?` — `(#123)`, `#123` 인라인 인용
   > - `\b(PR|pr|Pull Request) ?#?\d+\b` — `PR #50`, `PR50`, `Pull Request 50`
   > - `\b([Ii]ssue|이슈) ?#?\d+\b` — `Issue #65`, `이슈 #53`
   > - `\b(Added|Removed|Fixed|Changed|Introduced) in (PR|#)` — historical narrative 시작 패턴
   > - `## Post-Merge` — 날짜·PR 기반 섹션 헤더
   > - `<YYYY-MM-DD>`가 섹션 헤더 자체에 들어간 경우
   >
   > **섹션 명명 규칙**: topical name만 사용 (예: `## Process Lifecycle`, `## Crawler Throttling`). 날짜·PR·이슈 번호를 섹션명에 포함시키지 않는다.
   >
   > **Writing tone**: "X is async" (current-state). NOT "X was changed to async in PR #50" (history). NOT "Previously we used Y; now we use X (#50)" (transition narrative).
   >
   > **예외**: `Closes #N` / `Fixes #N` 류 GitHub keyword는 commit message / PR body / issue 본문에서만 허용. normative doc 안에서는 금지.

   > **Content-First principle**: Refine stale/duplicate content **in place first**, consolidate duplicates next, and only delete a file when it becomes empty or orphaned. File-level deletion is the last resort, not the default.

   **Pre-Audit: Clean Existing Pollution First**

   새 학습을 통합하기 전에 target 파일들의 기존 스탬프를 먼저 청소한다. 이전 실행이 남긴 누적 오염을 incremental하게 healing하는 단계.

   1. Target 파일 후보 목록 작성: `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.claude/rules/*.md` 중 존재하는 것만.
   2. 각 파일에 Core Principle 의 금지 패턴 grep:
      ```bash
      rg -nP '(\(?#\d+\)?|\b(PR|pr) ?#?\d+\b|\b([Ii]ssue|이슈) ?#?\d+\b|\b(Added|Removed|Fixed|Changed|Introduced) in (PR|#)|## Post-Merge)' <file>
      ```
   3. 히트가 0건이면 Pre-Audit 즉시 skip하고 다음 단계(Read the PR diff)로 진행.
   4. 히트가 있으면 사용자에게 보고:
      - 파일별 hit 줄 번호와 quoted 원문
      - 각 줄에 대한 "stamp 제거 + 의미 보존" 재작성 제안
   5. **재작성 원칙**:
      - 스탬프만 제거하고 normative content는 보존 — `"max_pages 기본값은 10 (이슈 #53)"` → `"max_pages 기본값은 10"`
      - Historical narrative는 current-state로 변환 — `"PR #18 벤치는 더 이상 안전 기준이 아님"` → 줄 자체 삭제 또는 `"uniform 1-2.5초 벤치는 사용하지 않는다"` (현재 규정만)
      - 같은 이슈를 여러 곳에서 인용한 중복 — 가장 적절한 한 섹션으로 내용 통합 후 나머지 인용 삭제
      - PR/이슈 본문에서 가져온 reasoning은 보존하되 출처 인용만 제거
   6. `AskUserQuestion`으로 적용 게이트:
      - "전부 적용" / "파일별 선택" / "Pre-Audit 건너뜀" 선택지 제공
      - description에 파일별 hit 수 명시
   7. 사용자 승인 후 정리 적용. 정리 완료 후 신규 학습 통합으로 진행.

   Read the PR diff (`gh pr diff <PR_NUMBER>`) and PR body to extract learnings. Then integrate each learning into the **appropriate existing section** of configuration files.

   **CRITICAL: Never append "Post-Merge Notes" sections.** All learnings must be woven into the existing document structure as if they were always there.

   - Check which configuration files exist:
     - `CLAUDE.md` - Claude Code specific instructions
     - `AGENTS.md` - Cross-tool AI coding agent instructions
     - `GEMINI.md` - Google Gemini CLI specific instructions
     - `.claude/rules/*.md` - Modular rule files

   - **Classification and Placement** (applies to all config files):

     | Learning Type | Target Section | Action |
     |---------------|----------------|--------|
     | New constraint / invariant | Golden Rules > Immutable | Add as a new bullet |
     | New convention / best practice | Golden Rules > Do's | Add as a new bullet |
     | New prohibition / anti-pattern | Golden Rules > Don'ts | Add as a new bullet |
     | New/changed command or script | Commands | Add or update the command block |
     | Module added/removed/changed | Key Modules table | Update the row description |
     | New data file or location | Data Locations table | Add or update the row |
     | New module rule reference | Modular Rules | Add `See @path` reference |
     | Module-specific rule | `.claude/rules/[module].md` | Update or propose creation |
     | Tech stack change | Project Context | Update the tech description |
     | Test count change | Commands or relevant section | Update the count |

   - **Integration Process**:
     1. Read the current config file to understand existing structure and content
     2. For each learning, find the most specific existing section it belongs to
     3. Merge the new information naturally -- update existing descriptions rather than adding footnotes
     4. If an existing bullet or row already covers the topic, **update it in place** rather than adding a new entry
     5. Remove any outdated information that the PR supersedes (e.g., old module descriptions, removed features)

   - **Content Removal**:
     - Temporary instructions (e.g., `TODO: remove after #N`)
     - Resolved known issues
     - Workaround descriptions for fixed bugs
     - **Existing "Post-Merge Notes" sections** -- migrate their content into proper sections, then delete the notes

   - **Modular Rule Files** (.claude/rules/*.md):
     - Check if relevant module file exists
     - Propose path-specific rules with frontmatter: `paths: src/[module]/**`
     - Follow structure: Role, Key Components, Do's, Don'ts
     - **Always confirm with user before creating new rule files**

   - **Pre-presentation validation (스탬프 자체 검증)**:

     proposal을 사용자에게 보여주기 전에 **추가/수정되는 모든 라인**을 Core Principle 금지 패턴으로 self-check. (`Remove:` 류 cleanup 라인은 검증 대상 아님 — 스탬프 제거가 목적이므로 정상.)

     검증 체크리스트:
     - [ ] 추가/수정되는 어떤 라인도 `(#N)`, `PR #N`, `이슈 #N`, `Issue #N` 류 인라인 인용 없음
     - [ ] 새 섹션 헤더가 날짜·PR·이슈 번호 포함하지 않음 (`## Post-Merge`, `## 2026-04-28 Updates` 등 금지)
     - [ ] 모든 추가 bullet이 current-state 톤 ("X is async") — 변천사 톤 ("X was changed to async") 아님
     - [ ] "Added in PR" / "Removed in PR" / "Fixed in PR" / "Introduced in PR" 어구 없음

     **하나라도 실패 시**: proposal을 사용자에게 보여주지 말고 먼저 재작성. 패턴을 만족할 때까지 self-loop. 사용자에게 보여줄 시점에는 모든 체크리스트가 ✓ 상태여야 한다.

   - Present the integration proposal to user as a diff-style summary before applying:
     ```
     CLAUDE.md changes:
       Golden Rules > Don'ts: + "Never reintroduce preview branching (Dispatcher is direct-send only)"
       Key Modules > electron-admin: "4 nav tabs" -> "3 nav tabs: Dashboard / AI / Settings"
       Remove: "Post-Merge Notes (PR #130)" section (content migrated above)
     ```

7. **Update Serena Memory (if Serena MCP available)**

   > **Content-First principle**: Before appending new learnings, scan existing memory for stale or duplicate content and refine it **in place**. Only delete a memory file when its content has been fully migrated elsewhere or becomes orphaned.

   Integrate PR learnings into Serena memory as native content. Learnings should read as if they were always part of the memory -- not as appended post-merge notes.

   **Pre-Audit (기존 memory 파일의 스탬프 정리)**:

   `list_memories` → `read_memory` 단계 전에 모든 memory 파일에 Core Principle 패턴 grep. 히트 발견 시 Step 6의 Pre-Audit과 동일한 절차로 사용자 승인 후 정리 (`edit_memory` 사용). 정리 완료 후 신규 학습 통합 진행.

   특히 다음 패턴은 즉시 정리 대상 (아래 "Bad" 예제 형태):
   - `## Post-Merge (date, PR #N)` 헤더 — topical 섹션으로 내용 분산 후 헤더 삭제
   - `post_merge_prN.md` 파일명 자체 — 내용을 topical 파일로 이전 후 파일 삭제
   - bullet 본문의 `(Issue #N)` / `(이슈 #N)` 인라인 인용 — 인용만 제거, 내용 보존

   **Procedure:**

   1. Run `list_memories` to discover existing memory files
   2. Run `read_memory` on candidate files to understand their current sections and structure
   3. Analyze PR diff and body for learnings worth preserving:
      - Architectural decisions, new patterns, resolved issues, module-specific knowledge
   4. For each learning, find the best-fit section in an existing memory file (use the mapping table below)
   5. Use `edit_memory` to add or update content within that section

   **Memory File Mapping:**

   | Learning Category | Likely Target File | Section to Update |
   |-------------------|--------------------|-------------------|
   | Architecture changes, new modules, removed features | `project_overview.md` | Architecture, Key Features, Key Files |
   | Code patterns, naming, type changes | `code_style.md` | Code Patterns, Conventions |
   | New scripts, commands | `suggested_commands.md` | Relevant command group |
   | Workflow insights, process notes | `task_completion.md` | Relevant section |

   **Integration Rules:**
   - **NEVER create new memory files** (especially not `post_merge_prN.md`)
   - **NEVER add `## Post-Merge` headers** -- `## Post-Merge (date, PR #N)` creates changelog noise, not reference material
   - Find the existing section that covers the topic and add bullets there
   - If no matching section exists, create a **topical section** named after the subject (e.g., `## Shutdown Handling`), not after the PR
   - Update outdated descriptions in place rather than keeping old text alongside new
   - If content doesn't fit any existing file, append to `project_overview.md` as catch-all
   - **Self-check before applying `edit_memory`**: 추가하려는 텍스트가 Core Principle 금지 패턴(`(#N)`, `PR #N`, `이슈 #N`, "Added in PR" 등)을 포함하는지 검증. 포함 시 재작성 후 적용.

   **Example -- Good (PR #132: graceful shutdown fix):**

   Before (`task_completion.md`):
   ```
   ## Process Lifecycle
   - `start()` initializes polling loop
   - `stopPolling()` signals shutdown
   ```

   After:
   ```
   ## Process Lifecycle
   - `start()` initializes polling loop and resets `isShuttingDown` flag
   - `gracefulShutdown()` is async; awaits shutdown handlers before exit
   - `isShuttingDown` flag prevents double-shutdown race conditions
   - `pollOnce` for-loop checks `isRunning` for early abort during shutdown
   ```

   **Example -- Bad (what NOT to do):**
   ```
   ## Post-Merge (2026-02-16, PR #132)
   - Graceful shutdown race condition fixed (Issue #69)
   - `Orchestrator.gracefulShutdown()` async conversion
   - `isShuttingDown` flag for double-shutdown prevention
   ```

   Skip if no significant learnings or Serena unavailable.

8. **Update README.md (if needed)**

   Check if PR introduced changes that affect README:
   - New features or commands
   - Changed installation steps
   - Updated dependencies
   - Modified usage examples
   - Removed features (update feature list)

   If README exists and updates are needed:
   1. Draft the README changes
   2. Apply `/humanizer:humanize` to the changed sections to remove AI-generated patterns
   3. Apply `/docs-forge:readme` guidelines (CRO best practices, structure, clarity)
   4. Present the final proposal to user for confirmation before applying

   Skip if no README-relevant changes.

9. **Commit Changes (Optional)**
   - If any configuration files were modified, prompt user to confirm commit
   - If confirmed: Commit using Conventional Commits format
   - Stage only modified files: `git add CLAUDE.md AGENTS.md GEMINI.md README.md .serena/memories/ 2>/dev/null || true`

> See [Work Guidelines](../guidelines/work-guidelines.md)

## Configuration File Integration Guide

The following guidelines apply to CLAUDE.md, AGENTS.md, GEMINI.md, and `.claude/rules/*.md`:

### Expected File Structure

**Root Config (CLAUDE.md, AGENTS.md, GEMINI.md)**:
1. Project Context - Business goal + tech stack (1-2 sentences)
2. Commands - Package manager and run commands
3. Golden Rules - Immutable / Do's / Don'ts
4. Modular Rules - `See @.claude/rules/[module].md` references
5. Project-Specific - Data locations, key modules, tracking, etc.

**Modular Rules (.claude/rules/*.md)**:
```markdown
---
paths: src/[module]/**  # Optional: conditional loading
---
# [Module] Rules
Role description (1-2 lines)
## Key Components
## Do's
## Don'ts
```

### Anti-Patterns (NEVER do these)

→ See **Core Principle: No Stamps, Topical Names, Current State Only** at the top of Step 6.

요약:
- normative doc 안에 PR/이슈 인용 금지 (인라인, 헤더, footnote 모두)
- `## Post-Merge` 류 changelog-style 섹션 / `post_merge_prN.md` 류 PR-specific memory 파일 금지
- Append-only 패턴 금지 — 기존 섹션을 in-place 업데이트
- Historical narrative 금지 — current-state로 작성

### Correct Integration Examples

**Instead of**:
```markdown
## Post-Merge Notes (PR #130)
- Preview Mode removed. Dispatcher is direct-send only.
- Admin Nav changed from 4 tabs to 3 tabs.
```

**Do this**:
```markdown
## Golden Rules
### Don'ts
- Never reintroduce preview branching (Dispatcher is registerSendFunction() + direct-send only)

## Key Modules
| apps/electron-admin/ | Electron admin app (...3 nav tabs: Dashboard / AI / Settings...) |
```

### Examples of Content to Remove
- Temporary notes like `TODO: remove after #123 is resolved`
- Temporary workaround descriptions for specific issues
- Known issues lists that have been resolved
- Any existing `## Post-Merge Notes (PR #N)` sections (migrate content first)

### Examples of Content to Modify
- Changed directory structure descriptions
- Updated dependency information
- Commands or configurations that are no longer valid
- Module descriptions that no longer match reality
- Test counts that have changed
