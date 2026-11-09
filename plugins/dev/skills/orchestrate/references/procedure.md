# Orchestrate procedure

Step-by-step detail for `SKILL.md`, keyed by its 7 step numbers. The bright lines, the preset and structure tables and the job card stay in `SKILL.md`.

## 1-3. Slice, write the cards, pick presets

- **1. Slice**: write each slice's goal, whether it depends on another slice's result, the absolute paths it owns for writing and the paths it only reads. Two slices that would write the same path are merged or ordered; investigation and review slices own no write paths. Done when every path appears under at most one writer.
- **2. Write the job cards**: one card per slice with all seven fields. The worker never inherits the session, so Inputs carry what the conversation settled, including any test seam agreed before dispatch (a worker subagent has no `AskUserQuestion`). Done when each card can be answered without a follow-up question.
- **3. Pick preset and structure** from the two tables in `SKILL.md`, and give every agent a `name` so a re-query reaches the same transcript. Done when each card names its preset and the run names its structure.

## 4. Dispatch

Independent slices go out in one message, in the background; dependent slices wait for the result they consume. While agents run, the orchestrator prepares step 6's verification instead of doing a worker's job.

Before dispatching, check the main checkout for uncommitted changes on any path a card owns or consults, and have the user commit them, not stash them. A worktree branches from a commit, so an uncommitted edit reaches neither the workers nor the integration tree.

Choose the base each worktree starts from:

