# ML/CV Library Pitfalls

Supporting reference for `ml-dev-principles`. These are library-level mistakes below
the how-to-work discipline in `SKILL.md` — they break output correctness or
throughput regardless of process, and they recur across CV projects independently
of which model or dataset is in play.

## Quick reference

| Pitfall | Symptom | Fix |
|---|---|---|
| Per-file inference loop | GPU utilization < 10% | Batch through a `DataLoader` |
| Early BGR→RGB conversion | Annotation colors inverted | Convert only right before display |
| Manual BGR→RGB before YOLO | Colors double-inverted | Pass BGR directly — YOLO converts internally |
| WandB left at default | Unwanted run, or no run when one was expected | Set `yolo settings wandb=<true\|false>` explicitly |

## Batch inference

Calling a single-file predict API in a loop caps GPU utilization under 10% — this is
the single-GPU prerequisite check before reaching for the multi-GPU strategies in §5:
profile utilization first, and fix a per-file loop before adding parallelism on top of it.

```python
# Good: batch inference (GPU utilization 90%+)
loader = DataLoader(dataset, batch_size=64, num_workers=8)
with torch.no_grad():
    for batch in loader:
        outputs = model(batch["image"].cuda())

# Bad: file-by-file (only acceptable for demo/interactive use)
for f in files:
    predictor.predict_file(f)  # GPU sits idle between calls
```

`batch_size` follows GPU memory (24GB → 64, 12GB → 32); combine `torch.no_grad()` with
autocast to cut memory further.

## BGR vs RGB color format

OpenCV reads images as BGR; matplotlib and most display code expect RGB. Convert only
once, immediately before display — annotate in BGR the whole way through.

```python
# Correct: convert just before display
img = cv2.imread(path)                    # BGR
img = annotator.annotate(img, detections) # still BGR
img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
plt.imshow(img)

# Wrong: convert too early — annotation colors land on an RGB image and invert
img = cv2.imread(path)
img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
img = annotator.annotate(img, detections)
plt.imshow(img)
```

### Exception: Ultralytics YOLO

YOLO converts BGR→RGB internally. Pass it BGR directly — a manual conversion first
causes a second, unwanted conversion inside the call.

```python
# Correct: YOLO does the conversion
img = cv2.imread(path)      # BGR
results = yolo_model(img)   # converts internally

# Wrong: double conversion inverts the result
img = cv2.imread(path)
img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
results = yolo_model(img)   # YOLO converts again -> back to BGR order
```

## Ultralytics WandB integration

WandB logging is disabled by default in Ultralytics YOLO. Set it explicitly rather
than relying on the default matching what the task needs:

```bash
yolo settings wandb=True   # enable
yolo settings wandb=False  # disable
```
