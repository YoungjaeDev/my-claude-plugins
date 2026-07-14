---
name: post-merge
description: Run after a PR merges — clean up the local branch, sync tracking, integrate what merged into config + wiki, commit. Use when the user types /github-dev:post-merge, says "post-merge cleanup", "integrate PR learnings", or merged a PR. Identifies the merged PR (gh pr view is the authoritative merge signal — never compare git SHAs), switches to base, deletes the merged branch, syncs GitHub Project/milestone + .claude/state/spec.json, integrates learnings into CLAUDE.md/AGENTS.md/.claude/rules + Serena memory under a no-stamp current-state-only rule, then runs a MANDATORY wiki-lore ingest (absorbed post-merge-wiki, file-list-first candidates + autonomy triage, delegating to llm-wiki:ingest-finding), updates README, commits. Knowledge routing — mechanical tool rules → CLAUDE.md/.claude/rules; cross-agent lore → .llmwiki via the wiki step, recorded once. Runs from the main repo, not a worktree. Codex note — Serena/rules-forge/claude-md-improver/humanize-korean/docs-forge sub-steps are Claude-only and skip.
allowed-tools: Read Write Edit Bash Glob Grep AskUserQuestion
---

# Post-Merge

## Hermes Agent Compatibility

When this skill is loaded through Hermes as `github-dev:<skill>`, map Claude/Codex tool names to Hermes tools:

| Claude/Codex term | Hermes tool |
|---|---|
| Bash | terminal |
| Read | read_file |
| Write | write_file |
| Edit | patch |
| Glob/Grep | search_files |
| AskUserQuestion | clarify |
| Task | delegate_task |
| Monitor | process |

Treat `$ARGUMENTS` as the natural-language arguments supplied when the user asks Hermes to load the skill. Plugin-provided skills are explicit opt-in loads in Hermes; use `skill_view("github-dev:<skill>")` (or ask Hermes to load that qualified skill) rather than relying on bare text like `github-dev:<skill> ...`.

Local cleanup + knowledge integration after a PR is merged. One run takes a merged PR from branch cleanup → tracking sync → config/memory integration → **mandatory** wiki-lore ingest → README → commit. Follow project guidelines in `@CLAUDE.md` and `@AGENTS.md` throughout.

For worktree removal, use `/exit` with its cleanup option.

## Guidelines

- **Worktree guard (P0).** post-merge must run from the main repo, not a worktree — Step 3 checks out the base branch, which collides with the original repo's checkout. The Step 1 guard aborts when run inside a worktree.
- **`gh pr view` is the authoritative merge signal.** Step 1's `gh pr view ... state=MERGED` is the single source of truth for "did this land". Later steps MUST NOT re-verify merge state by comparing git SHAs.
- **Never use SHA-level merge comparison.** `git log <base>..<branch>`, `git cherry`, `git rev-list --left-right` all false-positive after squash merge (base gets one new SHA) and rebase merge (branch SHAs rewritten). If unsure content landed, diff content not SHAs (Step 4).
- **No stamps, current-state only.** Normative docs hold current rules; provenance lives in git/PR/blame. No `(#N)` / `PR #N` / `이슈 #N` citations, no `## Post-Merge` headers. Full rules + the `<!-- history-allowed [max=N] -->` opt-out + language consistency + SSOT cross-file dedup + content-first: see `references/core-principle.md`.
- **Knowledge routing (no double-recording).** Mechanical / tool-operation rules → `CLAUDE.md` / `AGENTS.md` / `.claude/rules/` / Serena memory (Steps 6-7). Cross-agent *lore* (provider quirks, design rationale, debugging stories) → `.llmwiki/` via the wiki step (Step 8). Each fact is recorded in exactly one home; the wiki step (run *after* config integration) dedups against what Steps 6-7 already absorbed. Cross-agent rules that graduate do so to `.llmwiki/insight/` via the wiki step, never to `.claude/rules/` (Codex can't read it).
- **Leftover-review surface (Step 1.5) is informational.** The run reads cr-fix's state file (`.claude/state/cr-fix-<PR>.json`, else the latest `.claude/state/archive/` copy) to surface autonomously-deferred or cap/timeout-stopped findings after the merge, but never blocks cleanup. It always prints one `leftover-reviews: …` checkpoint line (mirroring the Step 8 wiki checkpoint) so a skip can't pass unnoticed. `gh` / `jq` / `Read` only → identical under Claude and Codex.
- **Codex partial-execution.** Under Codex 0.135 the Serena (Step 7), `rules-forge:split` / `claude-md-management:claude-md-improver` (Step 6.5), and `humanize-korean` / `docs-forge:readme` (Step 9) sub-steps are Claude-only — gracefully skip them and note the skip rather than failing.

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

**Open the run record (state-envelope v0).** With `PR_NUMBER` + `MERGE_SHA` fixed, open a per-run record so every later step's outcome is machine-visible — a step that skipped **silently** was previously invisible. Convention + schema: `.claude/rules/state-envelope.md` (concept mirror in `AGENTS.md`). No shared library — this per-skill `jq` is the whole mechanism, and the file lives under gitignored `.claude/state/`, so it is machine-local and is **never** staged (never added to Step 10's `RUN_TOUCHED`).

