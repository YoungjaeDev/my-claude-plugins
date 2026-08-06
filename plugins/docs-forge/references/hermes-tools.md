# Hermes tool mapping — docs-forge

`docs-forge` is in `HERMES_ELIGIBLE` (`scripts/manifest-eligibility.mjs`), so the generated adapter registers every skill under this plugin as `docs-forge:<skill>`. Skill bodies name Claude/Codex tools, which are identical on those two runtimes; Hermes exposes different ones.

Read this table when running any `docs-forge` skill under Hermes.

| Claude/Codex term | Hermes tool |
|---|---|
| `Bash` | `terminal` |
| `Read` | `read_file` |
| `Write` | `write_file` |
| `Edit` | `patch` |
| `Glob` / `Grep` | `search_files` |
| `AskUserQuestion` | `clarify` |
| `Task` (subagent) | `delegate_task` |
| `Skill` | `skill_view` |

Two load-contract notes, both easy to get wrong:

- **Plugin skills are explicit opt-in loads.** Hermes never surfaces a body from its `description` the way Claude Code and Codex index skills. Call `skill_view("docs-forge:<skill>")` after `--enable` in a fresh session. A body that assumes it was auto-selected is wrong here.
- **`clarify` is the interaction gate.** Where a skill says "ask the user" via `AskUserQuestion`, Hermes must route it through `clarify` rather than printing the question and proceeding — the confirmation is the point, not the prose.

Skills carrying no tool usage at all (`readme-guide`, `moc-guide`, `deploy-doc-guide`) are pure reference and need no mapping.
