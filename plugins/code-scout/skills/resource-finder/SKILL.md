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

## Supported Platforms

| Platform | Search Targets | Tool |
|----------|---------------|------|
| **GitHub** | Repositories, Code, Templates | `gh` CLI |
| **Hugging Face** | Models, Datasets, Spaces | `huggingface_hub` API |

## Use Cases

| Goal | What to Search | Example Query |
|------|----------------|---------------|
| **Start new project** | boilerplate, template, starter | `"fastapi production boilerplate"` |
| **Find implementation pattern** | Similar projects, reference code | `"oauth2 implementation python"` |
| **Discover ML resources** | Models, datasets, demo apps | `"object detection gradio demo"` |
| **Learn best practices** | awesome-* curated lists | `"awesome fastapi"` |

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

Search from 2-3 perspectives if initial results aren't sufficient:

```bash
# Framework focus
gh search repos "fastapi boilerplate" --sort stars

# Feature focus
gh search repos "python api authentication jwt" --sort stars

# Template focus
gh search repos "cookiecutter fastapi" --sort stars
```

### 4. Use Quality Filters

```bash
# Recent + quality filter
gh search repos "keyword" stars:>50 pushed:>2024-01-01 --language python
```

## Scripts

**Run with `--help` first** to see usage options.

### Available Scripts

| Script | Purpose |
|--------|---------|
| `scripts/search_github.py` | GitHub repository search |
| `scripts/search_huggingface.py` | HuggingFace models/datasets/spaces search |

### Quick Examples

```bash
# GitHub - find boilerplates
python scripts/search_github.py "fastapi boilerplate" --limit 10

# HuggingFace - find models
python scripts/search_huggingface.py "object detection" --type models --limit 10

# HuggingFace - find demo apps
python scripts/search_huggingface.py "gradio demo" --type spaces --limit 10
```

## GitHub Search

### Finding Starter Templates

```bash
# Production-ready boilerplates
gh search repos "fastapi boilerplate production ready" --sort stars
gh search repos "react typescript starter template" --sort stars
gh search repos "pytorch lightning project template" --sort stars

# Cookiecutter templates (Python ecosystem)
gh search repos "cookiecutter ml project" --sort stars
gh search repos "cookiecutter fastapi" --sort stars
```

| Keyword | What You Get |
|---------|--------------|
| `boilerplate` | Production-ready project structure |
| `starter`, `starter-kit` | Minimal setup to get running |
| `template` | Reusable project scaffolding |
| `scaffold` | Code generation base |
| `cookiecutter` | Python templating system |

### Curated Lists (awesome-*)

Community-curated high-quality resources. **Start here before deep-diving:**

```bash
gh search repos "awesome object-detection" --sort stars
gh search repos "awesome fastapi" --sort stars
gh search repos "awesome gradio" --sort stars
```

**Why use awesome lists:**
- Pre-vetted quality (community-curated)
- Categorized by use case
- Often includes hidden gems

### Repository Analysis

After finding a repository:

1. Review README.md for usage
2. Check main entry points (app.py, main.py)
3. Review dependencies (requirements.txt, pyproject.toml)
4. Study implementation patterns

### Using gh CLI

```bash
# Search repos
gh search repos "keyword" --sort stars --limit 10

# Filter by language
gh search repos "gradio app" --language python

# View repo details
gh repo view owner/repo

# Search code
gh search code "Qwen2VL" --extension py
```

## Hugging Face Search

### Search Commands

```bash
# Models
python scripts/search_huggingface.py "object detection" --type models

# Datasets
python scripts/search_huggingface.py "coco" --type datasets

# Spaces (demos)
python scripts/search_huggingface.py "gradio demo" --type spaces

# All types
python scripts/search_huggingface.py "qwen vl" --type all
```

### Download for Analysis

```bash
# Download space source code (use /tmp/ for temporary)
uvx hf download <space_id> --repo-type space --include "*.py" --local-dir /tmp/<name>

# Download model files
uvx hf download <repo_id> --include "*.json" --local-dir /tmp/<name>
```

**Note**: Always use `/tmp/` for temporary code analysis.

### Analyzing a Space

1. Find space: `python scripts/search_huggingface.py "keyword" --type spaces`
2. Download: `uvx hf download <space_id> --repo-type space --include "*.py" --local-dir /tmp/<name>`
3. Focus on `app.py` for main logic
4. Check `requirements.txt` for dependencies

## Example Workflows

### Starting a New FastAPI Project

```bash
# 1. Find boilerplates
gh search repos "fastapi boilerplate production" --sort stars --limit 5

# 2. Check awesome list
gh search repos "awesome fastapi" --sort stars

# 3. Analyze top result
gh repo view tiangolo/full-stack-fastapi-template
```

### Finding ML Demo Patterns

```bash
# 1. Search Spaces
python scripts/search_huggingface.py "object detection gradio" --type spaces

# 2. Download for analysis
uvx hf download <space_id> --repo-type space --include "*.py" --local-dir /tmp/demo

# 3. Study app.py
cat /tmp/demo/app.py
```

## Tips

1. **Start with awesome-* lists** for curated quality
2. **Use stars + recency filters** for maintained projects
3. **Download selectively** with `--include` patterns
4. **Check activity** - recently updated repos are better maintained
5. **Cite sources** - include URLs you referenced

## Resources

- `scripts/` - Python search wrappers
- `references/` - CLI detailed references
