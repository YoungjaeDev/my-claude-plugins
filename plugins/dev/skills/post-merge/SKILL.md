---
name: post-merge
description: "Clean up after a PR merges: switch to base, delete the merged branch, sync GitHub Project/milestone and .claude/state/spec.json, integrate what merged into CLAUDE.md/AGENTS.md/.claude/rules, run the mandatory wiki-lore ingest, curate README and the repo About line, commit. Use on /dev:post-merge, 'post-merge cleanup', '머지 후 정리', 'integrate PR learnings', or right after a PR merges. gh pr view is the merge signal, never git SHAs; inside a worktree it works on the main repo and prints the worktree removal command last. Not for an open PR's review feedback (/dev:cr-fix)."
allowed-tools: Read Write Edit Bash Glob Grep AskUserQuestion
---

# Post-Merge

Local cleanup + knowledge integration after a PR is merged. One run takes a merged PR from branch cleanup → tracking sync → config/memory integration → **mandatory** wiki-lore ingest → README → commit. Follow project guidelines in `@CLAUDE.md` and `@AGENTS.md` throughout.

## Guidelines

- **Worktree mode.** post-merge runs from the main repo or from the PR's worktree. Every step works on the main repo: git calls run as `git -C "$MAIN_REPO"` and repo paths resolve under `$MAIN_REPO/`, in the steps below and in `references/`. `MAIN_REPO=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")` gives the same answer from either place, so re-derive it in any fresh shell. Inside a worktree (`IN_WT=1`) Step 1 copies the worktree's cr-fix state into the main repo's archive, Step 4 leaves the branch alone (the worktree still has it checked out), and Step 11 prints the one command that removes the worktree and the branch. post-merge never removes the worktree itself: on Windows a worktree removed from inside itself is only half deleted.
- **Non-default base.** For a PR into a branch CodeRabbit does not auto-review, cr-fix on the `auto` / `pr-bot` source posts `@coderabbitai review` itself, unless the repo set `reviews.auto_review.enabled: false` (`plugins/dev/skills/cr-fix/SKILL.md` Step 2); Step 3 below checks out that base like any other. It also changes what the merge did to the linked issues: GitHub honours a closing keyword only on a merge into the default branch, so a non-default base leaves every one of them open with no signal on the PR page — Step 5 is what catches that, and it runs on every PR.
- **`gh pr view` is the authoritative merge signal.** Step 1's `gh pr view ... state=MERGED` is the single source of truth for "did this land". Later steps MUST NOT re-verify merge state by comparing git SHAs.
- **Never use SHA-level merge comparison.** `git log <base>..<branch>`, `git cherry`, `git rev-list --left-right` all false-positive after squash merge (base gets one new SHA) and rebase merge (branch SHAs rewritten). If unsure content landed, diff content not SHAs (Step 4).
- **No stamps, current-state only.** Normative docs hold current rules; provenance lives in git/PR/blame. No `(#N)` / `PR #N` / `이슈 #N` citations, no `## Post-Merge` headers. Full rules + the `<!-- history-allowed [max=N] -->` opt-out + language consistency + SSOT cross-file dedup + content-first: see `references/core-principle.md`.
- **Knowledge routing (no double-recording).** Mechanical / tool-operation rules → `CLAUDE.md` / `AGENTS.md` / `.claude/rules/` / Serena memory (Steps 6-7). Cross-agent *lore* (provider quirks, design rationale, debugging stories) → `.llmwiki/` via the wiki step (Step 8). Each fact is recorded in exactly one home; the wiki step (run *after* config integration) dedups against what Steps 6-7 already absorbed. Cross-agent rules that graduate do so to `.llmwiki/insight/` via the wiki step, never to `.claude/rules/` (Codex can't read it).
- **Leftover-review surface (Step 1.5) is informational.** The run reads cr-fix's state file (`.claude/state/cr-fix-<PR>.json`, else the latest `.claude/state/archive/` copy) to surface autonomously-deferred or cap/timeout-stopped findings after the merge, but never blocks cleanup. It always prints one `leftover-reviews: …` checkpoint line (mirroring the Step 8 wiki checkpoint) so a skip can't pass unnoticed. `gh` / `jq` / `Read` only → identical under Claude and Codex.
- **Codex partial-execution.** The Serena (Step 7), `docs:write-rules` (Step 6.5), and `humanize-korean` / `docs:readme` (Step 9) sub-steps are Claude-only; under Codex, gracefully skip them and note the skip rather than failing. Every other step runs identically on both runtimes.
- **Interactive input is capability-aware.** Every prompt and confirmation below, each `AskUserQuestion` mention included, is a gate rather than a tool name: `AskUserQuestion` under Claude Code, `request_user_input` under Codex where exposed, otherwise one concise blocking question asked before the irreversible action (`git rm`, `gh repo edit`). Full policy: `AGENTS.md` → "Cross-runtime interactive input policy".
- **Run record.** Step 1 opens `.claude/state/post-merge-<PR>.json` and every step appends its outcome, so a silent skip becomes visible; Step 10 finalizes it. Mechanism, per-step skip reasons, and the finalize block: `references/run-record.md`.

## Arguments

- PR number (optional): if not provided, infer from conversation context, else `gh pr list --state merged --limit 5` and prompt the user to select.

## Workflow

### 1. Identify PR

**Worktree detection**: run first. A linked worktree's git dir differs from the common git dir; the main checkout's does not.

```bash
MAIN_REPO=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
IN_WT=0; WT_PATH=""
if [ "$(git rev-parse --absolute-git-dir)" != "$(git rev-parse --path-format=absolute --git-common-dir)" ]; then
  IN_WT=1; WT_PATH=$(git rev-parse --show-toplevel)
  echo "post-merge: worktree mode (worktree $WT_PATH, main repo $MAIN_REPO)"
fi
```

- Use the PR number argument if given; else infer from context; else `gh pr list --state merged --limit 5` and prompt.
- `gh pr view <PR_NUMBER> --json number,title,url,baseRefName,headRefName,body,state,files,mergeCommit`. `url` is what Step 5 puts in a close comment; a bare `#<PR>` is resolved in the *issue's* repository, so the comment must carry the PR's own URL rather than reconstruct one.
- Verify `state` is `MERGED`. This result is the **authoritative merge signal** (see Guidelines); no later SHA comparison.
- Capture `MERGE_SHA=$(gh pr view <PR_NUMBER> --json mergeCommit --jq '.mergeCommit.oid')`: this is **this PR's** merge commit, used to label the wiki log entry and read diff content. Step 8 derives the merged **file list** from `gh pr diff <N> --name-only` (PR-scoped, merge-method-agnostic, uncapped), not from `MERGE_SHA` (a `--no-ff` merge commit shows an empty combined diff; a multi-commit rebase merge's SHA only points at the last replayed commit).

