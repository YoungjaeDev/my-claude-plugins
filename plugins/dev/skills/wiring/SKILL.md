---
name: wiring
description: "Diagnose whether an EXISTING repository's agent-harness setup actually takes effect: 14 axes including core.hooksPath, an @import that defeats .claude/rules paths: scoping, MCP servers registered twice, and the Codex AGENTS.md byte budget. Use on /dev:wiring, '프로젝트 진단', '셋업 점검', '하네스 배선 확인', 'check my project wiring', 'diagnose my project setup'. Verdicts FAIL / WARN / ASK / INFO / SKIP / OK; read-only until approved. Not for empty directories (/dev:new) or wiki health (/wiki:lint)."
---

# dev `wiring` skill

Diagnose whether an existing repository's agent-harness conventions are actually wired up across 14 axes, then fix what the user approves. It is the inverse of `new`, which bootstraps an empty directory and aborts on a non-empty one.

Read `references/procedure.md` before Step 2. It explains the efficacy, codex and memory axes, the report shape, and how `ASK` answers are recorded.

## Contract

- **Detection is read-only**: `scripts/project_state.sh` never writes. Run it first, always, and never re-derive a field with ad-hoc `test -f` calls.
- **Nothing is fixed before approval**: present the full report, ask the `ASK` axes, then one gate for the mechanical fixes. Ask with `AskUserQuestion` on Claude Code or `request_user_input` on Codex; when neither is available, report only, fix nothing, and say so.
- **Delegate, do not reimplement**: every remediation that needs judgment routes to the skill that owns it. Only the mechanical, reversible edits in Step 4 are applied here.
- **Absent tooling is not a defect**: a missing optional CLI is never a `FAIL`. For `gws-sync` the verdict comes from the table in "gws-sync is a two-step ASK", never from the CLI's absence alone.
- **A decision is not a defect**: an axis the filesystem cannot answer (a git remote, Drive deliverables) reports `ASK`, is asked once, and its answer is persisted so the next run stays quiet.

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

`ASK` answers live in gitignored `.claude/state/wiring.json`, because values such as a Drive folder id are machine-local. `CLAUDE.md` carries only a pointer to this path, never the values. The file shape is in `references/procedure.md` "Recording `ASK` answers".

`project_state.sh` surfaces the `answers` object verbatim under `.answers`. Before raising an `ASK`, check whether its key holds a terminal value; if so, report `OK` or `SKIP`. `gws_sync: "pending-install"` is not terminal: re-ask once its precondition is met.

Otherwise re-ask only when the user asks to revisit the decision; answers do not expire.

## Step 0 — Resolve PLUGIN_ROOT

