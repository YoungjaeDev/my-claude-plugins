---
name: wiring
description: "This skill should be used when the user asks to run a project setup diagnostic on an EXISTING repository — phrases like '프로젝트 진단', '셋업 점검', '하네스 배선 확인', '이 repo 설정 제대로 됐는지 확인', 'check my project wiring', 'is this repo wired up', 'diagnose my project setup', or an explicit /project-init:wiring invocation. Detects 14 axes of agent-harness configuration, including four that check whether config takes EFFECT rather than merely exists: git core.hooksPath, an @import that defeats .claude/rules paths: scoping, MCP servers registered twice so one copy is silently discarded, and the Codex AGENTS.md byte budget. Verdicts are FAIL / WARN / ASK / INFO / SKIP / OK — an ASK is a decision nobody made yet, asked once and persisted to .claude/state/wiring.json. Read-only until approved. Complements /project-init:new (empty dirs only). Not for mem0 store diagnostics (/mem0-ops:doctor) or wiki-content health (/llm-wiki:lint-wiki)."
---

# project-init `wiring` skill

Diagnose whether an existing repository's agent-harness conventions are actually wired up, then fix what the user approves.

Sibling of `new`: `new` bootstraps an empty directory and hard-aborts on a non-empty one. `wiring` is the inverse — it only makes sense on a repo that already exists.

## Contract

- **Detection is read-only.** `scripts/project_state.sh` never writes. Run it first, always.
- **Nothing is fixed before approval.** Present the full report, then a single `AskUserQuestion` gate.
- **Delegate, do not reimplement.** Every remediation that needs judgment routes to the skill that owns it. Only mechanical, reversible edits are applied here.
- **Absent tooling is not a defect.** An unconfigured optional integration (gws-sync without the `gws` CLI) reports `SKIP`, never `FAIL`.
- **A decision is not a defect.** Some axes have no correct answer the filesystem can know — whether this project wants a git remote, whether its deliverables belong on a shared Drive. Those report `ASK`, are put to the user once, and the answer is persisted so the next run stays quiet. An axis that barks the same un-answerable warning every run trains the user to ignore the ones that matter.

## Verdict classes

| Class | Means | Next run |
|---|---|---|
| `FAIL` | broken, or losing data | keeps failing until fixed |
| `WARN` | works but degraded | keeps warning until fixed |
| `ASK` | a decision nobody has made yet — not a defect | silent once answered |
| `INFO` | worth seeing, no action implied | always shown |
| `SKIP` | optional and not adopted | silent |
| `OK` | healthy | one line |

## Answers file

`ASK` answers live in `.claude/state/wiring.json` (gitignored, alongside `spec.json` and `cr-fix-*.json`). Values are machine-local — a Drive folder id is not the same on another clone — so they do not belong in a committed file. `CLAUDE.md` carries only a pointer to this path, never the values.

```json
{
  "schema": 1,
  "answers": {
    "git_remote": { "value": "none-intended", "answered_at": "2026-07-10" },
    "gws_sync":   { "value": "not-for-this-repo", "answered_at": "2026-07-10" }
  }
}
```

`project_state.sh` surfaces the file's `answers` object verbatim under `.answers`. Before raising any `ASK`, check whether its key holds a **terminal** value; if so, report it as `OK` or `SKIP` and move on. A value that records a step still pending (`gws_sync: "pending-install"`) is not terminal — re-ask once its precondition is met, or the answer file silently swallows the follow-up question. Re-ask otherwise only when the user says so, or when an answer is older than a year.

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

Emits one JSON object. `WIRING_TMP_STALE_DAYS` (default 14) sets the `.tmp/` staleness window. Requires `jq`.

Do not re-derive any field with ad-hoc `test -f` calls — the script is the detection SSOT, and duplicating it is how the three pre-existing detectors drifted.

## Step 2 — Verdict per axis

Map the JSON to verdicts. Suppress any `ASK` whose key already appears in `.answers`.

