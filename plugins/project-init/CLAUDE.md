# Project-Init Plugin

Orchestrates a project's **agent-harness lifecycle**. The two directions are symmetric.

- `new` — Day-1 setup (`.claude/`, CLAUDE.md, AGENTS.md, README/CHANGELOG, gh repo create + push). **Empty directories only.**
- `wiring` — diagnoses the harness config of an already-existing repo. **The inverse of `new`.** Read-only detection, then edits only behind an `AskUserQuestion` gate.

## Surfaces

| Surface | Entry | Description |
|---------|-------|-------------|
| Command | `/project-init:new` | Explicit user invocation — the primary surface for bootstrap. |
| Skill | `new` | For capability discovery by Codex (and Claude Code). The description is scoped narrowly so only phrases like "bootstrap a new project in this empty dir" match. |
| Skill | `wiring` | Diagnoses an existing repo. No command surface — a `/project-init:wiring` skill call is enough, and a command would not be emitted to Codex, only duplicating the body. |

Both surfaces of `new` put a **preflight hard guard** in the first block of the body — if `.git/`, `.claude/`, or a source file exists anywhere in cwd, abort. It does not rely on description-based matching alone; it enforces at runtime. `wiring` has no such guard (by definition it is only meaningful in a non-empty repo).

## Detection SSOT

`scripts/project_state.sh` is **solely** responsible for project-state detection. Pure read-only, emitting a single JSON blob.

- `wiring` consumes all 14 axes. Four of them look at not "does the file exist" but **"does the config actually take effect"** — `core.hooksPath` (must be turned on per clone), whether an `@import` has defeated the `paths:` scoping of `.claude/rules`, whether the same MCP server registered in two user-scope files causes one definition to be discarded wholesale, and whether Codex `AGENTS.md` fits within the `project_doc_max_bytes` budget.
- An axis that is a **decision** rather than a defect (`git remote`, `gws-sync`) is emitted as `ASK`. The answer is written to `answers` in `.claude/state/wiring.json` and the script carries it forward as-is — the skill never re-asks an already-answered item. Because values differ per machine (Drive folder ids, etc.), they stay in gitignored state, and `CLAUDE.md` keeps only a **one-line path pointer**. A warning that barks every run trains people to ignore it, and then a real `FAIL` gets buried with it.
- **An `ASK` must have a step that actually asks** (Step 3.5). If it is only stamped `(unanswered)` in the report with nowhere to ask, no answer is recorded and the next run repeats the same line verbatim — the class becomes decoration. A question closed without an answer leaves no key. An unrecorded `ASK` is not a recorded "no".
- Write a suppression condition in **one place only**. The `gws_sync` verdict is not decided by the answer alone — it also reads whether `.gws-sync.json` exists and whether the `gws` CLI is present, so the filesystem moves even after the answer is recorded. Writing the same condition three times across the verdict table, the prose, and the question step means it drifts three ways.
- **Orphan MCP registrations are not handled.** A server left behind by a deleted plugin needs usage history to judge, so it is the built-in `/doctor`'s territory. A **duplicate registration**, by contrast, is the intersection of two files' keys, so it is pure computation — do not pretend to catch what determinism cannot.
- `idempotent-seed.sh diagnose` wraps this script and picks out only the legacy output shape (`cwd`/`dir_name`/`git`/`seeded`/`code_signal`). It does not re-implement the detection logic.
- **The Step 0 hard guard of `new` is not absorbed here.** The guard has zero dependencies (pure `find`) and must run **before** the `PLUGIN_ROOT` resolver. Turning it into a script call would introduce a new failure mode where "the guard silently does not run if PLUGIN_ROOT resolution fails". A safety device is never moved behind a lazy-load.

`find` expresses "not found" as exit 1. Under `set -o pipefail`, `find ... | wc -l` kills the script on a legitimate empty result. Every `find` goes through the `find_or_empty` / `count_files` helpers, and `code_signal` uses `-print -quit` to avoid a `head`-induced SIGPIPE false positive.

