# Segmentation Notebook Templates

Complete cell templates for segmentation tasks using SAM, SAM 2, and YOLO-Seg.

---

## 1. Model Loading

### SAM (Segment Anything Model)

```python
# Install and import SAM
!pip install git+https://github.com/facebookresearch/segment-anything.git
!pip install supervision

import torch
import numpy as np
from segment_anything import sam_model_registry, SamPredictor
from PIL import Image
import cv2
import matplotlib.pyplot as plt

# Download checkpoint (choose one)
# !wget https://dl.fbaipublicfiles.com/segment_anything/sam_vit_h_4b8939.pth
# !wget https://dl.fbaipublicfiles.com/segment_anything/sam_vit_l_0b3195.pth
# !wget https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth

# Load SAM model
sam_checkpoint = "sam_vit_h_4b8939.pth"
model_type = "vit_h"  # or "vit_l", "vit_b"
device = "cuda" if torch.cuda.is_available() else "cpu"

sam = sam_model_registry[model_type](checkpoint=sam_checkpoint)
sam.to(device=device)

predictor = SamPredictor(sam)
print(f"SAM model loaded on {device}")
```

### SAM 2 (Latest Version)

```python
# Install and import SAM 2
!pip install git+https://github.com/facebookresearch/segment-anything-2.git
!pip install supervision

import torch
import numpy as np
from sam2.build_sam import build_sam2
from sam2.sam2_image_predictor import SAM2ImagePredictor
from PIL import Image
import cv2
import matplotlib.pyplot as plt

# Download checkpoint
# !wget https://dl.fbaipublicfiles.com/segment_anything_2/sam2_hiera_large.pt

# Load SAM 2 model
sam2_checkpoint = "sam2_hiera_large.pt"
model_cfg = "sam2_hiera_l.yaml"
device = "cuda" if torch.cuda.is_available() else "cpu"

sam2_model = build_sam2(model_cfg, sam2_checkpoint, device=device)
predictor = SAM2ImagePredictor(sam2_model)
print(f"SAM 2 model loaded on {device}")
```

### YOLO-Seg (Ultralytics)

```python
# Install and import YOLO
!pip install ultralytics supervision

from ultralytics import YOLO
import torch
import cv2
import numpy as np
from PIL import Image
import matplotlib.pyplot as plt

# Load pre-trained YOLO-Seg model
# Options: yolov8n-seg.pt, yolov8s-seg.pt, yolov8m-seg.pt, yolov8l-seg.pt, yolov8x-seg.pt
model = YOLO("yolov8n-seg.pt")

# Check device
device = "cuda" if torch.cuda.is_available() else "cpu"
model.to(device)
print(f"YOLO-Seg model loaded on {device}")
print(f"Model classes: {model.names}")
```

---

## 2. Inference

### SAM - Point Prompts

```python
# Load image
image_path = "path/to/image.jpg"
image = cv2.imread(image_path)
image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

# Set image for predictor
predictor.set_image(image_rgb)

# Define point prompts (x, y coordinates)
input_points = np.array([[500, 375]])  # Single point
input_labels = np.array([1])  # 1 = foreground, 0 = background

# Predict masks
masks, scores, logits = predictor.predict(
    point_coords=input_points,
    point_labels=input_labels,
    multimask_output=True  # Get 3 mask predictions
)

print(f"Generated {len(masks)} masks with scores: {scores}")

# Display results
fig, axes = plt.subplots(1, len(masks) + 1, figsize=(15, 5))
axes[0].imshow(image_rgb)
axes[0].scatter(input_points[:, 0], input_points[:, 1], c='red', s=100, marker='*')
axes[0].set_title("Input Image with Point")
axes[0].axis('off')

for idx, (mask, score) in enumerate(zip(masks, scores)):
    axes[idx + 1].imshow(image_rgb)
    axes[idx + 1].imshow(mask, alpha=0.5, cmap='jet')
    axes[idx + 1].set_title(f"Mask {idx + 1} (Score: {score:.3f})")
    axes[idx + 1].axis('off')

plt.tight_layout()
plt.show()
```

### SAM - Box Prompts

