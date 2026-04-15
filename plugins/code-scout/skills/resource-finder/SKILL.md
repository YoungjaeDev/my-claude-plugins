---
name: resource-finder
description: |
  Search and discover open-source resources: boilerplates, starter templates,
  reference implementations on GitHub, and ML models/datasets/demos on Hugging Face.
  Use when starting new projects, finding code patterns, or discovering ML resources.
---

# Resource Finder

## Overview

Find open-source resources for your projects:
- **Boilerplates & Templates**: Production-ready project starters
- **Reference Implementations**: Learn from existing code patterns
- **ML Resources**: Models, datasets, and demo apps on Hugging Face

## Tool Priority (Important)

Primary tools are **portable CLIs on `$PATH`**, not skill-internal scripts.
Skill scripts (`scripts/*.py`) are advanced wrappers with extra filters; they
require cwd=skill-root OR an absolute path, and they need `uv`/`python3`
available. Prefer the direct tools first:

| Platform | Primary (cwd-free, no Python) | Fallback (structured output) |
|----------|-------------------------------|------------------------------|
| **GitHub** | `gh search repos` / `gh search code` / `gh repo view` | `uv run <abs>/scripts/search_github.py` |
| **Hugging Face** | `uvx hf search` (+ `curl https://huggingface.co/api/...`) | `uv run <abs>/scripts/search_huggingface.py` |

`<abs>` resolves to `plugins/code-scout/skills/resource-finder` in Claude Code
(repo-rooted) or `~/.agents/skills/resource-finder` in Codex (after sync). Use
the absolute path to avoid cwd surprises.

## Search Quality Principles

### 1. Verify Current Date

```bash
date +%Y-%m-%d
```

Use **current year** in searches for recency filtering.

### 2. Natural Query Formulation

Write queries as you would ask a person:

| Intent | Query Style | Example |
|--------|-------------|---------|
| **Find starter** | "boilerplate" + stack | `"react typescript starter template"` |
| **Find implementation** | "how to" + task | `"how to implement websocket in fastapi"` |
| **Compare options** | "vs" / "comparison" | `"YOLOv8 vs RT-DETR 2024"` |
| **Find demo** | task + "demo" | `"image segmentation gradio demo"` |

### 3. Multi-Query Approach

Search from 2-3 perspectives when initial results aren't sufficient:

```bash
gh search repos "fastapi boilerplate" --sort stars
gh search repos "python api authentication jwt" --sort stars
gh search repos "cookiecutter fastapi" --sort stars
```

### 4. Quality Filters

```bash
gh search repos "keyword" stars:>50 pushed:>2026-01-01 --language python --sort stars
```

## GitHub Search (primary: `gh` CLI)

`gh` is installed and authenticated on the user's environment. Every query
below works from any directory.

### Starter Templates & Boilerplates

```bash
gh search repos "fastapi boilerplate production ready" --sort stars --limit 10
gh search repos "react typescript starter template" --sort stars --limit 10
gh search repos "pytorch lightning project template" --sort stars --limit 10

# Cookiecutter (Python-native scaffolding)
gh search repos "cookiecutter ml project" --sort stars
gh search repos "cookiecutter fastapi" --sort stars
```

| Keyword | Outcome |
|---------|---------|
| `boilerplate` | Production-ready project structure |
| `starter`, `starter-kit` | Minimal setup to get running |
| `template` | Reusable project scaffolding |
| `scaffold` | Code generation base |
| `cookiecutter` | Python templating system |

### Curated Lists (awesome-*)

Community-curated quality. Check first before deep-diving:

```bash
gh search repos "awesome object-detection" --sort stars
gh search repos "awesome fastapi" --sort stars
gh search repos "awesome gradio" --sort stars
```

### Repository Analysis

After finding a candidate:

1. `gh repo view <owner>/<repo>` — README + stats
2. `gh repo view <owner>/<repo> --json description,stargazerCount,pushedAt`
3. Clone or `gh browse` specific files (app.py, pyproject.toml, requirements.txt)

### Code Search

```bash
gh search code "Qwen2VL" --extension py --limit 20
gh search code "from huggingface_hub import" --language python
```

