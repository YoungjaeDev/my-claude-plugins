---
name: flow
description: "Router over the whole dev flow: which skill to call next, from idea to merged PR. Use on /dev:flow, 'dev 흐름', '다음에 뭐 해', '어떤 스킬 써', '어떤 스킬', 'which skill next', 'what do I run next'. The front half is Matt's skills (/grill-with-docs -> /to-spec -> /to-tickets -> /implement-spec or /implement); the back half is dev (/dev:cr-fix -> merge -> /dev:post-merge -> /retro, /dev:release on demand). Also names the branches (bug -> /diagnosing-bugs, no PR, ad-hoc parallel work -> /dev:orchestrate, small ambiguous request, wiki ingest and query, worktree, non-default base, E2E) and the one-time product-repo setup. Front-half detail goes to /ask-matt. Recommends only, never acts; no side effects of its own."
---

# dev flow

A short router, not a skill that does the work itself. Matt's skills (`mattpocock-skills`) own the front half, from idea to a PR ready for review; dev owns the back half, from that PR to merge and cleanup.

## The flow

```
[Matt] /grill-with-docs → /to-spec → /to-tickets    in one context window, no /compact in between
[Matt] /implement-spec ("open a draft PR" gives one PR) or /implement per ticket (/clear between tickets)
── when there is a PR ──
[dev]  /dev:cr-fix → merge → /dev:post-merge → /retro [Matt] in the session that built it
[dev]  /dev:release when needed
```

- **Front half.** For anything this block does not answer (context management, the prototype and wayfinder branches, which Matt skill fits an odd request), ask `/ask-matt`. This router keeps no copy of Matt's rules, so it cannot go stale against them.
- **Back half.** `/dev:cr-fix` loops CodeRabbit + Codex review to convergence; `/dev:post-merge` cleans up the branch and tracking after the merge; `/retro` turns what went wrong into automated checks.

## Branches

- **Bug.** `/diagnosing-bugs` → `/retro`.
- **No PR.** Skip the back half.
- **Ad-hoc parallel work without a spec.** `/dev:orchestrate`. A spec's tickets go through `/implement-spec` instead.
- **Small request, but ambiguous.** `/docs:interview-methodology`.
- **An original arrives** (meeting notes, research, a customer or vendor document). `/wiki:ingest`; it creates the wiki on first use. **Asking what that knowledge says.** `/wiki:query`.
- **Worktree.** `/dev:post-merge` runs from inside a worktree too: it operates on the main repo throughout and prints one cleanup line (`git worktree remove` plus the branch delete) as its last step instead of trying to remove itself.
- **Non-default base.** `/dev:cr-fix` detects a PR base that is not the default branch and posts `@coderabbitai review` itself on every push (unless the repo disabled auto-review), because CodeRabbit's own auto-review only covers the default branch plus `base_branches`.
- **Playwright E2E.** `/dev:e2e-setup` once per repo (harness + CI). `/dev:e2e-author` per critical user flow. `/dev:e2e-debug` when a CI E2E run fails or flakes.

## Product repo setup (once per repo)

1. `/setup-matt-pocock-skills` (Matt) wires the issue tracker, triage labels and domain docs into the repo's agent guidance.
2. Create the five triage labels, or the first `/to-spec` fails on a missing label:

   ```bash
   for l in needs-triage needs-info ready-for-agent ready-for-human wontfix; do gh label create "$l" --force; done
   ```

   `--force` updates a label that already exists instead of failing, so a re-run is safe.

## Standalone

- **`/dev:new`** bootstraps a brand-new empty-directory project.
- **`/dev:wiring`** audits an existing repo's harness (hooks, guidance, labels doc, CI) before the flow assumes one exists.
- **`/dev:commit-and-push`** commits a specific set of files outside the flow.
- **`/dev:session-handoff`** hands a session off mid-work.

This router stays implicitly invocable: it only names the flow, and never edits a file or calls `gh` itself.