```python
# Load image
image_path = "path/to/image.jpg"
image = cv2.imread(image_path)
image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

predictor.set_image(image_rgb)

# Define bounding box (x1, y1, x2, y2)
input_box = np.array([100, 100, 500, 400])

# Predict mask
masks, scores, logits = predictor.predict(
    point_coords=None,
    point_labels=None,
    box=input_box[None, :],
    multimask_output=False
)

print(f"Generated mask with score: {scores[0]:.3f}")

# Visualize
fig, axes = plt.subplots(1, 2, figsize=(12, 6))

axes[0].imshow(image_rgb)
rect = plt.Rectangle((input_box[0], input_box[1]),
                      input_box[2] - input_box[0],
                      input_box[3] - input_box[1],
                      fill=False, edgecolor='red', linewidth=3)
axes[0].add_patch(rect)
axes[0].set_title("Input Image with Box")
axes[0].axis('off')

axes[1].imshow(image_rgb)
axes[1].imshow(masks[0], alpha=0.5, cmap='jet')
axes[1].set_title("Segmentation Result")
axes[1].axis('off')

plt.tight_layout()
plt.show()
```

### SAM - Automatic Mask Generation

```python
from segment_anything import SamAutomaticMaskGenerator

# Create automatic mask generator
mask_generator = SamAutomaticMaskGenerator(
    model=sam,
    points_per_side=32,
    pred_iou_thresh=0.86,
    stability_score_thresh=0.92,
    crop_n_layers=1,
    crop_n_points_downscale_factor=2,
    min_mask_region_area=100,  # Requires open-cv to run post-processing
)

# Load image
image_path = "path/to/image.jpg"
image = cv2.imread(image_path)
image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

# Generate masks
masks = mask_generator.generate(image_rgb)
print(f"Generated {len(masks)} masks automatically")

# Visualize all masks
plt.figure(figsize=(12, 8))
plt.imshow(image_rgb)

# Create a colored overlay
sorted_masks = sorted(masks, key=lambda x: x['area'], reverse=True)
mask_overlay = np.zeros((*image_rgb.shape[:2], 4))

for idx, mask_data in enumerate(sorted_masks):
    mask = mask_data['segmentation']
    color = np.random.random(3)
    mask_overlay[mask] = [*color, 0.5]

plt.imshow(mask_overlay)
plt.title(f"Automatic Segmentation ({len(masks)} masks)")
plt.axis('off')
plt.show()
```

### SAM 2 - Point and Box Prompts

```python
# Load image
image_path = "path/to/image.jpg"
image = cv2.imread(image_path)
image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

# Set image
predictor.set_image(image_rgb)

# Point prompts
input_points = np.array([[500, 375], [600, 400]])
input_labels = np.array([1, 1])  # Both foreground

# Box prompt
input_box = np.array([100, 100, 500, 400])

# Predict with combined prompts
masks, scores, _ = predictor.predict(
    point_coords=input_points,
    point_labels=input_labels,
    box=input_box,
    multimask_output=True
)

# Visualize
fig, axes = plt.subplots(1, 2, figsize=(14, 7))

axes[0].imshow(image_rgb)
axes[0].scatter(input_points[:, 0], input_points[:, 1], c='red', s=100, marker='*')
rect = plt.Rectangle((input_box[0], input_box[1]),
                      input_box[2] - input_box[0],
                      input_box[3] - input_box[1],
                      fill=False, edgecolor='yellow', linewidth=2)
axes[0].add_patch(rect)
axes[0].set_title("Input Prompts")
axes[0].axis('off')

best_mask_idx = np.argmax(scores)
axes[1].imshow(image_rgb)
axes[1].imshow(masks[best_mask_idx], alpha=0.6, cmap='jet')
axes[1].set_title(f"Best Mask (Score: {scores[best_mask_idx]:.3f})")
axes[1].axis('off')

plt.tight_layout()
plt.show()
```

### YOLO-Seg - Instance Segmentation

