# Object Detection Notebook Templates

Complete cell templates for object detection workflows using YOLO and RT-DETR models.

## 1. Model Loading

### YOLO Models
```python
from ultralytics import YOLO
import supervision as sv

# Load pretrained model
model = YOLO('yolov8n.pt')  # nano
# model = YOLO('yolov8s.pt')  # small
# model = YOLO('yolov8m.pt')  # medium
# model = YOLO('yolov8l.pt')  # large
# model = YOLO('yolov8x.pt')  # xlarge

# Load custom trained model
# model = YOLO('path/to/best.pt')

print(f"Model: {model.model_name}")
print(f"Classes: {model.names}")
```

### RT-DETR Models
```python
from ultralytics import RTDETR
import supervision as sv

# Load pretrained RT-DETR
model = RTDETR('rtdetr-l.pt')  # large
# model = RTDETR('rtdetr-x.pt')  # xlarge

# Load custom trained model
# model = RTDETR('path/to/best.pt')

print(f"Model: {model.model_name}")
print(f"Classes: {model.names}")
```

## 2. Inference

### Single Image Inference
```python
import cv2
from PIL import Image

# Option 1: From file path
results = model.predict('path/to/image.jpg', conf=0.25, iou=0.45)

# Option 2: From PIL Image
image = Image.open('path/to/image.jpg')
results = model.predict(image, conf=0.25, iou=0.45)

# Option 3: From numpy array
image = cv2.imread('path/to/image.jpg')
image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
results = model.predict(image_rgb, conf=0.25, iou=0.45)

# Extract detections
result = results[0]
boxes = result.boxes.xyxy.cpu().numpy()  # [x1, y1, x2, y2]
confidences = result.boxes.conf.cpu().numpy()
class_ids = result.boxes.cls.cpu().numpy().astype(int)

print(f"Detected {len(boxes)} objects")
```

### Batch Inference
```python
from pathlib import Path
import numpy as np

# Batch predict on multiple images
image_paths = list(Path('images/').glob('*.jpg'))
results = model.predict(image_paths, conf=0.25, iou=0.45, batch=16)

# Process results
for i, result in enumerate(results):
    boxes = result.boxes.xyxy.cpu().numpy()
    confidences = result.boxes.conf.cpu().numpy()
    class_ids = result.boxes.cls.cpu().numpy().astype(int)

    print(f"{image_paths[i].name}: {len(boxes)} detections")
```

### Video Inference
```python
# Process video file
results = model.predict(
    'path/to/video.mp4',
    conf=0.25,
    iou=0.45,
    stream=True,  # Stream results for memory efficiency
    save=True,    # Save annotated video
    project='runs/detect',
    name='video_inference'
)

for i, result in enumerate(results):
    if i % 30 == 0:  # Print every 30 frames
        print(f"Frame {i}: {len(result.boxes)} detections")
```

## 3. Visualization

### Basic Visualization with Supervision
```python
import supervision as sv
import cv2
from PIL import Image
import matplotlib.pyplot as plt

# Run inference
image = cv2.imread('path/to/image.jpg')
image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
results = model.predict(image_rgb, conf=0.25, iou=0.45)

# Convert to supervision Detections
detections = sv.Detections.from_ultralytics(results[0])

# Create annotators
box_annotator = sv.BoxAnnotator(thickness=2)
label_annotator = sv.LabelAnnotator(text_thickness=1, text_scale=0.5)

# Create labels
labels = [
    f"{model.names[class_id]} {confidence:.2f}"
    for class_id, confidence in zip(detections.class_id, detections.confidence)
]

# Annotate image
annotated_image = box_annotator.annotate(scene=image_rgb.copy(), detections=detections)
annotated_image = label_annotator.annotate(scene=annotated_image, detections=detections, labels=labels)

# Display
plt.figure(figsize=(12, 8))
plt.imshow(annotated_image)
plt.axis('off')
plt.title(f'Detections: {len(detections)}')
plt.show()
```