**Carry cr-fix state out of the worktree** (`IN_WT=1` only). cr-fix wrote its state under the worktree, which Step 11's command deletes; copy it to the main repo's archive first so Step 1.5 and later runs still find it. The archive name keeps the `cr-fix-<PR>-` prefix Step 1.5 globs for:

```bash
if [ "$IN_WT" = 1 ]; then
  # Fail loud: Step 11's command deletes the worktree, so a silent failed copy loses the state.
  ARC="$MAIN_REPO/.claude/state/archive"
  mkdir -p "$ARC" || { echo "post-merge: cannot create $ARC" >&2; exit 1; }
  for f in "$WT_PATH/.claude/state/archive/cr-fix-${PR_NUMBER}-"*.json; do
    [ -f "$f" ] || continue
    cp -p "$f" "$ARC/" || { echo "post-merge: copying $f failed" >&2; exit 1; }
  done
  live="$WT_PATH/.claude/state/cr-fix-${PR_NUMBER}.json"
  if [ -f "$live" ]; then
    # $$ as in cr-fix's own archive names: a same-second rerun keeps both copies.
    cp -p "$live" "$ARC/cr-fix-${PR_NUMBER}-$(date +%Y%m%d-%H%M%S)-$$-wt.json" \
      || { echo "post-merge: copying $live failed" >&2; exit 1; }
  fi
fi
```

**Open the run record.** With `PR_NUMBER` + `MERGE_SHA` fixed, run the init block in `references/run-record.md` and `record_step 1 done`. That file also holds the per-step recording contract every later step follows.

### 1.5. Surface unresolved review items (informational)

A merge can land while `cr-fix` still left findings unresolved: items it autonomously **deferred** (real + high-severity + too invasive for autopilot), or a loop that exited on a cap/timeout rather than converging clean. That signal sits in `cr-fix`'s state file and nobody reads it. This step surfaces it **once, right after the merge is confirmed**. It is **informational: it never blocks cleanup**; like the Step 8 wiki checkpoint it ALWAYS prints exactly one terminal status line so a skip can't pass unnoticed.

