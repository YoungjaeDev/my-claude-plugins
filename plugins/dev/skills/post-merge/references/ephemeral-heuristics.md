# Ephemeral Artifact Pruning (Step 4.5, optional)

After a PR merges, some of the files it added were scaffolding — one-off analysis
scripts, scratch/debug output, root clutter — useful during the work but not meant
to live in the repo. This step finds those, asks the user, and `git rm`s only what
they confirm. It is the deletion counterpart to the wiki-ingest step: heuristic
candidate derivation + autonomy-boundary triage, never autonomous deletion.

> A removed file here is a **tracked, committed** file on the base branch. `git rm`
> stages a real repo change that Step 10 then commits — this is not local-junk
> cleanup (Step 2 already decided to leave untracked files alone).

## Purpose / scope

- **Only PR-added files** are candidates. Derive them from the PR file list, status
  `added`. `{owner}/{repo}` is gh's current-repo placeholder (no `$OWNER`/`$REPO` to
  set); `<PR_NUMBER>` is the merged PR from Step 1:
  `gh api --paginate "repos/{owner}/{repo}/pulls/<PR_NUMBER>/files" --jq '.[] | select(.status=="added") | .filename'`
- `modified` / `renamed` / `removed` files are out of scope — pruning a file the PR
  only edited would revert real work, not remove scaffolding.

## Heuristics (confidence tiers)

- **High (filename)** — strong throwaway signal in the name itself:
  - `scratch_*`
  - `tmp_*` / `temp_*`
  - `*_debug.*` / `debug_*`
  - `*_one-off.*` / `*_oneoff.*`
  - root-level `analyze_*` / `analysis_*.{csv,json,ipynb}` clutter
- **High (path)** — lives in a throwaway location:
  - under `tmp/`, `.tmp/`, `scratch/`
  - a non-standard new file dropped at the repo root
- **Low (content — confirm required)** — head ~10 lines carry a self-marked throwaway
  comment: `one-off`, `throwaway`, `temporary`, `delete after`, `debug script`.
  Low-confidence: read the head before proposing, never delete on the comment alone.

## Hard exclusions (never a candidate)

- Anything under `src/` (and language-specific source roots), `tests/`, `docs/`,
  `.github/`.
- `*.md` documentation (README / CHANGELOG / any doc).
- Config: `package.json`, `pyproject.toml`, `tsconfig.json`, `.env*`, `*.lock`.
- Build / dependency directories.
- Files matching a `.gitignore` pattern.
- Project standard entrypoints.

A file that survives a hard exclusion still has to pass the reference check below.

## Reference check (false-positive guard)

Before proposing any candidate, confirm nothing else in the repo depends on it:

```bash
git grep -l "$(basename "$path" | sed 's/\.[^.]*$//')"
```

If any **other** tracked file imports or references the basename, the file is
load-bearing — **drop it from the candidate list**. A referenced file is not a
one-off, whatever its name suggests.

## Deletion gating

| Action | LLM alone | Needs user confirm |
|---|---|---|
| Scan PR-added files for ephemeral patterns | ✅ | — |
| Build candidate list (+ `git grep` ref check) | ✅ | — |
| `git rm` a candidate | ❌ | ✅ |
| Skip all | ✅ | — |

Gate via `AskUserQuestion` (multi-select): show each surviving candidate with its
path and the reason it was flagged ("named `scratch_*`", "root-level analysis
script", "head comment says `delete after`"). Offer pick-files-to-remove and a
skip-all option. Read each candidate's head first; if it looks load-bearing, drop
it before prompting.

## Step 10 staging interaction

`git rm -- "$path"` stages the removal **immediately**. Therefore:

- Do **not** add removed paths to `RUN_TOUCHED`. Step 10's add-loop is
  `[ -e "$p" ] && git add -- "$p"` — the `[ -e "$p" ]` existence test fails for a
  deleted file and `git add` cannot stage a deletion anyway. `git rm` already did it.
- Step 10's commit gate is `git diff --cached --quiet`, which sees the staged
  deletion and commits it alongside any config/wiki changes. A prune-only run (no
  config learning, no wiki ingest) still commits because the deletion is staged.
- post-merge commits locally and does not push (Step 10). The deletion commit stays
  local; it reaches the remote when the user pushes the base branch — same as the
  config-integration commit.

## Anti-patterns

- **Auto-delete** — pruning is gated; no candidate is removed without explicit
  user confirmation.
- **Touch `src/` / `tests/` / `docs/`** — these are hard-excluded; scaffolding does
  not live there.
- **Delete on filename alone** — read the head and run the `git grep` reference
  check before proposing; a `scratch_`-named file imported elsewhere is not a one-off.
- **Guess candidates from the PR body text** — trust the file list
  (`status==added`) only, never prose descriptions of what the PR did.

## Verification

- Every deleted file was `status==added` in this PR (not modified/renamed/removed).
- No other tracked file references the deleted file (`git grep` came back empty).
- The user explicitly approved each deletion via `AskUserQuestion`.
- The deletion is staged by `git rm` and lands in the Step 10 commit as a removal.
