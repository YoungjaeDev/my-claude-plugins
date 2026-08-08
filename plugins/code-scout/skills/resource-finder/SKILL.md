---
name: resource-finder
description: |
  Shared search hygiene + cwd-free GitHub / Hugging Face query reference for
  code-scout's github-scout and hf-scout agents. Date anchoring, multi-query
  patterns, quality filters, and the optional Python wrappers for richer JSON
  output. Use when authoring a query that runs through `gh` or HF REST and you
  want the canonical cheat-sheet.
---

# Resource Finder

## Hermes Agent Compatibility

When this skill is loaded through Hermes as `code-scout:resource-finder`, map Claude/Codex tool names to
Hermes tools:

| Claude/Codex term | Hermes tool |
|---|---|
| `Bash` | `terminal` |
| `Write` | `write_file` |

Plugin skills are explicit opt-in loads in Hermes — call `skill_view("code-scout:resource-finder")` after
`--enable` in a fresh session; the description never surfaces this body on its own.


Shared hygiene reference for `github-scout` and `hf-scout`. Tool-specific call patterns and reliability rubrics live in each scout's agent file — this skill is the cross-axis cheat-sheet.

## Tool priority

Primary tools are **portable CLIs on `$PATH`**, not skill-internal scripts. Prefer the direct tools first:

| Platform | Primary (cwd-free, no Python) | Fallback (structured JSON) |
|---|---|---|
| GitHub | `gh search repos` / `gh search code` / `gh repo view` | `uv run <abs>/scripts/search_github.py` |
| Hugging Face | `curl https://huggingface.co/api/...` (+ `uvx hf {models\|spaces\|datasets} ls/search/info`) | `uv run <abs>/scripts/search_huggingface.py` |

`<abs>` resolves to `plugins/code-scout/skills/resource-finder` in Claude Code (repo-rooted) or `~/.agents/skills/resource-finder` in Codex (after sync). Use absolute paths to avoid cwd surprises.

## Search hygiene

### 1. Verify current date

```bash
date +%Y-%m-%d
```

Use the **current year** in queries for recency filtering. Don't hard-code last year.

### 2. Natural query formulation

Write queries as you would ask a person:

| Intent | Query style | Example |
|---|---|---|
| Find starter | "boilerplate" + stack | `react typescript starter template` |
| Find implementation | "how to" + task | `how to implement websocket in fastapi` |
| Compare options | `vs` / `comparison` | `YOLOv8 vs RT-DETR 2026` |
| Find demo | task + `demo` | `image segmentation gradio demo` |

### 3. Multi-query approach

Search from 2-3 angles when the first query is thin:

```bash
gh search repos "fastapi boilerplate" --sort stars
gh search repos "python api authentication jwt" --sort stars
gh search repos "cookiecutter fastapi" --sort stars
```

### 4. Quality filters

```bash
# Embed qualifiers inside the quoted query string — leaving stars:>50 unquoted in
# the shell makes Bash treat `>` as a redirection and silently drops the filter.
gh search repos "keyword stars:>50 pushed:>2026-01-01" --language python --sort stars
```

For HF, use `?sort=downloads&direction=-1` on the REST endpoint to surface mature models first.

## GitHub cheat-sheet (`gh` CLI)

`gh` is installed and authenticated on the user's environment. Every query works from any directory.

```bash
# Starter templates / boilerplates
gh search repos "fastapi boilerplate production ready" --sort stars --limit 10
gh search repos "cookiecutter ml project" --sort stars

# Curated awesome-lists (check first for high-signal pre-filtered links)
gh search repos "awesome object-detection" --sort stars

# Repository inspection
gh repo view <owner>/<repo>                                  # README + stats
gh repo view <owner>/<repo> --json description,stargazerCount,pushedAt,primaryLanguage

# Code search (pattern discovery)
gh search code "Qwen2VL" --extension py --limit 20
gh search code "from huggingface_hub import" --language python
```

Keyword vocabulary:

| Keyword | Outcome |
|---|---|
| `boilerplate` | Production-ready project structure |
| `starter`, `starter-kit` | Minimal setup to get running |
| `template` | Reusable project scaffolding |
| `scaffold` | Code generation base |
| `cookiecutter` | Python templating system |

## Hugging Face cheat-sheet (`uvx hf` + REST)

### Public REST (no auth)

```bash
# Models
curl -sS "https://huggingface.co/api/models?search=object+detection&limit=10" | jq

# Datasets
curl -sS "https://huggingface.co/api/datasets?search=coco&limit=5" | jq

# Spaces (demos)
curl -sS "https://huggingface.co/api/spaces?search=gradio+demo&limit=10" | jq

# Sorted by downloads
curl -sS "https://huggingface.co/api/models?search=qwen+vl&sort=downloads&direction=-1&limit=10" \
  | jq '.[] | {id, downloads, likes}'
```

### `uvx hf` (official CLI)

The top-level `hf` CLI groups commands by repo type — there is no `hf search-repos`. Use the per-type subcommands instead:

```bash
# Models — list with sort + filter
uvx hf models ls --sort downloads --limit 10
uvx hf models info <repo_id>                      # full metadata for a single model

# Spaces — has real semantic search
uvx hf spaces search "object detection gradio" --limit 10

# Datasets — list (no search subcommand; use REST API above for keyword search)
uvx hf datasets ls --limit 10
uvx hf datasets info <repo_id>

# Downloads (any repo type via --repo-type)
uvx hf download <repo_id> --include "*.json" --local-dir /tmp/<name>     # config only
uvx hf download <space_id> --repo-type space --include "*.py" --local-dir /tmp/<name>
```

For keyword search across models or datasets, the REST endpoints above are simpler than the CLI.

Download into `/tmp/` — always temporary, outside the repo root.

## Optional Python wrappers

Use only when you want JSON filtering beyond what `gh` flags / `curl + jq` support. PEP 723 inline metadata lets `uv` run them from anywhere:

```bash
# Claude Code
uv run plugins/code-scout/skills/resource-finder/scripts/search_github.py \
    "fastapi boilerplate" --limit 10 --detailed

uv run plugins/code-scout/skills/resource-finder/scripts/search_huggingface.py \
    "object detection" --type models --limit 10

# Codex (after codex-bridge sync)
uv run ~/.agents/skills/resource-finder/scripts/search_huggingface.py \
    "object detection" --type models --limit 10
```

First HF wrapper run installs `huggingface_hub` in an ephemeral venv via `uv`.

## Citation discipline

Every result a scout emits must carry the canonical URL the user can click — `https://github.com/<owner>/<repo>` or `https://huggingface.co/<repo_id>`. Never paraphrase a finding without its source.

## Requirements

- `gh` CLI authenticated — primary for GitHub
- `uv` — auto-installs HF deps, runs wrapper scripts portably
- `jq` — JSON parsing for REST responses
- Python 3.11+ (resolved via `uv run`; no direct `python` call needed)

## Resources

- `scripts/search_github.py` — optional wrapper (stdlib only, PEP 723)
- `scripts/search_huggingface.py` — optional wrapper (`huggingface_hub`, PEP 723)
- `references/` — CLI flag references
