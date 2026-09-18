---
name: flow
description: "Router over the dev skills: which one to call next in the dev flow. Use on /dev:flow, 'dev 흐름', '다음에 뭐 해', '어떤 스킬 써', '어떤 스킬', 'which skill next', 'what do I run next'. Points at decompose-issue -> resolve-issue (-> diagnose for bugs) -> cr-fix -> post-merge, and the branches: worktree, non-default base, when to hand off to orchestrate, and Playwright E2E (e2e-setup once per repo, e2e-author per critical flow, e2e-debug on a CI E2E failure). Recommends only, never acts; no side effects of its own."
---

# dev flow

Format borrowed from mattpocock/skills `ask-matt/SKILL.md` (commit 74ca5fe): a short router over the skills below, not a skill that does the work itself.

## The main flow

1. **`dev:decompose-issue`** breaks the work into vertical-slice GitHub issues (one PR each), confirming decisions and the test seam up front so later steps run non-interactively.
2. **`dev:resolve-issue <number>`** implements one issue: branch, TDD from the agreed seam, verification, PR. Branches into **`dev:diagnose`** first when the issue is a bug that resists a first-glance fix, to find the root cause before patching.
3. **`dev:cr-fix`** loops CodeRabbit + Codex review to convergence (apply / defer / skip each finding), then stops clean, at a minor floor, or on churn.
4. **`dev:post-merge`** cleans up after merge: branch, tracking, CLAUDE.md / AGENTS.md / wiki integration.

## Branches

- **Worktree.** `dev:post-merge` runs from inside a worktree too: it operates on the main repo throughout and prints one cleanup line (`git worktree remove` plus the branch delete) as its last step instead of trying to remove itself.
- **Non-default base.** `dev:cr-fix` detects a PR base that is not the default branch and posts `@coderabbitai review` itself on every push (unless the repo disabled auto-review), because CodeRabbit's own auto-review only covers the default branch plus `base_branches`.
- **Hand off to `dev:orchestrate`.** When an issue splits into 2+ disjoint-file slices with no user decision needed mid-slice, feed decompose-issue's output into orchestrate's job cards instead of one resolve-issue run.
- **Playwright E2E.** `dev:e2e-setup` once per repo (harness + CI). `dev:e2e-author` per critical user flow, from decompose-issue's E2E branch. `dev:e2e-debug` when a CI E2E run fails or flakes.

## Standalone

- **`dev:new`** bootstraps a brand-new empty-directory project; not on this flow, there is nothing to resolve yet.
- **`dev:release`** cuts a version release, called on demand rather than as a flow step.
- **`dev:commit-and-push`** commits a specific set of files outside the issue flow.
- **`dev:state-tracker`** answers "what's in flight" from `.claude/state/spec.json` at session start.
- **`dev:wiring`** audits an existing repo's harness (labels, guards, CI) before decompose-issue assumes one exists.
- **`dev:session-handoff`** hands a session off mid-work, outside the merge flow above.

This router stays implicitly invocable: it only names the flow, and never edits a file or calls `gh` itself.
