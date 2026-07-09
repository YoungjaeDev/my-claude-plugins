---
name: checkup
description: "This skill should be used when the user asks to run a project setup diagnostic on an EXISTING repository — phrases like '프로젝트 진단', '셋업 점검', '이 repo 설정 제대로 됐는지 확인', 'project checkup', 'is this repo wired up', 'diagnose my project setup', or an explicit /project-init:checkup invocation. Detects 11 axes of agent-harness configuration (git, CLAUDE.md/AGENTS.md guidance, .claude/rules, llm-wiki layout + staging backlog, Serena onboarding, memory surfaces, spec locations, gws-sync, .tmp convention, git hooksPath, .gitignore coverage), reports a verdict per axis with the remediation skill named, then gates every fix behind AskUserQuestion. Read-only until the user approves. Complements /project-init:new (which bootstraps an EMPTY dir and refuses to run here). Not for mem0 store diagnostics (use /mem0-ops:doctor) or wiki-content health (use /llm-wiki:lint-wiki)."
---

# project-init `checkup` skill

Diagnose whether an existing repository's agent-harness conventions are actually wired up, then fix what the user approves.

Sibling of `new`: `new` bootstraps an empty directory and hard-aborts on a non-empty one. `checkup` is the inverse — it only makes sense on a repo that already exists.

## Contract

- **Detection is read-only.** `scripts/project_state.sh` never writes. Run it first, always.
- **Nothing is fixed before approval.** Present the full report, then a single `AskUserQuestion` gate.
- **Delegate, do not reimplement.** Every remediation that needs judgment routes to the skill that owns it. Only mechanical, reversible edits are applied here.
- **Absent tooling is not a defect.** An unconfigured optional integration (gws-sync without the `gws` CLI) reports `SKIP`, never `FAIL`.

## Step 0 — Resolve PLUGIN_ROOT

