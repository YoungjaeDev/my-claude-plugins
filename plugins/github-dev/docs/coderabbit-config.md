# CodeRabbit Configuration for `cr-fix` Auto-Fetch

Recommended `.coderabbit.yaml` keys to keep `/github-dev:cr-fix` working without surprises.

This file is reference only — drop the snippet into your repo's `.coderabbit.yaml` after a quick review. The plugin does NOT auto-write this file into user repos.

## Minimum required

```yaml
reviews:
  enable_prompt_for_ai_agents: true   # default true; our fetch path parses "🤖 Prompt for AI Agents" blocks
  commit_status: true                 # default true; cr-fix polls this status check
auto_review:
  enabled: true                       # default true; review fires on PR open + push
```

`enable_prompt_for_ai_agents` is the load-bearing key — if disabled, the GraphQL fetch returns thread bodies without the `<details><summary>🤖 Prompt for AI Agents</summary>` block, and the per-issue fix workflow has no machine-readable guidance.

## Recommended additions

```yaml
reviews:
  profile: chill                      # chill | assertive ; chill = default, lower noise
  request_changes_workflow: false     # auto-merge gating is out of scope for this plugin
auto_review:
  drafts: false                       # don't burn rate on draft PRs
  auto_incremental_review: true       # review each new push, not just initial PR
  base_branches:                      # restrict review to branches that matter
    - main
    - master
```

## Rate-limit sanity

CodeRabbit Pro has per-seat hourly review quotas. To avoid hitting them in the cr-fix loop:

```yaml
reviews:
  auto_pause_after_reviewed_commits: 5   # pause after 5 incremental reviews per PR
```

Combined with the plugin defaults (`/github-dev:cr-fix --timeout 1800`), this keeps long iteration loops within free-tier limits.

## Path filters (optional, large monorepos)

```yaml
reviews:
  path_filters:
    - "!docs/**"           # skip review on docs-only changes
    - "!**/*.lock"
    - "!.github/workflows/**"
```

## Repository instruction discovery

CodeRabbit auto-ingests `CLAUDE.md` / `AGENTS.md` / `.cursorrules` as review criteria — no extra config needed. If you maintain `.claude/rules/*.md` modules in this repo, they ARE picked up via the root `CLAUDE.md` `@.claude/rules/...` references.

## Verification

After saving, push a commit and verify:

1. Within ~1 minute, `gh api repos/<owner>/<repo>/commits/<sha>/status --jq '.statuses[].context'` returns at least one row containing `CodeRabbit` (case-insensitive).
2. After review completes, `gh api graphql ...` over `pullRequest.reviewThreads` returns thread bodies containing the literal `🤖 Prompt for AI Agents` substring.

If either fails, the corresponding flag in this config is the most likely culprit.

## What is intentionally NOT in this template

- `pre_merge_checks.*.mode: error` and `request_changes_workflow: true` — these gate auto-merge and are out of scope for cr-fix's default flow. Add them only when adopting auto-merge separately.
- Custom Finishing-Touch recipes — Pro+ feature, not required for the official autofix flow this plugin uses.
- Webhooks — CodeRabbit does not provide an inbound webhook for "review done"; commit-status polling is the supported wait path.
