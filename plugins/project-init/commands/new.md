---
description: First-day project bootstrap — interview, .claude/ scaffold, CLAUDE.md + AGENTS.md (Codex reviewer guidelines) + README + CHANGELOG seed, gh repo create + initial push
---

# /project-init:new

Called once in a new directory to produce a "Day 1 ready" project — interview → local seed → gh repo create → initial commit/push.

> **Trigger surface**: explicit user invocation only. No automatic trigger (running it in the wrong directory is dangerous).

## Step 0 — Preflight hard guard (NON-NEGOTIABLE, runs before any other body content)

This guard runs before Phase 0 of `references/new-procedure.md`. It aborts in a non-empty directory.

```bash
# Hard guard — refuses to run if cwd contains ANYTHING beyond ignorable OS junk.
# Walks up to 5 levels deep so deeper sources (e.g. src/app/main.py) and any
# top-level file (Dockerfile, Makefile, .env, docs/*) trigger the abort. Only
# .git/ and OS metadata (.DS_Store, Thumbs.db, desktop.ini) are pruned — a
# pre-existing top-level .claude/ deliberately makes the guard fire (it means
# the directory has already been initialized and re-running would clash).
FIRST_EXISTING=$(find . -mindepth 1 -maxdepth 5 \
  \( -name '.git' -o -path './.git/*' \
   -o -name '.DS_Store' -o -name 'Thumbs.db' \
   -o -name 'desktop.ini' \) -prune \
  -o -print 2>/dev/null | head -1)

if [ -d .git ] || [ -n "$FIRST_EXISTING" ]; then
  echo "[abort] project-init refuses to run in a non-empty directory."
  echo "        cwd: $(pwd)"
  echo "        Existing entry detected: ${FIRST_EXISTING:-.git/}"
  echo "        If you really want to add Claude/Codex scaffolding to an existing"
  echo "        project, use /rules-forge:write-rules or /llm-wiki:bootstrap-wiki"
  echo "        instead."
  exit 1
fi
```

The legacy Phase 0 idempotency guard (in the procedure file) is now redundant for fresh-dir runs but remains as a defense-in-depth check for the partial-seed re-run path (user removed `.gitkeep` files between attempts).

## Step 1 — Procedure

Once the guard passes, follow the full Phase 0–7. The body lives in this plugin's `references/new-procedure.md` — the `new` skill points to the same file. Under Claude Code it resolves to `${CLAUDE_PLUGIN_ROOT}/references/new-procedure.md`; under Codex it resolves to the same relative path (`references/new-procedure.md`) against the plugin cache directory.

What the reference covers:
- Phase 0 — Preflight (gh auth, identity, owner-candidate extraction).
- Phase 1 — Project identity interview (name / owner / visibility / license, batched AskUserQuestion).
- Phase 2 — `.claude/` + `.llmwiki/` scaffold.
- Phase 3 — CLAUDE.md minimal stub.
- Phase 4 — AGENTS.md seed (variant: `general` / `ml` / `web`).
- Phase 5 — README + CHANGELOG seed.
- Phase 6 — `git init` + `gh repo create`.
- Phase 7 — Summary + next actions (`/rules-forge:write-rules`, `/llm-wiki:bootstrap-wiki`, `/github-dev:post-merge`).
