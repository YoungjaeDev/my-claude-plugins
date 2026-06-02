# Learning Integration (config + Serena)

Detailed procedure for Step 6 (config files) and Step 7 (Serena memory). Apply the `core-principle.md` rules to every added or modified line.

## Step 6: Integrate learnings into configuration files

### Pre-Audit: clean existing pollution first

Before integrating new learnings, scrub existing stamps out of the target files. This is the incremental healing step that gradually undoes pollution left by prior runs.

1. Build the target file candidate list: `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.claude/rules/*.md` — whichever exist.
2. For each file, grep for the Core Principle's forbidden patterns:
   ```bash
   rg -nP '(\(?#\d+\)?|\b(PR|pr|Pull Request) ?#?\d+\b|\b([Ii]ssue|이슈) ?#?\d+\b|\b(Added|Removed|Fixed|Changed|Introduced) in (PR|#)|## Post-Merge|<(YYYY-MM-DD|\d{4}-\d{2}-\d{2})>)' <file>
   ```
3. **Marker filter**: for each hit, walk back to the nearest preceding H2/H3 heading. If a line `<!-- history-allowed [...] -->` appears between that heading and the next H2/H3 (the hit lives inside a marked section), drop the hit. Only hits outside marker sections proceed.
4. If the hit count is 0, skip Pre-Audit and proceed to read the PR diff.
5. If hits are found, report to the user: per-file hit line numbers with the quoted original text, plus a "strip-stamp, preserve meaning" rewrite proposal for each line.
6. **Rewrite principles**:
   - Strip the stamp only, preserve normative content — `"max_pages default is 10 (#53)"` → `"max_pages default is 10"`.
   - Convert historical narrative to current-state — `"PR #18 benchmark is no longer the safety baseline"` → delete the line, or `"the uniform 1-2.5s benchmark is not used"` (current rule only).
   - Same issue cited across multiple places — consolidate into the single best-fit section, then delete the other citations.
   - Reasoning lifted from PR/issue bodies stays; only the citation goes.
7. Apply gate via `AskUserQuestion`: offer "apply all" / "pick per file" / "skip Pre-Audit", showing per-file hit counts. Apply the approved cleanup, then integrate the new learnings.

### Integrate the new learnings

Read the PR diff (`gh pr diff <PR_NUMBER>`) and PR body to extract learnings. Integrate each into the **appropriate existing section**. **CRITICAL: never append "Post-Merge Notes" sections** — weave learnings into the existing document structure as if they were always there.

