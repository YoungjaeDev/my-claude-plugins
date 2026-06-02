---
name: post-merge
description: Run after a PR merges — clean up the local branch, sync tracking, integrate what merged into config + wiki, commit. Use when the user types /github-dev:post-merge, says "post-merge cleanup", "integrate PR learnings", or merged a PR. Identifies the merged PR (gh pr view is the authoritative merge signal — never compare git SHAs), switches to base, deletes the merged branch, syncs GitHub Project/milestone + .claude/state/spec.json, integrates learnings into CLAUDE.md/AGENTS.md/.claude/rules + Serena memory under a no-stamp current-state-only rule, then runs a MANDATORY wiki-lore ingest (absorbed post-merge-wiki, file-list-first candidates + autonomy triage, delegating to llm-wiki:ingest-finding), updates README, commits. Knowledge routing — mechanical tool rules → CLAUDE.md/.claude/rules; cross-agent lore → .llmwiki via the wiki step, recorded once. Runs from the main repo, not a worktree. Codex note — Serena/rules-forge/claude-md-improver/humanizer/docs-forge sub-steps are Claude-only and gracefully skip.
allowed-tools: Read Write Edit Bash Glob Grep AskUserQuestion
---

# Post-Merge

Local cleanup + knowledge integration after a PR is merged. One run takes a merged PR from branch cleanup → tracking sync → config/memory integration → **mandatory** wiki-lore ingest → README → commit. Follow project guidelines in `@CLAUDE.md` and `@AGENTS.md` throughout.

For worktree removal, use `/exit` with its cleanup option.

## Guidelines

- **Worktree guard (P0).** post-merge must run from the main repo, not a worktree — Step 3 checks out the base branch, which collides with the original repo's checkout. The Step 1 guard aborts when run inside a worktree.
- **`gh pr view` is the authoritative merge signal.** Step 1's `gh pr view ... state=MERGED` is the single source of truth for "did this land". Later steps MUST NOT re-verify merge state by comparing git SHAs.
- **Never use SHA-level merge comparison.** `git log <base>..<branch>`, `git cherry`, `git rev-list --left-right` all false-positive after squash merge (base gets one new SHA) and rebase merge (branch SHAs rewritten). If unsure content landed, diff content not SHAs (Step 4).
- **No stamps, current-state only.** Normative docs hold current rules; provenance lives in git/PR/blame. No `(#N)` / `PR #N` / `이슈 #N` citations, no `## Post-Merge` headers. Full rules + the `<!-- history-allowed [max=N] -->` opt-out + language consistency + SSOT cross-file dedup + content-first: see `references/core-principle.md`.
- **Knowledge routing (no double-recording).** Mechanical / tool-operation rules → `CLAUDE.md` / `AGENTS.md` / `.claude/rules/` / Serena memory (Steps 6-7). Cross-agent *lore* (provider quirks, design rationale, debugging stories) → `.llmwiki/` via the wiki step (Step 8). Each fact is recorded in exactly one home; the wiki step (run *after* config integration) dedups against what Steps 6-7 already absorbed. Cross-agent rules that graduate do so to `.llmwiki/insight/` via the wiki step, never to `.claude/rules/` (Codex can't read it).
- **Codex partial-execution.** Under Codex 0.135 the Serena (Step 7), `rules-forge:split` / `claude-md-management:claude-md-improver` (Step 6.5), and `humanizer` / `docs-forge:readme` (Step 9) sub-steps are Claude-only — gracefully skip them and note the skip rather than failing.

## Arguments

- PR number (optional): if not provided, infer from conversation context, else `gh pr list --state merged --limit 5` and prompt the user to select.

## Workflow

### 1. Identify PR

**Worktree guard (P0)** — run first:

```bash
case "$(git rev-parse --absolute-git-dir)" in
  */worktrees/*)
    MAIN_REPO=$(cd "$(git rev-parse --git-common-dir)/.." && pwd -P)
    echo "[abort] post-merge cannot run inside a worktree."
    echo "Run /exit (cleanup option), then re-run /github-dev:post-merge from $MAIN_REPO"
    exit 1
    ;;
esac
```

- Use the PR number argument if given; else infer from context; else `gh pr list --state merged --limit 5` and prompt.
- `gh pr view <PR_NUMBER> --json number,title,baseRefName,headRefName,body,state,files,mergeCommit`.
- Verify `state` is `MERGED`. This result is the **authoritative merge signal** (see Guidelines) — no later SHA comparison.
- Capture `MERGE_SHA=$(gh pr view <PR_NUMBER> --json mergeCommit --jq '.mergeCommit.oid')` — this is **this PR's** merge commit, used to label the wiki log entry and read diff content. Step 8 derives the merged **file list** from `gh pr diff <N> --name-only` (PR-scoped, merge-method-agnostic, uncapped), not from `MERGE_SHA` (a `--no-ff` merge commit shows an empty combined diff; a multi-commit rebase merge's SHA only points at the last replayed commit).

