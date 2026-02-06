# Computer Vision Notebook Code Patterns

Comprehensive collection of reusable code patterns for CV notebooks (Colab/Kaggle compatible).

---

## 1. Environment Setup

### GPU Check and Device Selection

```python
import torch

def get_device():
    """Detect and return optimal device (cuda/mps/cpu)."""
    if torch.cuda.is_available():
        device = torch.device("cuda")
        print(f"GPU: {torch.cuda.get_device_name(0)}")
        print(f"VRAM: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB")
    elif torch.backends.mps.is_available():
        device = torch.device("mps")
        print("Using Apple Silicon GPU (MPS)")
    else:
        device = torch.device("cpu")
        print("WARNING: Using CPU (slow)")
    return device

DEVICE = get_device()
```

### Path Management (Colab/Kaggle)

```python
import os
from pathlib import Path

# Auto-detect environment
IS_COLAB = 'COLAB_GPU' in os.environ
IS_KAGGLE = 'KAGGLE_KERNEL_RUN_TYPE' in os.environ

# Set base paths
if IS_COLAB:
    BASE_DIR = Path('/content')
    DRIVE_DIR = Path('/content/drive/MyDrive')  # After mounting
elif IS_KAGGLE:
    BASE_DIR = Path('/kaggle/working')
    INPUT_DIR = Path('/kaggle/input')
else:
    BASE_DIR = Path.cwd()

# Standard directories
DATA_DIR = BASE_DIR / 'data'
OUTPUT_DIR = BASE_DIR / 'output'
MODELS_DIR = BASE_DIR / 'models'

for dir_path in [DATA_DIR, OUTPUT_DIR, MODELS_DIR]:
    dir_path.mkdir(parents=True, exist_ok=True)

print(f"Environment: {'Colab' if IS_COLAB else 'Kaggle' if IS_KAGGLE else 'Local'}")
print(f"Base: {BASE_DIR}")
```

### Package Installation (Platform-Specific)

```python
import sys

def install_packages(packages: list[str], upgrade: bool = False):
    """Install packages with platform-specific handling."""
    import subprocess

    cmd = [sys.executable, "-m", "pip", "install"]
    if upgrade:
        cmd.append("--upgrade")
    cmd.extend(packages)

    try:
        subprocess.check_call(cmd, stdout=subprocess.DEVNULL)
        print(f"[OK] Installed: {', '.join(packages)}")
    except subprocess.CalledProcessError as e:
        print(f"[FAIL] Failed: {e}")
        raise

# Standard CV stack
install_packages([
    'supervision',
    'roboflow',
    'ultralytics',
    'opencv-python',
    'pillow',
    'matplotlib'
])

# Optional: Transformers-based models
install_packages([
    'transformers',
    'accelerate',
    'einops',
    'timm',
    'flash-attn --no-build-isolation'  # For latest VLMs
])
```

---

## 2. Visualization (Supervision)

### Box Annotations

```python
import supervision as sv
import cv2
import numpy as np

def annotate_boxes(
    image: np.ndarray,
    detections: sv.Detections,
    labels: list[str] = None,
    show_conf: bool = True
) -> np.ndarray:
    """Annotate image with bounding boxes and labels."""

    box_annotator = sv.BoxAnnotator(
        thickness=2,
        color=sv.ColorPalette.DEFAULT
    )

    label_annotator = sv.LabelAnnotator(
        text_scale=0.5,
        text_thickness=1,
        text_padding=5
    )

    annotated = box_annotator.annotate(image.copy(), detections)

    if labels:
        if show_conf and detections.confidence is not None:
            labels = [
                f"{label} {conf:.2f}"
                for label, conf in zip(labels, detections.confidence)
            ]
        annotated = label_annotator.annotate(annotated, detections, labels)

    return annotated

# Usage
detections = sv.Detections(
    xyxy=np.array([[100, 100, 200, 200]]),
    confidence=np.array([0.95]),
    class_id=np.array([0])
)
labels = ['person']
result = annotate_boxes(image, detections, labels)
```

### Mask Annotations

