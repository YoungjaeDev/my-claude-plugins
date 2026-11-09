# ML Toolkit Plugin

Four skills for machine learning and computer vision work. Each skill's `description` holds its triggers; this file only maps where things live.

## Skills

| Skill | What it does |
|-------|-------------|
| `ml-dev-principles` | How to run ML, multimodal and CV work: license filtering from the rule text, eval isolation, mandatory EDA, FP/FN image review, GPU throughput, dual-model judgment |
| `cv-notebook` | Generates CV Jupyter notebooks (detection, segmentation, classification, VLM) with level-based Korean insights, plus an ipywidgets exploration mode |
| `edit-notebook` | Edits `.ipynb` files through a structure-aware path only (`NotebookEdit` on Claude Code, `nbformat` on Codex); the user runs the cells |
| `gradio-cv-app` | Builds a Gradio CV demo app in the Editorial design, with dark mode and Korean/English labels |

## Where things live

- **Library pitfalls** (BGR/RGB, per-file inference loops, YOLO conversion, WandB): `skills/ml-dev-principles/references/ml-pitfalls.md`.
- **Multi-GPU dataset processing**: `skills/ml-dev-principles/references/gpu-parallel.md`, cited from §5 of that skill. Keep the §5 numbering stable.
- **Notebook templates**: `skills/cv-notebook/references/templates/`, seeded code that the shape rules skip.
- **Gradio theme and task code**: `skills/gradio-cv-app/references/`.
