---
id: coderabbit-config-branch
aliases: [coderabbit-yaml-head-branch, auto-review-toggle]
last_verified: 2026-09-21
status: active
volatility: volatile
sources: 2
---

# CodeRabbit reads `.coderabbit.yaml` from the PR head, so the toggle takes effect before it merges

Turning CodeRabbit's auto-review off is a one-line config change, and the obvious mental model is that the setting on the default branch governs the repository. It does not. The reviewer reads the config on the **pull request's own head**, so a PR that changes `.coderabbit.yaml` is reviewed under its own new config, not the base's.

Two runs in the same repository, both with `reviews.auto_review.enabled: false` still on `main`:

- PR #254's head carried `enabled: false` → CodeRabbit posted `Review skipped: automatic reviews are disabled` and never reviewed. Eleven rounds ran on Codex alone.
- PR #259's head removed that key → CodeRabbit auto-reviewed on the opening push (`No actionable comments were generated`) while `main` still had the key.

## What this changes

- **A re-enable is live in its own PR.** There is no window where the flag is merged but not yet in effect, and no need to merge first and test after.
- **A disable is live in its own PR too.** A PR that switches auto-review off loses its own review, which is the moment you most want one.
- **`cr-fix` reads the working tree, so it agrees.** `plugins/dev/skills/cr-fix/scripts/cr-review-request.sh` parses the checked-out `.coderabbit.yaml` and skips posting `@coderabbitai review` while auto-review is disabled. Reading the head is the correct behaviour precisely because the head is what CodeRabbit obeys.

Turning auto-review off drops `/dev:cr-fix` from two reviewers to one without saying so: the loop reaches convergence on Codex alone, and nothing in its final JSON records that CodeRabbit was never asked. Bound review consumption with `cr-fix`'s `MAX_ITER` cap and minor soft-stop, `auto_review.ignore_title_keywords` and `path_instructions` instead of disabling the reviewer.

## Sources

- GitHub PR #254 (head had `enabled: false`; CodeRabbit skipped)
- GitHub PR #259 (head removed it while `main` still had it; CodeRabbit reviewed)

> Evidence: https://github.com/YoungjaeDev/my-claude-plugins/pull/259
> See-also: [[review-loop-churn]]
