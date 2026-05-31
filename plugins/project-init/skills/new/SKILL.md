---
name: new
description: Use when the user explicitly asks to bootstrap a brand-new project in the current empty directory (creates `.claude/`, `CLAUDE.md`, `AGENTS.md`, `README.md`, `CHANGELOG.md`, runs `git init`, calls `gh repo create`). NEVER trigger on phrases like "let's add a feature", "set up X", "initialize Y in this folder" when the folder is not empty. Hard requirement (enforced at runtime by the preflight guard below): `$PWD` must contain no existing `.git/`, `.claude/`, or source files before this skill takes any action. Triggers on explicit phrases such as "bootstrap a new project here", "start a brand-new repo in this empty dir", "/project-init:new", or equivalent.
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

The procedure file uses `${CLAUDE_PLUGIN_ROOT}` for all asset / script references (`scripts/idempotent-seed.sh`, `scripts/infer-github-context.sh`, `assets/AGENTS.review-guidelines.*.md`, `assets/README.minimal.md`, `assets/CHANGELOG.initial.md`).

Under **Claude Code** `${CLAUDE_PLUGIN_ROOT}` is set automatically.

Under **Codex 0.135** that env var is not currently exposed. The procedure file's Phase 0 opens with a portable resolver that derives `PLUGIN_ROOT` from `${CLAUDE_PLUGIN_ROOT:-}` first and falls back to a Codex-side lookup (`~/.codex/plugins/cache/<marketplace>/project-init/<version>/`); all subsequent bash blocks reference `${PLUGIN_ROOT}` rather than `${CLAUDE_PLUGIN_ROOT}` directly. If neither lookup succeeds the procedure aborts with an explicit message asking the user to export `PLUGIN_ROOT` manually.

## Why this skill exists alongside the command

The `/project-init:new` command remains the primary explicit-invocation surface. This skill ships so Codex (and Claude Code in capability-discovery mode) can recognize the bootstrap workflow by description. The preflight guard is duplicated at both surfaces because the description-based safety relies on the model interpreting the trigger correctly — the runtime guard is what actually prevents damage.