### 2. Check local changes

`git status --porcelain`:
- Untracked (`??`) — ignore, proceed.
- Modified/staged (`M`/`A`/`D`) — prompt via `AskUserQuestion`: **stash** (`git stash push -m "post-merge: temp save"`) / **discard** (`git restore --staged --worktree -- .` — reverts tracked changes only; never `git clean`, so pre-existing untracked files/drafts are preserved per the rule above) / **abort**.
- If stashed, prompt at the end of the run for **pop** / **apply** / **later**.

### 3. Switch to base branch

```bash
git fetch origin
git checkout <baseRefName>
git pull origin <baseRefName>
```

### 4. Clean up local branch

- `git branch --list "$headRefName"`.
- **No SHA-level merge check** (see Guidelines). If unsure content landed, diff content: `git diff "origin/$baseRefName..$headRefName" -- <paths>` (empty = fully landed; safe for squash).
- If the branch exists, confirm deletion, then `git branch -d "$headRefName"`.
  - For squash merges expect `warning: not yet merged to HEAD` — normal; `-d` detects the merge via `origin/<branch>` tracking and still succeeds. Do NOT escalate to `-D`, do NOT treat as data loss, do NOT open a "missing commits" PR.
- If worktrees remain for the branch, tell the user to run `/exit` with cleanup.

### 5. Update GitHub Project status (optional)

- Extract issue refs from the PR body (`Closes #N` / `Fixes #N` / `Resolves #N`).
- `gh project list --owner <owner> --format json`. If none, skip silently. Else `gh project item-list` → `gh project field-list` → `gh project item-edit` to set Status to "Done". Skip if the issue is not in the project.

### 5.5. Sync milestone progress (if issues have milestones)

For each related issue with a milestone, recompute module progress and regenerate the milestone table + Type M-2 diagrams. Full mechanics: `skills/update-progress/SKILL.md` ("Milestone Format" / "Type M-2"). Skip silently when no related issue carries a milestone.

### 5.7. Update `.claude/state/spec.json` (if present)

- If `.claude/state/spec.json` exists, move the `in_progress` entry whose `linked.pr` matches the merged PR (or `linked.issue`) to `completed` with `merge_sha` (first 7 chars) + `completed_at` (today, UTC `YYYY-MM-DD`), and set the spec file's frontmatter `status: merged`.
- Mechanics are owned by `spec-state:state-tracker` — invoke `/spec-state:state-tracker complete <spec-path>` if installed; otherwise apply the direct JSON edit per `plugins/spec-state/skills/state-tracker/SKILL.md`.
- Skip silently if no matching entry, or if `.claude/state/` does not exist.

### 6. Integrate learnings into config files

Read `gh pr diff <PR_NUMBER>` + the PR body, then weave each learning into the **appropriate existing section** of `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` / `.claude/rules/*.md`. **Never append a "Post-Merge Notes" section.**

Full procedure — Pre-Audit (scrub existing stamps first), the classification/placement table, the integration process, modular-rule-file structure, the pre-presentation stamp self-check, History Rotation (6.4), and the Normative Doc Size Audit (6.5, with `rules-forge:split` / `claude-md-improver` routing) — lives in **`references/learning-integration.md`**. Apply its Core Principle (`references/core-principle.md`) to every added/modified line; present a diff-style proposal before applying.

