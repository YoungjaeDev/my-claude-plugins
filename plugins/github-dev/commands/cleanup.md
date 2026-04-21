---
description: Archive or delete stale files across OMC state, build artifacts, logs, old docs, and user-specified paths
argument-hint: "[--dry-run] [--paths p1,p2,...] [--skip-omc] [--skip-build] [--skip-spec] [--skip-docs] [--stale-days N]"
---

# Repo Cleanup

Scan the repository for stale temp files, build artifacts, logs, old date-based documents, and user-specified paths. Propose archive or deletion per category with explicit user approval before any destructive action. Follow project guidelines in `@CLAUDE.md`.

**Guiding principle — Content-First, File-Last**: For rules, memory, and markdown docs, refine content in-place first, consolidate duplicates next, and only delete files as a last resort when they become empty or orphaned. This command applies that principle by defaulting `docs/` and `research/` sweeps to "skip" and requiring explicit user consent before removing documents.

## Arguments

| Flag | Description |
|------|-------------|
| `--dry-run` | Detect and classify only. No `mv`/`rm` performed. |
| `--paths p1,p2,...` | Add comma-separated glob paths to Category E. |
| `--skip-omc` | Skip Category A (`.omc/` sweep). |
| `--skip-build` | Skip Category B (build artifacts + logs). |
| `--skip-spec` | Skip Category C (date-based stale docs). |
| `--skip-docs` | Skip Category D (`docs/`, `research/` directory audit). |
| `--stale-days N` | Override 90-day threshold for Categories C and D. |

## Workflow

### Phase 1 -- Preflight

1. **Detect project root** — command runs from repo root; capture via `git rev-parse --show-toplevel` (fall back to `pwd` if not a git repo).
2. **Resolve stale threshold** — default 90 days, override with `--stale-days N`.
3. **Resolve archive root** — `.omc/_archive/<YYYY-MM-DD>/` where the date is today (UTC date from `date -u +%Y-%m-%d`). Create on first use. Same-day re-runs append to the same date directory; existing files in the target are never overwritten (use rename-with-suffix if collision).
4. **Detect active session** (used by Category A):
   - If `CLAUDE_SESSION_ID` env var is set, treat that UUID as active.
   - Otherwise, any subdirectory under `.omc/state/sessions/` with `mtime` within the last 24 hours is treated as active.
   - If neither heuristic yields a result, set a flag `active_unknown=true` and protect ALL `.omc/sessions/*.json` and `.omc/state/sessions/<*>/` from deletion. Report the fallback to the user.

### Phase 2 -- Detection (per category)

Skip categories based on `--skip-*` flags or missing source directories. For each candidate, record relative path, size (`du -sh`), mtime age in days, and proposed default action.

#### Category A — OMC state (skip if `.omc/` missing or `--skip-omc`)

| Subpath | Default | Notes |
|---------|---------|-------|
| `.omc/plans/*` | archive | Historical design docs. Archive to `_archive/<date>/A/plans/`. |
| `.omc/research/*` | archive | Historical research dumps. |
| `.omc/handoffs/*` | delete | Team-mode ephemeral state. |
| `.omc/state/checkpoints/*` | delete | Workflow checkpoint cache. |
| `.omc/sessions/*.json` | delete | Session pointer files. **Exclude** UUIDs flagged active. Skip entire set if `active_unknown=true`. |
| `.omc/state/sessions/<uuid>/` | delete | Per-session state dirs. **Exclude** active UUID. Skip entire set if `active_unknown=true`. |
| `.omc/state/project-tracking-*.json` | conditional | Archive if ALL issues have `"state": "closed"` in the JSON. Otherwise protect. |

**Always protect** (never propose): `.omc/project-memory.json`, `.omc/prd.json`, `.omc/progress.txt`, `.omc/state/mission-state.json`, `.omc/state/hud-stdin-cache.json`, `.omc/state/subagent-tracking.json`, `.omc/state/workflow-progress.json`, `.omc/state/agent-replay-*.jsonl`, `.omc/state/team/**`, and `.omc/_archive/**`.

#### Category B — Build artifacts & logs (skip if `--skip-build`)

1. Check `.gitignore` at repo root for each candidate path. Only include paths listed in gitignore.
2. Candidates:
   - `dist/`, `build/` (top-level directories)
   - `*.log`, `**/*.log` (any log files, excluding `.omc/_archive/`)