**Primary signal: the cr-fix state file.** cr-fix archives its live state on exit (`emit-final-json.sh` persists the final `final_state` + `auto_judge_stats` into the file, then moves `.claude/state/cr-fix-<PR>.json` → `.claude/state/archive/cr-fix-<PR>-<ts>.json`), so the archived copy is the usual hit and is self-describing; check the live path first, then the latest archive:

Run the block in `references/leftover-reviews.md` ("Primary signal") verbatim.

**Secondary signal (advisory): open CR review threads on the merged PR.** Top-level (non-reply) review comments are a coarse proxy for unresolved threads; it is NOT the primary gate:

Run the block in `references/leftover-reviews.md` ("Secondary signal") verbatim.

**Decide the checkpoint line.** The primary trigger is a non-empty defer list OR a `final_state` that means the loop stopped with work potentially outstanding (`iteration_cap`, `timeout`, `cli_failed`, `rate_limited`). `user_declined` always carries `defer > 0`, so the defer list catches it; `minor_floor` deferred nothing by definition and its low-severity fixes were already pushed, so it is not a trigger on its own:

Run the block in `references/leftover-reviews.md` ("Decide the checkpoint line") verbatim.

- **Leftover present**: after the `leftover-reviews: <N> deferred (final_state=<X>)` line, render the `$DEFERS` items as a table (`Path:Line · Severity · Reason`), and append the open-thread count when `OPEN_THREADS > 0`. Tell the user these were **not** auto-applied: review them on the PR page (`gh pr view <PR_NUMBER> --comments`) or in a follow-up; do not silently drop them.
- **None**: print `leftover-reviews: none` when no cr-fix state file resolves, or it shows `defer == 0` with a non-trigger `final_state`.
- **Recurring leftover**: before printing, grep the older archives (`.claude/state/archive/cr-fix-*.json`, excluding this PR) for the same finding. A leftover that surfaces a second time is a standing rule, not an incident — mark it `promotion-candidate` in the table and hand it to Step 8 so `wiki:ingest-finding` files it under `.llmwiki/insight/`. Do not promote it here.

### 2. Check local changes

`git -C "$MAIN_REPO" status --porcelain` (the main repo is what Step 3 switches):
- Untracked (`??`): ignore, proceed.
- Modified/staged (`M`/`A`/`D`); prompt via `AskUserQuestion`: **stash** (`git -C "$MAIN_REPO" stash push -m "post-merge: temp save"`) / **discard** (`git -C "$MAIN_REPO" restore --staged --worktree -- .`, reverts tracked changes only; never `git clean`, so pre-existing untracked files/drafts are preserved per the rule above) / **abort**.
- If stashed, prompt at the end of the run for **pop** / **apply** / **later**.

### 3. Switch to base branch

```bash
git -C "$MAIN_REPO" fetch origin
git -C "$MAIN_REPO" checkout <baseRefName>
git -C "$MAIN_REPO" pull origin <baseRefName>
```

### 4. Clean up local branch

- `IN_WT=1`: skip the deletion (the worktree still has the branch checked out, so `git branch -d` would refuse); Step 11 prints it. The content check below still applies.
- `git -C "$MAIN_REPO" branch --list "$headRefName"`.
- **No SHA-level merge check** (see Guidelines). If unsure content landed, diff content: `git -C "$MAIN_REPO" diff "origin/$baseRefName..$headRefName" -- <paths>` (empty = fully landed; safe for squash).
- If the branch exists, confirm deletion, then `git -C "$MAIN_REPO" branch -d "$headRefName"`.
  - For squash merges expect `warning: not yet merged to HEAD`, which is normal; `-d` detects the merge via `origin/<branch>` tracking and still succeeds. Do NOT escalate to `-D`, do NOT treat as data loss, do NOT open a "missing commits" PR.
- If another worktree (not this one) still has the branch checked out, report its path from `git -C "$MAIN_REPO" worktree list` and leave it.

### 4.5. Prune ephemeral artifacts merged by this PR (optional)

Some PRs merge throwaway files (one-off analysis scripts, scratch/debug output,
root clutter) useful during the work but not meant to live in the repo. After the
merge these are **tracked, committed** files on the base branch, so removing one is
a real repo change (`git rm` + commit), not local-junk cleanup. Surface only files
**added by this PR** and remove only what the user confirms; never auto-delete.

