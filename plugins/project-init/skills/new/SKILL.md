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

If the guard passes, proceed to the run record, then the full procedure.

## Step 0.5 — Run record (state-envelope v0)

Once the guard passes, open a per-run record so a bootstrap interrupted midway (Phase 1 interview cancelled, `gh repo create` failed) leaves a machine-readable trail of which phases already ran. Convention + schema: `.claude/rules/state-envelope.md` (concept mirror in this repo's `AGENTS.md`). No shared library — this per-skill `jq` is the whole mechanism, and the record lives under `.claude/state/`, so it stays machine-local and is **never** added to the Phase 6 commit.

Because the Step 0 guard aborts on any non-empty cwd, a *normal* re-run never reaches this point — so a pre-existing record means the guard was deliberately bypassed to recover a partial seed. Handle both: a fresh init, or a **resume** that reads `steps[]`, skips the phases already recorded `done`, and keeps appending to the same record.

```bash
SLUG=$(basename "$(pwd)" | tr -c 'A-Za-z0-9._-' '-' | sed 's/-\{2,\}/-/g; s/^-//; s/-$//')
[ -n "$SLUG" ] || SLUG="project"
REC=".claude/state/project-init-${SLUG}.json"
mkdir -p .claude/state/archive
if [ -f "$REC" ] && [ "$(jq -r '.status' "$REC" 2>/dev/null)" = "in_progress" ]; then
  echo "[resume] prior interrupted bootstrap — phases already done (skip these, do not redo):"
  jq -r '.steps[] | "  phase \(.step): \(.status)" + (if .reason then " ("+.reason+")" else "" end)' "$REC"
else
  # fresh run: archive any completed prior record (fail closed), then init a new one
  if [ -f "$REC" ]; then
    mv "$REC" ".claude/state/archive/project-init-${SLUG}-$(date +%Y%m%d-%H%M%S)-$$.json" \
      || { echo "state-envelope: archive rotation failed for $REC — aborting so the next write cannot clobber it" >&2; exit 1; }
  fi
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  jq -n --arg rid "project-init-${SLUG}" --arg now "$NOW" \
    '{schema:"state-envelope/v0", run_id:$rid, status:"in_progress", conclusion:null,
      started_at:$now, updated_at:$now, anchor_sha:null, attempt:1,
      session_id:(env.CLAUDE_SESSION_ID // null), steps:[]}' > "$REC"
fi

# record_step <phase-n> <done|skipped> [reason] — append one entry, bump updated_at.
record_step() {
  if [ "$2" = "skipped" ] && [ -z "${3:-}" ]; then
    echo "state-envelope: a skipped phase needs a reason" >&2; return 1
  fi
  tmp=$(mktemp)
  jq --argjson step "$1" --arg status "$2" --arg reason "${3:-}" \
     --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     '.updated_at = $now
      | .steps += [ {step: $step, status: $status}
                    + (if $reason == "" then {} else {reason: $reason} end) ]' \
     "$REC" > "$tmp" && mv "$tmp" "$REC"
}
```

**Recording contract.** The `step` integer is the phase number. As each Phase 0-7 closes, append its outcome — `record_step <n> done`, or `record_step <n> skipped "<reason>"` when a phase is legitimately skipped (Phase 5 with no license chosen, Phase 6 when the user declines a remote). **Shell state does not persist across separate tool calls** — `REC` is the deterministic path `.claude/state/project-init-<slug>.json`, so in a later phase's bash block re-derive `SLUG`/`REC` and re-declare `record_step` before calling it. After Phase 7 closes, finalize the envelope and keep the record out of the commit:

```bash
tmp=$(mktemp)
jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '.status = "completed" | .conclusion = "success" | .updated_at = $now' \
  "$REC" > "$tmp" && mv "$tmp" "$REC"
```

Under Hermes run these blocks via `terminal`. Note: this record is orthogonal to `.claude/state/spec.json` (owned by `spec-state`) — different file, different concern.

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

As each phase closes, `record_step <phase-n> done` (or `skipped "<reason>"`) per the Step 0.5 recording contract; finalize the record after Phase 7.

The procedure file uses `${PLUGIN_ROOT}` for all asset / script references (`scripts/idempotent-seed.sh`, `scripts/infer-github-context.sh`, `assets/AGENTS.review-guidelines.*.md`, `assets/README.minimal.md`, `assets/CHANGELOG.initial.md`). `PLUGIN_ROOT` is resolved at the top of Phase 0 by a portable shell block:

1. Honors a caller-supplied `PLUGIN_ROOT` (escape hatch for unusual layouts).
2. Falls back to `${CLAUDE_PLUGIN_ROOT:-}` — the Claude Code path.
3. Falls back to `${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}/<marketplace>/project-init/<version>/`, picking the highest version available — the Codex 0.135 path.
4. Aborts with an explicit message asking the user to export `PLUGIN_ROOT` manually if none of the above resolves to a directory containing readable `scripts/` and `assets/` subdirectories.

All subsequent bash blocks in `references/new-procedure.md` reference `${PLUGIN_ROOT}` rather than `${CLAUDE_PLUGIN_ROOT}` directly, so the same procedure body runs unchanged under both runtimes.

## Why this skill exists alongside the command

The `/project-init:new` command remains the primary explicit-invocation surface. This skill ships so Codex (and Claude Code in capability-discovery mode) can recognize the bootstrap workflow by description. The preflight guard is duplicated at both surfaces because the description-based safety relies on the model interpreting the trigger correctly — the runtime guard is what actually prevents damage.
