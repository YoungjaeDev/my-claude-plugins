# Hugging Face Hub Reference

## Installation

```bash
# For uvx hf (no install needed)
uvx hf --help

# Or install huggingface_hub globally
pip install -U huggingface_hub
```

## Authentication

```bash
# Login interactively
uvx hf auth login

# Or set token
export HF_TOKEN="your_token_here"
```

---

# uvx hf CLI Commands

Note: `hf` CLI does NOT have search commands. Use Python API for searching.

## Download Commands

### Download Repository

```bash
# Download entire model
uvx hf download <repo_id>

# Download specific files
uvx hf download <repo_id> --include "*.py"
uvx hf download <repo_id> --include "config.json" --include "*.safetensors"

# Download to specific directory
uvx hf download <repo_id> --local-dir ./my-model

# Download from specific repo type
uvx hf download <repo_id> --repo-type space
uvx hf download <repo_id> --repo-type dataset
```

### Download Examples

```bash
# Download model config (temporary analysis)
uvx hf download microsoft/resnet-50 --include "*.json" --local-dir /tmp/resnet-50

# Download space source code (temporary analysis)
uvx hf download Qwen/Qwen3-VL-Demo --repo-type space --include "*.py" --local-dir /tmp/qwen3-vl-demo

# Download specific file
uvx hf download Qwen/Qwen2.5-VL-7B-Instruct config.json --local-dir /tmp/qwen-config
```

**Note**: Always use `--local-dir /tmp/` for temporary code analysis to avoid cluttering the project.

## Repository Commands

```bash
# View repo info
uvx hf repo info <repo_id>

# List files in repo
uvx hf repo-files list <repo_id>

# Create new repo
uvx hf repo create <repo_name>
uvx hf repo create <repo_name> --type space
```

## Upload Commands

```bash
# Upload file
uvx hf upload <repo_id> <local_path> <path_in_repo>

# Upload folder
uvx hf upload <repo_id> ./local_folder
```

---

# Python API (huggingface_hub) - For Searching

## Basic Setup

```python
from huggingface_hub import HfApi

api = HfApi()
```

## Search Models

```python
# Basic search
models = list(api.list_models(search="object detection", limit=10))

# With filters
models = list(api.list_models(
    search="qwen vl",
    task="image-text-to-text",
    sort="downloads",
    direction=-1,
    limit=20
))

# Print results
for m in models:
    print(f"{m.id}: {m.downloads:,} downloads")
```

### Model Tasks

Common task filters:
- `object-detection`
- `image-segmentation`
- `image-classification`
- `image-text-to-text`
- `text-generation`

## Search Datasets

```python
datasets = list(api.list_datasets(search="coco", limit=10))

for d in datasets:
    print(f"{d.id}: {d.downloads:,} downloads")
```

## Search Spaces

```python
spaces = list(api.list_spaces(search="gradio demo", limit=10))

# Filter by SDK
spaces = list(api.list_spaces(
    search="object detection",
    sdk="gradio",
    sort="likes",
    direction=-1,
    limit=20
))

for s in spaces:
    print(f"{s.id}: {s.likes} likes, SDK: {s.sdk}")
```

## Download Files (Python)

```python
from huggingface_hub import hf_hub_download

# Download model file
file_path = hf_hub_download(
    repo_id="microsoft/resnet-50",
    filename="config.json"
)

# Download from space
file_path = hf_hub_download(
    repo_id="Qwen/Qwen3-VL-Demo",
    filename="app.py",
    repo_type="space"
)
```

## List Repository Files

```python
# List model files
files = api.list_repo_files("microsoft/resnet-50")

# List space files
files = api.list_repo_files("Qwen/Qwen3-VL-Demo", repo_type="space")
```

---

# Web URLs

## Direct Access

```
Models:   https://huggingface.co/{model_id}
Datasets: https://huggingface.co/datasets/{dataset_id}
Spaces:   https://huggingface.co/spaces/{space_id}
```

## View Files

```
https://huggingface.co/{model_id}/tree/main
https://huggingface.co/spaces/{space_id}/tree/main
```

## Raw File Access

```
https://huggingface.co/{model_id}/raw/main/{filename}
https://huggingface.co/spaces/{space_id}/raw/main/app.py
```

---

# Common Patterns

## Search + Download Workflow

```bash
# 1. Search for spaces (using script)
python scripts/search_huggingface.py "qwen vl" --type spaces

# 2. Download the source code (to /tmp/ for temporary analysis)
uvx hf download Qwen/Qwen3-VL-Demo --repo-type space --include "*.py" --local-dir /tmp/qwen-demo
```

## Analyze Space Implementation

```bash
# Download app.py and requirements (to /tmp/)
uvx hf download username/space-name --repo-type space --include "app.py" --include "requirements.txt" --local-dir /tmp/space-code

# Read the code
cat /tmp/space-code/app.py
```

---

# Rate Limits

- Anonymous: 1,000 requests/hour
- Authenticated: 10,000 requests/hour