| Axis | JSON | FAIL when | WARN when | ASK / INFO when | Remediation |
|---|---|---|---|---|---|
| git | `.git` | `initialized: false` | `commits: 0` | **ASK** `remote_origin: false` — "push할 원격을 만들까요?" (`git_remote`) | `git init` / `gh repo create` |
| hooksPath | `.git.hooks_path`, `.hooks_dir_present` | — | `hooks_dir_present: true` but `hooks_path: null` | — | `git config core.hooksPath .githooks` |
| guidance | `.seeded.claude_md`, `.guidance` | `claude_md: false` | `cross_runtime_gap: true` | — | `/rules-forge:write-rules` |
| rules scoping | `.rules_scoping` | — | `paths_defeated_by_import` non-empty | — | drop the `@` (mechanical, Step 4) |
| llm-wiki | `.llmwiki` | `staging_pending > 0` | `state: absent`; `state: legacy`; `state: current` but `insight_layer: false` or `raw_source_buckets: false` | — | pending → `/llm-wiki:ingest-finding`; absent → `/llm-wiki:bootstrap-wiki`; legacy → `/llm-wiki:migrate-wiki` |
| serena | `.serena` | — | `state: not-registered` / `registered`; `name_drift: true` | — | onboard via Serena MCP `onboarding`; drift → edit `.serena/project.yml` |
| memory | `.memory` | `native_auto_memory_enabled: true` **and** `mem0_settings: true` | orphan `MEMORY.md`; `mem0_settings: true` but `federate_labels: false`; `mem0_project_mapped: false` | — | see "Memory posture" below |
| mcp config | `.mcp` | — | `duplicates` non-empty; `unreadable` non-empty | — | collapse to one file (see below) |
| codex | `.codex` | — | `agents_md_bytes + global_agents_md_bytes` ≥ 80% of `project_doc_max_bytes` | **INFO** otherwise when `config: true` | over budget → trim `AGENTS.md`; else visibility only |
| spec | `.spec` | — | `missing_frontmatter > 0` | **INFO** `claude_spec > 0` **and** `superpowers_spec > 0` | `/spec-state:state-tracker init` |
| gws-sync | `.gws_sync` | — | — | **ASK** unless answered with a terminal value (`gws_sync`) — see below | `/gws-sync:gws-sync` |
| .tmp | `.tmp` | — | `dir: true` and `gitignored: false`; `stale_files > 0` | — | mechanical fix (Step 4) |
| gitignore | `.gitignore` | `env: false` | any of `claude_state` / `serena` / `llmwiki_staging` false | — | mechanical fix (Step 4) |
| code_signal | `.code_signal` | — | — | **INFO** | — |

### The four efficacy axes

Existence checks answer "is it there?". These four answer "**does it take effect?**" — the failure mode where a file exists, looks configured, and is inert.

- **hooksPath.** `.githooks/` is tracked; `core.hooksPath` is per-clone git config that is *not*. A fresh clone has the hook scripts and no hook. Silent until CI catches it after the push. When `.githooks/` is absent the axis says nothing — plenty of repos don't use it.
- **rules scoping.** A `.claude/rules/*.md` carrying `paths:` frontmatter is meant to load only when Claude touches matching files. `@import`ing that same file from `CLAUDE.md` expands it unconditionally at launch, so the scoping is dead and its tokens are paid every session. Fix: drop the `@` and wrap the path in backticks — import parsing skips code spans, so the line survives as a human pointer.
- **mcp config.** When the same server name appears in both `~/.claude.json` and `~/.claude/settings.json`, Claude Code picks one entry whole and discards the other — fields are never merged. Two definitions that have drifted mean one file's edits have never once taken effect. Report the duplicate names and say plainly that editing the losing copy does nothing. Orphan registrations (a server left behind by a deleted plugin) need usage history to identify — that is the built-in `/doctor`'s job, not this skill's.

  `unreadable` is a separate `WARN`. A user-scope file that is not valid JSON cannot be compared, and the detector refuses to answer "no duplicates" when what it means is "could not look". Name the file and say the duplicate check did not run.