```python
def annotate_masks(
    image: np.ndarray,
    detections: sv.Detections,
    labels: list[str] = None,
    opacity: float = 0.5
) -> np.ndarray:
    """Annotate image with segmentation masks."""

    mask_annotator = sv.MaskAnnotator(
        color=sv.ColorPalette.DEFAULT,
        opacity=opacity
    )

    annotated = mask_annotator.annotate(image.copy(), detections)

    if labels:
        label_annotator = sv.LabelAnnotator(text_scale=0.5)
        annotated = label_annotator.annotate(annotated, detections, labels)

    return annotated

# Usage with SAM-generated masks
detections = sv.Detections(
    xyxy=boxes,
    mask=masks,  # (N, H, W) boolean array
    class_id=class_ids
)
result = annotate_masks(image, detections, labels=['object'])
```

### Grid Visualization

```python
import matplotlib.pyplot as plt

def plot_images_grid(
    images: list[np.ndarray],
    titles: list[str] = None,
    ncols: int = 3,
    figsize: tuple = (15, 10),
    cmap: str = None
):
    """Plot images in grid layout."""

    n_images = len(images)
    nrows = (n_images + ncols - 1) // ncols

    fig, axes = plt.subplots(nrows, ncols, figsize=figsize)
    axes = np.atleast_2d(axes).flatten()

    for idx, (ax, img) in enumerate(zip(axes, images)):
        if img.ndim == 3 and img.shape[2] == 3:
            # BGR to RGB
            img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

        ax.imshow(img, cmap=cmap)
        ax.axis('off')

        if titles and idx < len(titles):
            ax.set_title(titles[idx], fontsize=10)

    # Hide unused subplots
    for ax in axes[n_images:]:
        ax.axis('off')

    plt.tight_layout()
    plt.show()

# Usage
plot_images_grid(
    [original, annotated, masked],
    titles=['Original', 'Detected', 'Segmented'],
    ncols=3
)
```

---

## 3. Roboflow Integration

### Dataset Download with API Key Handling

```python
def get_roboflow_api_key() -> str:
    """Get API key with fallback chain: Colab secrets -> Kaggle secrets -> env -> prompt."""

    # Try Colab secrets
    if IS_COLAB:
        try:
            from google.colab import userdata
            return userdata.get('ROBOFLOW_API_KEY')
        except:
            pass

    # Try Kaggle secrets
    if IS_KAGGLE:
        try:
            from kaggle_secrets import UserSecretsClient
            return UserSecretsClient().get_secret("ROBOFLOW_API_KEY")
        except:
            pass

    # Try environment variable
    api_key = os.getenv('ROBOFLOW_API_KEY')
    if api_key:
        return api_key

    # Prompt user
    from getpass import getpass
    return getpass("Enter Roboflow API key: ")

# Download dataset
from roboflow import Roboflow

rf = Roboflow(api_key=get_roboflow_api_key())
project = rf.workspace("workspace-name").project("project-name")
dataset = project.version(1).download("yolov8", location=str(DATA_DIR))

print(f"Dataset downloaded to: {dataset.location}")
print(f"Classes: {dataset.names}")
```

### Model Deployment (Upload Predictions)

```python
def upload_to_roboflow(
    project_id: str,
    version: int,
    predictions: list[dict],
    api_key: str = None
):
    """Upload predictions to Roboflow for visualization."""

    if api_key is None:
        api_key = get_roboflow_api_key()

    from roboflow import Roboflow

    rf = Roboflow(api_key=api_key)
    project = rf.workspace().project(project_id)
    model = project.version(version).model

    # Upload batch
    for pred in predictions:
        model.upload_image(
            image_path=pred['image_path'],
            hosted_image=False,
            prediction={
                'predictions': pred['detections'],
                'image': {'width': pred['width'], 'height': pred['height']}
            }
        )

    print(f"[OK] Uploaded {len(predictions)} predictions")
```

---

## 4. Model-Specific Patterns

### YOLO (Ultralytics)