### Advanced Visualization with Custom Colors
```python
import supervision as sv
import cv2
import matplotlib.pyplot as plt
import numpy as np

# Run inference
image = cv2.imread('path/to/image.jpg')
image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
results = model.predict(image_rgb, conf=0.25, iou=0.45)

# Convert to supervision Detections
detections = sv.Detections.from_ultralytics(results[0])

# Create custom color palette
colors = sv.ColorPalette.from_hex(['#FF6B6B', '#4ECDC4', '#45B7D1', '#FFA07A', '#98D8C8'])

# Create annotators with custom styling
box_annotator = sv.BoxAnnotator(
    thickness=2,
    color=colors
)
label_annotator = sv.LabelAnnotator(
    text_thickness=1,
    text_scale=0.5,
    text_color=sv.Color.WHITE,
    color=colors
)

# Create labels with confidence scores
labels = [
    f"{model.names[class_id]} {confidence:.2f}"
    for class_id, confidence in zip(detections.class_id, detections.confidence)
]

# Annotate
annotated_image = box_annotator.annotate(scene=image_rgb.copy(), detections=detections)
annotated_image = label_annotator.annotate(scene=annotated_image, detections=detections, labels=labels)

# Display with statistics
plt.figure(figsize=(14, 10))
plt.imshow(annotated_image)
plt.axis('off')

# Add statistics text
unique_classes = np.unique(detections.class_id)
stats_text = f"Total Detections: {len(detections)}\n"
stats_text += "Per-class counts:\n"
for class_id in unique_classes:
    count = np.sum(detections.class_id == class_id)
    stats_text += f"  {model.names[class_id]}: {count}\n"

plt.title(stats_text, fontsize=10, loc='left', pad=20)
plt.show()
```

## 4. Dataset Preparation

### Roboflow Dataset Download
```python
from roboflow import Roboflow
import os

# Initialize Roboflow
rf = Roboflow(api_key="YOUR_API_KEY")

# Download dataset
project = rf.workspace("workspace-name").project("project-name")
dataset = project.version(1).download("yolov8", location="./datasets/my_dataset")

print(f"Dataset downloaded to: {dataset.location}")
print(f"Data YAML: {dataset.location}/data.yaml")
```

### Manual data.yaml Structure
```python
# Create data.yaml file for custom dataset
import yaml

data_config = {
    'path': '/absolute/path/to/dataset',  # Dataset root directory
    'train': 'images/train',  # Train images (relative to path)
    'val': 'images/val',      # Validation images
    'test': 'images/test',    # Optional test images
    'nc': 3,                  # Number of classes
    'names': ['class1', 'class2', 'class3']  # Class names
}

# Save to file
with open('data.yaml', 'w') as f:
    yaml.dump(data_config, f, sort_keys=False)

print("data.yaml created successfully")
```

### Dataset Validation
```python
from pathlib import Path
import yaml

# Load data.yaml
with open('data.yaml', 'r') as f:
    data = yaml.safe_load(f)

# Validate paths
dataset_path = Path(data['path'])
train_path = dataset_path / data['train']
val_path = dataset_path / data['val']

train_images = list(train_path.glob('*.jpg')) + list(train_path.glob('*.png'))
val_images = list(val_path.glob('*.jpg')) + list(val_path.glob('*.png'))

print(f"Dataset Path: {dataset_path}")
print(f"Classes ({data['nc']}): {data['names']}")
print(f"Train Images: {len(train_images)}")
print(f"Val Images: {len(val_images)}")

# Check for corresponding labels
train_labels_path = dataset_path / 'labels' / 'train'
val_labels_path = dataset_path / 'labels' / 'val'

train_labels = list(train_labels_path.glob('*.txt'))
val_labels = list(val_labels_path.glob('*.txt'))

print(f"Train Labels: {len(train_labels)}")
print(f"Val Labels: {len(val_labels)}")
```

## 5. Training

### Basic Training (YOLO)
```python
from ultralytics import YOLO

# Load pretrained model
model = YOLO('yolov8n.pt')

# Train
results = model.train(
    data='data.yaml',
    epochs=100,
    imgsz=640,
    batch=16,
    name='yolov8n_custom',
    project='runs/detect',
    device=0,  # GPU 0, use 'cpu' for CPU
)

print(f"Training complete. Best model: {model.trainer.best}")
```

