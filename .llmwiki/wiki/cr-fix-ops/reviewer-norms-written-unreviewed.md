---
id: reviewer-norms-written-unreviewed
aliases: [coderabbit-code-guidelines-autodetect, post-merge-writes-reviewer-norms, agents-md-is-review-criteria]
last_verified: 2026-08-11
status: active
volatility: stable
sources: 4
---

# The reviewer's own norms are written by a commit that skips review

CodeRabbit's code guidelines are **on by default and need no configuration**: it scans the repository for well-known agent instruction files and applies their contents as review criteria. `**/AGENTS.md` and `**/CLAUDE.md` are both in the default pattern list. This repository has no `knowledge_base` block in `.coderabbit.yaml` at all, so its review criteria come entirely from that auto-detection.

`github-dev:post-merge` edits exactly those files. Step 6 routes merge learnings into `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` / `.claude/rules`, and Step 10 stages and commits them on the base branch after a user confirmation. It never opens a pull request — the skill has no `gh pr create`.

The loop closes:

```
PR -> CodeRabbit review -> cr-fix applies -> merge
   -> post-merge edits AGENTS.md -> commit on base (no PR, no review)
   -> the next PR is reviewed against the new AGENTS.md
```

The criteria a review is measured against change through the one commit that is never itself reviewed. This is true today regardless of configuration, because auto-detection is the default.

## Why `code_review.md` was deliberately left out of `filePatterns`

Adding the repository's review-rule file to `knowledge_base.code_guidelines.filePatterns` was proposed and rejected. It would deepen the self-reference by one level, and the failure path is concrete: a false positive appears, post-merge adds a do-not-flag entry, CodeRabbit stops raising that class permanently. The do-not-flag list only grows — nothing in the loop removes an entry — so suppression of false positives spreading into suppression of true positives leaves no trace in any diff.

Two arguments carried the decision. The benefit is unmeasured: whether feeding the file reduces false positives is `unverified`, while the cost (a monotonically growing self-suppression list) follows from the mechanism. And the coverage it would buy already exists — `AGENTS.md` carries a hard-injected P0/P1/do-not-flag minimal core, and `AGENTS.md` is auto-detected.

The general shape is one this repository already treats as a failure mode elsewhere: `llm-wiki:lint-wiki` names "monotonic relationships" as one of four wiki-rot modes. No equivalent guard watches `code_review.md`.

## What is a guideline, and what only looks like one

`code_guidelines` means "enforce this," so descriptive documents do not belong there. Lore under `.llmwiki/**` and a link catalog like `docs/llm-doc-sources.md` are facts, not requirements; feeding them in makes the reviewer read a description as a demand. This repository's current split already respects that line — `.llmwiki/**` appears in `path_instructions` (how to *review* those files) and nowhere in `code_guidelines`.

Two adjacent traps, both doc-confirmed:

- **`.claude/rules/` matches no default pattern.** The defaults include `**/.cursor/rules/*` and `**/.rules/*`; neither matches `.claude/rules/`. A rule that lives only there is invisible to CodeRabbit exactly as it is to Codex, which is the same blind spot recorded in `agents-md-verbatim-no-import`.
- **Naming a guideline file in `path_instructions` does the opposite of what it looks like.** Per the docs it tells CodeRabbit to *review that file as changed code*, not to use it as a guideline. The mechanism for "use this file as a norm" is `filePatterns`, or auto-detection.

Scoping is directory-based: a guideline file governs its own directory and below, so a root `CLAUDE.md` applies to every file, and a guideline stored in a docs directory governs nothing outside it unless an object-form `filePatterns` entry maps it with `applyTo`.

## What this does not say

It is not established that any wrong review has resulted from this path. The recorded fact is that the channel is open and unguarded. The cheap mitigation, if one is ever wanted, is to treat a post-merge commit that touches `AGENTS.md` / `CLAUDE.md` as review-worthy rather than as housekeeping.

> Refines: [[agents-md-verbatim-no-import]]
> See-also: [[cr-fix-yagni-over-engineering-axis]]
> Evidence: plugins/github-dev/skills/post-merge/SKILL.md
> Evidence: .coderabbit.yaml

## Sources
1. **CodeRabbit docs — Code Guidelines** (`docs.coderabbit.ai/knowledge-base/code-guidelines`, fetched 2026-08-11) — the default detected pattern table (`**/AGENTS.md`, `**/CLAUDE.md`, `**/GEMINI.md`, `**/.cursorrules`, `**/.cursor/rules/*`, `**/.rules/*`, `.github/copilot-instructions.md`, …), directory-based scoping with `applyTo` as the explicit override, the `path_instructions` mistake ("tells CodeRabbit to **review** those files as changed code, not to **use** them as guidelines"), and `filePatterns` supplementing rather than replacing the defaults.
2. **CodeRabbit docs — Knowledge Base overview** (`docs.coderabbit.ai/knowledge-base`, fetched 2026-08-11) — the on-by-default table: code guidelines "Reads supported config files automatically; no setup required."
3. **`plugins/github-dev/skills/post-merge/SKILL.md`** (v2.12.0) — Step 6 config integration targets `CLAUDE.md`/`AGENTS.md`/`GEMINI.md`/`.claude/rules`; Step 10 stages `RUN_TOUCHED` and commits after user confirmation; `git checkout <baseRefName>` at line 165 and no `gh pr create` anywhere in the body.
4. **Session `9fbcf0a9` transcript** (2026-08-04, `.staging/pending-9fbcf0a9-*` marker) — the analysis that surfaced the loop, the rejection of adding `code_review.md`, and the guideline-vs-reference-material distinction. The session ended on an unanswered offer to record this, which is why it reached the wiki through a staging drain rather than a post-merge ingest.