```python
from ultralytics import YOLO

# Load pretrained
model = YOLO('yolov8n.pt')  # n/s/m/l/x variants
model.to(DEVICE)

# Inference
results = model.predict(
    source=image_path,
    conf=0.25,
    iou=0.45,
    device=DEVICE,
    verbose=False
)

# Convert to supervision
detections = sv.Detections.from_ultralytics(results[0])

# Training
model.train(
    data='dataset.yaml',
    epochs=100,
    imgsz=640,
    batch=16,
    device=DEVICE,
    project=str(OUTPUT_DIR),
    name='yolo_train',
    exist_ok=True,
    patience=20,  # Early stopping
    save=True,
    plots=True
)

# Validation
metrics = model.val()
print(f"mAP50: {metrics.box.map50:.3f}")
print(f"mAP50-95: {metrics.box.map:.3f}")
```

### RT-DETR (Ultralytics)

```python
from ultralytics import RTDETR

# Load
model = RTDETR('rtdetr-l.pt')  # l/x variants
model.to(DEVICE)

# Inference (same as YOLO)
results = model.predict(
    source=image_path,
    conf=0.25,
    device=DEVICE
)

detections = sv.Detections.from_ultralytics(results[0])

# Training
model.train(
    data='coco8.yaml',
    epochs=100,
    imgsz=640,
    device=DEVICE,
    batch=4  # Lower batch due to transformer memory
)
```

### SAM (Segment Anything)

```python
from segment_anything import sam_model_registry, SamPredictor
import torch

# Load model
MODEL_TYPE = "vit_h"  # vit_h/vit_l/vit_b
CHECKPOINT = "sam_vit_h_4b8939.pth"

sam = sam_model_registry[MODEL_TYPE](checkpoint=CHECKPOINT)
sam.to(DEVICE)
predictor = SamPredictor(sam)

# Set image
image = cv2.imread(str(image_path))
image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
predictor.set_image(image_rgb)

# Predict with box prompt
input_box = np.array([100, 100, 300, 300])  # x1, y1, x2, y2
masks, scores, logits = predictor.predict(
    box=input_box[None, :],
    multimask_output=True
)

# Best mask
best_mask = masks[np.argmax(scores)]

# Convert to supervision
detections = sv.Detections(
    xyxy=input_box[None, :],
    mask=best_mask[None, ...],
    confidence=np.array([scores.max()])
)

# Automatic mask generation
from segment_anything import SamAutomaticMaskGenerator

mask_generator = SamAutomaticMaskGenerator(
    model=sam,
    points_per_side=32,
    pred_iou_thresh=0.9,
    stability_score_thresh=0.95,
    crop_n_layers=1,
    crop_n_points_downscale_factor=2
)

masks = mask_generator.generate(image_rgb)
print(f"Generated {len(masks)} masks")
```

### Florence-2 (Transformers)

```python
from transformers import AutoProcessor, AutoModelForCausalLM
from PIL import Image

# Load model
MODEL_ID = "microsoft/Florence-2-large"  # base/large/large-ft
processor = AutoProcessor.from_pretrained(MODEL_ID, trust_remote_code=True)
model = AutoModelForCausalLM.from_pretrained(
    MODEL_ID,
    trust_remote_code=True,
    torch_dtype=torch.float16
).to(DEVICE)

# Inference
image = Image.open(image_path).convert('RGB')
prompt = "<OD>"  # Object Detection task

inputs = processor(text=prompt, images=image, return_tensors="pt").to(DEVICE)

with torch.no_grad():
    generated_ids = model.generate(
        **inputs,
        max_new_tokens=1024,
        num_beams=3
    )

results = processor.batch_decode(generated_ids, skip_special_tokens=False)[0]
parsed = processor.post_process_generation(
    results,
    task=prompt,
    image_size=(image.width, image.height)
)

# Convert to supervision
detections = sv.Detections.from_lmm(
    lmm=sv.LMM.FLORENCE_2,
    result=parsed,
    resolution_wh=(image.width, image.height)
)

# Available tasks
TASKS = {
    '<OD>': 'Object Detection',
    '<DENSE_REGION_CAPTION>': 'Dense Captioning',
    '<REGION_PROPOSAL>': 'Region Proposal',
    '<CAPTION>': 'Image Captioning',
    '<DETAILED_CAPTION>': 'Detailed Captioning',
    '<MORE_DETAILED_CAPTION>': 'Very Detailed Captioning'
}
```

### PaliGemma (Transformers)

