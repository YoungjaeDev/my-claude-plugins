# publish Plugin

## translate-web-article (흡수: translator)

Translate web articles to Korean markdown with intelligent image captioning.

### Skill

| Skill | Description |
|-------|-------------|
| `translate-web-article` | Web page to Korean markdown conversion |

### Features

- Fetch web pages via Bright Data MCP (`scrape_as_markdown`), with the `bdata` CLI as the terminal fallback
- Translate text to natural Korean
- Keep technical terms in English
- VLM analysis for image captions
- Preserve code blocks and tables with Korean explanations

### Triggers

- "translate web page"
- "blog to Korean"
- "translate this article"

### Usage

```
/publish:translate-web-article https://example.com/blog-post
```

### Workflow

1. Fetch page via Bright Data
2. Ask user for output directory and image options
3. Translate text (keep tech terms)
4. Analyze images with VLM for Korean captions
5. Generate markdown file

### Requirements

- Bright Data MCP configured, or the `bdata` CLI installed and authenticated with a default zone (see the `brightdata-guide` preflight)
- VLM capability for image analysis

### Output

```
{output_dir}/
├── {article_name}.md    # Translated markdown
└── images/              # Downloaded images (optional)
```

## gws-sync (흡수: gws-sync)

Local folder → Google Drive **one-way, proposal-based sync**. Built on the gws
CLI (the official googleworkspace/cli) — it calls the CLI, not an MCP server.
Authentication (`gws auth login`) is a prerequisite.

### Skill

| Skill | Description |
|-------|-------------|
| `gws-sync` | Remembers the mapping config (`.gws-sync.json`) → walks the Drive tree → produces a new/changed diff report → **requires AskUserQuestion approval of the upload location** → uploads (existing files use a content update, preserving the file ID, share link, and version history). Deletion is proposal-only. |

### Design principles (hard rules)

1. **One-way** — local → Drive only. Drive-side changes are never pulled back down to local.
2. **Proposal-based** — every write happens only after a diff report plus user approval.
3. **No automatic deletion** — orphaned Drive files are proposed as a list, never deleted.
4. **Update ≠ re-upload** — updating an existing file uses `files update --upload` (keeping the ID). It never creates a new file that would break the link.

### Dependencies

- The `gws` CLI is **required** — if it is missing, print install guidance (`npm install -g @googleworkspace/cli` + github.com/googleworkspace/cli) and stop. Do not install it automatically.
- `references/gws-skills-llms.txt` — a catalog of the 54 official skills + 41 recipes. An index for proposing an uninstalled skill/recipe that fits the user's situation, via an `npx skills add` line.

### Structure

```text
gws-sync/
├── .claude-plugin/plugin.json
├── CLAUDE.md                    # this file
└── skills/gws-sync/
    ├── SKILL.md                 # 0. prerequisite check → 1. mapping config → 2. location approval → 3. diff → approval → upload
    └── references/gws-skills-llms.txt
```