Codex does not export `CLAUDE_PLUGIN_ROOT`. Resolve across runtimes before calling any bundled script:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && [ -d plugins/dev/scripts ] && PLUGIN_ROOT=plugins/dev
if [ -z "$PLUGIN_ROOT" ]; then
  cache_root="${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"
  # Newest version first; the first one that has scripts/ wins.
  if sort -V </dev/null >/dev/null 2>&1; then
    candidates=$(ls -1d "$cache_root"/*/dev/* 2>/dev/null | awk -F/ '{print $NF "\t" $(0)}' | sort -rV | cut -f2-)
  else
    candidates=$(ls -1d "$cache_root"/*/dev/* 2>/dev/null | awk -F/ '{print $NF "\t" $(0)}' | sort -t. -k1,1rn -k2,2rn -k3,3rn | cut -f2-)
  fi
  while IFS= read -r d; do [ -d "$d/scripts" ] && { PLUGIN_ROOT="$d"; break; }; done <<< "$candidates"
fi
[ -d "$PLUGIN_ROOT/scripts" ] || { echo "dev scripts not found"; exit 1; }
```

## Step 1 — Detect

```bash
bash "$PLUGIN_ROOT/scripts/project_state.sh"
```

Emits one JSON object and requires `jq`. `WIRING_TMP_STALE_DAYS` (default 14) sets the `.tmp/` staleness window.

## Step 2 — Verdict per axis

Map the JSON to verdicts. Suppress an `ASK` only when its key in `.answers` holds a terminal value (see "Answers file").

| Axis | JSON | FAIL when | WARN when | ASK / INFO when | Remediation |
|---|---|---|---|---|---|
| git | `.git` | `initialized: false` | `commits: 0` | **ASK** `remote_origin: false` — "push할 원격을 만들까요?" (`git_remote`) | `git init` / `gh repo create` |
| hooksPath | `.git.hooks_path`, `.hooks_dir_present` | — | `hooks_dir_present: true` but `hooks_path: null` | — | `git config core.hooksPath .githooks` |
| guidance | `.seeded.claude_md`, `.guidance` | `claude_md: false`; `cross_runtime_gap: true` | — | — | `/docs:write-rules` |
| rules scoping | `.rules_scoping` | — | `paths_defeated_by_import` non-empty | — | drop the `@` (mechanical, Step 4) |
| wiki | `.llmwiki` | — | `state: legacy` | **SKIP** `state: absent` (the wiki is optional; `/wiki:ingest` creates it when the first original arrives) | legacy → move the pages under `.llmwiki/wiki/` by hand (old-format pages stay readable), then `/wiki:lint` |
| serena | `.serena` | — | `state: not-registered` / `registered`; `name_drift: true` | — | onboard via Serena MCP `onboarding`; drift → edit `.serena/project.yml` |
| memory | `.memory` | `native_auto_memory_enabled: true` **and** `mem0_settings: true` | orphan `MEMORY.md` | — | see "Memory posture" in `references/procedure.md` |
| mcp config | `.mcp` | `duplicates_drifted` non-empty | `duplicates` non-empty (identical copies); `unreadable` non-empty | — | collapse to one file (delegated, see Step 4) |
| codex | `.codex` | `agents_md_bytes + global_agents_md_bytes` > `project_doc_max_bytes` | same sum ≥ 80% of `project_doc_max_bytes` | **INFO** otherwise when `config: true` | over cap → trim `AGENTS.md` or raise `project_doc_max_bytes`; else visibility only |
| spec | `.spec` | — | `issue_tracker_doc: false` | **INFO** `claude_spec > 0` **or** `superpowers_spec > 0` | `/setup-matt-pocock-skills` (Matt) |
| gws-sync | `.gws_sync`, `.answers.gws_sync` | — | `config: true` but `cli: false` | **ASK** / **OK** / **SKIP** / **INFO** per the table in "gws-sync is a two-step ASK" | `/docs:gws-sync` |
| .tmp | `.tmp` | — | `dir: true` and `gitignored: false`; `stale_files > 0` | — | mechanical fix (Step 4) |
| gitignore | `.gitignore` | `env: false` | any of `claude_state` / `serena` false | — | mechanical fix (Step 4) |
| code_signal | `.code_signal` | — | — | **INFO** | — |

### gws-sync is a two-step ASK

The verdict reads the filesystem (`.gws_sync.cli`, `.gws_sync.config`) and the recorded answer, never the answer alone. This table is the single definition; Step 2 and Step 3.5 both defer to it.

| `config` | recorded `gws_sync` | `cli` | Verdict | Ask? |
|---|---|---|---|---|
| `true` | any | `true` | `OK` — already adopted | no |
| `true` | any | `false` | `WARN` — `.gws-sync.json` exists but the `gws` CLI is gone | no |
| `false` | `not-for-this-repo` | any | `SKIP` | no |
| `false` | `configured` | any | `ASK` — the config it claims is gone; confirm before rewriting | yes |
| `false` | `pending-install` | `false` | `INFO` — waiting on the `gws` install | no |
| `false` | `pending-install` | `true` | `ASK` step 2 | yes |
| `false` | *(none)* | `false` | `ASK` step 1 | yes |
| `false` | *(none)* | `true` | `ASK` step 2 | yes |

1. **Step 1** ASK: "이 프로젝트 산출물을 Google Drive 에 올리나요?" If yes, guide the `gws` install and stop; record `gws_sync: "pending-install"`. If no, record `gws_sync: "not-for-this-repo"`.
2. **Step 2** ASK which local folders are the deliverables and which Drive folder receives them, then hand off to `/docs:gws-sync` to write `.gws-sync.json`. Record `gws_sync: "configured"`.

## Step 3 — Report

- Print the fixed-width table from `references/procedure.md`, most severe first.
- Name the remediation on every non-OK row; a verdict without a next action is noise.
- State that the scan is filesystem-only and name the owners of what it does not check (`/wiki:lint`, the built-in `/doctor`).

## Step 3.5 — Put the `ASK` axes to the user

- Ask every axis the report printed as `[ASK] … (unanswered)`, before Step 4, and only when Step 2 marked it `ASK`.
- Ask one question per axis: `git_remote` and `gws_sync` are unrelated, so no `multiSelect`.
- Record each answer as `references/procedure.md` "Recording `ASK` answers" says. A dismissed question leaves the key absent: an unanswered `ASK` is not a recorded "no".

## Step 4 — Gate, then fix

Ask once about the mechanical fixes: "Apply all mechanical fixes (Recommended)" first, "Let me pick" second, "Report only" last. "Let me pick" is followed by one `multiSelect` question, one option per fix group.

| Fix | Edit |
|---|---|
| `.gitignore` coverage | append missing lines for `.env`, `.claude/state/`, `.serena/`, `.tmp/` |
| `.tmp/` convention | `mkdir -p .tmp && : > .tmp/.gitkeep` + the `.gitignore` line |
| hooksPath | `git config core.hooksPath .githooks` |
| serena name drift | rewrite the `project_name:` line in `.serena/project.yml` |
| rules scoping | in `CLAUDE.md`, change `@.claude/rules/<f>.md` to `` `.claude/rules/<f>.md` `` — restores `paths:` scoping, keeps the pointer readable |

- **Never fixed here, delegated by name**: legacy wiki migration, CLAUDE.md authoring, spec relocation, Serena onboarding, mem0 changes, the codex doc budget, and MCP config collapse (it edits a user-scope file holding credentials).
- **Stale `.tmp/` deletion is destructive**: list the files, confirm separately, and never widen the glob beyond `.tmp/`.
- **Answers file**: write answered `ASK`s even when "apply all" is declined, and only after `git check-ignore -q .claude/state/wiring.json` passes. Never edit `~/.claude/settings.json` as part of "apply all".