### Advanced Training Configuration (YOLO)
```python
from ultralytics import YOLO

# Load model
model = YOLO('yolov8s.pt')

# Train with advanced parameters
results = model.train(
    # Dataset
    data='data.yaml',

    # Training duration
    epochs=300,
    patience=50,  # Early stopping patience

    # Image settings
    imgsz=640,
    batch=32,

    # Optimization
    optimizer='AdamW',  # 'SGD', 'Adam', 'AdamW', 'RMSProp'
    lr0=0.01,          # Initial learning rate
    lrf=0.01,          # Final learning rate (lr0 * lrf)
    momentum=0.937,
    weight_decay=0.0005,

    # Augmentation
    hsv_h=0.015,       # HSV-Hue augmentation
    hsv_s=0.7,         # HSV-Saturation
    hsv_v=0.4,         # HSV-Value
    degrees=0.0,       # Rotation (+/- deg)
    translate=0.1,     # Translation (+/- fraction)
    scale=0.5,         # Scale (+/- gain)
    shear=0.0,         # Shear (+/- deg)
    perspective=0.0,   # Perspective (+/- fraction)
    flipud=0.0,        # Vertical flip probability
    fliplr=0.5,        # Horizontal flip probability
    mosaic=1.0,        # Mosaic augmentation probability
    mixup=0.0,         # Mixup augmentation probability
    copy_paste=0.0,    # Copy-paste augmentation probability

    # Hyperparameters
    box=7.5,           # Box loss gain
    cls=0.5,           # Classification loss gain
    dfl=1.5,           # DFL loss gain

    # Output
    name='yolov8s_advanced',
    project='runs/detect',
    exist_ok=False,
    pretrained=True,

    # Hardware
    device=0,          # GPU device (0, 1, 2, etc.) or 'cpu'
    workers=8,         # Dataloader workers

    # Validation
    val=True,          # Validate during training
    save=True,         # Save checkpoints
    save_period=-1,    # Save checkpoint every N epochs (-1 = disabled)

    # Misc
    verbose=True,
    seed=0,
    deterministic=True,
    single_cls=False,  # Train as single-class dataset
    rect=False,        # Rectangular training
    cos_lr=False,      # Use cosine learning rate scheduler
    close_mosaic=10,   # Disable mosaic augmentation for last N epochs
    amp=True,          # Automatic Mixed Precision
)

print(f"Best model saved to: {model.trainer.best}")
```

### RT-DETR Training
```python
from ultralytics import RTDETR

# Load RT-DETR model
model = RTDETR('rtdetr-l.pt')

# Train RT-DETR
results = model.train(
    data='data.yaml',
    epochs=100,
    imgsz=640,
    batch=16,
    name='rtdetr_custom',
    project='runs/detect',
    device=0,
    lr0=0.0001,  # RT-DETR typically uses lower learning rate
    optimizer='AdamW',
)

print(f"Training complete. Best model: {model.trainer.best}")
```

### Resume Training
```python
from ultralytics import YOLO

# Resume from last checkpoint
model = YOLO('runs/detect/yolov8n_custom/weights/last.pt')
results = model.train(resume=True)
```

## 6. Evaluation

### Basic Metrics
```python
from ultralytics import YOLO

# Load trained model
model = YOLO('runs/detect/yolov8n_custom/weights/best.pt')

# Validate on validation set
metrics = model.val(data='data.yaml')

# Print key metrics
print(f"mAP50: {metrics.box.map50:.4f}")
print(f"mAP50-95: {metrics.box.map:.4f}")
print(f"Precision: {metrics.box.mp:.4f}")
print(f"Recall: {metrics.box.mr:.4f}")
```

### Detailed Per-Class Metrics
```python
from ultralytics import YOLO
import pandas as pd

# Load model and validate
model = YOLO('runs/detect/yolov8n_custom/weights/best.pt')
metrics = model.val(data='data.yaml')

# Per-class AP
per_class_ap = metrics.box.maps  # AP for each class

# Create DataFrame
results_df = pd.DataFrame({
    'Class': list(model.names.values()),
    'AP50': per_class_ap,
    'Images': metrics.box.nc,  # Number of images per class
})

print("\nPer-Class Results:")
print(results_df.to_string(index=False))

# Overall metrics
print(f"\nOverall Metrics:")
print(f"  mAP50: {metrics.box.map50:.4f}")
print(f"  mAP50-95: {metrics.box.map:.4f}")
print(f"  Precision: {metrics.box.mp:.4f}")
print(f"  Recall: {metrics.box.mr:.4f}")
print(f"  F1: {2 * (metrics.box.mp * metrics.box.mr) / (metrics.box.mp + metrics.box.mr):.4f}")
```