```python
from transformers import PaliGemmaProcessor, PaliGemmaForConditionalGeneration

# Load model
MODEL_ID = "google/paligemma-3b-mix-224"
processor = PaliGemmaProcessor.from_pretrained(MODEL_ID)
model = PaliGemmaForConditionalGeneration.from_pretrained(
    MODEL_ID,
    torch_dtype=torch.float16
).to(DEVICE)

# Detection with text prompt
image = Image.open(image_path)
prompt = "detect person ; car"

inputs = processor(text=prompt, images=image, return_tensors="pt").to(DEVICE)

with torch.no_grad():
    output = model.generate(**inputs, max_new_tokens=100)

result = processor.decode(output[0], skip_special_tokens=True)

# Parse results (format: "<loc0000><loc0000><loc0000><loc0000> person")
# Use supervision's from_lmm with PaliGemma parser
detections = sv.Detections.from_lmm(
    lmm=sv.LMM.PALIGEMMA,
    result=result,
    resolution_wh=(image.width, image.height),
    classes=[c.strip() for c in prompt.replace('detect', '').split(';')]
)
```

### Qwen2.5-VL (Transformers)

```python
from transformers import Qwen2VLForConditionalGeneration, AutoProcessor
from qwen_vl_utils import process_vision_info

# Load model
MODEL_ID = "Qwen/Qwen2.5-VL-7B-Instruct"
model = Qwen2VLForConditionalGeneration.from_pretrained(
    MODEL_ID,
    torch_dtype=torch.bfloat16,
    device_map="auto"
)
processor = AutoProcessor.from_pretrained(MODEL_ID)

# Detection prompt
messages = [
    {
        "role": "user",
        "content": [
            {"type": "image", "image": image_path},
            {"type": "text", "text": "Detect all objects in this image."}
        ]
    }
]

text = processor.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
image_inputs, video_inputs = process_vision_info(messages)

inputs = processor(
    text=[text],
    images=image_inputs,
    videos=video_inputs,
    padding=True,
    return_tensors="pt"
).to(DEVICE)

with torch.no_grad():
    output_ids = model.generate(**inputs, max_new_tokens=256)

output_text = processor.batch_decode(
    output_ids,
    skip_special_tokens=True,
    clean_up_tokenization_spaces=False
)[0]

# Convert to detections
detections = sv.Detections.from_lmm(
    lmm=sv.LMM.QWEN2_VL,
    result=output_text,
    resolution_wh=image.size
)

# Grounding (with bounding boxes)
grounding_prompt = "Detect <ref>person</ref> and <ref>car</ref>"
# Returns detections with boxes
```

---

## 5. Evaluation Metrics

### Detection Metrics (YOLO/RT-DETR)

```python
from ultralytics.utils.metrics import ConfusionMatrix, ap_per_class

def evaluate_detection(model, val_loader, conf_thresh=0.25):
    """Comprehensive detection evaluation."""

    all_preds = []
    all_targets = []

    model.eval()
    with torch.no_grad():
        for images, targets in val_loader:
            preds = model(images)
            all_preds.extend(preds)
            all_targets.extend(targets)

    # Confusion matrix
    cm = ConfusionMatrix(nc=len(model.names))
    cm.process_batch(all_preds, all_targets)
    cm.plot(save_dir=OUTPUT_DIR, names=list(model.names.values()))

    # Per-class AP
    stats = ap_per_class(
        *fitness_metrics(all_preds, all_targets),
        names=model.names
    )

    # Print results
    print("Per-Class Results:")
    print(f"{'Class':<20} {'AP@.5':<10} {'AP@.5:.95':<10}")
    print("-" * 40)
    for i, name in enumerate(model.names.values()):
        print(f"{name:<20} {stats[0][i]:.3f}      {stats[1][i]:.3f}")

    print(f"\nmAP@.5: {stats[0].mean():.3f}")
    print(f"mAP@.5:.95: {stats[1].mean():.3f}")

    return stats

# Simple per-image evaluation
def compute_iou(box1, box2):
    """Compute IoU between two boxes [x1, y1, x2, y2]."""
    x1 = max(box1[0], box2[0])
    y1 = max(box1[1], box2[1])
    x2 = min(box1[2], box2[2])
    y2 = min(box1[3], box2[3])

    inter = max(0, x2 - x1) * max(0, y2 - y1)
    area1 = (box1[2] - box1[0]) * (box1[3] - box1[1])
    area2 = (box2[2] - box2[0]) * (box2[3] - box2[1])
    union = area1 + area2 - inter

    return inter / union if union > 0 else 0
```

