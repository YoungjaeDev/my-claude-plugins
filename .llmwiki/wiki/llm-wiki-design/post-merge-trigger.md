---
id: post-merge-trigger
aliases: [post-merge-wiki-trigger, step-5-8, wiki-ingest-trigger]
last_verified: 2026-05-29
status: active
volatility: stable
sources: 2
---

# Post-merge wiki trigger

`post-merge-wiki` (the skill that scans a merged diff for wiki-worthy lore) is
reached by **two complementary triggers**, not one. Knowing which fires when
explains why a merge sometimes prompts a wiki ingest and sometimes does not.

## The two triggers

- **`github-dev:post-merge` Step 5.8** — a conditional step inside the post-merge
  command. It resolves the wiki root (`.llmwiki/wiki/` -> `.claude/wiki/` ->
  `.codex/wiki/`), skips trivial merges, and otherwise surfaces an
  `AskUserQuestion` offering to run `/llm-wiki:post-merge-wiki`. Because it lives
  in the workflow rather than reacting to a git event, it runs for **GitHub-UI
  merges** too — the user drives `github-dev:post-merge` after merging in the web
  UI, and Step 5.8 fires there.
- **`wiki_post_commit_hint.sh`** — a `PostToolUse(Bash)` soft-hint hook that
  prints "Consider /post-merge-wiki" when it observes a **local CLI merge
  commit**. It never fires for a web-UI merge, because no merge `git` command
  runs on the local machine.

## Why two

The hook alone leaves a coverage gap: PR-based work is usually merged in the
GitHub web UI, which produces no local merge commit, so the hook stays silent
and the wiki never hears about the merge. Step 5.8 closes that gap by attaching
to the post-merge *workflow* instead of a local git event. The two are
complementary — the hook nudges on raw CLI merges; Step 5.8 covers the full
post-merge workflow including UI merges.

## Soft dependency

Step 5.8 mirrors the Step 5.7 (`spec-state`) "if present / skip if absent"
pattern. Four independent skip gates — no wiki root resolves, trivial merge,
user declines the prompt, or the `post-merge-wiki` skill is not installed — keep
`github-dev:post-merge` fully functional in repos with no wiki layer and no
`llm-wiki` install. llm-wiki is a soft dependency here, never a hard one.

## Sources

- `plugins/github-dev/commands/post-merge.md` — Step 5.8 (the conditional
  wiki-ingest trigger) and the mirrored Step 5.7 spec-state pattern it follows.
- `plugins/llm-wiki/hooks/wiki_post_commit_hint.sh` — the PostToolUse(Bash)
  soft-hint hook that fires on local CLI merge commits only.

> See-also: [[curated-conservative]]
> Evidence: plugins/github-dev/commands/post-merge.md