```bash
REC=".claude/state/post-merge-${PR_NUMBER}.json"
mkdir -p .claude/state/archive
# Archive a prior same-PR record before overwriting (mirrors cr-fix Step 2).
# Fail closed: a failed archive must abort init, else the jq below clobbers the only live copy.
if [ -f "$REC" ]; then
  mv "$REC" ".claude/state/archive/post-merge-${PR_NUMBER}-$(date +%Y%m%d-%H%M%S)-$$.json" \
    || { echo "post-merge: archiving the prior run record failed — aborting to avoid clobbering it" >&2; exit 1; }
fi
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n --arg rid "post-merge-${PR_NUMBER}" --arg sha "$MERGE_SHA" --arg now "$NOW" \
  '{schema:"state-envelope/v0", run_id:$rid, status:"in_progress", conclusion:null,
    started_at:$now, updated_at:$now, anchor_sha:($sha // null), attempt:1,
    session_id:(env.CLAUDE_SESSION_ID // null), steps:[]}' > "$REC"

# record_step <n> <done|skipped> [reason] — append one entry, bump updated_at.
record_step() {
  if [ "$2" = "skipped" ] && [ -z "${3:-}" ]; then
    echo "post-merge: a skipped step needs a reason" >&2; return 1
  fi
  local tmp; tmp=$(mktemp)
  jq --argjson step "$1" --arg status "$2" --arg reason "${3:-}" \
     --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     '.updated_at = $now
      | .steps += [ {step: $step, status: $status}
                    + (if $reason == "" then {} else {reason: $reason} end) ]' \
     "$REC" > "$tmp" && mv "$tmp" "$REC"
}
record_step 1 done
```

**Recording contract.** After each top-level Step 2-10 closes, append its outcome — `record_step <n> done`, or `record_step <n> skipped "<reason>"` when that step's skip-condition fires (Steps 5, 5.5, 5.7, 9, 9.5 skip silently today, and under Codex Step 7 records `skipped "Codex — Serena unavailable"`; the record is what makes each skip visible). Sub-steps (1.5, 4.5, 4.6, 6.5) fold into their parent top-level entry. **Shell state does not persist across separate tool calls** — `REC` is the deterministic path `.claude/state/post-merge-<PR>.json`, so in the bash block that closes a later step, re-`export REC=...` and re-declare `record_step` (or run the equivalent inline `jq`) before calling it. Step 10 finalizes the envelope to `status: completed`.

### 1.5. Surface unresolved review items (informational)

A merge can land while `cr-fix` still left findings unresolved — items it autonomously **deferred** (real + high-severity + too invasive for autopilot), or a loop that exited on a cap/timeout rather than converging clean. That signal sits in `cr-fix`'s state file and nobody reads it. This step surfaces it **once, right after the merge is confirmed**. It is **informational — it never blocks cleanup**; like the Step 8 wiki checkpoint it ALWAYS prints exactly one terminal status line so a skip can't pass unnoticed.

**Primary signal — the cr-fix state file.** cr-fix archives its live state on exit (`emit-final-json.sh` persists the final `final_state` + `auto_judge_stats` into the file, then moves `.claude/state/cr-fix-<PR>.json` → `.claude/state/archive/cr-fix-<PR>-<ts>.json`), so the archived copy is the usual hit and is self-describing; check the live path first, then the latest archive:

