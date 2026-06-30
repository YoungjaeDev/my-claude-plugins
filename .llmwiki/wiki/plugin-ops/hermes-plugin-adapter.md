---
id: hermes-plugin-adapter
aliases: [hermes-adapter, plugin-yaml, hermes-native-plugin, skill-view-optin, hermes-third-runtime]
last_verified: 2026-06-30
status: active
volatility: stable
sources: 3
---

# Hermes native plugin adapter (third runtime)

The shared-source `plugins/<name>/` tree is read by a **third** runtime, Hermes
Agent — alongside Claude Code (native) and Codex 0.135 (generated
`.codex-plugin/plugin.json`). Hermes consumes the same tree in place via a
hand-written native adapter, not the Codex manifest generator and not the
`npx skills` install path. `github-dev` is the pilot plugin.

> See-also: [[shared-source-codex-manifests]]
> See-also: [[skills-install-wrapper]]

## The adapter = two files in the plugin root

A plugin becomes Hermes-installable by adding, next to its existing
`.claude-plugin/` and `.codex-plugin/` manifests:

- `plugin.yaml` — Hermes manifest. `name`, `version`, `kind: standalone`.
- `__init__.py` — Python entrypoint Hermes loads.

Install a single plugin from a monorepo subdirectory:

```bash
hermes plugins install <owner>/<repo>/plugins/<name> --enable
hermes gateway restart   # if Hermes runs behind a messaging gateway
```

Before the adapter existed, this install **completed with a warning** — the
plugin had Claude/Codex manifests but no Hermes `plugin.yaml` / entrypoint, so
Hermes registered nothing. The adapter is a thin wrapper; existing Claude/Codex
behavior is untouched.

(Version-sync mechanics — `plugin.yaml` `version` must match
`plugin.json` / `marketplace.json` and is not caught by
`sync-codex-manifests.mjs --check` — live in `.claude/rules/plugin-versioning.md`,
not here.)

## Skills are opt-in: `skill_view`, not bare invocation

Hermes plugin-provided skills are **not** auto-exposed in the system prompt or
`skills_list`. A caller must explicitly load the qualified skill:

```text
skill_view("github-dev:resolve-issue")
skill_view("github-dev:cr-fix")
```

Consequences:

- Quickstart / README examples must show `skill_view("<plugin>:<skill>")`, never
  a bare `github-dev:resolve-issue ...` text/slash line — bare input does **not**
  deterministically load the skill.
- Start a **fresh Hermes session** after `--enable` so the plugin skill registry
  is rebuilt.

## Runtime-portable bodies (extends the shared-source rule)

The same skill bodies run under all three runtimes, so they carry a Hermes
compatibility block mapping Claude/Codex tool names to Hermes tools:

| Claude / Codex | Hermes |
|---|---|
| `Bash` | `terminal` |
| `Read` | `read_file` |
| `Edit` | `patch` |
| `AskUserQuestion` | `clarify` |
| `Task` | `delegate_task` |
| `Monitor` | `process` |

Bodies that shell out to bundled scripts resolve `SKILL_DIR` in order —
source tree → `$HERMES_HOME/plugins/<name>/...` → `~/.hermes/plugins/<name>/...` —
so one body works whether the plugin runs from the repo or from a Hermes install.

## Sources

- PR #83 (merged `b5021b4`) — adds `plugin.yaml` + `__init__.py` to `github-dev`, registers its 8 workflows as Hermes skills, adds the tool-name map + dynamic `SKILL_DIR`.
- `plugins/github-dev/plugin.yaml`, `plugins/github-dev/__init__.py`, `plugins/github-dev/CLAUDE.md` (Hermes Agent section).
- Hermes docs — plugin-provided skills are opt-in, loaded via `skill_view("plugin:skill")`.