`jq` digs the same pit. If `jq` exits non-zero on a single corrupted user config file, that failure rides up through command substitution and `set -e` kills the script — instead of failing to judge one axis, the whole diagnostic vanishes and the user sees no output at all. Confine one axis's failure to that axis (like `mcp.unreadable`) and keep emitting the rest of the diagnostic. And **never report "did not see it" as "no problem".**

When reading an external tool's value to pass to `jq --argjson`, do not trust the source format. TOML allows an inline comment after a value and a `_` separator in integers, so `65536 # bytes` scraped by `sed` is a valid config yet invalid JSON. Normalize numbers and confirm they are all digits; otherwise fall back to the documented default.

The Codex config location is `${CODEX_HOME:-$HOME/.codex}` (`codex --help`). Hardcoding `$HOME/.codex` reports `config: false` on a machine that uses `CODEX_HOME`, wiping out the approval/sandbox posture and doc-budget verdicts wholesale.

## Principles

- **Preflight hard guard is non-negotiable**: the same guard is embedded in Step 0 of both `commands/new.md` and `skills/new/SKILL.md`. The premise is that a description alone cannot block a wrong trigger — even if the model misreads the description, runtime blocks it. Removing the guard must be an explicit (high-friction, deliberate) user decision.
- **wiring does not diagnose another owner's territory**: wiki-page health is owned by `/llm-wiki:lint-wiki`, and mem0 store/config posture by `/mem0-ops:doctor`. wiring looks only at filesystem signals — "does a wiki exist / is the layout right / has mid-drain capture piled up". Overlap means the day comes when two diagnostics give different answers.
- **Name the owning skill for each defect**: a verdict with no next action is noise. wiring directly fixes only mechanical, reversible edits (a `.gitignore` line, creating `.tmp/`, `core.hooksPath`, serena `project_name`); anything needing judgment (`.staging` curation, wiki bootstrap/migrate, CLAUDE.md authoring, spec migration, Serena onboarding, mem0 changes) is delegated.
- **Minimal seeding, explicit follow-ups**: seed only what Day 1 needs. Tech-stack-based rule generation and the wiki-domain interview are **not invoked, only pointed to**. Generating generic content in an empty project imposes an overwrite cost on the user.
- **Owner gate is mandatory**: since the user has a personal + multiple-org context, never auto-decide the owner. Require an explicit choice via `AskUserQuestion`.
- **Codex GitHub reviewer surface**: the AGENTS.md `## Review guidelines` section is what the Codex GitHub cloud reviewer reads automatically. It must be **seeded at repo-creation time** to take effect from the first PR.
- **Idempotent re-runs**: on a second invocation in the same directory, preserve existing files + skip steps + print a notice. Never overwrite. (But since the hard guard aborts on the mere presence of `.git`/`.claude`, an idempotent re-run does not occur on the normal path — it only matters on the recovery path for a partial seed that bypassed the guard.)

## File layout

```text
plugins/project-init/
├── .claude-plugin/plugin.json
├── commands/new.md                     # explicit slash surface (preflight guard + pointer)
├── skills/
│   ├── new/SKILL.md                    # bootstrap skill surface (same preflight guard + pointer)
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

## Preflight guard contract

The same POSIX shell block sits in Step 0 of `commands/new.md` and `skills/new/SKILL.md`:

```bash
FIRST_EXISTING=$(find . -mindepth 1 -maxdepth 5 \
  \( -name '.git' -o -path './.git/*' \
   -o -name '.DS_Store' -o -name 'Thumbs.db' \
   -o -name 'desktop.ini' \) -prune \
  -o -print 2>/dev/null | head -1)

if [ -d .git ] || [ -n "$FIRST_EXISTING" ]; then
  echo "[abort] project-init refuses to run in a non-empty directory."
  ...
  exit 1
