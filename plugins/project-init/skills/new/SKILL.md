---
name: new
description: Use when the user explicitly asks to bootstrap a brand-new project in the current empty directory (creates `.claude/`, `CLAUDE.md`, `AGENTS.md`, `README.md`, `CHANGELOG.md`, runs `git init`, calls `gh repo create`). NEVER trigger on phrases like "let's add a feature", "set up X", "initialize Y in this folder" when the folder is not empty. Hard runtime requirement enforced by the preflight guard at the top of this skill — the working directory must contain no existing `.git/`, `.claude/`, or source files before this skill takes any action. Triggers on explicit phrases such as "bootstrap a new project here", "start a brand-new repo in this empty dir", an explicit slash invocation of /project-init/new, or equivalent.
---

# project-init `new` skill

Day-1 bootstrap for an empty project directory. Same orchestration as the `/project-init:new` command — both surfaces gate on the preflight guard before ANY destructive op.

## Step 0 — Preflight hard guard (NON-NEGOTIABLE)

Run this **before any other body content**. It refuses to run in a non-empty directory. The model MUST NOT skip this block, MUST NOT rewrite it to a softer check, and MUST surface the abort message verbatim if the guard fires.

```bash
# Hard guard — refuses to run if cwd contains ANYTHING beyond ignorable OS junk.
# Walks up to 5 levels deep so deeper sources (e.g. src/app/main.py) and any
# top-level file (Dockerfile, Makefile, .env, docs/*) trigger the abort. Only
# .git/ and OS metadata (.DS_Store, Thumbs.db, desktop.ini) are pruned.
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

> **Windows / non-POSIX hosts**: the guard above is POSIX shell. On Codex CLI / Claude Code where the default shell is PowerShell, wrap it: `bash -c '<guard>'` (Git Bash, WSL, or any POSIX shell on PATH). The intent — refuse to proceed if cwd has any content beyond `.git/` and OS metadata — must be honored regardless of how the check is invoked.

If the guard passes, proceed to the full procedure.

## Step 1 — Procedure

Follow the full Phase 0–7 procedure in `references/new-procedure.md` (relative to this plugin's installed root — `${CLAUDE_PLUGIN_ROOT}/references/new-procedure.md` under Claude Code; the same relative path under the Codex plugin cache):

- Phase 0 — Preflight (gh auth, identity, owner candidates).
- Phase 1 — Project identity interview (name / owner / visibility / license).
- Phase 2 — `.claude/` scaffold (structure only, via `scripts/idempotent-seed.sh`).
- Phase 3 — CLAUDE.md minimal stub.
- Phase 4 — AGENTS.md seed (variant: `general` / `ml` / `web`).
- Phase 5 — README + CHANGELOG seed.
- Phase 6 — `git init` + `gh repo create`.
- Phase 7 — Summary + next actions.

The procedure file uses `${PLUGIN_ROOT}` for all asset / script references (`scripts/idempotent-seed.sh`, `scripts/infer-github-context.sh`, `assets/AGENTS.review-guidelines.*.md`, `assets/README.minimal.md`, `assets/CHANGELOG.initial.md`). `PLUGIN_ROOT` is resolved at the top of Phase 0 by a portable shell block:

1. Honors a caller-supplied `PLUGIN_ROOT` (escape hatch for unusual layouts).
2. Falls back to `${CLAUDE_PLUGIN_ROOT:-}` — the Claude Code path.
3. Falls back to `${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}/<marketplace>/project-init/<version>/`, picking the highest version available — the Codex 0.135 path.
4. Aborts with an explicit message asking the user to export `PLUGIN_ROOT` manually if none of the above resolves to a directory containing readable `scripts/` and `assets/` subdirectories.

All subsequent bash blocks in `references/new-procedure.md` reference `${PLUGIN_ROOT}` rather than `${CLAUDE_PLUGIN_ROOT}` directly, so the same procedure body runs unchanged under both runtimes.

## Why this skill exists alongside the command

The `/project-init:new` command remains the primary explicit-invocation surface. This skill ships so Codex (and Claude Code in capability-discovery mode) can recognize the bootstrap workflow by description. The preflight guard is duplicated at both surfaces because the description-based safety relies on the model interpreting the trigger correctly — the runtime guard is what actually prevents damage.
