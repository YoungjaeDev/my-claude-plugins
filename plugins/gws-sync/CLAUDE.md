# gws-sync Plugin

Local folder → Google Drive **one-way, proposal-based sync**. Built on the gws
CLI (the official googleworkspace/cli) — it calls the CLI, not an MCP server.
Authentication (`gws auth login`) is a prerequisite.

## Skill

| Skill | Description |
|-------|-------------|
| `gws-sync` | Remembers the mapping config (`.gws-sync.json`) → walks the Drive tree → produces a new/changed diff report → **requires AskUserQuestion approval of the upload location** → uploads (existing files use a content update, preserving the file ID, share link, and version history). Deletion is proposal-only. |

## Design principles (hard rules)

1. **One-way** — local → Drive only. Drive-side changes are never pulled back down to local.
2. **Proposal-based** — every write happens only after a diff report plus user approval.
3. **No automatic deletion** — orphaned Drive files are proposed as a list, never deleted.
4. **Update ≠ re-upload** — updating an existing file uses `files update --upload` (keeping the ID). It never creates a new file that would break the link.

## Dependencies

- The `gws` CLI is **required** — if it is missing, print install guidance (`npm install -g @googleworkspace/cli` + github.com/googleworkspace/cli) and stop. Do not install it automatically.
- `references/gws-skills-llms.txt` — a catalog of the 54 official skills + 41 recipes. An index for proposing an uninstalled skill/recipe that fits the user's situation, via an `npx skills add` line.

## Structure

```text
gws-sync/
├── .claude-plugin/plugin.json
├── CLAUDE.md                    # this file
└── skills/gws-sync/
    ├── SKILL.md                 # 0. prerequisite check → 1. mapping config → 2. location approval → 3. diff → approval → upload
    └── references/gws-skills-llms.txt
```
