# ML Toolkit Plugin

Machine Learning and AI development skills.

## Skills

| Skill | Description |
|-------|-------------|
| `gpu-parallel-pipeline` | Design PyTorch GPU parallel processing pipelines |
| `gradio-cv-app` | Create professional Gradio computer vision apps |
| `cv-notebook` | Generate production-quality Computer Vision Jupyter notebooks |
| `cv-explorer` | Generate interactive CV data exploration notebooks with ipywidgets |

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