Codex does not export `CLAUDE_PLUGIN_ROOT`. Resolve across runtimes before calling any bundled script:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && [ -d plugins/project-init/scripts ] && PLUGIN_ROOT=plugins/project-init
if [ -z "$PLUGIN_ROOT" ]; then
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  PLUGIN_ROOT=$(ls -1d "$cache_root"/*/project-init/* 2>/dev/null | sort | tail -1)
fi
[ -d "$PLUGIN_ROOT/scripts" ] || { echo "project-init scripts not found"; exit 1; }
```

## Step 1 — Detect

```bash
bash "$PLUGIN_ROOT/scripts/project_state.sh"
```

Emits one JSON object. `CHECKUP_TMP_STALE_DAYS` (default 14) sets the `.tmp/` staleness window. Requires `jq`.

Do not re-derive any field with ad-hoc `test -f` calls — the script is the detection SSOT, and duplicating it is how the three pre-existing detectors drifted.

## Step 2 — Verdict per axis

Map the JSON to verdicts. `FAIL` = broken or losing data. `WARN` = works but degraded. `SKIP` = optional and not adopted. `OK` = healthy.

| Axis | JSON | FAIL when | WARN when | Remediation |
|---|---|---|---|---|
| git | `.git` | `initialized: false` | `commits: 0` or `remote_origin: false` | `git init` / `gh repo create` |
| hooksPath | `.git.hooks_path`, `.hooks_dir_present` | — | `hooks_dir_present: true` but `hooks_path: null` | `git config core.hooksPath .githooks` |
| guidance | `.seeded.claude_md`, `.guidance` | `claude_md: false` | `cross_runtime_gap: true` | `/rules-forge:write-rules` |
| llm-wiki | `.llmwiki` | `staging_pending > 0` | `state: absent`; `state: legacy`; `state: current` but `insight_layer: false` or `raw_source_buckets: false` | pending → `/llm-wiki:ingest-finding`; absent → `/llm-wiki:bootstrap-wiki`; legacy → `/llm-wiki:migrate-wiki` |
| serena | `.serena` | — | `state: not-registered` / `registered`; `name_drift: true` | onboard via Serena MCP `onboarding`; drift → edit `.serena/project.yml` |
| memory | `.memory` | `native_auto_memory_enabled: true` **and** `mem0_settings: true` | `native_memory_md: true` but auto-memory disabled (orphan files); `mem0_settings: true` but `federate_labels: false`; `mem0_project_mapped: false` | see "Memory posture" below |
| spec | `.spec` | — | `claude_spec > 0` **and** `superpowers_spec > 0` (split home); `missing_frontmatter > 0` | `/spec-state:state-tracker init` |
| gws-sync | `.gws_sync` | — | `cli: true` but `config: false` | `/gws-sync:gws-sync` |
| .tmp | `.tmp` | — | `dir: true` and `gitignored: false`; `stale_files > 0` | mechanical fix (Step 4) |
| gitignore | `.gitignore` | `env: false` | any of `claude_state` / `serena` / `llmwiki_staging` false | mechanical fix (Step 4) |
| code_signal | `.code_signal` | — | — | informational only |

Three verdicts need an explanation the JSON cannot carry:

- **`staging_pending > 0` is FAIL, not WARN.** The llm-wiki Stop-hook captured session lore into `.llmwiki/.staging/`, and the SessionStart drain never curated it. That directory is gitignored, so the lore is one `rm` from being lost permanently.
- **The memory FAIL keys on `native_auto_memory_enabled`, never on `native_memory_md`.** File presence is a proxy for a feature being on, and the two diverge the moment auto-memory is disabled: `MEMORY.md` survives the setting change. Keying the verdict on the file would keep reporting a conflict this skill already helped resolve. A leftover `MEMORY.md` with auto-memory off is a WARN (dead files), not a FAIL.
- **`gitignore.env: false` is FAIL.** An untracked-but-uncovered `.env` is one `git add -A` from committing credentials. The other gitignore entries only leak local state.

`llm-wiki` layout note: there is no version stamp in `.llmwiki/`. `state: current` + `insight_layer: true` + `raw_source_buckets: true` together mean the post-2.4.0 layout. Any one of them false means a partial migration, not a plugin-version mismatch.

## Step 3 — Report

Print a fixed-width table, most severe first. Name the remediation on every non-OK row — a verdict without a next action is noise.

```
## Project Checkup — <dir_name>

[FAIL] llm-wiki    .llmwiki/.staging: 2 pending captures uncurated
                   -> /llm-wiki:ingest-finding  (gitignored; lore is unrecoverable if cleaned)
[WARN] serena      project.yml name "oh-my-claudecode" != dir "my-claude-plugins"
                   -> edit .serena/project.yml
[WARN] .tmp        not covered by .gitignore
                   -> mechanical fix available
[SKIP] gws-sync    gws CLI not installed
[ OK ] llm-wiki    post-2.4.0 layout (insight + raw buckets)
[ OK ] serena      onboarded (1 memory)
```

State the scan is filesystem-only. Two things it deliberately does not check, to avoid duplicating their owners:

- wiki page staleness / identity duplication → `/llm-wiki:lint-wiki`
- mem0 store contents and config posture → `/mem0-ops:doctor`

## Step 4 — Gate, then fix

Present ONE `AskUserQuestion`. Put "Apply all mechanical fixes (Recommended)" first, "Let me pick" second, "Report only" last. If the user picks "Let me pick", follow with one `multiSelect` question, one option per fix group.

**Mechanically fixable here** (reversible, no judgment):

| Fix | Edit |
|---|---|
| `.gitignore` coverage | append missing lines for `.env`, `.claude/state/`, `.serena/`, `.llmwiki/.staging/`, `.tmp/` |
| `.tmp/` convention | `mkdir -p .tmp && : > .tmp/.gitkeep` + the `.gitignore` line |
| hooksPath | `git config core.hooksPath .githooks` |
| serena name drift | rewrite the `project_name:` line in `.serena/project.yml` |

**Never fixed here** — delegate, and say so:

`.staging` drain, wiki bootstrap/migrate, CLAUDE.md authoring, spec relocation, Serena onboarding, mem0 changes. Each needs LLM judgment or touches a store this skill does not own.

Deleting stale `.tmp/` files is destructive: list them, confirm separately, and never widen the glob beyond `.tmp/`.

## Memory posture

This axis checks **posture consistency** — which writers are live and whether their authority relationship is declared. It does **not** check **content consistency**: whether mem0 and `.llmwiki/` hold contradicting versions of the same fact. That comparison spans a cloud API and a markdown tree, no tool in this toolchain performs it, and claiming otherwise would be a lie. Say so when reporting.

Four surfaces, one role each:

- `.llmwiki/` — authoritative lore (git-tracked, dated, sourced).
- mem0 — recall assistance (cloud, ephemeral).
- Serena memories — symbol/structure maps.
- `.claude/rules/` — mechanical tool invariants only, never lore.

When `native_auto_memory_enabled` and `mem0_settings` are both true, two writers fight: mem0's `block_memory_write.sh` PreToolUse hook blocks `Write`/`Edit` to `MEMORY.md`, so the native file is loaded into every session's context yet cannot be updated. It rots silently.

Resolving it means user-scope settings changes — `autoMemoryEnabled: false`, plus `CORE_CONFIG_FEDERATE_MEM0=1` to activate the `[AUTHORITATIVE]` / `[RECALL]` labels in the prompt-inject hook. Both live outside this repo. Report the conflict, name the change, apply only with explicit approval, and never edit `~/.claude/settings.json` as part of "apply all".

`autoMemoryEnabled` resolves through the settings cascade (user < project < local); unset means native auto-memory is ON.

## Relationship to `new`

`new` and `checkup` share `scripts/project_state.sh` for state detection. They do **not** share the preflight guard: `new`'s Step 0 hard guard stays inline, dependency-free, and runs before `PLUGIN_ROOT` is resolved. Moving a safety gate behind a script lookup would add a failure mode where the guard silently does not run.