```python
# Load image
image_path = "path/to/image.jpg"
image = cv2.imread(image_path)

# Run inference
results = model.predict(
    source=image,
    conf=0.25,  # Confidence threshold
    iou=0.45,   # NMS IoU threshold
    imgsz=640,
    device=device
)

# Extract results
result = results[0]
boxes = result.boxes.xyxy.cpu().numpy()  # Bounding boxes
masks = result.masks.data.cpu().numpy() if result.masks else None
classes = result.boxes.cls.cpu().numpy()
confidences = result.boxes.conf.cpu().numpy()

print(f"Detected {len(boxes)} objects")

# Visualize with supervision
import supervision as sv

detections = sv.Detections(
    xyxy=boxes,
    mask=masks,
    class_id=classes.astype(int),
    confidence=confidences
)

# Annotate image
mask_annotator = sv.MaskAnnotator()
label_annotator = sv.LabelAnnotator()

labels = [
    f"{model.names[int(class_id)]} {confidence:.2f}"
    for class_id, confidence in zip(classes, confidences)
]

annotated_image = mask_annotator.annotate(scene=image.copy(), detections=detections)
annotated_image = label_annotator.annotate(scene=annotated_image, detections=detections, labels=labels)

# Display
plt.figure(figsize=(12, 8))
plt.imshow(cv2.cvtColor(annotated_image, cv2.COLOR_BGR2RGB))
plt.title(f"YOLO-Seg Results ({len(boxes)} objects)")
plt.axis('off')
plt.show()
```

---

## 3. Visualization

### Supervision - Advanced Mask Visualization

```python
import supervision as sv

# Create annotators
mask_annotator = sv.MaskAnnotator(opacity=0.5)
box_annotator = sv.BoxAnnotator()
label_annotator = sv.LabelAnnotator()

# Convert SAM masks to supervision format
def sam_to_detections(masks, image_shape):
    """Convert SAM masks to supervision Detections"""
    detections_list = []

    for mask in masks:
        # Get bounding box from mask
        ys, xs = np.where(mask)
        if len(xs) == 0 or len(ys) == 0:
            continue

        x1, y1 = xs.min(), ys.min()
        x2, y2 = xs.max(), ys.max()

        detections_list.append({
            'xyxy': [x1, y1, x2, y2],
            'mask': mask
        })

    if not detections_list:
        return None

    xyxy = np.array([d['xyxy'] for d in detections_list])
    masks = np.array([d['mask'] for d in detections_list])

    return sv.Detections(
        xyxy=xyxy,
        mask=masks
    )

# Example usage
image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
detections = sam_to_detections(masks, image.shape[:2])

if detections is not None:
    annotated_image = mask_annotator.annotate(scene=image.copy(), detections=detections)
    annotated_image = box_annotator.annotate(scene=annotated_image, detections=detections)

    plt.figure(figsize=(12, 8))
    plt.imshow(cv2.cvtColor(annotated_image, cv2.COLOR_BGR2RGB))
    plt.title("Mask Visualization with Supervision")
    plt.axis('off')
    plt.show()
```

### Multi-Mask Overlay

```python
def visualize_multiple_masks(image, masks, alpha=0.5):
    """Overlay multiple masks with different colors"""
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB) if len(image.shape) == 3 and image.shape[2] == 3 else image

    overlay = image_rgb.copy()

    # Generate distinct colors
    colors = []
    for i in range(len(masks)):
        hue = int(180 * i / len(masks))
        color = cv2.cvtColor(np.uint8([[[hue, 255, 255]]]), cv2.COLOR_HSV2RGB)[0][0]
        colors.append(color)

    # Apply masks
    for mask, color in zip(masks, colors):
        mask_colored = np.zeros_like(image_rgb)
        mask_colored[mask] = color
        overlay = cv2.addWeighted(overlay, 1, mask_colored, alpha, 0)

    return overlay

# Usage
overlay_image = visualize_multiple_masks(image, masks, alpha=0.4)

fig, axes = plt.subplots(1, 2, figsize=(14, 7))
axes[0].imshow(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
axes[0].set_title("Original Image")
axes[0].axis('off')

axes[1].imshow(overlay_image)
axes[1].set_title(f"Segmentation ({len(masks)} masks)")
axes[1].axis('off')

plt.tight_layout()
plt.show()
```

### Side-by-Side Comparison

```python
def compare_segmentation_methods(image, sam_masks, yolo_results):
    """Compare SAM and YOLO segmentation results"""
    fig, axes = plt.subplots(1, 3, figsize=(18, 6))

    # Original
    axes[0].imshow(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
    axes[0].set_title("Original Image")
    axes[0].axis('off')

    # SAM results
    sam_overlay = visualize_multiple_masks(image, sam_masks, alpha=0.5)
    axes[1].imshow(sam_overlay)
    axes[1].set_title(f"SAM ({len(sam_masks)} masks)")
    axes[1].axis('off')

    # YOLO results
    yolo_annotated = yolo_results[0].plot()
    axes[2].imshow(cv2.cvtColor(yolo_annotated, cv2.COLOR_BGR2RGB))
    axes[2].set_title("YOLO-Seg")
    axes[2].axis('off')

    plt.tight_layout()
    plt.show()

# Usage
compare_segmentation_methods(image, masks, results)
```