Skip silently when: the PR added no files, no candidate survives filtering, or the
user selects skip-all.

1. List PR-added files (status `added`, paginated). `{owner}/{repo}` is gh's
   current-repo placeholder: no need to set `$OWNER`/`$REPO`; `<PR_NUMBER>` is the
   merged PR from Step 1:
   `ADDED=$(gh api --paginate "repos/{owner}/{repo}/pulls/<PR_NUMBER>/files" --jq '.[] | select(.status=="added") | .filename')`
2. Filter to candidates via the heuristics + hard exclusions + the `git grep`
   reference check in `references/ephemeral-heuristics.md`. A file imported or
   referenced by any other tracked file is never a candidate.
3. Gate via `AskUserQuestion` (multi-select): each candidate with its path + reason
   ("named scratch_*", "root-level analysis script", ...). Options: pick files to
   remove / skip all. Read each candidate's head first; if it looks load-bearing,
   drop it before prompting.
4. For each confirmed file: `git -C "$MAIN_REPO" rm -- "$path"` (stages the removal immediately in the main repo's index, which Step 10 commits).
   Report each. Step 10's staged-diff gate then commits the deletion. Do NOT add
   removed paths to `RUN_TOUCHED` (Step 10's `[ -e "$p" ]` add-loop cannot stage a
   deletion; `git rm` already staged it).

Full heuristics, confidence tiers, hard exclusions, and the Step 10 staging
interaction: `references/ephemeral-heuristics.md`.

### 4.6. Surface deprecated-marker cleanup candidates (optional)

A merged PR sometimes makes previously-deprecated code removable, or lands a
deprecation pointer whose target is already gone. Scan what this PR touched for
deprecation markers and **surface** removal candidates; never auto-delete, and
never escalate to `-D`. Same confirm-only / `git rm` / Step 10 staged-diff
discipline as Step 4.5.

Skip silently when: no marker is found, or the user selects skip-all.

1. Scan the merged file list (`gh pr diff <PR_NUMBER> --name-only`) for markers
   in the **current base-branch content** (not the diff): `@deprecated`,
   `DEPRECATED`, `deprecated alias`, `Deprecated:`, doc-only "deprecated pointer"
   stubs. `git -C "$MAIN_REPO" grep -nE 'deprecated|DEPRECATED' -- <merged-files>` is enough.
2. **Distinguish intent before surfacing**: a marker the PR *added* usually means
   "deprecated but kept on purpose" (a grace-period alias); that is NOT a removal
   candidate. Only surface a marker as removable when its target is already gone,
   its grace window is documented as elapsed, or the PR body explicitly says it is
   now safe to drop. When unsure, surface it as **review-only** (show, don't
   stage).
3. Read each candidate's surrounding lines; if other tracked files still reference
   the deprecated symbol (`git grep` the name), drop it from the removal set:
   removing it would break a live caller.
4. Gate via `AskUserQuestion` (multi-select): each candidate with path + marker +
   reason. Options: pick items to clean up / skip all.
5. For each confirmed item: remove the deprecated block via `Edit` (in-file) or
   `git -C "$MAIN_REPO" rm` (whole stub file); `Edit` the `$MAIN_REPO/` path, never the worktree copy. `Edit`ed files go into `RUN_TOUCHED` (Step 10
   stages them); `git rm` already stages the deletion. Do NOT add it to
   `RUN_TOUCHED`. Report each.

### 5. Close the issues the merge left open (always runs)

Not optional and not conditional on a GitHub Project existing — 5.1 below is the optional part.

A merge does not always close what the PR body says it closes, and every way it fails is silent: the body still reads `Closes #N` and nothing on the PR page says otherwise. Two causes, both common:

- **Non-default base.** GitHub interprets a closing keyword only when the PR targets the default branch. "If the pull request targets any other branch, then these keywords are ignored, no links are created, and merging the PR has no effect on the issues." (`docs.github.com` → Linking a pull request to an issue.)
- **Auto-close disabled.** A repository can turn off "Auto-close issues with merged linked pull requests" in Settings → General → Issues. The link exists, the merge does not act on it.

**Read the issue's state, not the link set.** `closingIssuesReferences` is documented as issues that *may* be closed by the PR and includes manually linked ones, so subtracting it hides an issue that is linked and still open — exactly the case this step exists to catch. The issue's own `state` is the direct signal and needs no reasoning about link semantics.

That demotes the field from evidence to **a source of candidates, which it still is**. An issue linked by hand in the PR sidebar appears in no body and in no commit message, so a text scan alone never reaches it — and on a repository with auto-close disabled it is exactly the issue left open. Take `gh pr view <PR_NUMBER> --json closingIssuesReferences` as a third input alongside the body and the commits, and put every issue it names through the same state read.

- Extract issue refs from the PR body **and from every commit message on the PR** (`gh api --hostname <host> --paginate "repos/{owner}/{repo}/pulls/<PR_NUMBER>/commits"`, the host taken from the PR's `url` — `gh api` defaults to `github.com` whatever the local remote says, and `gh pr view --json commits` stops at 100 and drops the rest silently, the same cap that bites `--json files`). That endpoint has its own ceiling of 250 commits which `--paginate` does not lift, so a count that comes back at exactly 250 is a truncated scan: say so in the report rather than calling the sweep complete. All nine documented keywords, any case, with or without a colon: `close` / `closes` / `closed`, `fix` / `fixes` / `fixed`, `resolve` / `resolves` / `resolved`. Listing only the `-s` forms misses `Fixed #123`, which GitHub honours and which leaves no link behind on a non-default base — the very case this step exists to catch. GitHub honours a closing keyword in a commit message too, and such a reference never appears in the body, so a body-only scan reports a clean Step 5 over an issue nobody closed. Merge both sources and deduplicate on host + repo + number before showing anything.
- Keep the repository qualifier: a ref is `#N` (this repo) or `OWNER/REPO#N` (another repo — the documented cross-repository syntax). Collapsing `owner/other-repo#123` to `123` and closing it here closes **this** repository's issue 123 instead, while the user believes they confirmed the other one.
- A third spelling reaches the same issue: a full URL, `https://<host>/OWNER/REPO/issues/N`. GitHub's own syntax table lists only the two `#` forms, so whether a merge honours the URL is beside the point — what matters here is that a body written that way yields no refs at all and Step 5 completes silently on an issue nobody closed. The user confirms every candidate before anything closes, so over-collecting costs a line in a list and under-collecting is the failure this step exists to prevent.
- Validate every ref before it reaches a command line — a PR body and a commit message are both untrusted input. A `#` ref must match `^([A-Za-z0-9._-]+/[A-Za-z0-9._-]+)?#[0-9]+$`. A URL ref must match `^https://[^/[:space:]]+/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+/issues/[0-9]+$` **and** carry the same host as the PR's own `url` from Step 1. `https` only, and one host only: the refs come from text anyone can write, and the state read below is an outbound request made before the user has confirmed anything. A ref on another host is listed as unresolved, never queried and never closed.
- **Keep a URL ref as its URL.** `gh issue view` and `gh issue close` both take `{<number> | <url>}`, so a validated URL passes through untouched. Reducing it to `OWNER/REPO` and a number throws the host away, and a GitHub Enterprise issue then resolves against `github.com` — the same number, a different repository, silently. Show the host in the confirmation list too, so the user sees which server they are closing on. (`--repo` would also accept `[HOST/]OWNER/REPO`; passing the URL needs no such assembly.)
- For each ref, read its state: a URL ref via `gh issue view <url> --json state,title`, a `#` ref via `gh issue view <N> --repo <[HOST/]OWNER/REPO> --json state,title` — always pass `--repo`, with the repository resolved from the ref for a qualified one and from the current repo for a bare `#N`, and the host taken from the PR's own `url` in both cases. `gh` defaults an unqualified `--repo` to `github.com`, so on a GitHub Enterprise repository a bare `#N` would otherwise be read and closed on the wrong server. `state == "OPEN"` makes it a candidate, whatever the cause; a ref that 404s (private or deleted) is reported, not closed.
- Bound the sweep: the refs come from text anyone can write, so cap the deduplicated candidate list (a couple of dozen is generous for a real PR) and report anything past the cap as unresolved rather than issuing an unbounded run of API calls. A rate limit, a timeout or any other partial failure marks that ref unresolved too — keep the states already read, and never let a failed read pass as "not open".
- List the candidates with their host, repo, number and title, and confirm through the interactive-input gate which ones this PR resolved. Then close each confirmed one the same way it was read — `gh issue close <url> --comment "Resolved by <PR url>"`, or `gh issue close <N> --repo <[HOST/]OWNER/REPO> --comment "Resolved by <PR url>"` — the **same** repository identifier the state read used one step earlier. Dropping the host on the write path alone sends the close to `github.com` while the read came from the Enterprise server. The comment body is read **in the issue's repository**, so a bare `#<PR>` there points at that repository's own number — a different pull request, or nothing. The PR's `url` (from Step 1) resolves the same everywhere and needs no same-repo special case. Do not close an issue the user did not confirm.

### 5.1. Update GitHub Project status (optional)

- `gh project list --owner <owner> --format json`. If none, skip silently. Else `gh project item-list` → `gh project field-list` → `gh project item-edit` to set Status to "Done". Skip if the issue is not in the project.
- Two scopes, not one: listing and reading a Project needs `read:project`, and `gh project item-edit` writes, which needs `project`. A token with only the read scope gets through the listing and fails on the edit, so treat a permission error there as the skip condition it is, not as a run failure. A missing Project, or a token without either scope, skips **this sub-step only** — Step 5 above already ran. It gets no `steps[]` entry of its own: `state-envelope/v0` carries one entry per top-level step and folds sub-steps into the parent, and Step 5's own entry is now always `done`, so a skipped Project can no longer be misread as a skipped issue-close check. Report which condition fired in the run output; the envelope does not need it.

### 5.5. Sync milestone progress (if issues have milestones)

For each related issue with a milestone, recompute module progress and regenerate the milestone table + Type M-2 diagrams. Full mechanics: `references/update-progress.md` ("Milestone Format" / "Type M-2"). Skip silently when no related issue carries a milestone.

### 5.7. Update `.claude/state/spec.json` (if present)

- If `.claude/state/spec.json` exists, move the `in_progress` entry whose `linked.pr` matches the merged PR (or `linked.issue`) to `completed` with `merge_sha` (first 7 chars) + `completed_at` (today, UTC `YYYY-MM-DD`), and set the spec file's frontmatter `status: merged`.
- Mechanics are owned by `dev:state-tracker`: invoke `/dev:state-tracker complete <spec-path>` if installed; otherwise apply the direct JSON edit per `plugins/dev/skills/state-tracker/SKILL.md`.
- Skip silently if no matching entry, or if `.claude/state/` does not exist.

### 6. Integrate learnings into config files

Read `gh pr diff <PR_NUMBER>` + the PR body, then weave each learning into the **appropriate existing section** of `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` / `.claude/rules/*.md`. **Never append a "Post-Merge Notes" section.**

**6.1 Cross-file dedup gate (run before writing any learning).** For each fact, first grep the SSOT set (`CLAUDE.md`, `AGENTS.md`, the relevant `.claude/rules/*.md`) for an existing home. If one exists, **update that line in place**; do not add a parallel statement in a second file. A rule that must bind both runtimes lives once in `.claude/rules/<x>.md` (Claude) with a concise mirror block in `AGENTS.md` (Codex), tied by a one-line pointer in `CLAUDE.md` `## Modular Rules`: that pairing is the SSOT pattern, not duplication. When the same fact already appears in two files, collapse to one authoritative home + pointer rather than editing both copies. This is the config-side twin of the Step 8 wiki dedup gate; together they keep each fact in exactly one home.

Full procedure: Pre-Audit (scrub existing stamps first), the classification/placement table, the integration process, modular-rule-file structure, the pre-presentation stamp self-check, History Rotation (6.4), and the Normative Doc Size Audit (6.5, `docs:write-rules` routing); this lives in **`references/learning-integration.md`**. Apply its Core Principle (`references/core-principle.md`) to every added/modified line; present a diff-style proposal before applying.

### 7. Update Serena memory (Claude-only — Codex skips)

If Serena MCP is available, integrate PR learnings into existing memory files as native content (no `post_merge_prN.md`, no `## Post-Merge` headers). Pre-Audit, the memory-file mapping table, and the self-check are in **`references/learning-integration.md`** ("Serena memory"). Skip if Serena is unavailable or under Codex.

### 8. Wiki lore ingest (MANDATORY)

Absorbs the former `post-merge-wiki` skill as a required step. Runs **after** Steps 6-7 so the config integration is already settled and the wiki step can dedup against it (knowledge routing).

Resolve the wiki root (`.llmwiki/wiki/` → `.claude/wiki/` → `.codex/wiki/`); if none resolves, the step still runs to its checkpoint (below) but does no ingest. Otherwise derive ingest candidates **from the merged file list** (`gh pr diff <N> --name-only`), triage by autonomy boundary, and delegate the heavy lifting (diff-log, multi-page cross-update, insight graduation) to `wiki:ingest-finding`. Full procedure: candidate derivation, the autonomy-boundary triage table, the trivial-merge skip list, the `log.md` entry format, and the Step 6/7 routing-dedup rule; this lives in **`references/wiki-ingest.md`**.

**Mandatory checkpoint (no silent skip).** This step must ALWAYS print exactly one terminal status line so a skip can never pass unnoticed (a silently-skipped Step 8 was the original failure mode: nobody could tell whether lore was integrated or just dropped):

- `wiki-ingest: ingested <N>` (N pages created/updated, plus any insight graduations), OR
- `wiki-ingest: no-lore (<reason>)`, where reason ∈ `no wiki root` | `ingest-finding not installed` | `trivial merge` | `no candidates after triage` | `disabled via WIKI_AUTOINGEST=0`.

Set `WIKI_AUTOINGEST=0` to disable the ingest work for a run; the checkpoint line still prints (`no-lore (disabled via WIKI_AUTOINGEST=0)`), so disabling is visible, not silent.

### 9. Update README.md + repo About (README edit is optional; the About check is not)

If the PR changed features/commands/install/usage/deps and a README exists: draft the changes, then refine. If the README is Korean and the `humanize-korean` plugin is installed, apply `/humanize-korean:humanize-korean` to strip AI-writing tells; if it is not installed (it is a user-external plugin, not bundled here), do the equivalent pass by manual edit. Then apply `/docs:readme` guidelines. Both skill passes are Claude-only; under Codex skip them and keep the manual edit. Present for confirmation. Skip the README edit if no README-relevant changes.

**Curate, don't append.** README is a normative doc and gets the same discipline Step 6 applies to config files: find the existing section that covers the topic and update it **in place**, collapse a fact that now appears twice into one home, and delete what this merge superseded (a removed command, a stale count, a workaround for a bug this PR fixed). A README that only grows across post-merge runs is the failure mode this step exists to prevent.

**Repo About drift (runs even when the README needs no edit).** The remote About line is a separate surface nobody else in this skill touches, and it goes stale silently:

```bash
gh repo view --json description,repositoryTopics \
  --jq '{description, topics: [.repositoryTopics[].name]}'
```

Compare `description` against the README's opening claim and against what this PR changed (a renamed or removed feature, a changed count, a new entry point). If it drifted, propose the new one-liner via `AskUserQuestion` and apply only on approval — `gh repo edit` writes to the remote and is never unattended work. Report topic drift in the same breath, but do not edit topics.

```bash
gh repo edit --description "<approved one-liner>"
```

Print one line either way so the check cannot pass unnoticed: `repo-about: in sync` or `repo-about: updated`.

### 9.5. Update CHANGELOG (if present)

If a `CHANGELOG.md` (or `CHANGELOG`) exists at the repo root **and** the merged PR is changelog-worthy (a user-visible feature / fix / breaking change, not a pure docs/test/chore merge), reflect the merge into it. Mirror Step 9's guide-driven approach: read the `docs:doc-guides` skill (`## CHANGELOG` section) + `plugins/docs/references/CHANGELOG_PATTERNS.md` and apply the patterns **manually** (Keep-a-Changelog grouping, the `Unreleased` section, semantic-version discipline, no per-PR stamp noise in normative entries). Derive the entry from `gh pr diff <PR_NUMBER>` + the PR body, place it under the right `Unreleased` heading (Added / Changed / Fixed / Removed), present a diff-style proposal before applying, and add the file to `RUN_TOUCHED` for Step 10.

The `/docs:changelog` **command** is Claude-only (Codex emits no command surface); under Codex, skip the command and do the same edit manually from the `doc-guides` `## CHANGELOG` patterns. Skip silently when no CHANGELOG exists or the merge is not changelog-worthy.

### 10. Commit changes (optional)

If **any** tracked files were modified by this run, including config (`CLAUDE.md`/`AGENTS.md`/`GEMINI.md`/`.claude/rules`), README, `CHANGELOG.md` (Step 9.5), Serena memory, **`.llmwiki/` from the Step 8 wiki ingest**, **or a Step 4.5 / Step 4.6 `git rm` deletion**, confirm with the user, then commit using Conventional Commits. Do not gate on config-only changes: a wiki-only post-merge (Step 8 touched `.llmwiki/` but no config learning landed), or a prune-only post-merge (Step 4.5 / 4.6 `git rm`'d a file but no config/wiki change landed), must still commit, or the change is left uncommitted in the working tree. The `git diff --cached --quiet` check below catches the staged deletion even though it is not in `RUN_TOUCHED`.

Stage **only the exact files this run created or modified**: collect them as you go through Steps 4.6-9.5 (each config file you edited, the `.claude/state/spec.json` + spec file from Step 5.7, README, `CHANGELOG.md` from Step 9.5, any Step 4.6 in-file deprecated-block `Edit`, Serena memory files, and the specific wiki pages `ingest-finding` created/updated). Build that explicit list as `RUN_TOUCHED` and add only those paths; **never `git add` a whole directory** (`.llmwiki/`, `.claude/spec/`, …): a pre-existing untracked draft (e.g. a user's `.llmwiki/wiki/draft.md`) would otherwise be swept into this commit, and Step 2 already decided to leave untracked files alone.

```bash
# RUN_TOUCHED = the exact paths this run wrote, gathered across Steps 4.6-9.5.
# Existence-checked + added one at a time: `git add a b c` is atomic, so one
# stale path would abort the whole add (and `|| true` would hide it), leaving
# real changes unstaged.
for p in "${RUN_TOUCHED[@]}"; do
  # RUN_TOUCHED holds $MAIN_REPO/... paths; -C keeps the index the main repo's.
  [ -e "$p" ] && git -C "$MAIN_REPO" add -- "$p"
done
```

Skip the commit only when `git -C "$MAIN_REPO" diff --cached --quiet` reports nothing staged after the `git add` (a staged-only check); `git status --porcelain` would also count pre-existing untracked files and wrongly attempt an empty-index commit.

**Finalize the run record.** Run the finalize block in `references/run-record.md` to append Step 10 and mark the envelope terminal. The record stays under gitignored `.claude/state/`; do **not** add it to `RUN_TOUCHED`.

### 11. Print the worktree cleanup command (`IN_WT=1` only)

Print this one line, filled in, as the last line of the run, and do not run it. The user runs it after leaving the worktree session; removing a worktree from inside itself only half deletes it on Windows.

```bash
# %q: a quote, `$` or space in a path or branch name cannot change the pasted command.
[ "$IN_WT" = 1 ] && printf 'cd %q && git worktree remove %q && git branch -d %q\n' \
  "$MAIN_REPO" "$WT_PATH" "$headRefName"
```

`git worktree remove` refuses a worktree with modified or untracked files, which is the check to keep: anything it names was never committed. `git branch -d` behaves as in Step 4.

## References

- **No-stamp Core Principle + knowledge-routing boundary**: `references/core-principle.md`
- **Config + Serena learning integration** (Pre-Audit, classification, history rotation, size audit, memory mapping): `references/learning-integration.md`
- **Unresolved review surface** (Step 1.5, cr-fix state-file defer list + `final_state`, open-thread proxy): reads `.claude/state/cr-fix-<PR>.json` / `.claude/state/archive/`; field schema in `plugins/dev/skills/cr-fix/assets/final-output.schema.json`.
- **Leftover-review blocks** (Step 1.5 primary signal, secondary signal, checkpoint decision): `references/leftover-reviews.md`
- **Run-record envelope** (Step 1 init + recording contract + per-step skip reasons + Step 10 finalize): `references/run-record.md`; convention + schema in `.claude/rules/state-envelope.md` (concept mirror in `AGENTS.md`).
- **Mandatory wiki ingest** (absorbed post-merge-wiki, candidate derivation, autonomy triage, ingest-finding delegation, routing dedup): `references/wiki-ingest.md`
- **Ephemeral artifact pruning** (Step 4.5, heuristics, exclusions, git rm/commit interaction): `references/ephemeral-heuristics.md`
- Milestone / Type M-2 diagram mechanics: `references/update-progress.md`
- spec.json schema + ops: `plugins/dev/skills/state-tracker/SKILL.md`
- CHANGELOG patterns (Step 9.5): `docs:doc-guides` skill (`## CHANGELOG`) + `plugins/docs/references/CHANGELOG_PATTERNS.md`

> Follow ~/.claude/CLAUDE.md and the project CLAUDE.md.