### Segmentation Metrics

```python
import numpy as np

def compute_iou_mask(pred_mask: np.ndarray, gt_mask: np.ndarray) -> float:
    """Compute IoU for binary masks."""
    intersection = np.logical_and(pred_mask, gt_mask).sum()
    union = np.logical_or(pred_mask, gt_mask).sum()
    return intersection / union if union > 0 else 0

def compute_dice(pred_mask: np.ndarray, gt_mask: np.ndarray) -> float:
    """Compute Dice coefficient."""
    intersection = np.logical_and(pred_mask, gt_mask).sum()
    return 2 * intersection / (pred_mask.sum() + gt_mask.sum())

def evaluate_segmentation(pred_masks: list, gt_masks: list):
    """Evaluate segmentation across dataset."""
    ious = [compute_iou_mask(p, g) for p, g in zip(pred_masks, gt_masks)]
    dices = [compute_dice(p, g) for p, g in zip(pred_masks, gt_masks)]

    print(f"Mean IoU: {np.mean(ious):.3f} ± {np.std(ious):.3f}")
    print(f"Mean Dice: {np.mean(dices):.3f} ± {np.std(dices):.3f}")

    return {'iou': ious, 'dice': dices}
```

### Classification Metrics

```python
from sklearn.metrics import classification_report, confusion_matrix
import seaborn as sns

def evaluate_classification(y_true, y_pred, class_names):
    """Comprehensive classification evaluation."""

    # Classification report
    print(classification_report(y_true, y_pred, target_names=class_names))

    # Confusion matrix
    cm = confusion_matrix(y_true, y_pred)

    plt.figure(figsize=(10, 8))
    sns.heatmap(
        cm,
        annot=True,
        fmt='d',
        cmap='Blues',
        xticklabels=class_names,
        yticklabels=class_names
    )
    plt.ylabel('True Label')
    plt.xlabel('Predicted Label')
    plt.title('Confusion Matrix')
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'confusion_matrix.png')
    plt.show()

    # Per-class accuracy
    class_acc = cm.diagonal() / cm.sum(axis=1)
    for name, acc in zip(class_names, class_acc):
        print(f"{name}: {acc:.3f}")

    return cm
```

---

## 6. Error Handling Patterns

### GPU Availability Fallback

```python
def load_model_safe(model_class, checkpoint, prefer_gpu=True):
    """Load model with graceful GPU fallback."""

    device = torch.device('cpu')

    if prefer_gpu:
        if torch.cuda.is_available():
            device = torch.device('cuda')
            print(f"[OK] Using GPU: {torch.cuda.get_device_name(0)}")
        elif torch.backends.mps.is_available():
            device = torch.device('mps')
            print("[OK] Using Apple Silicon GPU")
        else:
            print("[WARN] GPU not available, using CPU (slow)")

    try:
        model = model_class.from_pretrained(checkpoint)
        model.to(device)
        return model, device
    except RuntimeError as e:
        if 'out of memory' in str(e).lower():
            print("[WARN] OOM error, falling back to CPU")
            torch.cuda.empty_cache()
            model = model_class.from_pretrained(checkpoint)
            model.to('cpu')
            return model, torch.device('cpu')
        raise
```

### API Key Validation with Fallbacks

```python
def validate_api_key(api_key: str, service: str = "roboflow") -> bool:
    """Validate API key with test request."""

    if service == "roboflow":
        try:
            from roboflow import Roboflow
            rf = Roboflow(api_key=api_key)
            rf.workspace()  # Test call
            return True
        except Exception as e:
            print(f"[FAIL] Invalid API key: {e}")
            return False

    return False

def get_api_key_with_retry(service: str = "roboflow", max_attempts: int = 3) -> str:
    """Get valid API key with retry."""

    for attempt in range(max_attempts):
        api_key = get_roboflow_api_key()

        if validate_api_key(api_key, service):
            print(f"[OK] Valid {service} API key")
            return api_key

        print(f"Attempt {attempt + 1}/{max_attempts} failed")

    raise ValueError(f"Failed to get valid {service} API key after {max_attempts} attempts")
```

