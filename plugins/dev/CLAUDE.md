# GitHub Dev Plugin

GitHub workflow automation skills for Claude Code. All workflows are skills (no command surface), so `/dev:<name>` slash calls resolve to the skill and run under both Claude Code and Codex.

## Skills

| Skill | Description |
|---------|-------------|
| `/dev:commit-and-push` | Analyze changes, commit with conventional message, push |
| `/dev:decompose-issue` | Break down large issues into sub-tasks, define architecture mapping |
| `/dev:post-merge` | Clean up branch, integrate PR learnings, sync milestone progress |
| `/dev:resolve-issue` | Resolve GitHub issue end-to-end (enhanced with review, verification) |
| `/dev:cr-fix` | Unified CodeRabbit + ChatGPT-Codex pipeline (multi-file skill at `skills/cr-fix/`): wait + fetch + apply + push loop until clean, with optional auto-merge (default OFF; pass `--auto-merge` to enroll). Gates merge on branch-protection presence and on actual CR engagement. Step 9 v2 judges each finding autonomously: the LLM validates it against local code, reassesses severity and fix size, then applies/defers/skips per the decision matrix — no per-finding AskUserQuestion gate. CR Nitpicks and Codex P3 are silently skipped. Codex is auto-detected per PR (engaged at least once → ON; never engaged → OFF). `--skip-minor` opt-in demotes CR Minor severity (excluding Bug/Security) + Codex P2 to skip. `--cr-source <auto\|pr-bot\|cli\|codex-only>` controls review source; `auto` falls back to the local `coderabbit` CLI or Codex-only when the PR-bot is rate-limited (early-escape ~30s, no more 1800s spin). Minor soft-stop (default ON, `--no-minor-stop` off): from iter 2 a cycle that applied only low-severity fixes with nothing deferred stops at `final_state=minor_floor` (not auto-merge eligible) instead of looping the low-value tail. Bounded same-file generalization (default ON, `--no-generalize` off): a real + high-confidence + grep-able finding also patches sibling occurrences of the same pattern within the same file (audit-logged, never cross-file). 2.8.0 correctness repairs: `cr-commit-state.sh` fetch failures (auth/network/rate-limit) now map to a distinct `state:"error"` channel instead of a clean `none`; `fetch-cr-threads.sh` fails loudly on a null-repository GraphQL response rather than converging false-clean on `[]`; an active `query-cr-rate-limit.sh` (`@coderabbitai rate limit`, id-anchored to its own post) resolves ambiguous passive rate-limit sniffs; check-run `created_at` prefers `completed_at`; `auto-merge-gate.sh` reads CR state through the same dual-surface reader as the rest of the loop, so `--auto-merge` works on check-run-only repos (not just commit-status repos). Fixture suite (`tests/run-tests.sh`) runs in `.githooks/pre-commit` + `validate-codex.yml`. |
| `/dev:release` | Create versioned GitHub release with auto-generated changelog |
| `/dev:state-tracker` | spec/issue/PR work-pipeline aggregate over `.claude/state/spec.json` (absorbed from `spec-state`) |

## resolve-issue Flags

| Flag | Description |
|------|-------------|
| `--skip-review` | Skip 2-stage review (for trusted changes) |
| `--strict` | Treat lint failures as blocking errors |
| `--skip-cr-fix` | Skip the auto cr-fix loop after PR creation (default ON) |
| `--cr-fix-max <n>` | Cap iterations on the auto cr-fix loop (default: 5) |
| `--auto-merge` | Pass through to cr-fix; auto-merge after convergence (default OFF) |
| `--codex-grace <sec>` | Pass through to cr-fix; Codex grace window after CR completes (default: 90) |
| `--no-codex` | Pass through to cr-fix; force-disable Codex auto-detect for the run |
| `--skip-minor` | Pass through to cr-fix; demote CR Minor (excluding Bug/Security) + Codex P2 to skip |
| `--no-minor-stop` | Pass through to cr-fix; disable the minor soft-stop (default ON — stop from iter 2 on a low-severity-only cycle, `final_state=minor_floor`) |
| `--no-generalize` | Pass through to cr-fix; disable bounded same-file generalization (default ON — patch same-file siblings of a real + high-confidence + grep-able finding) |
| `--cr-source <mode>` | Pass through to cr-fix; review source: `auto` (default, fall back to CLI/codex-only on PR-bot rate-limit), `pr-bot`, `cli`, `codex-only` |