### `codex` is visibility, except the doc budget

`approval_policy: "never"` with `sandbox_mode: "danger-full-access"` means a `/codex:rescue` edits the working tree without asking. That is a legitimate dev-box choice, so it is not a defect — but it should never be a surprise. Print it. The one part of this axis that *is* a verdict is the doc budget below. Same for `model_pinned`: pinning freezes the model that `codex-image` deliberately leaves unpinned to auto-track the latest, which is maintenance debt, not breakage.

Also print the Codex doc budget when `AGENTS.md` exists: `agents_md_bytes + global_agents_md_bytes` against `project_doc_max_bytes`. Codex concatenates root-down and truncates at the cap — and the tail of `AGENTS.md` is usually `## Review guidelines`, the part the GitHub cloud reviewer loads into its system prompt. So the budget is a `WARN` at 80% and above, not an `INFO`: past the cap the guidance is silently gone, with no error anywhere. Below 80% it is `INFO`, visibility only.

### gws-sync is a two-step ASK

Never a defect — it is a question about what this project produces.

1. If `cli: false` → ASK: "이 프로젝트 산출물을 Google Drive 에 올리나요?" If yes, guide the install (`gws` CLI) and stop; record `gws_sync: "pending-install"`. If no, record `gws_sync: "not-for-this-repo"` and never ask again.
2. If `cli: true` and `config: false` → ASK which local folders are the deliverables and which Drive folder receives them, then hand off to `/gws-sync:gws-sync` to write `.gws-sync.json`. Record `gws_sync: "configured"`.

**Only a terminal answer suppresses the ASK.** `not-for-this-repo` and `configured` are decisions; `pending-install` is a step that has not happened yet. Treating all three as "answered" means the user installs `gws`, re-runs `wiring`, and is never asked step 2 — the answer file has silently swallowed the question. Re-ask whenever the recorded value is `pending-install` and `cli: true`.

### spec is a preference, not a migration

Two spec homes is `INFO`, not `WARN`: state which one this project prefers (`.claude/spec/` unless the project says otherwise) and leave the files where they are. Only `missing_frontmatter > 0` is a `WARN`, because a spec without `status:` frontmatter is invisible to `spec-state` regardless of which directory it sits in. Never move spec files as part of "apply all".

Three verdicts need an explanation the JSON cannot carry:

- **`staging_pending > 0` is FAIL, not WARN.** The llm-wiki Stop-hook captured session lore into `.llmwiki/.staging/`, and the SessionStart drain never curated it. That directory is gitignored, so the lore is one `rm` from being lost permanently.
- **The memory FAIL keys on `native_auto_memory_enabled`, never on `native_memory_md`.** File presence is a proxy for a feature being on, and the two diverge the moment auto-memory is disabled: `MEMORY.md` survives the setting change. Keying the verdict on the file would keep reporting a conflict this skill already helped resolve. A leftover `MEMORY.md` with auto-memory off is a WARN (dead files), not a FAIL.
- **`gitignore.env: false` is FAIL.** An untracked-but-uncovered `.env` is one `git add -A` from committing credentials. The other gitignore entries only leak local state.

`llm-wiki` layout note: there is no version stamp in `.llmwiki/`. `state: current` + `insight_layer: true` + `raw_source_buckets: true` together mean the post-2.4.0 layout. Any one of them false means a partial migration, not a plugin-version mismatch.

## Step 3 — Report

Print a fixed-width table, most severe first. Name the remediation on every non-OK row — a verdict without a next action is noise.