```bash
CRF=".claude/state/cr-fix-${PR_NUMBER}.json"
[ -f "$CRF" ] || CRF=$(ls -1t ".claude/state/archive/cr-fix-${PR_NUMBER}-"*.json 2>/dev/null | head -1)
if [ -n "${CRF:-}" ] && [ -f "$CRF" ]; then
  CRF_FINAL=$(jq -r '.final_state // "unknown"' "$CRF")
  # deferred findings, audit detail: path:line + severity + reason
  DEFERS=$(jq -c '[.auto_judge_log[]? | select(.action=="defer")
    | {path, line, sev: .badge_or_sev, reason}]' "$CRF")
  # prefer the persisted stat; fall back to counting defer entries in the log for
  # archives written before cr-fix persisted final fields (auto_judge_stats absent).
  DEFER_N=$(jq -r '.auto_judge_stats.defer // ([.auto_judge_log[]? | select(.action=="defer")] | length)' "$CRF")
else
  CRF_FINAL=""; DEFER_N=0; DEFERS='[]'
fi
```

**Secondary signal (advisory) — open CR review threads on the merged PR.** Top-level (non-reply) review comments are a coarse proxy for unresolved threads; it is NOT the primary gate:

```bash
# --paginate emits one JSON array PER page; piping to `jq -s 'add'` slurps every
# page into a single array before counting. Using `--jq length` here would instead
# print a per-page count ("30\n5") and break the OPEN_THREADS > 0 test below.
OPEN_THREADS=$(gh api --paginate "repos/{owner}/{repo}/pulls/${PR_NUMBER}/comments" 2>/dev/null \
  | jq -s 'add // [] | [.[] | select(.in_reply_to_id == null)] | length' 2>/dev/null || echo 0)
```

**Decide the checkpoint line.** The primary trigger is a non-empty defer list OR a `final_state` that means the loop stopped with work potentially outstanding (`iteration_cap`, `timeout`, `cli_failed`, `rate_limited`). `user_declined` always carries `defer > 0`, so the defer list catches it; `minor_floor` deferred nothing by definition and its low-severity fixes were already pushed, so it is not a trigger on its own:

```bash
case "$CRF_FINAL" in
  iteration_cap|timeout|cli_failed|rate_limited) CAP_TRIGGER=1 ;;
  *) CAP_TRIGGER=0 ;;
esac
if [ "$DEFER_N" -gt 0 ] || [ "$CAP_TRIGGER" = 1 ]; then
  echo "leftover-reviews: ${DEFER_N} deferred (final_state=${CRF_FINAL:-none})"
else
  echo "leftover-reviews: none"
fi
```

- **Leftover present** — after the `leftover-reviews: <N> deferred (final_state=<X>)` line, render the `$DEFERS` items as a table (`Path:Line · Severity · Reason`), and append the open-thread count when `OPEN_THREADS > 0`. Tell the user these were **not** auto-applied — review them on the PR page (`gh pr view <PR_NUMBER> --comments`) or in a follow-up; do not silently drop them.
- **None** — print `leftover-reviews: none` when no cr-fix state file resolves, or it shows `defer == 0` with a non-trigger `final_state`.

**Codex**: runs identically under Claude and Codex — `gh` / `jq` / `Read` only (no Serena / rules-forge).

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

### 4.5. Prune ephemeral artifacts merged by this PR (optional)

Some PRs merge throwaway files (one-off analysis scripts, scratch/debug output,
root clutter) useful during the work but not meant to live in the repo. After the
merge these are **tracked, committed** files on the base branch, so removing one is
a real repo change (`git rm` + commit), not local-junk cleanup. Surface only files
**added by this PR** and remove only what the user confirms — never auto-delete.

Skip silently when: the PR added no files, no candidate survives filtering, or the
user selects skip-all.

1. List PR-added files (status `added`, paginated). `{owner}/{repo}` is gh's
   current-repo placeholder — no need to set `$OWNER`/`$REPO`; `<PR_NUMBER>` is the
   merged PR from Step 1:
   `ADDED=$(gh api --paginate "repos/{owner}/{repo}/pulls/<PR_NUMBER>/files" --jq '.[] | select(.status=="added") | .filename')`
