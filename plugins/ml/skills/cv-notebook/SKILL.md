---
name: cv-notebook
description: Generate production-quality Computer Vision Jupyter notebooks. Supports detection, segmentation, classification, and VLM tasks. Follows roboflow/notebooks patterns with supervision visualization. Triggers on "CV notebook", "detection notebook", "segmentation notebook", "classification notebook", "VLM notebook", "train YOLO notebook", "fine-tune notebook", "inference notebook", "computer vision tutorial". Also builds interactive ipywidgets exploration notebooks over COCO, YOLO, NPZ, CSV, or ImageFolder data with detection, segmentation, tracking, or classification viewers, comparison view, and threshold tuning. Triggers on "exploration notebook", "explore dataset", "interactive viewer", "data viewer", "browse dataset", "browse annotations".
---

# CV Notebook Generator

Generates Computer Vision Jupyter notebooks for 4 task types in the roboflow/notebooks style, with Korean insights at 3 levels, plus an interactive exploration mode. The output is a notebook that passed the End Gate, never one only asserted to be correct.

**Structure-aware authoring**: Claude Code authors `.ipynb` cells with the `NotebookEdit` tool. Codex has no `NotebookEdit`: author cells through an `nbformat` Python snippet instead (detect the interpreter `python3` → `python` → `py -3`, check `<py> -c "import nbformat"`, install on miss with `<py> -m pip install nbformat`). Never hand-edit notebook JSON as raw text on either runtime; `ml:edit-notebook` holds the full editing rules.

## Design principles

- **Apply (Roboflow style)**: banner image at top, Colab/GitHub badges, GPU check cell first, clear section structure (Setup → Data → Model → Training → Evaluation).
- **Libraries**: supervision for all visualizations, the Roboflow SDK for dataset management.
- **Avoid**: hardcoded API keys (use environment variables or secrets), model-specific code outside templates, executing cells (the user runs them in their environment), direct `.ipynb` text manipulation.

## Supported task types

| Task | Description | Key Models |
|------|-------------|------------|
| `detection` | Object detection | YOLO, RT-DETR |
| `segmentation` | Instance/semantic segmentation | SAM, YOLO-Seg |
| `classification` | Image classification | ResNet, ViT, DINOv2 |
| `vlm` | Vision-Language Models | Florence-2, PaliGemma, Qwen2.5-VL |

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| task | enum | detection | detection/segmentation/classification/vlm |
| model | string | auto | Model name (YOLO, SAM, Florence, etc.) |
| level | enum | intermediate | beginner/intermediate/expert |
| environment | enum | colab | colab/kaggle/local |
| include_training | bool | true | Include fine-tuning section |
| include_roboflow | bool | true | Include Roboflow dataset integration |
| dataset_format | enum | yolov8 | yolov8/coco/voc/pascal - Roboflow export format |
| language | enum | hybrid | en/ko/hybrid (Korean insights) |

## Notebook structure

Standard section order for all CV notebooks:

| Section | Cell Type | Required | Description |
|---------|-----------|----------|-------------|
| Header | Markdown | Yes | Banner, badges, title, description |
| GPU Check | Code | Yes | nvidia-smi and torch.cuda check |
| Setup | Code | Yes | Package installation, imports |
| API Config | Code | Conditional | Roboflow/HuggingFace API keys |
| Data | Code+MD | Yes | Dataset download, exploration, visualization |
| Model | Code+MD | Yes | Load pretrained, test inference |
| Training | Code+MD | Optional | Fine-tuning workflow |
| Evaluation | Code+MD | Yes | Metrics, confusion matrix, visualization |
| Deployment | Code+MD | Optional | Export, Roboflow Deploy |
| Conclusion | Markdown | Yes | Summary, next steps, resources |

## User level configuration

Insight density by level (format spec and insight bank in `references/insights-ko.md`):

| Level | Insight Blocks | Inline Comments | MD:Code Ratio |
|-------|----------------|-----------------|---------------|
| beginner | 15-20 per notebook | 80%+ of code lines | 1:1 |
| intermediate | 8-12 per notebook | 40% of code lines | 1:2 |
| expert | 3-5 per notebook | 10% of code lines | 1:4 |

Insight injection points:

| Section | Beginner | Intermediate | Expert |
|---------|----------|--------------|--------|
| GPU Check | Block after | - | - |
| Package Install | All inline | Key only | - |
| Model Load | Block after | Block after | - |
| Inference | Both | Inline | Inline |
| Training Config | Block after | Block after | - |
| Evaluation | Block after | Block after | Block |

## Generation workflow

1. **Identify parameters**: parse task, model, level, environment from the request.
2. **Select template**: load the matching task template from `references/templates/`.
3. **Apply environment**: insert Colab/Kaggle/Local specific setup (`references/environment-setup.md`).
4. **Inject insights**: add Korean insights at the level's density.
5. **Generate notebook**: author cells structure-aware, top to bottom (see below).
6. **Validate structure**: ensure every required section is present.
7. **End gate**: validate that the generated notebook actually parses (see below).

On Claude Code, insert cells sequentially and pass the `cell_id` returned by each `NotebookEdit` response to the next `edit_mode="insert"` call; an insert without it lands at the top. On Codex, append to `nb.cells` in the same order.

```python
NotebookEdit(notebook_path="notebook.ipynb", edit_mode="insert", cell_type="markdown", new_source="# Header")
NotebookEdit(notebook_path="notebook.ipynb", edit_mode="insert", cell_id="<previous>", cell_type="code", new_source="!nvidia-smi")
```

## End gate (mandatory)

Never hand back a notebook that has not been validated. Read `references/end-gate.md` before step 7 and take the strongest path the environment allows.

- **Execute** the setup and first data-load cells with `jupyter nbconvert --execute` on a sliced temp copy when `jupyter` and the deps are present.
- **py_compile** every code cell in order, magics stripped; this fallback always runs and needs no packages or GPU.
- **Report** the first failure as "unverified beyond cell N", or "unverified beyond cell N, env lacks `<pkg>`" when only the execute path failed on a missing dependency. Fix the cell and re-run until it passes.

## Exploration mode

Triggers on "exploration notebook", "explore dataset", "interactive viewer", "data viewer", "browse dataset", "browse annotations", "visualize dataset interactively", instead of the training/Roboflow flow above.

Read `references/exploration-mode.md` for its viewer types, parameters and generation steps; it uses the same structure-aware authoring and the same End Gate.

Non-triggers route to the standard flow above instead: "training notebook", "train model", "fine-tune", "transfer learning", "deploy model", "export model".

## Additional resources

- Code patterns: [references/patterns.md](references/patterns.md)
- Exploration mode: [references/exploration-mode.md](references/exploration-mode.md), [references/explorer-patterns.md](references/explorer-patterns.md), [references/explorer-data-loaders.md](references/explorer-data-loaders.md)
- Environment setup: [references/environment-setup.md](references/environment-setup.md)
- Korean insights: [references/insights-ko.md](references/insights-ko.md)
- Architecture diagrams: [references/diagrams.md](references/diagrams.md)
- Templates: [references/templates/](references/templates/) (`exploration.md` for exploration mode)
