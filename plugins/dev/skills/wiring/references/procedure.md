# Wiring procedure

Detail for `SKILL.md` Steps 2 to 4: why the efficacy axes read the way they do, how the codex and memory axes are reported, the report shape, and how `ASK` answers are recorded. The verdict tables and bright lines stay in `SKILL.md`.

## The four efficacy axes (Step 2)

Existence checks answer "is it there?". These four answer "does it take effect?", the failure where a file exists, looks configured, and is inert.

- **hooksPath**: `.githooks/` is tracked, but `core.hooksPath` is per-clone git config, so a fresh clone has the scripts and no hook. It stays silent until CI catches it after the push. With no `.githooks/` the axis says nothing.
- **rules scoping**: a `.claude/rules/*.md` with `paths:` frontmatter loads only when Claude touches matching files. `@import`ing it from `CLAUDE.md` expands it at launch, so the scoping is dead and its tokens are paid every session. The fix drops the `@` and wraps the path in backticks; import parsing skips code spans, so the pointer survives.
- **mcp config**: when one server name is in both `~/.claude.json` and `~/.claude/settings.json`, Claude Code keeps one entry whole and discards the other, never merging fields. A name in `duplicates_drifted` has two different definitions, so the losing copy is inert (`FAIL`); identical copies are a `WARN`. Report the names and say that editing the losing copy does nothing.
- **mcp unreadable**: a user-scope file that is not valid JSON cannot be compared, so `unreadable` is its own `WARN`. Name the file and say the duplicate check did not run.

Orphan MCP registrations (a server left by a deleted plugin) need usage history, which is the built-in `/doctor`'s job.

## The codex axis (Step 2)

`approval_policy: "never"` with `sandbox_mode: "danger-full-access"` means `/codex:rescue` edits the working tree without asking. It is a legitimate dev-box choice, so print it as `INFO`, never as a defect. `model_pinned` is the same: pinning freezes the model `codex-image` leaves unpinned, which is maintenance debt.

The doc budget is the one verdict on this axis. When `AGENTS.md` exists, print `agents_md_bytes + global_agents_md_bytes` against `project_doc_max_bytes`. Codex concatenates root-down and truncates at the cap, and the tail of `AGENTS.md` is usually `## Code Review Rules`, which the GitHub cloud reviewer loads.

- **Over 100%**: `FAIL`; guidance is already being lost with no error, and by position it is the review-critical tail.
- **80% to 100%**: `WARN`. Below 80%: `INFO`.
- **Remediation is user judgment**: the codex axis is not in Step 4's mechanical set, so wiring never trims `AGENTS.md` or edits a Codex config. Offer trimming `AGENTS.md`, or raising `project_doc_max_bytes` in `${CODEX_HOME:-~/.codex}/config.toml` (machine-local; the detector reads `$CODEX_HOME` when set).

## Verdicts the JSON cannot explain (Step 2)

- **`cross_runtime_gap: true` is FAIL**: `.claude/rules/*.md` exist but `AGENTS.md` does not, so every Codex session runs with no project guidance and no error.
- **The memory FAIL keys on `native_auto_memory_enabled`**, never on `native_memory_md`: `MEMORY.md` survives disabling auto-memory. A leftover `MEMORY.md` with auto-memory off is a `WARN` (dead file).
- **`gitignore.env: false` is FAIL**: an uncovered `.env` is one `git add -A` from committing credentials. The other gitignore entries only leak local state.
- **wiki state**: `current` means `.llmwiki/wiki/` holds `index.md` or `log.md`; `legacy` means only `.claude/wiki/` or `.codex/wiki/` do. Page layout and freshness belong to `/wiki:lint`.
- **spec**: a spec is an issue in the tracker Matt `/to-spec` publishes to, and `docs/agents/issue-tracker.md` records which tracker. Without it `issue_tracker_doc: false` is a `WARN`; local spec files (`.claude/spec/`, `docs/superpowers/specs/`) are `INFO` and never moved.

## gws-sync behavior (Step 2, Step 3.5)

The two-step table in `SKILL.md` is the only definition.

- Treating `pending-install` as final would never ask step 2 after the install.
- Treating it as unanswered would ask before the install on every run.
- A repo with a live `.gws-sync.json` is never asked whether it wants Drive at all.

## Memory posture (Step 2)

The axis checks posture consistency: which writers are live and whether their authority is declared. It does not check whether mem0 and `.llmwiki/` hold contradicting versions of a fact; no tool here compares a cloud API with a markdown tree, so say so when reporting.

- `.llmwiki/`: outside knowledge (git-tracked, dated, sourced). Decisions live in `docs/adr/`, terms in `GLOSSARY.md`.
- mem0: recall assistance (cloud, ephemeral). Serena memories: symbol and structure maps. `.claude/rules/`: mechanical tool invariants only.
- When `native_auto_memory_enabled` and `mem0_settings` are both true, mem0's `block_memory_write.sh` PreToolUse hook blocks `Write`/`Edit` to `MEMORY.md`, so the native file loads every session and cannot be updated.

The fix is the user-scope setting `autoMemoryEnabled: false`, outside this repo. Report it, name the change, apply it only on explicit approval and never as part of "apply all". `autoMemoryEnabled` resolves through the settings cascade (user < project < local); unset means native auto-memory is on.

## Report shape (Step 3)

Print a fixed-width table, most severe first, with the remediation on every non-OK row:

```
## Project Wiring — <dir_name>

[WARN] rules       plugin-versioning.md has paths: scoping, but CLAUDE.md @imports it
                   -> scoping is dead; ~2k tokens loaded every session. mechanical fix
[WARN] mcp         7 servers registered twice (~/.claude.json wins, settings.json copy inert)
                   -> context7 deepwiki exa brave mcpdocs notion shadcn-ui
[ASK ] gws-sync    does this project publish deliverables to Drive?  (unanswered)
[ASK ] git         no origin remote — create one?                    (unanswered)
[INFO] codex       approval=never sandbox=danger-full-access -> /codex:rescue edits unprompted
[INFO] codex       AGENTS.md 28,506 / 65,536 B (43%) of the doc budget
[INFO] spec        .claude/spec 8 + docs/superpowers/specs 6 local records — new specs go to the issue tracker
[ OK ] wiki        .llmwiki/wiki/index.md present
[ OK ] serena      onboarded (1 memory)
```

State that the scan is filesystem-only, and name what it leaves to other owners: wiki page staleness, broken links and Sources (`/wiki:lint`); MCP servers left by deleted plugins and unused extensions (the built-in `/doctor`, which reads usage history).

## Recording `ASK` answers (Step 3.5, Step 4)

- Write every answered `ASK` to `.claude/state/wiring.json` under `answers.<key>` with `value` and `answered_at` (UTC `YYYY-MM-DD`), creating the file if absent.
- Write it even when the rest of "apply all" is declined, and never write an answer the user did not give.
- Run `git check-ignore -q .claude/state/wiring.json` before writing. If it fails, add `.claude/state/` to `.gitignore` as a precondition, not as part of "apply all".
- If the user declines that line, do not create the file: report the answer as unrecorded and say why. Outside a git repository the check does not apply.
