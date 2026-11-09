# Resource Finder

Shared hygiene reference for `github-scout` and `hf-scout`. Tool-specific call patterns and reliability rubrics live in each scout's agent file — this reference is the cross-axis cheat-sheet.

## Tool priority

Primary tools are portable CLIs on `$PATH`, not skill-internal scripts. Prefer the direct tools first:

| Platform | Primary (cwd-free, no Python) | Fallback (structured JSON) |
|---|---|---|
| GitHub | `gh search repos` / `gh search code` / `gh repo view` | `uv run <abs>/scripts/search_github.py` |
| Hugging Face | `curl https://huggingface.co/api/...` (+ `uvx hf {models\|spaces\|datasets} ls/search/info`) | `uv run <abs>/scripts/search_huggingface.py` |

`<abs>` resolves in order: `$CLAUDE_PLUGIN_ROOT/skills/research-orchestrator` when that env var is set (Claude Code), the source tree `plugins/scout/skills/research-orchestrator` when running inside this repo, else the newest Codex plugin cache entry (`ls -1d "${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"/*/scout/*/skills/research-orchestrator`, pick the highest version whose `scripts/` exists). Use absolute paths to avoid cwd surprises; if none of the three resolves, stay on the primary portable CLIs above — the wrappers are an optional fallback.

## Search hygiene

### 1. Verify current date

```bash
date +%Y-%m-%d
```

Use the current year in queries for recency filtering. Don't hard-code last year.

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
uvx hf download <repo_id> --include "*.json" --local-dir "$WORKSPACE/dl/<name>"     # config only
uvx hf download <space_id> --repo-type space --include "*.py" --local-dir "$WORKSPACE/dl/<name>"
```

For keyword search across models or datasets, the REST endpoints above are simpler than the CLI.

Download into `$WORKSPACE/dl/` (under the gitignored `.tmp/research/` run directory), never into the tracked tree.

## Optional Python wrappers

Use them only when you want JSON filtering beyond what `gh` flags or `curl + jq` support. PEP 723 inline metadata lets `uv` run them from anywhere, with `<abs>` resolved as in "Tool priority" above:

```bash
uv run "<abs>/scripts/search_github.py" "fastapi boilerplate" --limit 10 --detailed
uv run "<abs>/scripts/search_huggingface.py" "object detection" --type models --limit 10
```

- **`search_github.py`**: stdlib only.
- **`search_huggingface.py`**: the first run installs `huggingface_hub` in an ephemeral venv via `uv`.
- **Citation discipline**: every result a scout emits carries the canonical URL the user can click (`https://github.com/<owner>/<repo>` or `https://huggingface.co/<repo_id>`). Never paraphrase a finding without its source.

## Requirements and flag reference

- `gh` CLI authenticated (primary for GitHub), `uv` (HF deps and the wrappers), `jq` (REST responses), Python 3.11+ through `uv run`.
- For flags and JSON fields not shown here, read the live help rather than a copy: `gh search repos --help`, `gh repo view --help`, `uvx hf <command> --help`, <https://cli.github.com/manual/> and <https://huggingface.co/docs/huggingface_hub/en/guides/cli>.
- JSON field names differ by command: `gh search repos --json` takes `stargazersCount`, `gh repo view --json` takes `stargazerCount`.