### Confusion Matrix
```python
from ultralytics import YOLO
from ultralytics.utils.plotting import plot_results
import matplotlib.pyplot as plt

# Load model
model = YOLO('runs/detect/yolov8n_custom/weights/best.pt')

# Validate with confusion matrix
metrics = model.val(
    data='data.yaml',
    plots=True,  # Generate plots including confusion matrix
    save_json=True,  # Save results to JSON
)

# Confusion matrix is automatically saved to:
# runs/detect/val/confusion_matrix.png

# Display confusion matrix
from PIL import Image

cm_path = 'runs/detect/val/confusion_matrix.png'
if Path(cm_path).exists():
    cm_img = Image.open(cm_path)
    plt.figure(figsize=(10, 10))
    plt.imshow(cm_img)
    plt.axis('off')
    plt.title('Confusion Matrix')
    plt.show()
```

### Custom Confusion Matrix Calculation
```python
from ultralytics import YOLO
from ultralytics.utils.metrics import ConfusionMatrix
import matplotlib.pyplot as plt
import numpy as np

# Load model
model = YOLO('runs/detect/yolov8n_custom/weights/best.pt')

# Run validation to get predictions
results = model.val(data='data.yaml')

# Access confusion matrix from metrics
conf_matrix = results.confusion_matrix.matrix  # numpy array

# Visualize
fig, ax = plt.subplots(figsize=(12, 10))
im = ax.imshow(conf_matrix, cmap='Blues')

# Set ticks and labels
class_names = list(model.names.values())
ax.set_xticks(np.arange(len(class_names) + 1))
ax.set_yticks(np.arange(len(class_names) + 1))
ax.set_xticklabels(class_names + ['background'], rotation=45, ha='right')
ax.set_yticklabels(class_names + ['background'])

# Add colorbar
plt.colorbar(im, ax=ax)

# Add text annotations
for i in range(len(class_names) + 1):
    for j in range(len(class_names) + 1):
        text = ax.text(j, i, int(conf_matrix[i, j]),
                      ha="center", va="center", color="black", fontsize=8)

ax.set_xlabel('Predicted')
ax.set_ylabel('True')
ax.set_title('Confusion Matrix')
plt.tight_layout()
plt.show()
```

### Precision-Recall Curve
```python
from ultralytics import YOLO
from pathlib import Path
import matplotlib.pyplot as plt
from PIL import Image

# Load model and validate
model = YOLO('runs/detect/yolov8n_custom/weights/best.pt')
metrics = model.val(data='data.yaml', plots=True)

# PR curve is automatically saved
pr_curve_path = 'runs/detect/val/PR_curve.png'
if Path(pr_curve_path).exists():
    pr_img = Image.open(pr_curve_path)
    plt.figure(figsize=(12, 8))
    plt.imshow(pr_img)
    plt.axis('off')
    plt.title('Precision-Recall Curve')
    plt.show()
```

### F1-Confidence Curve
```python
from ultralytics import YOLO
from pathlib import Path
import matplotlib.pyplot as plt
from PIL import Image

# Load model and validate
model = YOLO('runs/detect/yolov8n_custom/weights/best.pt')
metrics = model.val(data='data.yaml', plots=True)

# F1 curve is automatically saved
f1_curve_path = 'runs/detect/val/F1_curve.png'
if Path(f1_curve_path).exists():
    f1_img = Image.open(f1_curve_path)
    plt.figure(figsize=(12, 8))
    plt.imshow(f1_img)
    plt.axis('off')
    plt.title('F1-Confidence Curve')
    plt.show()
```

### Test Set Evaluation
```python
from ultralytics import YOLO
import yaml

# Load model
model = YOLO('runs/detect/yolov8n_custom/weights/best.pt')

# Create test data config
with open('data.yaml', 'r') as f:
    data_config = yaml.safe_load(f)

# Ensure test split exists
if 'test' not in data_config:
    print("Warning: No test split defined in data.yaml")
    print("Using validation set for evaluation")
    test_data = 'data.yaml'
else:
    test_data = 'data.yaml'

# Run evaluation on test set
metrics = model.val(
    data=test_data,
    split='test',  # Use test split
    plots=True,
    save_json=True,
)

print(f"\nTest Set Results:")
print(f"  mAP50: {metrics.box.map50:.4f}")
print(f"  mAP50-95: {metrics.box.map:.4f}")
print(f"  Precision: {metrics.box.mp:.4f}")
print(f"  Recall: {metrics.box.mr:.4f}")
```