2. Filter to candidates via the heuristics + hard exclusions + the `git grep`
   reference check in `references/ephemeral-heuristics.md`. A file imported or
   referenced by any other tracked file is never a candidate.
3. Gate via `AskUserQuestion` (multi-select): each candidate with its path + reason
   ("named scratch_*", "root-level analysis script", ...). Options: pick files to
   remove / skip all. Read each candidate's head first; if it looks load-bearing,
   drop it before prompting.
4. For each confirmed file: `git rm -- "$path"` (stages the removal immediately).
   Report each. Step 10's staged-diff gate then commits the deletion — do NOT add
   removed paths to `RUN_TOUCHED` (Step 10's `[ -e "$p" ]` add-loop cannot stage a
   deletion; `git rm` already staged it).

**Codex**: runs identically under Claude and Codex (gh/git/AskUserQuestion only —
no Serena/rules-forge).

Full heuristics, confidence tiers, hard exclusions, and the Step 10 staging
interaction: `references/ephemeral-heuristics.md`.

### 4.6. Surface deprecated-marker cleanup candidates (optional)

A merged PR sometimes makes previously-deprecated code removable, or lands a
deprecation pointer whose target is already gone. Scan what this PR touched for
deprecation markers and **surface** removal candidates — never auto-delete, and
never escalate to `-D`. Same confirm-only / `git rm` / Step 10 staged-diff
discipline as Step 4.5.

Skip silently when: no marker is found, or the user selects skip-all.

1. Scan the merged file list (`gh pr diff <PR_NUMBER> --name-only`) for markers
   in the **current base-branch content** (not the diff): `@deprecated`,
   `DEPRECATED`, `deprecated alias`, `Deprecated:`, doc-only "deprecated pointer"
   stubs. `git grep -nE 'deprecated|DEPRECATED' -- <merged-files>` is enough.
2. **Distinguish intent before surfacing** — a marker the PR *added* usually means
   "deprecated but kept on purpose" (a grace-period alias); that is NOT a removal
   candidate. Only surface a marker as removable when its target is already gone,
   its grace window is documented as elapsed, or the PR body explicitly says it is
   now safe to drop. When unsure, surface it as **review-only** (show, don't
   stage).
3. Read each candidate's surrounding lines; if other tracked files still reference
   the deprecated symbol (`git grep` the name), drop it from the removal set —
   removing it would break a live caller.
4. Gate via `AskUserQuestion` (multi-select): each candidate with path + marker +
   reason. Options: pick items to clean up / skip all.
5. For each confirmed item: remove the deprecated block via `Edit` (in-file) or
   `git rm` (whole stub file). `Edit`ed files go into `RUN_TOUCHED` (Step 10
   stages them); `git rm` already stages the deletion — do NOT add it to
   `RUN_TOUCHED`. Report each.

**Codex**: runs identically (gh/git/grep/AskUserQuestion only — no
Serena/rules-forge).

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

**6.1 Cross-file dedup gate (run before writing any learning).** For each fact, first grep the SSOT set (`CLAUDE.md`, `AGENTS.md`, the relevant `.claude/rules/*.md`) for an existing home. If one exists, **update that line in place** — do not add a parallel statement in a second file. A rule that must bind both runtimes lives once in `.claude/rules/<x>.md` (Claude) with a concise mirror block in `AGENTS.md` (Codex), tied by a one-line pointer in `CLAUDE.md` `## Modular Rules` — that pairing is the SSOT pattern, not duplication. When the same fact already appears in two files, collapse to one authoritative home + pointer rather than editing both copies. This is the config-side twin of the Step 8 wiki dedup gate; together they keep each fact in exactly one home.

Full procedure — Pre-Audit (scrub existing stamps first), the classification/placement table, the integration process, modular-rule-file structure, the pre-presentation stamp self-check, History Rotation (6.4), and the Normative Doc Size Audit (6.5, with `rules-forge:split` / `claude-md-improver` routing) — lives in **`references/learning-integration.md`**. Apply its Core Principle (`references/core-principle.md`) to every added/modified line; present a diff-style proposal before applying.