3. Default: delete.
4. **Never** touch `node_modules/`, `__pycache__/`, `.venv/`, `.pytest_cache/`, `.ruff_cache/`, `.mypy_cache/` — out of scope by design. Users who want these cleaned must pass via `--paths`.

#### Category C — Date-based stale documents (skip if `--skip-spec`)

1. Scan `.claude/spec/` for files matching `^\d{4}-\d{2}-\d{2}-.*\.md$`.
2. Filter to files where (today - parsed filename date) > stale-days.
3. Additionally cross-check `mtime` — if mtime is newer than threshold, exclude (file is being actively revised).
4. Default: archive to `_archive/<date>/C/spec/`.

#### Category D — Project doc directories (skip if `--skip-docs`)

1. Scan top-level of `docs/` and `research/` (if they exist) for files matching `^\d{4}-\d{2}-\d{2}-.*` (any extension).
2. Filter by mtime > stale-days AND no references from other files (`rg -l "<basename>" --glob '!.omc' --glob '!.git'` returns empty).
3. Default: **skip** (per Content-First principle, user must opt-in explicitly).

#### Category E — User-specified paths

1. If `--paths` passed, expand each comma-separated glob.
2. If no flag and running interactively, ask via `AskUserQuestion` whether the user wants to add custom paths (skippable).
3. Default: user decides per-path.

### Phase 3 -- Prompt

Use `AskUserQuestion` (one question per non-empty category) with `multiSelect: true` options:

- Label format: `"<action>: <count> items (<size>)"` — e.g., `"archive: 5 items (124 KB)"`.
- Options: `archive to _archive/<date>/`, `delete permanently`, `skip this category`.
- Description field: list top-5 paths as preview so the user sees what's at stake.

If `--dry-run` is set, skip the prompt — just output the classification report and exit.

### Phase 4 -- Execute

Per user-approved action:

- **archive**: `mkdir -p .omc/_archive/<date>/<category>/<original-parent-dir>/` then `mv <source> <target>`. On name collision, append `.1`, `.2`, … suffix.
- **delete**: `rm -rf <source>` (Category A/B) or `rm <source>` (Category C/D/E individual files).
- **skip**: no action, keep in report for summary.

Failure handling:

- Permission denied: report the failed path, continue with other paths in the same category, do NOT abort the whole run.
- `mv` across filesystems: fall back to `cp -r && rm -rf`.
- Any single category failure does not block later categories.

### Phase 5 -- Report

Output to stdout:

```
Cleanup complete (mode: dry-run | apply)

Category A -- OMC state
  archived: N items, X MB -> .omc/_archive/<date>/A/
  deleted:  N items, X MB
  skipped:  N items
  protected: <list>

Category B -- Build artifacts & logs
  ...

Category C -- Date-based stale docs
  ...

Category D -- Project doc directories
  ...

Category E -- User-specified paths
  ...

Total freed: X MB
Archive root: .omc/_archive/<date>/
```

If `active_unknown=true`, prepend a warning:

```
WARNING: active session UUID could not be determined.
All .omc/sessions/ and .omc/state/sessions/ entries were protected.
Set CLAUDE_SESSION_ID or run cleanup again after session timeout.
```

## Non-Goals

- **Python/Node cache removal** — out of scope. Reinstall cost is high and may break current builds. Use `--paths __pycache__,node_modules` only when the user explicitly asks.
- **Coded deprecation sweep** (`@deprecated`, `# DEPRECATED` comments) — subjective, belongs to code review.
- **Auto-scheduled execution** — manual invocation only.
- **Cross-repo cleanup** — single repository scope.
- **Archive retention / expiration** — `_archive/<date>/` directories are kept indefinitely; manual cleanup is the user's responsibility.
- **Serena memory / CLAUDE.md automated dedup** — handled by `/github-dev:post-merge` Step 6/7 content-first guidance and existing Content Removal rules.

## Notes

- `.omc/_archive/` is gitignored through the existing `.omc/` rule, so archiving leaves the working tree untracked.
- The command does not mutate git state (no branch switching, no commits). After archiving, users typically run `/github-dev:commit-and-push` if any tracked files were touched (should be rare — Category B only touches gitignored paths).
- For worktree users: run this from the original repo, not inside a linked worktree. The archive root is repo-local and will otherwise create per-worktree archive trees.

> See [Work Guidelines](../guidelines/work-guidelines.md)
