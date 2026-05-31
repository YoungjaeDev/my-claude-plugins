---
description: Deep query on GitHub repositories using DeepWiki
---

# /deepwiki:ask

Deep query a GitHub repository using DeepWiki's AI-powered documentation.

## Argument parsing

`$ARGUMENTS` parsing:
- Format: `owner/repo "question"` or `owner/repo question text`.
- Repository: extract the first `owner/repo` pattern.
- Question: everything after the repository.

Examples:
- `/deepwiki:ask facebook/react "How does the reconciliation algorithm work?"`
- `/deepwiki:ask vercel/next.js explain the app router architecture`
- `/deepwiki:ask pytorch/pytorch what are the autograd internals`

## Procedure

Follow the shared procedure in `${CLAUDE_PLUGIN_ROOT}/references/ask-procedure.md` — four phases (structure → optional contents → ask → optional multi-query expansion), the smart-query strategy table, multi-repo patterns, and the error handling table all live there. The `ask` skill uses the same file, so any update propagates to both surfaces.