### 7. Update Serena memory (Claude-only — Codex skips)

If Serena MCP is available, integrate PR learnings into existing memory files as native content (no `post_merge_prN.md`, no `## Post-Merge` headers). Pre-Audit, the memory-file mapping table, and the self-check are in **`references/learning-integration.md`** ("Serena memory"). Skip if Serena is unavailable or under Codex.

### 8. Wiki lore ingest (MANDATORY)

Absorbs the former `post-merge-wiki` skill as a required step. Runs **after** Steps 6-7 so the config integration is already settled and the wiki step can dedup against it (knowledge routing).

Resolve the wiki root (`.llmwiki/wiki/` → `.claude/wiki/` → `.codex/wiki/`); if none resolves, the step still runs to its checkpoint (below) but does no ingest. Otherwise derive ingest candidates **from the merged file list** (`gh pr diff <N> --name-only`), triage by autonomy boundary, and delegate the heavy lifting (diff-log, multi-page cross-update, insight graduation) to `llm-wiki:ingest-finding`. Full procedure — candidate derivation, the autonomy-boundary triage table, the trivial-merge skip list, the `log.md` entry format, and the Step 6/7 routing-dedup rule — lives in **`references/wiki-ingest.md`**.

**Mandatory checkpoint (no silent skip).** This step must ALWAYS print exactly one terminal status line so a skip can never pass unnoticed (a silently-skipped Step 8 was the original failure mode — nobody could tell whether lore was integrated or just dropped):

- `wiki-ingest: ingested <N>` — N pages created/updated (+ any insight graduations), OR
- `wiki-ingest: no-lore (<reason>)` — where reason ∈ `no wiki root` | `ingest-finding not installed` | `trivial merge` | `no candidates after triage` | `disabled via WIKI_AUTOINGEST=0`.

Set `WIKI_AUTOINGEST=0` to disable the ingest work for a run; the checkpoint line still prints (`no-lore (disabled via WIKI_AUTOINGEST=0)`), so disabling is visible, not silent.

### 9. Update README.md (if needed — humanize-korean/docs-forge are Claude-only)

If the PR changed features/commands/install/usage/deps and a README exists: draft the changes, then refine. If the README is Korean and the `humanize-korean` plugin is installed, apply `/humanize-korean:humanize-korean` to strip AI-writing tells; if it is not installed (it is a user-external plugin, not bundled here), do the equivalent pass by manual edit. Then apply `/docs-forge:readme` guidelines. Both skill passes are Claude-only — under Codex skip them and keep the manual edit. Present for confirmation. Skip if no README-relevant changes.

### 9.5. Update CHANGELOG (if present)

If a `CHANGELOG.md` (or `CHANGELOG`) exists at the repo root **and** the merged PR is changelog-worthy (a user-visible feature / fix / breaking change — not a pure docs/test/chore merge), reflect the merge into it. Mirror Step 9's guide-driven approach: read the `docs-forge:changelog-guide` skill + `plugins/docs-forge/references/CHANGELOG_PATTERNS.md` and apply the patterns **manually** (Keep-a-Changelog grouping, the `Unreleased` section, semantic-version discipline, no per-PR stamp noise in normative entries). Derive the entry from `gh pr diff <PR_NUMBER>` + the PR body, place it under the right `Unreleased` heading (Added / Changed / Fixed / Removed), present a diff-style proposal before applying, and add the file to `RUN_TOUCHED` for Step 10.

The `/docs-forge:changelog` **command** is Claude-only (Codex 0.135 emits no command surface) — under Codex, skip the command and do the same edit manually from the `changelog-guide` skill patterns. Skip silently when no CHANGELOG exists or the merge is not changelog-worthy.

### 10. Commit changes (optional)

