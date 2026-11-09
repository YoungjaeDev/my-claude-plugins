---
name: new
description: Use when the user explicitly asks to bootstrap a brand-new project in the current empty directory (creates `.claude/`, `CLAUDE.md`, `AGENTS.md`, `README.md`, `CHANGELOG.md`, runs `git init`, calls `gh repo create`). NEVER trigger on phrases like "let's add a feature", "set up X", "initialize Y in this folder" when the folder is not empty. Hard runtime requirement enforced by the preflight guard at the top of this skill — the working directory must contain no existing `.git/`, `.claude/`, or source files before this skill takes any action, unless it holds only what an interrupted run of this skill left behind with its in_progress run record. Triggers on explicit phrases such as "bootstrap a new project here", "start a brand-new repo in this empty dir", an explicit slash invocation of /dev:new, or equivalent.
---

# dev `new` skill

Day-1 bootstrap for an empty project directory. Same orchestration as the `/dev:new` command — both surfaces gate on the preflight guard before ANY destructive op.

## Step 0 — Preflight hard guard (NON-NEGOTIABLE)

Run this **before any other body content**. It refuses to run in a non-empty directory. The model MUST NOT skip this block, MUST NOT rewrite it to a softer check, and MUST surface the abort message verbatim if the guard fires.

```bash
# Hard guard — refuses to run if cwd contains ANYTHING beyond ignorable OS junk.
# Walks up to 5 levels deep so deeper sources (e.g. src/app/main.py) and any
# top-level file (Dockerfile, Makefile, .env, docs/*) trigger the abort. Only
# .git/ and OS metadata (.DS_Store, Thumbs.db, desktop.ini) are pruned.
# Recovery entry: an in_progress record shaped exactly as Phase 0.5 writes it
# (same slug, schema, run_id, step 0 first) also lets through what Phases
# 0.5-6 seed, and nothing else. Without jq the record cannot be verified: abort.
SLUG=$(basename "$(pwd)" | tr -c 'A-Za-z0-9._-' '-' | sed 's/-\{2,\}/-/g; s/^-//; s/-$//')
[ -n "$SLUG" ] || SLUG="project"
REC=".claude/state/project-init-${SLUG}.json"
RECOVERY=no ALLOW='^$'
if [ -f "$REC" ] && command -v jq >/dev/null 2>&1 \
   && jq -e --arg rid "project-init-${SLUG}" \
     '.schema == "state-envelope/v0" and .run_id == $rid and .status == "in_progress"
      and .conclusion == null and (.steps | type) == "array"
      and .steps[0] == {step: 0, status: "done"}' "$REC" >/dev/null 2>&1; then
  RECOVERY=yes
  ALLOW='^\./(\.claude(/state(/.*)?|/(spec|rules)(/\.gitkeep)?)?|\.llmwiki(/(raw|wiki)(/\.gitkeep)?)?|CLAUDE\.md|AGENTS\.md|README\.md|CHANGELOG\.md|\.gitignore)$'
fi
FIRST_EXISTING=$(find . -mindepth 1 -maxdepth 5 \
  \( -name '.git' -o -path './.git/*' \
   -o -name '.DS_Store' -o -name 'Thumbs.db' \
   -o -name 'desktop.ini' \) -prune \
  -o -print 2>/dev/null | grep -Ev "$ALLOW" | head -1)

if { [ -d .git ] && [ "$RECOVERY" = no ]; } || [ -n "$FIRST_EXISTING" ]; then
  echo "[abort] dev:new refuses to run in a non-empty directory."
  echo "        cwd: $(pwd)"
  echo "        Existing entry detected: ${FIRST_EXISTING:-.git/}"
  echo "        If you really want to add Claude/Codex scaffolding to an existing"
  echo "        project, use /docs:write-rules or /dev:wiring"
  echo "        instead."
  exit 1
fi
if [ "$RECOVERY" = yes ]; then
  echo "[recovery] resuming the interrupted bootstrap recorded in $REC"
fi
```

> **Windows / non-POSIX hosts**: the guard above is POSIX shell. On Codex CLI / Claude Code where the default shell is PowerShell, wrap it: `bash -c '<guard>'` (Git Bash, WSL, or any POSIX shell on PATH). The intent (refuse to proceed if cwd has any content beyond `.git/` and OS metadata, except a verified recovery run) must be honored regardless of how the check is invoked.

If the guard passes, proceed to the full procedure. Its Phase 0.5 opens the run record (`state-envelope/v0` under gitignored `.claude/state/`); do not re-inline that `jq` here. The guard only reads that record: when it printed `[recovery]`, Phase 0.5 resumes the record instead of starting fresh.

## Step 1 — Procedure

Follow the full Phase 0–7 procedure in `references/new-procedure.md`, relative to this plugin's installed root (`${CLAUDE_PLUGIN_ROOT}` on Claude Code, the same relative path under the Codex plugin cache):

- Phase 0 — Preflight (gh auth, identity, owner candidates).
- Phase 1 — Project identity interview (name / owner / visibility / license).
- Phase 2 — `.claude/` scaffold (structure only, via `scripts/idempotent-seed.sh`).
- Phase 3 — CLAUDE.md minimal stub.
- Phase 4 — AGENTS.md seed (variant: `general` / `ml` / `web`).
- Phase 5 — README + CHANGELOG seed.
- Phase 6 — `git init` + `gh repo create`.
- Phase 7 — Summary + next actions.

Each phase closes with its own `record_step`, so recording is not a separate step here. Phase 0 resolves `PLUGIN_ROOT` (a caller-supplied value, then `${CLAUDE_PLUGIN_ROOT:-}`, then the highest Codex cache version) and aborts when none holds `scripts/` and `assets/`. Every later block uses `${PLUGIN_ROOT}`, so the procedure runs unchanged on both runtimes.

The skill is the only surface; the narrow description keeps it from firing on a non-empty folder, and the Step 0 guard is what actually prevents damage when a trigger is misread.
