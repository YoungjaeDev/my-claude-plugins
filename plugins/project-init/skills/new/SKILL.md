---
name: new
description: Use when the user explicitly asks to bootstrap a brand-new project in the current empty directory (creates `.claude/`, `CLAUDE.md`, `AGENTS.md`, `README.md`, `CHANGELOG.md`, runs `git init`, calls `gh repo create`). NEVER trigger on phrases like "let's add a feature", "set up X", "initialize Y in this folder" when the folder is not empty. Hard requirement (enforced at runtime by the preflight guard below): `$PWD` must contain no existing `.git/`, `.claude/`, or source files before this skill takes any action. Triggers on explicit phrases such as "bootstrap a new project here", "start a brand-new repo in this empty dir", "/project-init:new", or equivalent.
---

# project-init `new` skill

Day-1 bootstrap for an empty project directory. Same orchestration as the `/project-init:new` command — both surfaces gate on the preflight guard before ANY destructive op.

## Step 0 — Preflight hard guard (NON-NEGOTIABLE)

Run this **before any other body content**. It refuses to run in a non-empty directory. The model MUST NOT skip this block, MUST NOT rewrite it to a softer check, and MUST surface the abort message verbatim if the guard fires.

```bash
# Hard guard — refuses to run if directory is not fresh
if [ -d .git ] || [ -d .claude ] || [ -n "$(find . -maxdepth 2 -type f \
    \( -name '*.py' -o -name '*.ts' -o -name '*.js' -o -name '*.go' \
    -o -name '*.rs' -o -name '*.java' -o -name 'package.json' \
    -o -name 'pyproject.toml' -o -name 'Cargo.toml' -o -name 'go.mod' \) \
    2>/dev/null)" ]; then
  echo "[abort] project-init refuses to run in a non-empty directory."
  echo "        cwd: $(pwd)"
  echo "        Found existing .git/, .claude/, or source files."
  echo "        If you really want to add Claude/Codex scaffolding to an existing"
  echo "        project, use /rules-forge:write-rules or /llm-wiki:bootstrap-wiki"
  echo "        instead."
  exit 1
fi
```

> **Windows / non-POSIX hosts**: the guard above is POSIX shell. On Codex CLI / Claude Code where the default shell is PowerShell, wrap it: `bash -c '<guard>'` (Git Bash, WSL, or any POSIX shell on PATH). The intent — refuse to proceed if `.git/`, `.claude/`, or source files exist in cwd — must be honored regardless of how the check is invoked.

If the guard passes, proceed to the full procedure.

## Step 1 — Procedure

Follow the full Phase 0–7 procedure in `${CLAUDE_PLUGIN_ROOT}/references/new-procedure.md`:

- Phase 0 — Preflight (gh auth, identity, owner candidates).
- Phase 1 — Project identity interview (name / owner / visibility / license).
- Phase 2 — `.claude/` scaffold (structure only, via `scripts/idempotent-seed.sh`).
- Phase 3 — CLAUDE.md minimal stub.
- Phase 4 — AGENTS.md seed (variant: `general` / `ml` / `web`).
- Phase 5 — README + CHANGELOG seed.
- Phase 6 — `git init` + `gh repo create`.
- Phase 7 — Summary + next actions.

The procedure file uses `${CLAUDE_PLUGIN_ROOT}` for all asset / script references (`scripts/idempotent-seed.sh`, `scripts/infer-github-context.sh`, `assets/AGENTS.review-guidelines.*.md`, `assets/README.minimal.md`, `assets/CHANGELOG.initial.md`) — they continue to work unchanged.

## Why this skill exists alongside the command

The `/project-init:new` command remains the primary explicit-invocation surface. This skill ships so Codex (and Claude Code in capability-discovery mode) can recognize the bootstrap workflow by description. The preflight guard is duplicated at both surfaces because the description-based safety relies on the model interpreting the trigger correctly — the runtime guard is what actually prevents damage.