**Expected root config structure** (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`):
1. Project Context — business goal + tech stack (1-2 sentences)
2. Commands — package manager and run commands
3. Golden Rules — Immutable / Do's / Don'ts
4. Modular Rules — `See @.claude/rules/[module].md` references
5. Project-Specific — data locations, key modules, tracking, etc.

**Classification and placement** (all config files):

| Learning Type | Target Section | Action |
|---------------|----------------|--------|
| New constraint / invariant | Golden Rules > Immutable | Add a new bullet |
| New convention / best practice | Golden Rules > Do's | Add a new bullet |
| New prohibition / anti-pattern | Golden Rules > Don'ts | Add a new bullet |
| New/changed command or script | Commands | Add or update the command block |
| Module added/removed/changed | Key Modules table | Update the row description |
| New data file or location | Data Locations table | Add or update the row |
| New module rule reference | Modular Rules | Add `See @path` reference |
| Module-specific rule | `.claude/rules/[module].md` | Update or propose creation |
| Tech stack change | Project Context | Update the tech description |
| Test count change | Commands or relevant section | Update the count |

**Integration process**:
1. Read the current config file to understand existing structure and content.
2. For each learning, find the most specific existing section it belongs to.
3. Merge naturally — update existing descriptions rather than adding footnotes.
4. If an existing bullet/row already covers the topic, **update it in place** rather than adding a new entry.
5. Remove outdated information the PR supersedes (old module descriptions, removed features).

**Content removal**: temporary instructions (`TODO: remove after #N`), resolved known issues, workaround descriptions for fixed bugs, and existing "Post-Merge Notes" sections (migrate their content into proper sections, then delete the notes).

**Modular rule files** (`.claude/rules/*.md`): check if a relevant module file exists; propose path-specific rules with frontmatter `paths: src/[module]/**`. Structure:
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
**Always confirm with the user before creating new rule files.**

> Note: cross-agent *lore* never lands in `.claude/rules/` — see the knowledge-routing boundary in `core-principle.md`. `.claude/rules/` is for mechanical tool-operation rules only.

### Pre-presentation validation (stamp self-check)

Before showing the proposal, self-check **every added or modified line** against the Core Principle's forbidden patterns. (`Remove:` style cleanup lines are exempt — removing stamps is the goal.) Lines added inside a `<!-- history-allowed -->` section are exempt from the four checks below.

- [ ] No added/modified line contains `(#N)`, `PR #N`, `Issue #N`, `이슈 #N`, or similar inline citations
- [ ] No new section header includes a date, PR number, or issue number
- [ ] Every added bullet uses current-state tone ("X is async") — not transition tone
- [ ] No "Added in PR" / "Removed in PR" / "Fixed in PR" / "Introduced in PR" phrasing

**If any check fails**, do not show the proposal — rewrite first and self-loop until every checkbox is ✓.

Present the integration proposal as a diff-style summary before applying:
```text
CLAUDE.md changes:
  Golden Rules > Don'ts: + "Never reintroduce preview branching (Dispatcher is direct-send only)"
  Key Modules > electron-admin: "4 nav tabs" -> "3 nav tabs: Dashboard / AI / Settings"
  Remove: "Post-Merge Notes" section (content migrated above)
```

### Step 6.4: History Rotation (sections marked `<!-- history-allowed max=N -->` only)

After Step 6 integration, scan each normative doc for sections marked `<!-- history-allowed max=N -->`. For each such section whose bullet count exceeds N:
1. Identify which oldest bullets have been fully absorbed into normative sections of the same doc.
2. Present an absorption mapping via `AskUserQuestion` (one row per candidate bullet: bullet text + "absorbed where" OR "not absorbed"; options "remove all absorbed" / "remove subset" / "keep all").
3. After confirmation, remove the approved bullets. Any non-redundant nuance not yet absorbed MUST be migrated to its proper normative section before deletion — never delete net-new content.

Sections without `max=N`, or with bullet count ≤ N, are skipped. Rotation is opt-in.

### Step 6.5: Normative Doc Size Audit

After Step 6 integration, measure normative docs and offer split/improve when oversized. **Threshold: 32000 chars** (8k below Claude Code's 40k perf-warning).

1. Build candidate list (files that exist): `CLAUDE.md`, `AGENTS.md`, `GEMINI.md` at repo root + one-level `.claude/rules/*.md` (no recursion).
2. Measure char count per file with `wc -m` (chars, not bytes — Korean/multibyte safe).
3. If no file exceeds 32000 chars: emit `All normative docs within 32k; size audit clean.` and proceed.
4. If at least one file exceeds 32000 chars, show a per-file size table marking offenders, then `AskUserQuestion` (header `Size audit`):
   - **Split with rules-forge:split** (Recommended) — `/rules-forge:split --threshold 20` per oversized file. Best when the file is bulky.
   - **Improve with claude-md-improver** — the `claude-md-management:claude-md-improver` skill (dedup, stale content, rubric scoring). Best when already modular but verbose.
   - **Both: split first, then improve** — split, re-measure, run improver on the trimmed root if still > 32000.
   - **Defer** — print `Run /rules-forge:split or /claude-md-management:claude-md-improver later on: <files>` and continue.
   - **Skip** — continue silently.
5. Each path runs inline; the invoked skill prompts before applying. If the user declines mid-skill, return control to Step 7 (do not block the rest of post-merge).

**Why split-first is recommended**: at 32k+ chars the dominant problem is bulk, not phrasing. `rules-forge:split` is the dedicated extraction engine (auto-classifies sections, generates `@import`, supports `--dry-run`); `claude-md-improver` is rubric-based quality audit with no size-reduction logic.

> **Codex note**: `rules-forge:split` and `claude-md-improver` are Claude-only. Under Codex, report the oversized files and defer rather than invoking the skills.

## Step 7: Update Serena memory (Claude-only — Codex skips)

> **Content-First**: before appending, scan existing memory for stale/duplicate content and refine **in place**. Delete a memory file only when its content is fully migrated or orphaned.

Integrate PR learnings into Serena memory as native content — they should read as if always part of the memory, not appended post-merge notes.

### Pre-Audit (clean stamps from existing memory)

Before `list_memories` → `read_memory`, grep every memory file against the Core Principle patterns. If hits are found, run the same Step 6 Pre-Audit procedure (user approval, then `edit_memory`). The `<!-- history-allowed -->` marker exemption applies to memory files too.

Clean these on sight:
- `## Post-Merge (date, PR #N)` headers — distribute content into topical sections, then delete the header.
- `post_merge_prN.md` filenames — migrate content into a topical file, then delete the file.
- `(Issue #N)` / `(이슈 #N)` inline citations — strip the citation only, preserve content.

### Procedure

1. `list_memories` to discover existing files.
2. `read_memory` on candidates to understand current sections/structure.
3. Analyze the PR diff + body for learnings worth preserving (architectural decisions, new patterns, resolved issues, module knowledge).
4. For each learning, find the best-fit section using the mapping table.
5. `edit_memory` to add or update content within that section.

**Memory file mapping:**

| Learning Category | Likely Target File | Section to Update |
|-------------------|--------------------|-------------------|
| Architecture changes, new modules, removed features | `project_overview.md` | Architecture, Key Features, Key Files |
| Code patterns, naming, type changes | `code_style.md` | Code Patterns, Conventions |
| New scripts, commands | `suggested_commands.md` | Relevant command group |
| Workflow insights, process notes | `task_completion.md` | Relevant section |

**Integration rules:**
- **NEVER create new memory files** (especially not `post_merge_prN.md`).
- **NEVER add `## Post-Merge` headers** — they create changelog noise, not reference material.
- Find the existing section covering the topic and add bullets there.
- If no matching section exists, create a **topical section** named after the subject (e.g., `## Shutdown Handling`), not after the PR.
- Update outdated descriptions in place rather than keeping old text alongside new.
- If content fits no existing file, append to `project_overview.md` as catch-all.
- **Self-check before `edit_memory`**: verify the added text contains no Core Principle forbidden patterns. If it does, rewrite first.

**Good (PR fixed a graceful-shutdown race):**
```text
## Process Lifecycle
- `start()` initializes polling loop and resets `isShuttingDown` flag
- `gracefulShutdown()` is async; awaits shutdown handlers before exit
- `isShuttingDown` flag prevents double-shutdown race conditions
```
**Bad (what NOT to do):**
```text
## Post-Merge (2026-02-16, PR #132)
- Graceful shutdown race condition fixed (Issue #69)
```

Skip if no significant learnings, if Serena is unavailable, or under Codex.
