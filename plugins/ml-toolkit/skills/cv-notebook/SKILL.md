---
name: cv-notebook
description: Generate production-quality Computer Vision Jupyter notebooks. Supports detection, segmentation, classification, and VLM tasks. Follows roboflow/notebooks patterns with supervision visualization. Triggers on "CV notebook", "detection notebook", "segmentation notebook", "classification notebook", "VLM notebook", "train YOLO notebook", "fine-tune notebook", "inference notebook", "computer vision tutorial".
---

# CV Notebook Generator

A skill for generating professional Computer Vision Jupyter notebooks following roboflow/notebooks patterns with Korean insights.

## Design Principles

### What to Apply (Roboflow Style)
- Banner image at top
- Colab/GitHub badges
- GPU check cell first
- supervision library for all visualizations
- Roboflow SDK for dataset management
- Clear section structure (Setup → Data → Model → Training → Evaluation)

### What to Avoid
- Hardcoded API keys (use environment variables or secrets)
- Model-specific code outside templates
- Execution of cells (user runs in their environment)
- Direct .ipynb file manipulation (use NotebookEdit tool)

## Supported Task Types

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
| language | enum | hybrid | en/ko/hybrid (Korean insights) |

## Notebook Structure

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

## User Level Configuration

### Insight Density by Level

| Level | Insight Blocks | Inline Comments | MD:Code Ratio |
|-------|----------------|-----------------|---------------|
| beginner | 15-20 per notebook | 80%+ of code lines | 1:1 |
| intermediate | 8-12 per notebook | 40% of code lines | 1:2 |
| expert | 3-5 per notebook | 10% of code lines | 1:4 |

### Insight Injection Points

| Section | Beginner | Intermediate | Expert |
|---------|----------|--------------|--------|
| GPU Check | Block after | - | - |
| Package Install | All inline | Key only | - |
| Model Load | Block after | Block after | - |
| Inference | Both | Inline | Inline |
| Training Config | Block after | Block after | - |
| Evaluation | Block after | Block after | Block |

## Usage Examples

### Basic Detection Notebook
```
"Create a YOLOv8 detection notebook for beginners"
→ task=detection, model=yolov8, level=beginner, environment=colab
```

### Custom Segmentation
```
"Generate SAM segmentation notebook for Kaggle, intermediate level"
→ task=segmentation, model=sam, level=intermediate, environment=kaggle
```

### VLM Inference Only
```
"Create Florence-2 VLM notebook without training section"
→ task=vlm, model=florence-2, include_training=false
```

### Expert Training Notebook
```
"Generate expert-level RT-DETR fine-tuning notebook with Roboflow dataset"
→ task=detection, model=rt-detr, level=expert, include_roboflow=true
```

### Qwen2.5-VL Zero-Shot Detection
```
"Create Qwen2.5-VL notebook for zero-shot object detection"
→ task=vlm, model=qwen2.5-vl, include_training=false
```

## Generation Workflow

1. **Identify parameters**: Parse task, model, level, environment from request
2. **Select template**: Load appropriate task template from references/templates/
3. **Apply environment**: Insert Colab/Kaggle/Local specific setup
4. **Inject insights**: Add Korean insights based on level density
5. **Generate notebook**: Use NotebookEdit tool to create .ipynb file
6. **Validate structure**: Ensure all required sections present

## NotebookEdit Integration

This skill uses the NotebookEdit tool for .ipynb generation:

```python
# Cell generation sequence
NotebookEdit(notebook_path="notebook.ipynb", edit_mode="insert", cell_type="markdown", new_source="# Header")
NotebookEdit(notebook_path="notebook.ipynb", edit_mode="insert", cell_id="<previous>", cell_type="code", new_source="!nvidia-smi")
```

### Cell ID Strategy
- Generate cells sequentially (top to bottom)
- Track cell IDs for insertion points
- Use `edit_mode="insert"` with previous cell_id

## Additional Resources

- Code patterns: [references/patterns.md](references/patterns.md)
- Environment setup: [references/environment-setup.md](references/environment-setup.md)
- Korean insights: [references/insights-ko.md](references/insights-ko.md)
- Architecture diagrams: [references/diagrams.md](references/diagrams.md)
- Templates: [references/templates/](references/templates/)