### Advanced Wrapper (optional)

Use the Python wrapper only when you want JSON filtering that `gh` flags don't
support natively. PEP 723 inline metadata lets `uv` run it from anywhere:

```bash
# Claude Code context
uv run plugins/code-scout/skills/resource-finder/scripts/search_github.py \
    "fastapi boilerplate" --limit 10 --detailed

# Codex context (after sync)
uv run ~/.agents/skills/resource-finder/scripts/search_github.py \
    "fastapi boilerplate" --limit 10 --detailed
```

## Hugging Face Search (primary: `uvx hf` + REST API)

### Quick REST API (no auth needed for public search)

```bash
# Models
curl -sS "https://huggingface.co/api/models?search=object+detection&limit=10" | jq

# Datasets
curl -sS "https://huggingface.co/api/datasets?search=coco&limit=5" | jq

# Spaces (demos)
curl -sS "https://huggingface.co/api/spaces?search=gradio+demo&limit=10" | jq
```

### `uvx hf` (official CLI, bootstrapped via uv on demand)

```bash
uvx hf search-repos "object detection" --repo-type model --limit 10
uvx hf download <repo_id> --include "*.json" --local-dir /tmp/<name>
```

### Download Source for Analysis

```bash
# Space source code (for pattern study)
uvx hf download <space_id> --repo-type space --include "*.py" --local-dir /tmp/<name>

# Model config only (lightweight)
uvx hf download <repo_id> --include "*.json" --local-dir /tmp/<name>
```

Always write downloads under `/tmp/` (temporary, outside repo root).

### Advanced Wrapper (optional)

When tag filters or structured output helps:

```bash
# Claude Code
uv run plugins/code-scout/skills/resource-finder/scripts/search_huggingface.py \
    "object detection" --type models --limit 10

# Codex (after sync)
uv run ~/.agents/skills/resource-finder/scripts/search_huggingface.py \
    "object detection" --type models --limit 10
```

First run may take a moment — `uv` installs `huggingface_hub` in an ephemeral
venv (PEP 723 metadata declares the dep).

## Example Workflows

### Starting a New FastAPI Project

```bash
gh search repos "fastapi boilerplate production" --sort stars --limit 5
gh search repos "awesome fastapi" --sort stars
gh repo view tiangolo/full-stack-fastapi-template
```

### Finding ML Demo Patterns

```bash
# Search Spaces (primary)
curl -sS "https://huggingface.co/api/spaces?search=object+detection+gradio&limit=5" | jq '.[] | {id, likes, sdk}'

# Or via CLI
uvx hf search-repos "object detection gradio" --repo-type space --limit 5

# Study app.py
uvx hf download <space_id> --repo-type space --include "*.py" --local-dir /tmp/demo
cat /tmp/demo/app.py
```

### Comparing Model Families

```bash
# 1. Find candidates via REST
curl -sS "https://huggingface.co/api/models?search=qwen+vl&limit=10" | jq '.[].id'

# 2. Check downloads/likes (ranked)
curl -sS "https://huggingface.co/api/models?search=qwen+vl&sort=downloads&direction=-1&limit=10" \
    | jq '.[] | {id, downloads, likes}'

# 3. Official repo for docs
gh repo view QwenLM/Qwen2-VL
```

## Tips

1. **Start with `gh search` and `curl .../api/`** — they work anywhere, no Python
2. **`awesome-*` lists first** for curated high-signal resources
3. **Stars + recency filters** (`pushed:>YYYY-MM-DD`, `stars:>50`) surface maintained projects
4. **Download selectively** with `--include` glob patterns
5. **Cite sources** — include URLs in final output

## Requirements

- `gh` CLI (authenticated) — primary for GitHub
- `uv` — auto-installs HF deps, runs scripts portably
- `jq` — JSON parsing for REST responses
- Python 3.11+ (resolved via `uv run`; no direct `python` call needed)

## Resources

- `scripts/search_github.py` — optional wrapper (stdlib only, PEP 723)
- `scripts/search_huggingface.py` — optional wrapper (`huggingface_hub`, PEP 723)
- `references/` — CLI flag references