fi
```

- **Rejection rule**: anything in cwd that is not `.git/`, `.DS_Store`, `Thumbs.db`, or `desktop.ini` causes abort. `Dockerfile`, `Makefile`, `.env`, `docs/`, `src/app/main.py` — all of those trigger.
- **Search depth**: 5 levels (`find -maxdepth 5`). Deep-nested source files do not slip past the guard.
- **Abort message**: surfaces cwd + the first offending entry + a redirect to `/rules-forge:write-rules` or `/llm-wiki:bootstrap-wiki` for the "scaffold an existing project" case.
- **Non-POSIX hosts**: PowerShell-default environments must invoke via `bash -c '<guard>'` (Git Bash / WSL / Cygwin). The intent of the check, not the literal shell, is what matters — equivalent PowerShell rewrites are acceptable as long as they refuse the same conditions.

When modifying it, update both files at once. Changing only one makes the surfaces diverge in behavior.

## Cross-runtime plugin root resolution

`references/new-procedure.md` Phase 0 opens with a `PLUGIN_ROOT` resolver:

```bash
PLUGIN_ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$PLUGIN_ROOT" ]; then
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  if sort -V </dev/null >/dev/null 2>&1; then
    candidate=$(ls -1d "$cache_root"/*/project-init/* 2>/dev/null | sort -V | tail -1)
  else
    candidate=$(ls -1d "$cache_root"/*/project-init/* 2>/dev/null | sort | tail -1)
  fi
  [ -n "$candidate" ] && [ -d "$candidate" ] && PLUGIN_ROOT="$candidate"
fi
[ -n "$PLUGIN_ROOT" ] && [ -d "$PLUGIN_ROOT/scripts" ] || { echo "[abort] ..."; exit 1; }
```

- Under **Claude Code**, `${CLAUDE_PLUGIN_ROOT}` is set automatically and the resolver short-circuits on the first branch.
- Under **Codex 0.135**, no equivalent env var is currently exposed, so the resolver falls back to `~/.codex/plugins/cache/<marketplace>/project-init/<version>/`. Users can override with `CODEX_PLUGIN_CACHE` or set `PLUGIN_ROOT` directly.
- All subsequent bash blocks reference `${PLUGIN_ROOT}/scripts/...` and `${PLUGIN_ROOT}/assets/...`. Adding a new asset / script means updating only the procedure file — no per-surface duplication.

## Placeholder convention

The templates under `assets/` use only these placeholders (sed substitution):

| Placeholder | Meaning |
|-------------|------|
| `{{PROJECT_NAME}}` | project name (Phase 1 answer) |
| `{{ONE_LINER}}` | one-line description |
| `{{OWNER}}` | personal account or org name |
| `{{LICENSE}}` | MIT / Apache-2.0 / GPL-3.0 / None |
| `{{YEAR}}` | current year |

When introducing a new placeholder, update the sed lines in Phase 4/5 of `references/new-procedure.md` as well.

## AGENTS.md variant policy

The three files share the same skeleton:

1. `## Project context` — `{{PROJECT_NAME}}` + `{{ONE_LINER}}` (1-2 lines)
2. `## Build / Test / Lint` — placeholder TODO
3. `## Review guidelines` — **the section the Codex cloud reviewer reads**
   - `### Do not flag` (linter territory — handled by tooling)
   - `### P0 — Correctness / Security`
   - `### P1 — Performance / Maintainability`
   - `### Domain-specific` (differs per variant; general has only a TODO)

The variant difference is the `### Domain-specific` section plus 1-2 domain-specific items added to `### P0` / `### P1`. **Only the domain sections differ on top of the base** — minimizing code duplication.

## Out of Scope

- CI/CD workflow seed (`.github/workflows/`) — too much per-variant variety
- Pre-commit hook seed — same reason
- Boilerplate auto-download (cookiecutter, copier) — a separate `Skill("code-scout:research-orchestrator")` call
- Multi-language interview branching — a single mixed Korean/English version is maintained

## References

- Plugin versioning rules: `.claude/rules/plugin-versioning.md`
- Codex GitHub integration: <https://developers.openai.com/codex/integrations/github>
- Related follow-ups: `/rules-forge:write-rules`, `/llm-wiki:bootstrap-wiki`