---

## 4. Evaluation

### IoU (Intersection over Union)

```python
def calculate_iou(mask1, mask2):
    """Calculate IoU between two binary masks"""
    intersection = np.logical_and(mask1, mask2).sum()
    union = np.logical_or(mask1, mask2).sum()

    if union == 0:
        return 0.0

    iou = intersection / union
    return iou

# Example: Compare predicted mask with ground truth
gt_mask = cv2.imread("ground_truth_mask.png", cv2.IMREAD_GRAYSCALE) > 127
pred_mask = masks[0]  # From SAM or YOLO

iou_score = calculate_iou(gt_mask, pred_mask)
print(f"IoU Score: {iou_score:.4f}")

# Visualize comparison
fig, axes = plt.subplots(1, 4, figsize=(16, 4))

axes[0].imshow(gt_mask, cmap='gray')
axes[0].set_title("Ground Truth")
axes[0].axis('off')

axes[1].imshow(pred_mask, cmap='gray')
axes[1].set_title("Prediction")
axes[1].axis('off')

axes[2].imshow(np.logical_and(gt_mask, pred_mask), cmap='Greens')
axes[2].set_title("Intersection")
axes[2].axis('off')

axes[3].imshow(np.logical_or(gt_mask, pred_mask), cmap='Reds')
axes[3].set_title(f"Union (IoU: {iou_score:.3f})")
axes[3].axis('off')

plt.tight_layout()
plt.show()
```

### Dice Coefficient

```python
def calculate_dice(mask1, mask2):
    """Calculate Dice coefficient between two binary masks"""
    intersection = np.logical_and(mask1, mask2).sum()

    if mask1.sum() + mask2.sum() == 0:
        return 1.0 if intersection == 0 else 0.0

    dice = (2 * intersection) / (mask1.sum() + mask2.sum())
    return dice

# Example usage
dice_score = calculate_dice(gt_mask, pred_mask)
print(f"Dice Coefficient: {dice_score:.4f}")
```

### Per-Instance Metrics

```python
def evaluate_instance_segmentation(pred_masks, gt_masks, iou_threshold=0.5):
    """
    Evaluate instance segmentation with multiple masks.
    Returns precision, recall, F1, and per-instance IoU.
    """
    num_pred = len(pred_masks)
    num_gt = len(gt_masks)

    # Compute IoU matrix
    iou_matrix = np.zeros((num_pred, num_gt))
    for i, pred_mask in enumerate(pred_masks):
        for j, gt_mask in enumerate(gt_masks):
            iou_matrix[i, j] = calculate_iou(pred_mask, gt_mask)

    # Match predictions to ground truth
    matched_pred = set()
    matched_gt = set()
    ious = []

    while True:
        max_iou = iou_matrix.max()
        if max_iou < iou_threshold:
            break

        i, j = np.unravel_index(iou_matrix.argmax(), iou_matrix.shape)
        matched_pred.add(i)
        matched_gt.add(j)
        ious.append(max_iou)

        iou_matrix[i, :] = 0
        iou_matrix[:, j] = 0

    true_positives = len(matched_pred)
    false_positives = num_pred - true_positives
    false_negatives = num_gt - true_positives

    precision = true_positives / (true_positives + false_positives) if num_pred > 0 else 0
    recall = true_positives / (true_positives + false_negatives) if num_gt > 0 else 0
    f1 = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0
    mean_iou = np.mean(ious) if ious else 0

    return {
        'precision': precision,
        'recall': recall,
        'f1': f1,
        'mean_iou': mean_iou,
        'true_positives': true_positives,
        'false_positives': false_positives,
        'false_negatives': false_negatives,
        'per_instance_iou': ious
    }

# Example usage
metrics = evaluate_instance_segmentation(pred_masks, gt_masks, iou_threshold=0.5)

print("Instance Segmentation Metrics:")
print(f"  Precision: {metrics['precision']:.4f}")
print(f"  Recall: {metrics['recall']:.4f}")
print(f"  F1 Score: {metrics['f1']:.4f}")
print(f"  Mean IoU: {metrics['mean_iou']:.4f}")
print(f"  TP: {metrics['true_positives']}, FP: {metrics['false_positives']}, FN: {metrics['false_negatives']}")
```

