---
id: post-merge-trigger
aliases: [post-merge-wiki-trigger, wiki-ingest-trigger, post-merge-step-8]
last_verified: 2026-06-02
status: active
volatility: stable
sources: 3
---

# Post-merge wiki trigger

Wiki-worthy lore reaches the wiki after a merge through **two complementary
paths**, not one. Knowing which fires when explains why a merge sometimes
prompts a wiki ingest and sometimes does not.

## The two paths

- **`github-dev:post-merge` Step 8 (mandatory built-in)** — wiki ingest is a
  required step inside the post-merge *skill*, not an optional gate and not a
  separate skill. It resolves the wiki root (`.llmwiki/wiki/` -> `.claude/wiki/`
  -> `.codex/wiki/`), skips trivial merges, derives candidates file-list-first
  from `gh pr diff <N> --name-only` (PR-scoped, merge-method-agnostic, uncapped),
  triages by autonomy boundary, and delegates to
  `llm-wiki:ingest-finding`. Because it lives in the workflow rather than
  reacting to a git event, it runs for **GitHub-UI merges** too — the user
  drives `github-dev:post-merge` after merging in the web UI, and Step 8 fires
  there. There is no "shall I run the wiki step?" `AskUserQuestion` gate any
  more; the step is unconditional whenever a wiki root resolves and the merge is
  non-trivial.
- **`wiki_post_commit_hint.sh`** — a `PostToolUse(Bash)` soft-hint hook that
  fires on a **local CLI merge commit**. It now nudges toward
  `/github-dev:post-merge` (whose Step 8 does the ingest); for non-merge commits
  it still nudges toward `/llm-wiki:ingest-finding`. It never fires for a web-UI merge,
  because no merge `git` command runs on the local machine.

## Why two

The hook alone leaves a coverage gap: PR-based work is usually merged in the
GitHub web UI, which produces no local merge commit, so the hook stays silent.
Step 8 closes that gap by attaching to the post-merge *workflow* instead of a
local git event. The two are complementary — the hook nudges on raw CLI
commits; Step 8 covers the full post-merge workflow including UI merges.

## History: absorption of post-merge-wiki

This used to be a soft, optional `Step 5.8` that surfaced an `AskUserQuestion`
offering to run a separate `llm-wiki:post-merge-wiki` skill — so it was
frequently skipped. post-merge was converted from a command to a skill and
`post-merge-wiki` was absorbed as the mandatory Step 8; the candidate-derivation
and autonomy-triage logic moved into `post-merge`'s `references/wiki-ingest.md`,
while the heavy dedup / diff-log / insight-graduation work still delegates to
`ingest-finding`. llm-wiki remains a soft dependency — Step 8 skips silently when
no wiki root resolves or `ingest-finding` is not installed.

## Knowledge routing

Step 8 runs **after** the config/Serena integration steps so it can dedup
against them. Mechanical / tool-operation rules land in `CLAUDE.md` /
`AGENTS.md` / `.claude/rules/` / Serena; cross-agent *lore* lands in `.llmwiki/`
via Step 8; a finding meeting the graduation bar graduates to `.llmwiki/insight/`
(read by Claude + Codex through the prompt-inject hook), never to `.claude/rules/`.
Each fact is recorded in exactly one home.

## Sources

- `plugins/github-dev/skills/post-merge/SKILL.md` — Step 8 (mandatory wiki
  ingest) and the knowledge-routing guideline.
- `plugins/github-dev/skills/post-merge/references/wiki-ingest.md` — the absorbed
  post-merge-wiki body (candidate derivation, autonomy triage, ingest delegation).
- `plugins/llm-wiki/hooks/wiki_post_commit_hint.sh` — the PostToolUse(Bash)
  soft-hint hook that fires on local CLI merge commits.

> See-also: [[curated-conservative]]
> See-also: [[insight-layer-via-hook]]
> Evidence: plugins/github-dev/skills/post-merge/SKILL.md
