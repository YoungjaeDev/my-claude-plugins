# Integrate Learnings into Configuration Files — Full Policy

This reference holds the full policy for Steps 6, 6.4, 6.5, and 7 of the `post-merge` skill. The SKILL.md spine carries short summaries that point here. Preserve this text faithfully — it is high-value normative-doc hygiene policy.

## Step 6 — Integrate Learnings into Configuration Files

> **Core Principle: No Stamps, Topical Names, Current State Only**
>
> Normative docs (CLAUDE.md, AGENTS.md, GEMINI.md, .claude/rules/*, Serena memory) hold the **current rules only**. Change history (provenance) is already preserved permanently in git commit messages, PR bodies, and GitHub blame -- do not duplicate it inside the docs.
>
> **Forbidden patterns (regex-identifiable):**
> - `\(?#\d+\)?` -- `(#123)`, `#123` inline citations
> - `\b(PR|pr|Pull Request) ?#?\d+\b` -- `PR #50`, `PR50`, `Pull Request 50`
> - `\b([Ii]ssue|이슈) ?#?\d+\b` -- `Issue #65`, `이슈 #53` (Korean stamp variant retained so the regex matches both English and Korean projects)
> - `\b(Added|Removed|Fixed|Changed|Introduced) in (PR|#)` -- historical narrative openers
> - `## Post-Merge` -- date- or PR-based section headers
> - `<YYYY-MM-DD>` embedded inside a section header itself
>
> **Exception -- designed history sections**: A section MAY opt out of these rules by placing `<!-- history-allowed [max=N] -->` immediately after its H2/H3 heading. The marker applies until the next same-or-higher-level heading. Inside a marked section:
> - Pre-Audit stamp grep MUST skip hits.
> - Pre-presentation self-check MUST skip added/modified lines.
> - Date suffixes in the section name (see Section naming below) are allowed.
> - The Anti-Patterns "Never cite a PR or issue" rule does NOT apply.
> - If `max=N` is set, History Rotation (Step 6.4) applies.
>
> Use only when the section MUST hold time-ordered bullets that cannot be absorbed into normative sections (e.g. CHANGELOG entries migrated into a CLAUDE.md summary). Do NOT use as a blanket escape -- when in doubt, absorb the learning into a topical section and delete the bullet.
>
> **Section naming**: topical names only (e.g., `## Process Lifecycle`, `## Crawler Throttling`). PR numbers and issue numbers are forbidden in any section name. Date suffixes (`(YYYY-MM)`, `(YYYY-Q[1-4])`) are allowed ONLY inside a section marked `<!-- history-allowed -->`. Full ISO dates (`YYYY-MM-DD`) remain forbidden in section names regardless of marker -- bullet-level dates belong inside the bullet text, not in the heading.
>
> **Writing tone**: "X is async" (current-state). NOT "X was changed to async in PR #50" (history). NOT "Previously we used Y; now we use X (#50)" (transition narrative).
>
> **Language consistency**: Match the language of the surrounding section. If the existing doc/section is Korean, write the new bullet in Korean; if English, write English. Never introduce a second language into a single-language section -- mid-sentence code-switching breaks readability and grep. Inspect the file's dominant language before writing; when unsure, use the language of the closest sibling bullet.
>
> **Single source of truth (cross-file dedup)**: Each rule lives in exactly one file. Before adding new content to one normative doc, briefly check whether a sibling rule file (CLAUDE.md, AGENTS.md, GEMINI.md, .claude/rules/*) already covers the same topic. If a sibling already owns it, reference via `See @path/to/file.md` instead of duplicating the body. If two files already overlap on the same topic, pick the more specific file as owner, replace the other site with the `See @path` reference, and migrate any unique nuance into the owner. The check is intentionally lightweight -- a focused grep on the topic keyword, not a full re-read of every rule file.
>
> **Exception**: `Closes #N` / `Fixes #N` GitHub keywords are allowed only inside commit messages, PR bodies, and issue bodies. Forbidden inside normative docs.

> **Content-First principle**: Refine stale/duplicate content **in place first**, consolidate duplicates next, and only delete a file when it becomes empty or orphaned. File-level deletion is the last resort, not the default.

**Pre-Audit: Clean Existing Pollution First**

Before integrating new learnings, scrub existing stamps out of the target files first. This is the incremental healing step that gradually undoes pollution left by prior runs.

1. Build the target file candidate list: `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.claude/rules/*.md` -- whichever exist.
2. For each file, grep for the Core Principle's forbidden patterns:
   ```bash
   rg -nP '(\(?#\d+\)?|\b(PR|pr) ?#?\d+\b|\b([Ii]ssue|이슈) ?#?\d+\b|\b(Added|Removed|Fixed|Changed|Introduced) in (PR|#)|## Post-Merge)' <file>
   ```
2.5. **Marker filter**: For each grep hit, walk back to the nearest preceding H2/H3 heading. If a line `<!-- history-allowed [...] -->` appears between that heading and the next H2/H3 (i.e., the hit lives inside a marked section), drop the hit from the report. Only hits outside marker sections proceed to step 3.
3. If the hit count is 0, skip Pre-Audit immediately and proceed to the next step (Read the PR diff).
4. If hits are found, report to the user:
   - Per-file hit line numbers with the quoted original text
   - A "strip-stamp, preserve meaning" rewrite proposal for each line
5. **Rewrite principles**:
   - Strip the stamp only, preserve normative content -- `"max_pages default is 10 (#53)"` -> `"max_pages default is 10"`
   - Convert historical narrative to current-state -- `"PR #18 benchmark is no longer the safety baseline"` -> delete the line, or `"the uniform 1-2.5s benchmark is not used"` (current rule only)
   - Same issue cited across multiple places -- consolidate the content into the single best-fit section, then delete the other citations
   - Reasoning lifted from PR/issue bodies stays; only the citation goes
6. Apply gate via `AskUserQuestion`:
   - Offer "apply all" / "pick per file" / "skip Pre-Audit"
   - Show per-file hit counts in the description
7. Apply the approved cleanup, then proceed to integrate the new learnings.

Read the PR diff (`gh pr diff <PR_NUMBER>`) and PR body to extract learnings. Then integrate each learning into the **appropriate existing section** of configuration files.

**CRITICAL: Never append "Post-Merge Notes" sections.** All learnings must be woven into the existing document structure as if they were always there.

- Check which configuration files exist:
  - `CLAUDE.md` - Claude Code specific instructions
  - `AGENTS.md` - Cross-tool AI coding agent instructions
  - `GEMINI.md` - Google Gemini CLI specific instructions
  - `.claude/rules/*.md` - Modular rule files

- **Expected root config structure** (CLAUDE.md, AGENTS.md, GEMINI.md):
  1. Project Context - Business goal + tech stack (1-2 sentences)
  2. Commands - Package manager and run commands
  3. Golden Rules - Immutable / Do's / Don'ts
  4. Modular Rules - `See @.claude/rules/[module].md` references
  5. Project-Specific - Data locations, key modules, tracking, etc.

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
  - Follow this structure:
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
  - **Always confirm with user before creating new rule files**

- **Pre-presentation validation (stamp self-check)**:

  Before showing the proposal to the user, self-check **every added or modified line** against the Core Principle's forbidden patterns. (`Remove:` style cleanup lines are not subject to this check -- removing stamps is the goal.)

  **Marker exception**: lines being added inside a section marked `<!-- history-allowed -->` are exempt from the four checks below. All other added/modified lines must pass every check.

  Validation checklist:
  - [ ] No added/modified line contains `(#N)`, `PR #N`, `Issue #N`, `이슈 #N`, or similar inline citations
  - [ ] No new section header includes a date, PR number, or issue number (`## Post-Merge`, `## 2026-04-28 Updates`, etc. forbidden)
  - [ ] Every added bullet uses current-state tone ("X is async") -- not transition tone ("X was changed to async")
  - [ ] No "Added in PR" / "Removed in PR" / "Fixed in PR" / "Introduced in PR" phrasing

  **If any check fails**: do not show the proposal -- rewrite first. Self-loop until the patterns are satisfied. Every checkbox must be ✓ at the moment the proposal is presented.

- Present the integration proposal to user as a diff-style summary before applying:
  ```
  CLAUDE.md changes:
    Golden Rules > Don'ts: + "Never reintroduce preview branching (Dispatcher is direct-send only)"
    Key Modules > electron-admin: "4 nav tabs" -> "3 nav tabs: Dashboard / AI / Settings"
    Remove: "Post-Merge Notes (PR #130)" section (content migrated above)
  ```

## Step 6.4 — History Rotation (sections marked `<!-- history-allowed max=N -->` only)

After Step 6 integration is applied, scan each normative doc for sections marked `<!-- history-allowed max=N -->`. For each such section whose bullet count exceeds N:

1. Identify which oldest bullets have been fully absorbed into normative sections of the same doc (architecture / code conventions / commands / rules files).
2. Present an absorption mapping via `AskUserQuestion`:
   - One row per candidate bullet: bullet text + "absorbed where" (target section path) OR "not absorbed".
   - Options: "remove all absorbed" / "remove subset" / "keep all".
3. After user confirmation, remove the approved bullets. Any non-redundant nuance that has NOT yet been absorbed MUST be migrated to its proper normative section before deletion -- never delete net-new content.

Sections without the `max=N` parameter, or with bullet count <= N, are skipped. Rotation is intentionally opt-in: unmarked sections never trigger this step, and marked sections without `max` keep all bullets indefinitely.

## Step 6.5 — Normative Doc Size Audit

After Step 6 integration is applied, measure normative docs and offer split/improve when oversized.

**Threshold:** 32000 chars (8k below Claude Code's 40k perf-warning).

**Procedure:**

1. Build candidate list (files that exist):
   - `CLAUDE.md`, `AGENTS.md`, `GEMINI.md` at repo root
   - One-level matches under `.claude/rules/*.md` (no recursion)
2. Measure char count per file with `wc -m` (chars, not bytes — Korean/multibyte safe).
3. If no file exceeds 32000 chars: emit `All normative docs within 32k; size audit clean.` and proceed to Step 7.
4. If at least one file exceeds 32000 chars:
   a. Show per-file size table marking offenders.
   b. `AskUserQuestion`, header `Size audit`:
      - **Split with rules-forge:split** (Recommended) — invoke `/rules-forge:split --threshold 20` for each oversized file. Extracts topical sections to `.claude/rules/<topic>.md`, rewrites the root with `@import` references. Best when the file is bulky.
      - **Improve with claude-md-improver** — invoke the `claude-md-management:claude-md-improver` skill for quality refinement (dedup, stale content, rubric scoring). Best when the file is already modular but verbose.
      - **Both: split first, then improve** — run `rules-forge:split`, then re-measure; if root is still > 32000, run `claude-md-improver` on the trimmed root.
      - **Defer** — print `Run /rules-forge:split or /claude-md-management:claude-md-improver later on: <files>` and continue.
      - **Skip** — continue silently.
5. Each path runs inline as a sub-flow; the invoked skill/command itself prompts before applying changes. If the user declines mid-skill, return control to Step 7 (do not block the rest of post-merge).

**Why split-first is recommended**: at 32k+ chars the dominant problem is bulk, not phrasing. `rules-forge:split` (`plugins/rules-forge/commands/split.md`) is the dedicated extraction engine — auto-classifies sections (Architecture/Testing/API/Frontend/Deployment/Security), generates `@import` directives, supports `--dry-run`. `claude-md-improver` (`plugins/claude-md-management`) is rubric-based quality audit; its references contain no size-reduction logic.

## Step 7 — Update Serena Memory (if Serena MCP available)

> **Content-First principle**: Before appending new learnings, scan existing memory for stale or duplicate content and refine it **in place**. Only delete a memory file when its content has been fully migrated elsewhere or becomes orphaned.

Integrate PR learnings into Serena memory as native content. Learnings should read as if they were always part of the memory -- not as appended post-merge notes.

**Pre-Audit (clean stamps from existing memory files)**:

Before `list_memories` -> `read_memory`, grep every memory file against the Core Principle patterns. If hits are found, run the same Step 6 Pre-Audit procedure -- get user approval, then clean (`edit_memory`). After cleanup, proceed to integrate the new learnings.

**Marker exception**: the same `<!-- history-allowed -->` rule from Step 6 Core Principle applies to memory files. Sections marked with this comment are exempt from stamp grep and the self-check before `edit_memory`.

The following patterns must be cleaned on sight (matching the "Bad" example below):
- `## Post-Merge (date, PR #N)` headers -- distribute the content into topical sections, then delete the header
- `post_merge_prN.md` filenames themselves -- migrate the content into a topical file, then delete the file
- `(Issue #N)` / `(이슈 #N)` inline citations inside bullets -- strip the citation only, preserve the content

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
- **Self-check before applying `edit_memory`**: verify the text being added does not contain Core Principle forbidden patterns (`(#N)`, `PR #N`, `이슈 #N`, "Added in PR", etc.). If it does, rewrite first, then apply.

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