```
## Project Wiring — <dir_name>

[FAIL] llm-wiki    .llmwiki/.staging: 2 pending captures uncurated
                   -> /llm-wiki:ingest-finding  (gitignored; lore is unrecoverable if cleaned)
[WARN] rules       plugin-versioning.md has paths: scoping, but CLAUDE.md @imports it
                   -> scoping is dead; ~2k tokens loaded every session. mechanical fix
[WARN] mcp         7 servers registered twice (~/.claude.json wins, settings.json copy inert)
                   -> context7 deepwiki exa firecrawl mcpdocs notion shadcn-ui
[ASK ] gws-sync    does this project publish deliverables to Drive?  (unanswered)
[ASK ] git         no origin remote — create one?                    (unanswered)
[INFO] codex       approval=never sandbox=danger-full-access -> /codex:rescue edits unprompted
[INFO] codex       AGENTS.md 28,506 / 65,536 B (43%) of the doc budget
[INFO] spec        .claude/spec 8 + docs/superpowers/specs 6 — this project prefers .claude/spec
[ OK ] llm-wiki    post-2.4.0 layout (insight + raw buckets)
[ OK ] serena      onboarded (1 memory)
```

State the scan is filesystem-only. Things it deliberately does not check, to avoid duplicating their owners:

- wiki page staleness / identity duplication → `/llm-wiki:lint-wiki`
- mem0 store contents and config posture → `/mem0-ops:doctor`
- MCP servers left behind by deleted plugins, and which extensions go unused → the built-in `/doctor` (it reads usage history; this skill reads only the filesystem)

## Step 4 — Gate, then fix

Present ONE `AskUserQuestion`. Put "Apply all mechanical fixes (Recommended)" first, "Let me pick" second, "Report only" last. If the user picks "Let me pick", follow with one `multiSelect` question, one option per fix group.

**Mechanically fixable here** (reversible, no judgment):

| Fix | Edit |
|---|---|
| `.gitignore` coverage | append missing lines for `.env`, `.claude/state/`, `.serena/`, `.llmwiki/.staging/`, `.tmp/` |
| `.tmp/` convention | `mkdir -p .tmp && : > .tmp/.gitkeep` + the `.gitignore` line |
| hooksPath | `git config core.hooksPath .githooks` |
| serena name drift | rewrite the `project_name:` line in `.serena/project.yml` |
| rules scoping | in `CLAUDE.md`, change `@.claude/rules/<f>.md` to `` `.claude/rules/<f>.md` `` — restores `paths:` scoping, keeps the pointer readable |

**Never fixed here** — delegate, and say so:

`.staging` drain, wiki bootstrap/migrate, CLAUDE.md authoring, spec relocation, Serena onboarding, mem0 changes, MCP config collapse (it edits a user-scope file holding credentials). Each needs LLM judgment or touches a store this skill does not own.

Deleting stale `.tmp/` files is destructive: list them, confirm separately, and never widen the glob beyond `.tmp/`.

**Recording `ASK` answers.** Every `ASK` the user answers is written to `.claude/state/wiring.json` under `answers.<key>` with `value` and `answered_at` (UTC `YYYY-MM-DD`). Create the file if absent. Write it even when the rest of "apply all" is declined — a recorded "no" is the whole point of the class. Never write an answer the user did not give.

**The answers file must be ignored before it is written.** Its values are machine-local (a Drive folder id, a decision that holds for this clone only), so run `git check-ignore -q .claude/state/wiring.json` first. If it does not pass, add `.claude/state/` to `.gitignore` as a precondition — not as part of "apply all", which the user may have declined. If the user declines that line too, do not create the file: report the answer as unrecorded and say why. Persisting a "no" is worth a `.gitignore` line; it is not worth committing someone's Drive folder id on their next `git add -A`. Outside a git repository the check does not apply.

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

`new` and `wiring` share `scripts/project_state.sh` for state detection. They do **not** share the preflight guard: `new`'s Step 0 hard guard stays inline, dependency-free, and runs before `PLUGIN_ROOT` is resolved. Moving a safety gate behind a script lookup would add a failure mode where the guard silently does not run.