### Semantic Segmentation Metrics

```python
def semantic_segmentation_metrics(pred_mask, gt_mask, num_classes):
    """
    Calculate per-class IoU and mean IoU for semantic segmentation.
    Masks should contain class indices (0, 1, 2, ..., num_classes-1).
    """
    ious = []

    for cls in range(num_classes):
        pred_cls = (pred_mask == cls)
        gt_cls = (gt_mask == cls)

        intersection = np.logical_and(pred_cls, gt_cls).sum()
        union = np.logical_or(pred_cls, gt_cls).sum()

        if union > 0:
            iou = intersection / union
            ious.append(iou)
        else:
            ious.append(np.nan)  # Class not present

    mean_iou = np.nanmean(ious)

    return {
        'per_class_iou': ious,
        'mean_iou': mean_iou
    }

# Example usage (assuming multi-class semantic segmentation)
num_classes = 21  # e.g., COCO classes
metrics = semantic_segmentation_metrics(pred_mask, gt_mask, num_classes)

print(f"Mean IoU: {metrics['mean_iou']:.4f}")
print("\nPer-class IoU:")
for cls, iou in enumerate(metrics['per_class_iou']):
    if not np.isnan(iou):
        print(f"  Class {cls}: {iou:.4f}")
```

---

## 5. Training (YOLO-Seg)

### Dataset Format

```python
# YOLO segmentation dataset structure:
# dataset/
#   ├── images/
#   │   ├── train/
#   │   └── val/
#   ├── labels/
#   │   ├── train/
#   │   └── val/
#   └── data.yaml

# data.yaml content:
"""
path: /path/to/dataset
train: images/train
val: images/val

nc: 80  # Number of classes
names: ['person', 'bicycle', 'car', ...]  # Class names
"""

# Label format (one .txt file per image):
# <class_id> <x1> <y1> <x2> <y2> ... <xn> <yn>
# Normalized polygon coordinates (0-1)

# Example label file content:
# 0 0.1 0.2 0.3 0.2 0.3 0.4 0.1 0.4
# 1 0.5 0.5 0.7 0.5 0.7 0.7 0.5 0.7
```

### Training YOLO-Seg

```python
from ultralytics import YOLO

# Load a pretrained model
model = YOLO("yolov8n-seg.pt")  # or yolov8s-seg, yolov8m-seg, etc.

# Train the model
results = model.train(
    data="dataset/data.yaml",
    epochs=100,
    imgsz=640,
    batch=16,
    name="yolo_seg_custom",
    patience=50,
    save=True,
    device=0,  # GPU ID or 'cpu'
    workers=8,

    # Augmentation
    hsv_h=0.015,
    hsv_s=0.7,
    hsv_v=0.4,
    degrees=10.0,
    translate=0.1,
    scale=0.5,
    mosaic=1.0,
    mixup=0.0,

    # Hyperparameters
    lr0=0.01,
    lrf=0.01,
    momentum=0.937,
    weight_decay=0.0005,
    warmup_epochs=3.0,

    # Loss weights
    box=7.5,
    cls=0.5,
    dfl=1.5,
)

print(f"Training completed. Best model saved at: {results.save_dir}/weights/best.pt")
```

### Fine-Tuning on Custom Dataset

```python
# Load pretrained model
model = YOLO("yolov8m-seg.pt")

# Freeze backbone layers (optional)
for name, param in model.model.named_parameters():
    if "model.0" in name or "model.1" in name:  # First few layers
        param.requires_grad = False

# Fine-tune
results = model.train(
    data="custom_dataset/data.yaml",
    epochs=50,
    imgsz=640,
    batch=8,
    name="yolo_seg_finetuned",
    pretrained=True,
    freeze=10,  # Freeze first 10 layers
    device=0,
)
```

### Validation and Export

```python
# Validate model
metrics = model.val(data="dataset/data.yaml")

print(f"mAP50: {metrics.box.map50:.4f}")
print(f"mAP50-95: {metrics.box.map:.4f}")
print(f"Mask mAP50: {metrics.seg.map50:.4f}")
print(f"Mask mAP50-95: {metrics.seg.map:.4f}")

# Export to ONNX
model.export(format="onnx", dynamic=True, simplify=True)

# Export to TensorRT (requires TensorRT installed)
# model.export(format="engine", device=0)
```

---