- **The setting decides**: which commit an `isolation: worktree` branch starts from is the Claude Code `worktree.baseRef` setting (<https://code.claude.com/docs/en/worktrees#choose-the-base-branch>). Read the value in effect.
- **A base missing needed commits**: when that base lacks commits the cards depend on (a feature branch, unpushed work), have the user set it to the current `HEAD`, or create worktrees by hand with `git worktree add` and dispatch into them without `isolation`.
- **A dependent slice**: it starts from the accepted branch of the slice it consumes. The setting cannot name a branch, so create it by hand with `git worktree add -b <name> <path> <accepted branch>` and record that branch's tip as its base.
- **Record each base**: for an `isolation: worktree` branch, `git merge-base <worker branch> <the ref the setting names>`. Also record `git worktree list` as step 7's baseline.

Every writing slice goes out with `isolation: worktree` or into a hand-made worktree. Prepare each card for its worktree:

- **Untracked inputs**: a fresh worktree has no `.env`, local fixture or installed `node_modules`. Supply them with the user's approval or regenerate them with the repository's own setup step; when neither is possible, stop before dispatch.
- **Worktree-rooted paths**: rewrite the card's owned and consulted Paths as absolute paths under that worker's worktree root. With the main checkout's paths, a worker edits the user's files while its branch stays empty and the gate sees nothing.
- **Paths stay inside**: resolve every rewritten path against the worktree root and refuse one whose components leave it. Resolve the nearest existing ancestor and check the rest as text, since `realpath` without the GNU-only `-m` exits 1 on a missing parent (`review-loop`'s `scripts/path-trust.sh` is the worked form).
- **Commit before returning**: the card tells the worker to commit on its branch before returning and to make no merge commits. Uncommitted work is invisible to step 5 and never merges.

A symlink out of the tree turns a faithful write into an edit of the original checkout while the link's blob never changes. The symlink rules here and in step 5 catch only a link that survives into a commit; see the limit under step 5.

Done when the checkout was clean on every card's paths, every card went out with worktree-rooted paths, and every slice's base plus the worktree baseline are recorded.

## 5. Quality gate

Read each result against its card. Reject when the answer is hedged where the card asked for a decision, a claim carries no evidence (`file:line` for content, command plus output for a run, the path for a path), the result contradicts the repository, the done criteria are not met, or the card's owned Paths were exceeded.

A path violation is decided by git, not by the worker's report:

1. `git rev-list --merges <recorded base>..<worker branch>` must be empty. A merge commit is rejected outright, because a path introduced only in a conflict resolution appears in no parent's diff.
2. List every path the branch's own commits touched: `git log --no-renames -z --name-only --pretty=format: <recorded base>..<worker branch>`. Resolve each repo-relative path against the repo root.
3. A path outside this card's owned Paths is a violation, even when another card owns it. A branch that adds or retargets a symlink resolving outside the worktree root is a violation too, whatever paths it lists.

The three flags each close a hole. `git log` over two dots, never `git diff <base>...<branch>`, because a net diff hides a file added and deleted again, a leaked secret included. `--no-renames`, because a rename prints only its destination; `-z`, because a non-ASCII or newline path comes back octal-escaped.

A content violation is a diff inside an owned path that the card's Goal does not explain (an unrequested feature, a refactor nobody asked for, a bulk reformat).

On rejection, re-query in this order and stop at the first pass:

1. `SendMessage` to the same agent naming the failed criterion, at most twice, but never for a path violation. That agent keeps its branch, so the offending commit stays in `<base>..<branch>` however it is fixed. A path violation goes straight to a newly dispatched isolated agent from the recorded base, with the rejected answer and failed criterion as Inputs.
2. Re-dispatch the card once on the next preset up, with the rejected answer as an input. A rejected `dev:worker-max` result goes straight to 3.
3. Ask the user with the rejected answers summarised; another vendor's agent is one of the options there, never a silent fallback.

**Scope violations are not reverted.** A branch that fails the check is not merged, so its writes never reach the user's checkout. Send the card down the ladder naming the paths it left, write `scope violation: <path>` in the agent's ledger row, and ask before dropping a branch whose out-of-scope work looks worth keeping.

The guarantee covers writes that go through git only. A worker that creates a symlink under an owned path, writes through it and removes the link before committing leaves a clean branch while a file outside the worktree changed. No git-level check sees that; a filesystem boundary needs a sandbox, not a branch check.

Done when every slice has an accepted result or an open question in front of the user.

## 6. Integrate and verify

Merge every accepted branch into one integration worktree and verify there, not in each worktree and not in the untouched main checkout: either passes two branches whose APIs disagree. Run the tests, lint or build the repository defines, and `Read` the decisive `file:line` evidence. Worker self-reports do not count.

A quantitative check becomes the smallest script that fails when the property breaks; a qualitative one goes to a deep-preset review slice with its own card.

Done when the verification commands ran against the integrated tree in this session and their output is in hand.

## 7. Clean up and report

Bring the verified integration result into the user's branch; a branch that failed step 5 or 6 is dropped, not repaired by hand. Compare `git worktree list` with the step 4 baseline and remove worktrees until it matches, then delete each `worktree-<name>` branch.

A worker that left untracked build output or an uncommitted edit makes `git worktree remove` fail with `contains modified or untracked files`. Confirm its branch holds the merged commits, report what is discarded, and remove it with `--force`.

Report the outcome first, then the ledger:

| Agent | Preset | Retries | Verdict | Evidence |
|---|---|---|---|---|

Done when the report names what was verified and what remains `unverified`, with one ledger row per dispatched agent.

## Pitfalls

| Symptom | Cause |
|---|---|
| two agents edited the same file | step 1 skipped the per-path writer check |
| a worker asked a clarifying question and stalled | the card's Inputs omitted a decision the conversation had made |
| an accepted answer turned out wrong at step 6 | the gate accepted a claim without `file:line` |
| the orchestrator ran out of context mid-run | it read the workers' files itself during step 4 |
| a worktree survived the session | `isolation: worktree` keeps a changed worktree until a periodic sweep; step 7's baseline comparison was skipped |
| a worker edited a file no card owned | the writing slice went out without `isolation: worktree` |
| a worker's branch came back empty | the card never told it to commit, or carried the main checkout's paths |
| a dependent slice built against a stale interface | its worktree branched from the setting's base instead of the accepted branch |
| every slice's base looked wrong on a feature branch | the base was assumed to be `HEAD` instead of read from `worktree.baseRef` |
| integration broke only after the run ended | step 6 verified each worktree alone instead of one merged tree |
| a worker could not find a local config or dependency | it is untracked or ignored, so the worktree never had it |
| a re-query failed the gate twice on a good-looking fix | a path violation went back to the same agent instead of a new one |
| effort never changed between jobs | `model` was passed without a `dev:worker-*` type; effort lives in the preset |