If **any** tracked files were modified by this run — config (`CLAUDE.md`/`AGENTS.md`/`GEMINI.md`/`.claude/rules`), README, `CHANGELOG.md` (Step 9.5), Serena memory, **`.llmwiki/` from the Step 8 wiki ingest**, **or a Step 4.5 / Step 4.6 `git rm` deletion** — confirm with the user, then commit using Conventional Commits. Do not gate on config-only changes: a wiki-only post-merge (Step 8 touched `.llmwiki/` but no config learning landed), or a prune-only post-merge (Step 4.5 / 4.6 `git rm`'d a file but no config/wiki change landed), must still commit, or the change is left uncommitted in the working tree. The `git diff --cached --quiet` check below catches the staged deletion even though it is not in `RUN_TOUCHED`.

Stage **only the exact files this run created or modified** — collect them as you go through Steps 4.6-9.5 (each config file you edited, the `.claude/state/spec.json` + spec file from Step 5.7, README, `CHANGELOG.md` from Step 9.5, any Step 4.6 in-file deprecated-block `Edit`, Serena memory files, and the specific wiki pages `ingest-finding` created/updated). Build that explicit list as `RUN_TOUCHED` and add only those paths — **never `git add` a whole directory** (`.llmwiki/`, `.claude/spec/`, …): a pre-existing untracked draft (e.g. a user's `.llmwiki/wiki/draft.md`) would otherwise be swept into this commit, and Step 2 already decided to leave untracked files alone.

```bash
# RUN_TOUCHED = the exact paths this run wrote, gathered across Steps 4.6-9.5.
# Existence-checked + added one at a time: `git add a b c` is atomic, so one
# stale path would abort the whole add (and `|| true` would hide it), leaving
# real changes unstaged.
for p in "${RUN_TOUCHED[@]}"; do
  [ -e "$p" ] && git add -- "$p"
done
```

Skip the commit only when `git diff --cached --quiet` reports nothing staged after the `git add` — a staged-only check; `git status --porcelain` would also count pre-existing untracked files and wrongly attempt an empty-index commit.

**Finalize the run record.** Record this closing step and mark the envelope terminal. Step 10 is a fresh shell, so re-set `PR_NUMBER` (the merged PR number) + `REC` first — `record_step` is not used here, the append + finalize are inlined. The record stays under gitignored `.claude/state/` — do **not** add it to `RUN_TOUCHED`:

```bash
# Step 10 runs in a fresh shell — neither PR_NUMBER nor record_step from Step 1 persist.
# Re-set PR_NUMBER (the merged PR number) so REC points at the real record, not
# .claude/state/post-merge-.json; the :? guard fails loud if it is empty. Append + finalize inline.
REC=".claude/state/post-merge-${PR_NUMBER:?Step 10: re-set PR_NUMBER to the merged PR number before finalizing}.json"
tmp=$(mktemp)
jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '.steps += [{step: 10, status: "done"}]
   | .status = "completed" | .conclusion = "success" | .updated_at = $now' \
  "$REC" > "$tmp" && mv "$tmp" "$REC"
```

## References

- **No-stamp Core Principle + knowledge-routing boundary**: `references/core-principle.md`
- **Config + Serena learning integration** (Pre-Audit, classification, history rotation, size audit, memory mapping): `references/learning-integration.md`
- **Unresolved review surface** (Step 1.5 — cr-fix state-file defer list + `final_state`, open-thread proxy): reads `.claude/state/cr-fix-<PR>.json` / `.claude/state/archive/`; field schema in `plugins/github-dev/skills/cr-fix/assets/final-output.schema.json`.
- **Run-record envelope** (Step 1 + Step 10 — per-step `.claude/state/post-merge-<PR>.json`, schema + archive rotation + per-skill jq): `.claude/rules/state-envelope.md` (concept mirror in `AGENTS.md`).
- **Mandatory wiki ingest** (absorbed post-merge-wiki — candidate derivation, autonomy triage, ingest-finding delegation, routing dedup): `references/wiki-ingest.md`
- **Ephemeral artifact pruning** (Step 4.5 — heuristics, exclusions, git rm/commit interaction): `references/ephemeral-heuristics.md`
- Milestone / Type M-2 diagram mechanics: `skills/update-progress/SKILL.md`
- spec.json schema + ops: `plugins/spec-state/skills/state-tracker/SKILL.md`
- CHANGELOG patterns (Step 9.5): `docs-forge:changelog-guide` skill + `plugins/docs-forge/references/CHANGELOG_PATTERNS.md`

> Follow ~/.claude/CLAUDE.md and the project CLAUDE.md.