## 6. Semantic Segmentation Patterns

### Convert Instance to Semantic Masks

```python
def instance_to_semantic(instance_masks, class_ids):
    """
    Convert instance segmentation masks to semantic segmentation.

    Args:
        instance_masks: List or array of binary masks (H, W)
        class_ids: List of class IDs corresponding to each mask

    Returns:
        Semantic mask (H, W) with class indices
    """
    h, w = instance_masks[0].shape
    semantic_mask = np.zeros((h, w), dtype=np.int32)

    for mask, class_id in zip(instance_masks, class_ids):
        semantic_mask[mask] = class_id

    return semantic_mask

# Example usage
semantic_mask = instance_to_semantic(masks, classes)

# Visualize semantic segmentation
plt.figure(figsize=(12, 6))
plt.subplot(1, 2, 1)
plt.imshow(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
plt.title("Original Image")
plt.axis('off')

plt.subplot(1, 2, 2)
plt.imshow(semantic_mask, cmap='tab20')
plt.title("Semantic Segmentation")
plt.colorbar()
plt.axis('off')

plt.tight_layout()
plt.show()
```

### Semantic Mask Color Mapping

```python
def apply_color_map(semantic_mask, num_classes, colormap='tab20'):
    """Apply color map to semantic segmentation mask"""
    from matplotlib import cm

    cmap = cm.get_cmap(colormap, num_classes)
    colored_mask = cmap(semantic_mask / num_classes)
    colored_mask = (colored_mask[:, :, :3] * 255).astype(np.uint8)

    return colored_mask

# Usage
colored_semantic = apply_color_map(semantic_mask, num_classes=21)

# Overlay on image
overlay = cv2.addWeighted(
    cv2.cvtColor(image, cv2.COLOR_BGR2RGB),
    0.6,
    colored_semantic,
    0.4,
    0
)

plt.figure(figsize=(10, 6))
plt.imshow(overlay)
plt.title("Semantic Segmentation Overlay")
plt.axis('off')
plt.show()
```

---

## Complete Pipeline Example

```python
# Complete segmentation pipeline with all methods

import cv2
import numpy as np
import matplotlib.pyplot as plt
from segment_anything import sam_model_registry, SamPredictor
from ultralytics import YOLO
import supervision as sv

# Load image
image_path = "path/to/image.jpg"
image = cv2.imread(image_path)
image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

# 1. SAM Automatic Segmentation
from segment_anything import SamAutomaticMaskGenerator

sam = sam_model_registry["vit_h"](checkpoint="sam_vit_h_4b8939.pth")
sam.to("cuda")
mask_generator = SamAutomaticMaskGenerator(sam)
sam_masks = mask_generator.generate(image_rgb)

# 2. YOLO Instance Segmentation
yolo_model = YOLO("yolov8n-seg.pt")
yolo_results = yolo_model(image)

# 3. Visualization
fig, axes = plt.subplots(2, 2, figsize=(14, 14))

# Original
axes[0, 0].imshow(image_rgb)
axes[0, 0].set_title("Original Image")
axes[0, 0].axis('off')

# SAM results
sam_overlay = image_rgb.copy()
for mask_data in sorted(sam_masks, key=lambda x: x['area'], reverse=True):
    mask = mask_data['segmentation']
    color = np.random.random(3)
    sam_overlay[mask] = sam_overlay[mask] * 0.5 + (color * 255 * 0.5)
axes[0, 1].imshow(sam_overlay.astype(np.uint8))
axes[0, 1].set_title(f"SAM ({len(sam_masks)} masks)")
axes[0, 1].axis('off')

# YOLO results
yolo_annotated = yolo_results[0].plot()
axes[1, 0].imshow(cv2.cvtColor(yolo_annotated, cv2.COLOR_BGR2RGB))
axes[1, 0].set_title("YOLO-Seg")
axes[1, 0].axis('off')

# Statistics
stats_text = f"""
SAM Masks: {len(sam_masks)}
YOLO Detections: {len(yolo_results[0].boxes)}
YOLO Classes: {set(yolo_results[0].boxes.cls.cpu().numpy().astype(int))}
"""
axes[1, 1].text(0.5, 0.5, stats_text, ha='center', va='center', fontsize=12)
axes[1, 1].axis('off')
axes[1, 1].set_title("Statistics")

plt.tight_layout()
plt.show()

print("Segmentation pipeline complete!")
```
