# ML Toolkit Plugin

Machine Learning and AI development skills.

## Skills

| Skill | Description |
|-------|-------------|
| `gradio-cv-app` | Create professional Gradio computer vision apps |
| `cv-notebook` | Generate production-quality Computer Vision Jupyter notebooks (incl. interactive ipywidgets exploration mode) |
| `ml-dev-principles` | General ML/multimodal/CV working discipline (how to work, not which library) |
| `edit-notebook` | Safe Jupyter notebook editing (absorbed from `notebook`) |

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

Also generates interactive ipywidgets-based CV data exploration notebooks (absorbed from the former `cv-explorer` skill — see the "Exploration mode" section in `skills/cv-notebook/SKILL.md`).

**Exploration-mode triggers**: "exploration notebook", "explore dataset", "interactive viewer", "data viewer", "image viewer", "browse dataset", "browse annotations"

**Exploration-mode capabilities**:
- ipywidgets-based interactive viewers (detection, segmentation, tracking, classification)
- Multi-format support (COCO JSON, YOLO TXT, NPZ, CSV, ImageFolder)
- Side-by-side comparison, confidence threshold tuning, dataset statistics
- Optional supervision library integration for annotation rendering

## ml-dev-principles

General working discipline for ML / multimodal / CV development — how to work, not which library. Load at the start of an ML task.

**Triggers**: "EDA", "error analysis", "FP/FN", "train", "fine-tune", "SFT", "DPO", "LoRA", "eval harness", "test leakage", "dataset selection", "model selection", "license filtering", "GPU utilization", "multimodal", "VLM"

**Capabilities**:
- Rule-type classification (hard-block vs process-caution) before reflexive strict reading
- License/eligibility from actual rule text; eval-set isolation (hard rule vs flag-gated dev diagnostic)
- Mandatory EDA + human FP/FN image review; GPU eff-batch parallel strategy (§5), with multi-GPU ProcessPool/CUDA_VISIBLE_DEVICES isolation, CUDA Streams, and I/O+compute pipeline patterns for dataset-processing workloads absorbed from the former `gpu-parallel-pipeline` skill into `references/gpu-parallel.md`
- Liberal use of flat-rate Codex + Claude vision dual judgment

## Usage

Skills auto-activate based on trigger keywords.

```bash
# Gradio CV app
"Create a Gradio app for document OCR"

# CV notebook
"Create a YOLO detection notebook for Colab with beginner explanations"
"Generate a segmentation notebook with SAM and Roboflow dataset"

# CV notebook, exploration mode (absorbed cv-explorer)
"Create a COCO dataset exploration notebook"
"Create an interactive detection dataset viewer with comparison"

# ml-dev-principles (multi-GPU dataset processing, absorbed gpu-parallel-pipeline)
"Design a multi-GPU inference pipeline for YOLOv8 over a large image dataset"
```

## Related

See `core/guidelines/ml-guidelines.md` for common ML pitfalls (BGR/RGB, batch inference anti-patterns, YOLO edge cases).

## edit-notebook (흡수: notebook)

Safe Jupyter Notebook (.ipynb) editing.

### Skill

| Skill | Description |
|-------|-------------|
| `edit-notebook` | Guidelines for .ipynb file manipulation |

### Key Rules

1. **Structure-aware tool only** - `NotebookEdit` on Claude Code; on Codex (no `NotebookEdit`) an `nbformat` Python snippet; never text-edit `.ipynb`
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