### 7. Update Serena memory (Claude-only — Codex skips)

If Serena MCP is available, integrate PR learnings into existing memory files as native content (no `post_merge_prN.md`, no `## Post-Merge` headers). Pre-Audit, the memory-file mapping table, and the self-check are in **`references/learning-integration.md`** ("Serena memory"). Skip if Serena is unavailable or under Codex.

### 8. Wiki lore ingest (MANDATORY)

Absorbs the former `post-merge-wiki` skill as a required step. Runs **after** Steps 6-7 so the config integration is already settled and the wiki step can dedup against it (knowledge routing).

Resolve the wiki root (`.llmwiki/wiki/` → `.claude/wiki/` → `.codex/wiki/`); if none resolves, skip silently (no wiki layer — no hard dependency). Otherwise derive ingest candidates **from the merged file list** (`gh pr diff <N> --name-only`), triage by autonomy boundary, and delegate the heavy lifting (diff-log, multi-page cross-update, insight graduation) to `llm-wiki:ingest-finding`. Full procedure — candidate derivation, the autonomy-boundary triage table, the trivial-merge skip list, the `log.md` entry format, and the Step 6/7 routing-dedup rule — lives in **`references/wiki-ingest.md`**.

### 9. Update README.md (if needed — humanizer/docs-forge are Claude-only)

If the PR changed features/commands/install/usage/deps and a README exists: draft the changes, apply `/humanizer:humanize` then `/docs-forge:readme` guidelines (Claude-only — skip the skill passes under Codex, keep the manual edit), present for confirmation. Skip if no README-relevant changes.

### 10. Commit changes (optional)

If **any** tracked files were modified by this run — config (`CLAUDE.md`/`AGENTS.md`/`GEMINI.md`/`.claude/rules`), README, Serena memory, **or `.llmwiki/` from the Step 8 wiki ingest** — confirm with the user, then commit using Conventional Commits. Do not gate on config-only changes: a wiki-only post-merge (Step 8 touched `.llmwiki/` but no config learning landed) must still commit, or the ingest is left uncommitted in the working tree.

Stage **only the exact files this run created or modified** — collect them as you go through Steps 5.7-9 (each config file you edited, the `.claude/state/spec.json` + spec file from Step 5.7, README, Serena memory files, and the specific wiki pages `ingest-finding` created/updated). Build that explicit list as `RUN_TOUCHED` and add only those paths — **never `git add` a whole directory** (`.llmwiki/`, `.claude/spec/`, …): a pre-existing untracked draft (e.g. a user's `.llmwiki/wiki/draft.md`) would otherwise be swept into this commit, and Step 2 already decided to leave untracked files alone.

```bash
# RUN_TOUCHED = the exact paths this run wrote, gathered across Steps 5.7-9.
# Existence-checked + added one at a time: `git add a b c` is atomic, so one
# stale path would abort the whole add (and `|| true` would hide it), leaving
# real changes unstaged.
for p in "${RUN_TOUCHED[@]}"; do
  [ -e "$p" ] && git add -- "$p"
done
```

Skip the commit only when `git diff --cached --quiet` reports nothing staged after the `git add` — a staged-only check; `git status --porcelain` would also count pre-existing untracked files and wrongly attempt an empty-index commit.

## References

- **No-stamp Core Principle + knowledge-routing boundary**: `references/core-principle.md`
- **Config + Serena learning integration** (Pre-Audit, classification, history rotation, size audit, memory mapping): `references/learning-integration.md`
- **Mandatory wiki ingest** (absorbed post-merge-wiki — candidate derivation, autonomy triage, ingest-finding delegation, routing dedup): `references/wiki-ingest.md`
- Milestone / Type M-2 diagram mechanics: `skills/update-progress/SKILL.md`
- spec.json schema + ops: `plugins/spec-state/skills/state-tracker/SKILL.md`

> Follow ~/.claude/CLAUDE.md and the project CLAUDE.md.
