# ML Guidelines

Best practices for Machine Learning and Computer Vision tasks.

## Batch Inference Efficiency

Maximize GPU utilization with batch processing during validation/evaluation.

### Do's
- DataLoader + batch processing required for large-scale inference
- batch_size based on GPU memory (24GB -> 64, 12GB -> 32)
- Optimize memory with torch.no_grad() + autocast combination

### Don'ts
- Calling predict_file() repeatedly in file-by-file loop (GPU utilization < 10%)
- Using single-file API for large-scale inference

### Pattern

```python
# Good: Batch inference (GPU utilization 90%+)
loader = DataLoader(dataset, batch_size=64, num_workers=8)
with torch.no_grad():
    for batch in loader:
        outputs = model(batch["image"].cuda())

# Bad: File-by-file (only for demo/interactive use)
for f in files:
    predictor.predict_file(f)  # Excessive GPU idle time
```

## BGR vs RGB Color Format

OpenCV uses BGR, matplotlib uses RGB. Keep BGR during annotation, convert to RGB only before display.

```python
# Correct pattern
img = cv2.imread(path)                    # BGR
img = annotator.annotate(img, detections) # Keep BGR
img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB) # Convert just before display
plt.imshow(img)

# Wrong pattern (causes color inversion)
img = cv2.imread(path)
img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB) # Too early
img = annotator.annotate(img, detections)  # BGR colors on RGB image -> inverted
plt.imshow(img)
```

### Exception: Ultralytics YOLO

Ultralytics YOLO handles BGR to RGB conversion internally. Do NOT manually convert before passing to YOLO.

```python
# Correct: Pass BGR directly to YOLO (handles conversion internally)
img = cv2.imread(path)  # BGR
results = yolo_model(img)  # YOLO converts BGR->RGB internally

# Wrong: Manual conversion causes double conversion
img = cv2.imread(path)
img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)  # Unnecessary
results = yolo_model(img)  # YOLO converts again -> RGB->BGR (inverted)
```

## Ultralytics WandB Integration

Ultralytics YOLO has WandB disabled by default.

```bash
yolo settings wandb=True   # Enable
yolo settings wandb=False  # Disable
```
