# Code Scout Plugin

Find open-source resources and conduct technical research.

## Agents

| Agent | Model | Platforms | Use Case |
|-------|-------|-----------|----------|
| `scout` | haiku | GitHub, HuggingFace | Quick code/model search |
| `deep-scout` | sonnet | 10+ platforms | Comprehensive research |

### scout (Lightweight)

Fast search for code resources and ML assets.

```
Task(
  subagent_type="code-scout:scout",
  model="haiku",
  prompt="Find FastAPI production boilerplate with auth"
)
```

### deep-scout (Comprehensive)

Multi-platform research with synthesis and report generation.

**Platforms**: GitHub, HuggingFace, Reddit, StackOverflow, arXiv, Twitter/X, Threads, Context7, DeepWiki

```
Task(
  subagent_type="code-scout:deep-scout",
  model="sonnet",
  prompt="Research best practices for deploying PyTorch models in production"
)
```

**Modes**:
- **Quick** (default): Single-round parallel search
- **Deep** (add "deep" or "thorough"): Multi-round with cross-validation

## Skill: resource-finder

Search tool for GitHub and Hugging Face. **Portable tools first** (`gh` on
$PATH, `curl` + HF REST, `uvx hf`); skill-internal scripts are optional
wrappers run via `uv run <absolute_path>` (PEP 723 inline deps).

```bash
# GitHub (primary — works from any cwd)
gh search repos "fastapi boilerplate" --sort stars --limit 10

# HuggingFace via REST (no auth, no Python)
curl -sS "https://huggingface.co/api/models?search=yolo&limit=10" | jq

# HuggingFace CLI (bootstraps via uv on demand)
uvx hf search-repos "gradio" --repo-type space --limit 10

# Optional Python wrapper (uv handles venv + deps)
uv run plugins/code-scout/skills/resource-finder/scripts/search_huggingface.py "yolo" --type models
```

## When to Use

| Situation | Agent |
|-----------|-------|
| "Find a starter template" | `scout` |
| "What boilerplate should I use?" | `scout` |
| "Find object detection model" | `scout` |
| "Research deployment options" | `deep-scout` |
| "Compare frameworks" | `deep-scout` |
| "What does the community say about X?" | `deep-scout` |

## Requirements

- `gh` CLI installed and authenticated
- `huggingface_hub` library
- `uv` (for `uvx hf` downloads)

## Tips

1. Use `scout` for quick, targeted searches
2. Use `deep-scout` for comprehensive research
3. Add "deep" keyword for multi-round research
4. Check awesome-* lists first for curated quality