### Download Retry with Exponential Backoff

```python
import time
import requests
from typing import Optional

def download_with_retry(
    url: str,
    output_path: Path,
    max_retries: int = 3,
    initial_delay: float = 1.0
) -> bool:
    """Download file with exponential backoff retry."""

    delay = initial_delay

    for attempt in range(max_retries):
        try:
            print(f"Downloading {url} (attempt {attempt + 1}/{max_retries})...")

            response = requests.get(url, stream=True, timeout=30)
            response.raise_for_status()

            output_path.parent.mkdir(parents=True, exist_ok=True)

            with open(output_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)

            print(f"[OK] Downloaded to {output_path}")
            return True

        except (requests.RequestException, IOError) as e:
            print(f"[FAIL] Attempt {attempt + 1} failed: {e}")

            if attempt < max_retries - 1:
                print(f"Retrying in {delay:.1f}s...")
                time.sleep(delay)
                delay *= 2  # Exponential backoff
            else:
                print(f"[FAIL] Failed after {max_retries} attempts")
                return False

    return False

# Usage
MODEL_URL = "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_h_4b8939.pth"
CHECKPOINT_PATH = MODELS_DIR / "sam_vit_h.pth"

if not CHECKPOINT_PATH.exists():
    download_with_retry(MODEL_URL, CHECKPOINT_PATH)
```

### Batch Processing with Progress and Error Recovery

```python
from tqdm import tqdm
import traceback

def process_dataset_safe(
    image_paths: list[Path],
    process_fn,
    batch_size: int = 1,
    skip_errors: bool = True
):
    """Process dataset with progress bar and error handling."""

    results = []
    errors = []

    for i in tqdm(range(0, len(image_paths), batch_size), desc="Processing"):
        batch = image_paths[i:i + batch_size]

        for img_path in batch:
            try:
                result = process_fn(img_path)
                results.append({'path': img_path, 'result': result})

            except Exception as e:
                error_info = {
                    'path': img_path,
                    'error': str(e),
                    'traceback': traceback.format_exc()
                }
                errors.append(error_info)

                if not skip_errors:
                    raise
                else:
                    print(f"[WARN] Skipped {img_path.name}: {e}")

    print(f"\n[OK] Processed: {len(results)}/{len(image_paths)}")
    if errors:
        print(f"[FAIL] Errors: {len(errors)}")

        # Save error log
        error_log = OUTPUT_DIR / 'errors.json'
        import json
        with open(error_log, 'w') as f:
            json.dump(errors, f, indent=2, default=str)
        print(f"Error log saved to {error_log}")

    return results, errors
```

---

## Usage Guidelines

### Pattern Selection

| Task | Recommended Patterns |
|------|---------------------|
| Object detection | YOLO or RT-DETR + BoxAnnotator |
| Instance segmentation | SAM + MaskAnnotator |
| Visual Q&A | Florence-2 or Qwen2.5-VL |
| Grounded detection | PaliGemma or Qwen2.5-VL |
| Dataset download | Roboflow + retry logic |
| Evaluation | Model-specific metrics + confusion matrix |

### Performance Tips

1. **Batch Processing**: Use `batch_size > 1` for inference speedup
2. **Mixed Precision**: Use `torch.float16` or `torch.bfloat16` for transformers
3. **GPU Memory**: Monitor with `torch.cuda.memory_allocated()`
4. **Caching**: Save processed results to avoid recomputation
5. **Parallel Workers**: Use `num_workers > 0` in DataLoader

### Common Gotchas

| Issue | Solution |
|-------|----------|
| BGR vs RGB | Always convert: `cv2.cvtColor(img, cv2.COLOR_BGR2RGB)` |
| OOM errors | Reduce batch size or use gradient checkpointing |
| API rate limits | Add retry with exponential backoff |
| Missing secrets | Implement full fallback chain (Colab → Kaggle → env → prompt) |
| Model not found | Check model ID spelling and HuggingFace availability |

---

**Last Updated**: 2026-02-06
**Compatible With**: Colab, Kaggle, Local Jupyter
**Dependencies**: supervision, ultralytics, transformers, roboflow, opencv-python