## Worktree Workflow (PR-based)

Use Claude Code's built-in worktree (`claude --worktree <name>`) for isolated PR work:

```bash
claude --worktree feature-auth
# inside the worktree
/dev:resolve-issue 42       # creates branch + PR + drives cr-fix
# after PR is merged on GitHub, exit and switch contexts:
/exit                              # cleanup option for the worktree
# in a fresh session at the main repo
/dev:post-merge <PR>        # cleanup + integrate learnings
```

**Note:** `post-merge` aborts when run from a worktree (Step 3 checks out the base branch, which conflicts with the original repo's checkout). Exit the worktree first.

## Project Progress Tracking

Tracks milestone progress with architecture diagrams synced to GitHub.

**State file**: `.claude/state/project-tracking-{slug}.json` -- created by `decompose-issue`, updated by `resolve-issue` and `post-merge`

**Diagram types**:
| Type | Format | Used In |
|------|--------|---------|
| Type M-1 | ASCII (workflow + task summary) | Terminal output |
| Milestone | Markdown table (status + dependencies) | Milestone description |
| Type M-2 | Mermaid (full workflow + issue context) | Individual issue/PR body |

**Output format by medium**:
| Output Medium | Format | Reason |
|---------------|--------|--------|
| GitHub Issue/PR body | Mermaid | GitHub markdown renderer supports it |
| Milestone description | Markdown Table | GitHub milestones don't render Mermaid |
| Terminal (session output) | ASCII diagram | Terminal can't render Mermaid |
| State file (storage) | Mermaid source | Raw data for generating Issue/PR diagrams |

**Architecture data**: `mermaidSource` (10-20 node workflow captured during decompose-issue) + `scopeNodes` (highlighted nodes for this milestone). Issues have `dependsOn` (execution order) and `architectureNode` (workflow position).

**Trigger points**:
| When | What happens |
|------|-------------|
| `decompose-issue` | Architecture interview, state file + initial diagram created |
| `resolve-issue` | Local state updated (issue marked in_progress) |
| `post-merge` | GitHub auto-sync (milestone desc + issue bodies updated) |
| (manual full sync) | Retired update-progress skill — mechanics live in `skills/post-merge/references/update-progress.md`; post-merge Step 5.5 is the automated path |

**Body markers**: `<!-- project-tracking-start -->` / `<!-- project-tracking-end -->` -- only the section between markers is replaced, preserving existing content.

**Diagram colors**: `scope=#ddf4ff` (light blue bg), `done=#2da44e` (green), `active=#1f6feb` (blue), `pending=#6e7781` (gray), `here` (thick active border)

## Requirements

- `gh` CLI installed and authenticated
- GitHub repository with proper permissions

## gh / jq Invariants

All commands in this plugin shell out to `gh` and `jq`. Five pitfalls that silently break new bash blocks:

- A `gh api` REST path in a skill body must use gh's literal `{owner}/{repo}` placeholder (auto-resolved from the current repo) — never `$OWNER/$REPO` shell vars unless that skill demonstrably sets them. A skill step that interpolates an unset `$OWNER`/`$REPO` calls `repos//pulls/...` and fails silently or returns nothing. Prefer `gh api "repos/{owner}/{repo}/pulls/<N>/files"` (or `gh pr view/diff <N>`, which carry no repo coordinates) over raw-var REST.
- `gh ... --jq <expr>` accepts a single filter string and does NOT forward jq CLI flags (`--arg`, `--argjson`). Variable injection requires the pipe form: `gh ... | jq --arg name "$value" '...'`. Trying `gh ... --jq --arg name "$v" '...'` fails with `accepts 1 arg(s), received 4`.
- REST endpoints (`/pulls/{pr}/reviews`, `/issues/{pr}/comments`, `/commits/{sha}/statuses`) default to `per_page=30` and return paginated results. On long-lived PRs or CI-heavy SHAs the first page can be all-old or all-newest-30 — use `gh api --paginate ... | jq -s 'add // []' | jq ...` to slurp every page into a single array before filtering.
- `/commits/{sha}/statuses` (plural) returns every individual status event; `/commits/{sha}/status` (singular) collapses to one latest entry per context. The singular endpoint hides early `pending` entries, so use plural when the earliest moment a SHA was observed matters.
- Commit `committer.date` is git metadata — cherry-picks, rebases, or stale-commit pushes make it arbitrarily older than the actual push. For "when did GitHub first see this SHA" use the earliest `/statuses` `created_at`; `committer.date` is acceptable only as a last-resort fallback when no statuses exist yet.

## Task Tool 2.1.16 Syntax

This plugin uses Claude Code built-in agents with Task Tool 2.1.16:

```
Task(
  subagent_type="Explore",
  prompt="..."
)
```

### Model Selection Guide

| Task Type | Agent | Model |
|-----------|-------|-------|
| Code search | `Explore` | auto |
| Implementation | `claude` | `sonnet` |
| Complex refactoring | `claude` | `opus` |
| Test writing | `claude` | `sonnet` |
| Validation | `claude` | `haiku` |

## state-tracker (흡수: spec-state)

Single-file aggregate cache for a repo's spec → issue → PR work pipeline. One `Read` on `.claude/state/spec.json` answers "what's currently in flight, and against which spec?" — no `find` over `.claude/spec/` plus per-file frontmatter parse.

### What it ships

| Component | Path | Purpose |
|-----------|------|---------|
| **state-tracker skill** | `skills/state-tracker/` | 4 ops on `.claude/state/spec.json`: read / init / start / complete |

No hooks. Pure on-demand skill. Safe to install globally — operations only run when invoked.

### SSOT relationship

| Source | Authority | When it wins |
|--------|-----------|--------------|
| `.claude/spec/*.md` frontmatter (`status:`) | **SSOT** | Always — the spec file is the truth |
| `.claude/state/spec.json` | **aggregate cache** | Faster lookup; if it conflicts with frontmatter, regenerate via `init` |

Cache is regeneratable any time. Direct JSON edits are allowed but rare — prefer the 4 ops.

### Schema (versioned JSON)

```json
{
  "schema": 1,
  "updated_at": "<ISO 8601>",
  "in_progress": [
    {
      "spec": ".claude/spec/<YYYY-MM-DD>-<slug>.md",
      "section": "<spec internal anchor, optional>",
      "linked": { "issue": <number or null>, "pr": <number or null> },
      "description": "<spec 'Goal' first line, or user-provided one-liner>"
    }
  ],
  "completed": [
    {
      "spec": ".claude/spec/<YYYY-MM-DD>-<slug>.md",
      "linked": { "issue": <number or null>, "pr": <number or null> },
      "description": "<same as above>",
      "completed_at": "<YYYY-MM-DD>",
      "merge_sha": "<short SHA, 7 chars>"
    }
  ]
}
```

### Relation to other plugins

- `dev:post-merge` auto-calls `complete <spec-path>` after a merge to update the cache.
- `wiki` is independent — wiki lore (`.llmwiki/wiki/log.md`) tracks knowledge events; `state-tracker` tracks the work pipeline.

### Wiring status

The write-side wiring is intentionally asymmetric:

- **`complete` is auto-wired** — `dev:post-merge` Step 5.7 fires `complete <spec-path>` after a merge.
- **`start` / `init` are NOT auto-wired** into `resolve-issue` / `decompose-issue`. They run manually, or as part of the `superpowers:writing-plans` chain.

Consequence: `.claude/state/spec.json` stays absent until the first `start` / `init` in a repo. This dormancy is **by design**, not a bug: the cache materializes only once a tracked spec begins, and `dev:post-merge` Step 5.7 only fires `complete` when `.claude/state/` already exists, so the auto-call never hits a missing file.

### Conditional behavior

Safe to install in any repo. Skill operations no-op gracefully when `.claude/state/spec.json` (and `.claude/spec/`) are absent — `read` prints empty state, `init` requires user confirmation.


## project-init (흡수: project-init)

Orchestrates a project's **agent-harness lifecycle**. The two directions are symmetric.

- `new` — Day-1 setup (`.claude/`, CLAUDE.md, AGENTS.md, README/CHANGELOG, gh repo create + push). **Empty directories only.**
- `wiring` — diagnoses the harness config of an already-existing repo. **The inverse of `new`.** Read-only detection, then edits only behind an `AskUserQuestion` gate.

### Surfaces

| Surface | Entry | Description |
|---------|-------|-------------|
| Skill | `/dev:new` | Explicit invocation and capability discovery on both runtimes (the separate `commands/new.md` was dropped in the 2.30.0 consolidation; a skill is the one surface Codex also reads). The description is scoped narrowly so only phrases like "bootstrap a new project in this empty dir" match. |
| Skill | `wiring` | Diagnoses an existing repo. No command surface — a `/dev:wiring` skill call is enough, and a command would not be emitted to Codex, only duplicating the body. |

`new` puts a **preflight hard guard** in the first block of the body — if `.git/`, `.claude/`, or a source file exists anywhere in cwd, abort. It does not rely on description-based matching alone; it enforces at runtime. `wiring` has no such guard (by definition it is only meaningful in a non-empty repo).

### Detection SSOT

`scripts/project_state.sh` is **solely** responsible for project-state detection. Pure read-only, emitting a single JSON blob.

- `wiring` consumes all 14 axes. Four of them look at not "does the file exist" but **"does the config actually take effect"** — `core.hooksPath` (must be turned on per clone), whether an `@import` has defeated the `paths:` scoping of `.claude/rules`, whether the same MCP server registered in two user-scope files causes one definition to be discarded wholesale, and whether Codex `AGENTS.md` fits within the `project_doc_max_bytes` budget.
- An axis that is a **decision** rather than a defect (`git remote`, `gws-sync`) is emitted as `ASK`. The answer is written to `answers` in `.claude/state/wiring.json` and the script carries it forward as-is — the skill never re-asks an already-answered item. Because values differ per machine (Drive folder ids, etc.), they stay in gitignored state, and `CLAUDE.md` keeps only a **one-line path pointer**. A warning that barks every run trains people to ignore it, and then a real `FAIL` gets buried with it.
- **An `ASK` must have a step that actually asks** (Step 3.5). If it is only stamped `(unanswered)` in the report with nowhere to ask, no answer is recorded and the next run repeats the same line verbatim — the class becomes decoration. A question closed without an answer leaves no key. An unrecorded `ASK` is not a recorded "no".
- Write a suppression condition in **one place only**. The `gws_sync` verdict is not decided by the answer alone — it also reads whether `.gws-sync.json` exists and whether the `gws` CLI is present, so the filesystem moves even after the answer is recorded. Writing the same condition three times across the verdict table, the prose, and the question step means it drifts three ways.
- **Orphan MCP registrations are not handled.** A server left behind by a deleted plugin needs usage history to judge, so it is the built-in `/doctor`'s territory. A **duplicate registration**, by contrast, is the intersection of two files' keys — and **drift** (`duplicates_drifted`) is a value comparison on that intersection — so both are pure computation. Do not pretend to catch what determinism cannot.
- `idempotent-seed.sh diagnose` wraps this script and picks out only the legacy output shape (`cwd`/`dir_name`/`git`/`seeded`/`code_signal`). It does not re-implement the detection logic.
- **The Step 0 hard guard of `new` is not absorbed here.** The guard has zero dependencies (pure `find`) and must run **before** the `PLUGIN_ROOT` resolver. Turning it into a script call would introduce a new failure mode where "the guard silently does not run if PLUGIN_ROOT resolution fails". A safety device is never moved behind a lazy-load.

`find` expresses "not found" as exit 1. Under `set -o pipefail`, `find ... | wc -l` kills the script on a legitimate empty result. Every `find` goes through the `find_or_empty` / `count_files` helpers, and `code_signal` uses `-print -quit` to avoid a `head`-induced SIGPIPE false positive.

`jq` digs the same pit. If `jq` exits non-zero on a single corrupted user config file, that failure rides up through command substitution and `set -e` kills the script — instead of failing to judge one axis, the whole diagnostic vanishes and the user sees no output at all. Confine one axis's failure to that axis (like `mcp.unreadable`) and keep emitting the rest of the diagnostic. And **never report "did not see it" as "no problem".**

When reading an external tool's value to pass to `jq --argjson`, do not trust the source format. TOML allows an inline comment after a value and a `_` separator in integers, so `65536 # bytes` scraped by `sed` is a valid config yet invalid JSON. Normalize numbers and confirm they are all digits; otherwise fall back to the documented default.

The Codex config location is `${CODEX_HOME:-$HOME/.codex}` (`codex --help`). Hardcoding `$HOME/.codex` reports `config: false` on a machine that uses `CODEX_HOME`, wiping out the approval/sandbox posture and doc-budget verdicts wholesale.

### Principles

- **Preflight hard guard is non-negotiable**: the guard is embedded in Step 0 of `skills/new/SKILL.md`. The premise is that a description alone cannot block a wrong trigger — even if the model misreads the description, runtime blocks it. Removing the guard must be an explicit (high-friction, deliberate) user decision.
- **wiring does not diagnose another owner's territory**: wiki-page health is owned by `/wiki:lint-wiki`, and mem0 store/config posture by `/wiki:fleet-scan`. wiring looks only at filesystem signals — "does a wiki exist / is the layout right / has mid-drain capture piled up". Overlap means the day comes when two diagnostics give different answers.
- **Name the owning skill for each defect**: a verdict with no next action is noise. wiring directly fixes only mechanical, reversible edits (a `.gitignore` line, creating `.tmp/`, `core.hooksPath`, serena `project_name`); anything needing judgment (`.staging` curation, wiki bootstrap/migrate, CLAUDE.md authoring, spec migration, Serena onboarding, mem0 changes) is delegated.
- **Minimal seeding, explicit follow-ups**: seed only what Day 1 needs. Tech-stack-based rule generation and the wiki-domain interview are **not invoked, only pointed to**. Generating generic content in an empty project imposes an overwrite cost on the user.
- **Owner gate is mandatory**: since the user has a personal + multiple-org context, never auto-decide the owner. Require an explicit choice via `AskUserQuestion`.
- **Codex GitHub reviewer surface**: the AGENTS.md `## Review guidelines` section is what the Codex GitHub cloud reviewer reads automatically. It must be **seeded at repo-creation time** to take effect from the first PR.
- **Idempotent re-runs**: on a second invocation in the same directory, preserve existing files + skip steps + print a notice. Never overwrite. (But since the hard guard aborts on the mere presence of `.git`/`.claude`, an idempotent re-run does not occur on the normal path — it only matters on the recovery path for a partial seed that bypassed the guard.)

### File layout

```text
plugins/dev/
├── .claude-plugin/plugin.json
├── skills/
│   ├── new/SKILL.md                    # bootstrap skill (preflight guard + pointer)
│   └── wiring/SKILL.md                # existing-repo diagnostic (read-only detection + gated edits)
├── references/
│   ├── new-procedure.md                # the body (Phase 0–7) — shared by both surfaces
│   ├── codex-review-discovery.md       # AGENTS.md vs /review CLI
│   └── gh-repo-create-flow.md          # owner inference + visibility decision
├── assets/                             # templates that go directly into the output
│   ├── AGENTS.review-guidelines.md     # general variant (base)
│   ├── AGENTS.review-guidelines.ml.md  # ML/data variant
│   ├── AGENTS.review-guidelines.web.md # web/full-stack variant
│   ├── README.minimal.md
│   └── CHANGELOG.initial.md
├── scripts/
│   ├── infer-github-context.sh         # gh api user + orgs
│   ├── idempotent-seed.sh              # conflict guard + .claude/ + .llmwiki/ seed (diagnose = wrapper)
│   └── project_state.sh                # detection SSOT — read-only 14-axis JSON
└── CLAUDE.md                           # this file
```

### Preflight guard contract

This POSIX shell block sits in Step 0 of `skills/new/SKILL.md`:

```bash
FIRST_EXISTING=$(find . -mindepth 1 -maxdepth 5 \
  \( -name '.git' -o -path './.git/*' \
   -o -name '.DS_Store' -o -name 'Thumbs.db' \
   -o -name 'desktop.ini' \) -prune \
  -o -print 2>/dev/null | head -1)

if [ -d .git ] || [ -n "$FIRST_EXISTING" ]; then
  echo "[abort] dev:new refuses to run in a non-empty directory."
  ...
  exit 1
fi
```

- **Rejection rule**: anything in cwd that is not `.git/`, `.DS_Store`, `Thumbs.db`, or `desktop.ini` causes abort. `Dockerfile`, `Makefile`, `.env`, `docs/`, `src/app/main.py` — all of those trigger.
- **Search depth**: 5 levels (`find -maxdepth 5`). Deep-nested source files do not slip past the guard.
- **Abort message**: surfaces cwd + the first offending entry + a redirect to `/docs:write-rules` or `/wiki:bootstrap-wiki` for the "scaffold an existing project" case.
- **Non-POSIX hosts**: PowerShell-default environments must invoke via `bash -c '<guard>'` (Git Bash / WSL / Cygwin). The intent of the check, not the literal shell, is what matters — equivalent PowerShell rewrites are acceptable as long as they refuse the same conditions.

When modifying it, update both files at once. Changing only one makes the surfaces diverge in behavior.

### Cross-runtime plugin root resolution

`references/new-procedure.md` Phase 0 opens with a `PLUGIN_ROOT` resolver:

```bash
PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$PLUGIN_ROOT" ]; then
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  if sort -V </dev/null >/dev/null 2>&1; then
    candidate=$(ls -1d "$cache_root"/*/dev/* 2>/dev/null \
      | awk -F/ '{print $NF "\t" $0}' | sort -V | tail -1 | cut -f2-)
  else
    candidate=$(ls -1d "$cache_root"/*/dev/* 2>/dev/null \
      | awk -F/ '{print $NF "\t" $0}' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1 | cut -f2-)
  fi
  [ -n "$candidate" ] && [ -d "$candidate" ] && PLUGIN_ROOT="$candidate"
fi
[ -n "$PLUGIN_ROOT" ] && [ -d "$PLUGIN_ROOT/scripts" ] || { echo "[abort] ..."; exit 1; }
```

- Under **Claude Code**, `${CLAUDE_PLUGIN_ROOT}` is set automatically and the resolver short-circuits on the first branch.
- Under **Codex 0.135**, no equivalent env var is currently exposed, so the resolver falls back to `~/.codex/plugins/cache/<marketplace>/dev/<version>/`. Users can override with `CODEX_PLUGIN_CACHE` or set `PLUGIN_ROOT` directly.
- **The sort key is the version basename, not the full path.** Sorting whole paths compares the marketplace directory name before it ever reaches the version, so `zeta/dev/0.4.0` beats `alpha/dev/0.10.0` — and `sort -V` does not save you, because it too starts at the first differing component. The `awk` prefix puts the version first and `cut -f2-` recovers the path. The `sort -V` probe stays for userlands that predate it (Apple's FreeBSD sort has had `-V` since 10.13, so this is rarer than it looks), and its fallback is a numeric dotted-field sort rather than plain `sort`, which would rank `0.6.1` above `0.10.0`. Same form as `plugins/dev/skills/cr-fix/SKILL.md`, whose `tests/run-tests.sh` case guards it.
- All subsequent bash blocks reference `${PLUGIN_ROOT}/scripts/...` and `${PLUGIN_ROOT}/assets/...`. Adding a new asset / script means updating only the procedure file — no per-surface duplication.

### Placeholder convention

The templates under `assets/` use only these placeholders (sed substitution):

| Placeholder | Meaning |
|-------------|------|
| `{{PROJECT_NAME}}` | project name (Phase 1 answer) |
| `{{ONE_LINER}}` | one-line description |
| `{{OWNER}}` | personal account or org name |
| `{{LICENSE}}` | MIT / Apache-2.0 / GPL-3.0 / None |
| `{{YEAR}}` | current year |

When introducing a new placeholder, update the sed lines in Phase 4/5 of `references/new-procedure.md` as well.

### AGENTS.md variant policy

The three files share the same skeleton:

1. `## Project context` — `{{PROJECT_NAME}}` + `{{ONE_LINER}}` (1-2 lines)
2. `## Build / Test / Lint` — placeholder TODO
3. `## Review guidelines` — **the section the Codex cloud reviewer reads**
   - `### Do not flag` (linter territory — handled by tooling)
   - `### P0 — Correctness / Security`
   - `### P1 — Performance / Maintainability`
   - `### Domain-specific` (differs per variant; general has only a TODO)

The variant difference is the `### Domain-specific` section plus 1-2 domain-specific items added to `### P0` / `### P1`; nothing else differs across variants.

### Out of Scope

- CI/CD workflow seed (`.github/workflows/`) — too much per-variant variety
- Pre-commit hook seed — same reason
- Boilerplate auto-download (cookiecutter, copier) — a separate `Skill("scout:research-orchestrator")` call
- Multi-language interview branching — a single mixed Korean/English version is maintained

### References

- Plugin versioning rules: `.claude/rules/plugin-versioning.md`
- Codex GitHub integration: <https://developers.openai.com/codex/integrations/github>
- Related follow-ups: `/docs:write-rules`, `/wiki:bootstrap-wiki`
