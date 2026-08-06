# ML Toolkit Plugin

Machine Learning and AI development skills.

## Skills

| Skill | Description |
|-------|-------------|
| `gpu-parallel-pipeline` | Design PyTorch GPU parallel processing pipelines |
| `gradio-cv-app` | Create professional Gradio computer vision apps |
| `cv-notebook` | Generate production-quality Computer Vision Jupyter notebooks |
| `cv-explorer` | Generate interactive CV data exploration notebooks with ipywidgets |
| `ml-dev-principles` | General ML/multimodal/CV working discipline (how to work, not which library) |
| `edit-notebook` | Safe Jupyter notebook editing (absorbed from `notebook`) |

## gpu-parallel-pipeline

Design and implement PyTorch GPU parallel processing for maximum throughput.

**Triggers**: "multi-GPU", "GPU parallel", "batch inference", "CUDA isolation", "ProcessPool GPU"

**Capabilities**:
- Multi-GPU scaling (ProcessPool, CUDA_VISIBLE_DEVICES isolation)
- Single GPU optimization (CUDA Streams, async inference, model batching)
- I/O + compute pipelines (ThreadPool for loading, batch inference)

## gradio-cv-app

Create professional Gradio computer vision applications with Editorial design.

**Triggers**: "OCR app", "image classification", "object detection", "segmentation app"

**Capabilities**:
- PRITHIVSAKTHIUR-style Editorial design
- OCR, classification, generation, segmentation, editing, captioning, detection
- Professional UI/UX for CV demos

## cv-notebook

Generate production-quality Computer Vision Jupyter notebooks.

**Triggers**: "CV notebook", "detection notebook", "segmentation notebook", "classification notebook", "VLM notebook", "train YOLO notebook", "fine-tune notebook"

**Capabilities**:
- Detection (YOLO, RT-DETR), Segmentation (SAM, YOLO-Seg), Classification (DINOv2), VLM (Florence-2, PaliGemma, Qwen2.5-VL)
- Roboflow dataset integration and supervision visualization
- Level-based Korean insights (beginner/intermediate/expert)
- Environment-specific setup (Colab/Kaggle/Local)

## cv-explorer

Generate interactive CV data exploration notebooks with ipywidgets.

**Triggers**: "exploration notebook", "explore dataset", "interactive viewer", "data viewer", "image viewer", "browse dataset", "browse annotations"

**Capabilities**:
- ipywidgets-based interactive viewers (detection, segmentation, tracking, classification)
- Multi-format support (COCO JSON, YOLO TXT, NPZ, CSV, ImageFolder)
- Side-by-side comparison, confidence threshold tuning, dataset statistics
- Optional supervision library integration for annotation rendering
- Level-based Korean insights (beginner/intermediate/expert)

## ml-dev-principles

General working discipline for ML / multimodal / CV development — how to work, not which library. Load at the start of an ML task.

**Triggers**: "EDA", "error analysis", "FP/FN", "train", "fine-tune", "SFT", "DPO", "LoRA", "eval harness", "test leakage", "dataset selection", "model selection", "license filtering", "GPU utilization", "multimodal", "VLM"

**Capabilities**:
- Rule-type classification (hard-block vs process-caution) before reflexive strict reading
- License/eligibility from actual rule text; eval-set isolation (hard rule vs flag-gated dev diagnostic)
- Mandatory EDA + human FP/FN image review; GPU eff-batch parallel strategy
- Liberal use of flat-rate Codex + Claude vision dual judgment

## Usage

Skills auto-activate based on trigger keywords.

```bash
# GPU parallel pipeline
"Design a multi-GPU inference pipeline for YOLOv8"

# Gradio CV app
"Create a Gradio app for document OCR"

# CV notebook
"Create a YOLO detection notebook for Colab with beginner explanations"
"Generate a segmentation notebook with SAM and Roboflow dataset"

# CV explorer
"Create a COCO dataset exploration notebook"
"Create an interactive detection dataset viewer with comparison"
```

## Related

See `core-config/guidelines/ml-guidelines.md` for common ML pitfalls (BGR/RGB, batch inference anti-patterns, YOLO edge cases).

## Hermes Agent

Install this plugin from the monorepo subdirectory:

```bash
hermes plugins install YoungjaeDev/my-claude-plugins/plugins/ml-toolkit --enable
hermes gateway restart  # if using Hermes through a messaging gateway
```

Load a skill explicitly (Hermes plugin skills are opt-in; start a fresh Hermes session after `--enable`):

```text
skill_view("ml-toolkit:ml-dev-principles")
skill_view("ml-toolkit:gpu-parallel-pipeline")
skill_view("ml-toolkit:cv-explorer")
skill_view("ml-toolkit:cv-notebook")
skill_view("ml-toolkit:gradio-cv-app")
```

Notes:
- Skill bodies carry a Hermes compatibility table mapping Claude/Codex tool terms (`Bash`, `Write`, `NotebookEdit`, ...) to Hermes tools (`terminal`, `write_file`, ...).
- Notebook-authoring skills (`cv-explorer`, `cv-notebook`): Hermes has no `NotebookEdit` tool — use the Hermes "Jupyter Live Kernel" skill or write/patch the `.ipynb` JSON directly.
- `gpu-parallel-pipeline` resolves its bundled-script directory across runtimes (repo path under Claude/Codex; `$HERMES_HOME/plugins/...` then `~/.hermes/plugins/...` under Hermes, matching the github-dev pilot's 3-branch fallback).

## edit-notebook (흡수: notebook)

Safe Jupyter Notebook (.ipynb) editing.

### Skill

| Skill | Description |
|-------|-------------|
| `edit-notebook` | Guidelines for .ipynb file manipulation |

### Key Rules

1. **NotebookEdit tool only** - Never use text editing tools on .ipynb
2. **Preserve outputs** - Don't accidentally clear cell outputs
3. **Cell order matters** - Verify order after modifications
4. **User executes** - Add/edit cells, user runs in Jupyter

### Usage

The skill auto-activates when working with .ipynb files.

### Common Operations

| Operation | Approach |
|-----------|----------|
| Add cell | `NotebookEdit` with `edit_mode=insert` |
| Modify cell | `NotebookEdit` with `edit_mode=replace` |
| Delete cell | `NotebookEdit` with `edit_mode=delete` |
| Read notebook | `Read` tool (renders all cells) |

### Best Practices

- Read notebook first to understand structure
- Use `cell_id` for precise targeting
- Specify `cell_type` (code/markdown) when inserting
- Verify cell order after complex edits