### Benchmark Inference Speed
```python
from ultralytics import YOLO
import time
import numpy as np
import cv2

# Load model
model = YOLO('runs/detect/yolov8n_custom/weights/best.pt')

# Prepare test image
test_image = cv2.imread('path/to/test/image.jpg')
test_image_rgb = cv2.cvtColor(test_image, cv2.COLOR_BGR2RGB)

# Warmup
for _ in range(10):
    _ = model.predict(test_image_rgb, verbose=False)

# Benchmark
num_runs = 100
times = []

for _ in range(num_runs):
    start = time.perf_counter()
    results = model.predict(test_image_rgb, verbose=False)
    end = time.perf_counter()
    times.append(end - start)

times = np.array(times)

print(f"\nInference Speed Benchmark ({num_runs} runs):")
print(f"  Mean: {times.mean()*1000:.2f} ms")
print(f"  Std: {times.std()*1000:.2f} ms")
print(f"  Min: {times.min()*1000:.2f} ms")
print(f"  Max: {times.max()*1000:.2f} ms")
print(f"  FPS: {1/times.mean():.2f}")
```

## 7. Export

### ONNX Export
```python
from ultralytics import YOLO

# Load model
model = YOLO('runs/detect/yolov8n_custom/weights/best.pt')

# Export to ONNX
onnx_path = model.export(
    format='onnx',
    dynamic=True,  # Dynamic input shapes
    simplify=True,  # Simplify model
    opset=12,  # ONNX opset version
)

print(f"Model exported to: {onnx_path}")
```

### TensorRT Export
```python
from ultralytics import YOLO

# Load model
model = YOLO('runs/detect/yolov8n_custom/weights/best.pt')

# Export to TensorRT
trt_path = model.export(
    format='engine',
    device=0,  # GPU device
    half=True,  # FP16 precision
    workspace=4,  # Max workspace size (GB)
    imgsz=640,
)

print(f"TensorRT engine exported to: {trt_path}")
```

### All Export Formats
```python
from ultralytics import YOLO

# Load model
model = YOLO('runs/detect/yolov8n_custom/weights/best.pt')

# Available formats:
export_formats = [
    'onnx',      # ONNX
    'engine',    # TensorRT
    'openvino',  # OpenVINO
    'coreml',    # CoreML (macOS)
    'saved_model',  # TensorFlow SavedModel
    'pb',        # TensorFlow GraphDef
    'tflite',    # TensorFlow Lite
    'edgetpu',   # TensorFlow Edge TPU
    'tfjs',      # TensorFlow.js
    'paddle',    # PaddlePaddle
]

# Export to specific format
format_choice = 'onnx'
exported_path = model.export(format=format_choice)
print(f"Exported to {format_choice}: {exported_path}")
```

### Export with Validation
```python
from ultralytics import YOLO
import onnxruntime as ort
import numpy as np

# Load and export model
model = YOLO('runs/detect/yolov8n_custom/weights/best.pt')
onnx_path = model.export(format='onnx', dynamic=True, simplify=True)

# Validate ONNX model
session = ort.InferenceSession(onnx_path)

# Get input/output info
input_name = session.get_inputs()[0].name
output_names = [output.name for output in session.get_outputs()]

print(f"\nONNX Model Info:")
print(f"  Input: {input_name}")
print(f"  Input shape: {session.get_inputs()[0].shape}")
print(f"  Outputs: {output_names}")

# Test inference
import cv2
test_image = cv2.imread('path/to/test/image.jpg')
test_image_rgb = cv2.cvtColor(test_image, cv2.COLOR_BGR2RGB)

# Preprocess (example for 640x640)
input_size = 640
test_image_resized = cv2.resize(test_image_rgb, (input_size, input_size))
input_array = test_image_resized.astype(np.float32) / 255.0
input_array = np.transpose(input_array, (2, 0, 1))  # HWC to CHW
input_array = np.expand_dims(input_array, axis=0)  # Add batch dimension

# Run inference
outputs = session.run(output_names, {input_name: input_array})
print(f"\nONNX inference successful!")
print(f"  Output shapes: {[out.shape for out in outputs]}")
```

## Notes

- All supervision visualization examples use the latest v0.22+ API
- YOLO models: YOLOv8n/s/m/l/x variants available
- RT-DETR models: Transformer-based detector alternative to YOLO
- Training automatically uses GPU if available (device=0)
- Validation plots saved to runs/detect/val/ directory
- Use `imgsz=1280` for better accuracy on small objects
- Batch size depends on GPU memory (reduce if OOM errors occur)
- Early stopping via `patience` parameter prevents overfitting
