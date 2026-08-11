# Interactive Exploration Patterns

Production-quality code patterns for ipywidgets-based CV data exploration.

## Pattern A: Image Navigation Widget

Core navigation widget with IntSlider for browsing images.

```python
import ipywidgets as widgets
from IPython.display import display, clear_output

# --- Image Navigation ---
slider = widgets.IntSlider(
    value=0, min=0, max=len(image_paths) - 1,
    step=1, description='Image:',
    continuous_update=False,
    layout=widgets.Layout(width='80%')
)

output = widgets.Output()

def on_index_change(change):
    with output:
        clear_output(wait=True)
        idx = change['new']
        img = load_image(image_paths[idx])
        display_image(img, title=f"[{idx}/{len(image_paths)-1}] {image_paths[idx].name}")

slider.observe(on_index_change, names='value')

# Trigger initial display
on_index_change({'new': 0})
display(widgets.VBox([slider, output]))
```

### Key Points
- `continuous_update=False`: Only trigger on release, not during drag (prevents lag)
- `clear_output(wait=True)`: Clear previous output before rendering new one (prevents flicker)
- `widgets.Output()`: Capture matplotlib/PIL output in widget context
- Always trigger initial display with `on_index_change({'new': 0})`

---

## Pattern B: Image Cache

Cache loaded images to avoid redundant disk I/O.

### Dict-based Cache (Recommended for large datasets)
```python
_cache = {}
MAX_CACHE_SIZE = 200  # Adjust based on available memory

def load_image_cached(path):
    """Load image with dict-based LRU-like cache."""
    key = str(path)
    if key not in _cache:
        if len(_cache) >= MAX_CACHE_SIZE:
            # Remove oldest entry
            oldest_key = next(iter(_cache))
            del _cache[oldest_key]
        img = cv2.imread(str(path))
        if img is not None:
            img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        _cache[key] = img
    return _cache[key]
```

### functools.lru_cache (Simple, for small datasets)
```python
from functools import lru_cache

@lru_cache(maxsize=100)
def load_image_cached(path_str: str):
    """Load and cache image. Pass string path for hashability."""
    img = cv2.imread(path_str)
    if img is not None:
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    return img
```

### Key Points
- Dict cache: manual eviction, works with any key type, memory-controllable
- lru_cache: automatic eviction, requires hashable args (use `str(path)`)
- Always convert BGR→RGB on load (cv2 default is BGR)
- Set cache size based on image resolution and available RAM

---

## Pattern C: Side-by-Side Comparison

Compare two views of the same image (e.g., raw vs annotated, model A vs model B).

```python
def show_comparison(idx, mode_left='raw', mode_right='annotated'):
    """Display side-by-side comparison."""
    fig, axes = plt.subplots(1, 2, figsize=(DISPLAY_WIDTH, DISPLAY_WIDTH // 2))

    img = load_image_cached(str(image_paths[idx]))

    # Left panel
    left_img = render_view(img, image_paths[idx], mode=mode_left)
    axes[0].imshow(left_img)
    axes[0].set_title(mode_left, fontsize=12)
    axes[0].axis('off')

    # Right panel
    right_img = render_view(img, image_paths[idx], mode=mode_right)
    axes[1].imshow(right_img)
    axes[1].set_title(mode_right, fontsize=12)
    axes[1].axis('off')

    plt.tight_layout()
    plt.show()

# --- Comparison Widget ---
mode_options = ['raw', 'annotated', 'grayscale', 'edges']

left_dropdown = widgets.Dropdown(options=mode_options, value='raw', description='Left:')
right_dropdown = widgets.Dropdown(options=mode_options, value='annotated', description='Right:')
comp_slider = widgets.IntSlider(
    value=0, min=0, max=len(image_paths) - 1,
    description='Image:', continuous_update=False,
    layout=widgets.Layout(width='80%')
)

comp_output = widgets.Output()

def on_comparison_change(change):
    with comp_output:
        clear_output(wait=True)
        show_comparison(comp_slider.value, left_dropdown.value, right_dropdown.value)

comp_slider.observe(on_comparison_change, names='value')
left_dropdown.observe(on_comparison_change, names='value')
right_dropdown.observe(on_comparison_change, names='value')

on_comparison_change({'new': None})
display(widgets.VBox([
    widgets.HBox([left_dropdown, right_dropdown]),
    comp_slider,
    comp_output
]))
```

---

## Pattern D: Threshold Tuning Slider

Interactive confidence threshold adjustment for detection/classification results.

```python
# --- Threshold Tuning ---
threshold_slider = widgets.FloatSlider(
    value=0.5, min=0.0, max=1.0, step=0.05,
    description='Conf Threshold:',
    continuous_update=False,
    readout_format='.2f',
    layout=widgets.Layout(width='80%'),
    style={'description_width': '120px'}
)

nms_slider = widgets.FloatSlider(
    value=0.45, min=0.0, max=1.0, step=0.05,
    description='NMS IoU:',
    continuous_update=False,
    readout_format='.2f',
    layout=widgets.Layout(width='80%'),
    style={'description_width': '120px'}
)

threshold_output = widgets.Output()

def on_threshold_change(change):
    with threshold_output:
        clear_output(wait=True)
        idx = slider.value  # Reuse main slider
        img = load_image_cached(str(image_paths[idx]))
        annotations = get_annotations(image_paths[idx])

        # Filter by confidence
        filtered = [a for a in annotations if a['score'] >= threshold_slider.value]

        # Apply NMS if applicable
        if nms_slider.value < 1.0:
            filtered = apply_nms(filtered, iou_threshold=nms_slider.value)

        # Render
        result = draw_annotations(img.copy(), filtered)
        plt.figure(figsize=(DISPLAY_WIDTH, DISPLAY_WIDTH * 0.75))
        plt.imshow(result)
        plt.title(f"Threshold: {threshold_slider.value:.2f} | NMS IoU: {nms_slider.value:.2f} | {len(filtered)} detections")
        plt.axis('off')
        plt.show()

threshold_slider.observe(on_threshold_change, names='value')
nms_slider.observe(on_threshold_change, names='value')
slider.observe(on_threshold_change, names='value')

on_threshold_change({'new': None})
display(widgets.VBox([threshold_slider, nms_slider, threshold_output]))
```

---

## Pattern E: Statistics Dashboard (HTML)

Dataset-level statistics rendered as HTML table in widget.

```python
def compute_statistics(annotations_dict):
    """Compute dataset-level statistics."""
    stats = {
        'total_images': len(annotations_dict),
        'total_annotations': sum(len(v) for v in annotations_dict.values()),
        'class_distribution': {},
        'avg_annotations_per_image': 0,
        'images_without_annotations': 0,
    }

    all_classes = []
    for img_id, anns in annotations_dict.items():
        if len(anns) == 0:
            stats['images_without_annotations'] += 1
        for ann in anns:
            cls = ann.get('category', ann.get('class', 'unknown'))
            all_classes.append(cls)

    from collections import Counter
    stats['class_distribution'] = dict(Counter(all_classes).most_common())
    stats['avg_annotations_per_image'] = (
        stats['total_annotations'] / max(stats['total_images'], 1)
    )
    return stats

def render_stats_html(stats):
    """Render statistics as HTML."""
    rows = "".join(
        f"<tr><td style='padding:4px 12px;font-weight:bold'>{k}</td>"
        f"<td style='padding:4px 12px'>{v}</td></tr>"
        for k, v in stats.items() if k != 'class_distribution'
    )
    html = f"""
    <div style='font-family:monospace;'>
    <h3>📊 Dataset Statistics</h3>
    <table style='border-collapse:collapse;'>
    {rows}
    </table>
    </div>
    """
    return widgets.HTML(html)

# --- Class Distribution Chart ---
def plot_class_distribution(stats):
    """Plot class distribution bar chart."""
    dist = stats['class_distribution']
    if not dist:
        print("No annotations found.")
        return

    classes = list(dist.keys())
    counts = list(dist.values())

    fig, ax = plt.subplots(figsize=(max(8, len(classes) * 0.5), 5))
    bars = ax.bar(range(len(classes)), counts, color='steelblue')
    ax.set_xticks(range(len(classes)))
    ax.set_xticklabels(classes, rotation=45, ha='right')
    ax.set_ylabel('Count')
    ax.set_title('Class Distribution')

    # Add count labels on bars
    for bar, count in zip(bars, counts):
        ax.text(bar.get_x() + bar.get_width()/2., bar.get_height(),
                str(count), ha='center', va='bottom', fontsize=9)

    plt.tight_layout()
    plt.show()
```

---

## Pattern F: Toggle Class Filter

Filter displayed annotations by class using ToggleButtons.

```python
# --- Class Filter ---
unique_classes = sorted(set(
    ann.get('category', ann.get('class', 'unknown'))
    for anns in annotations_dict.values()
    for ann in anns
))

class_toggle = widgets.ToggleButtons(
    options=['ALL'] + unique_classes,
    value='ALL',
    description='Class:',
    button_style='',
    layout=widgets.Layout(flex_flow='row wrap')
)

filter_output = widgets.Output()

def on_class_filter(change):
    with filter_output:
        clear_output(wait=True)
        selected_class = class_toggle.value
        idx = slider.value
        img = load_image_cached(str(image_paths[idx]))
        annotations = get_annotations(image_paths[idx])

        if selected_class != 'ALL':
            annotations = [a for a in annotations
                          if a.get('category', a.get('class')) == selected_class]

        result = draw_annotations(img.copy(), annotations)
        plt.figure(figsize=(DISPLAY_WIDTH, DISPLAY_WIDTH * 0.75))
        plt.imshow(result)
        plt.title(f"Class: {selected_class} | {len(annotations)} annotations")
        plt.axis('off')
        plt.show()

class_toggle.observe(on_class_filter, names='value')
slider.observe(on_class_filter, names='value')

on_class_filter({'new': None})
display(widgets.VBox([class_toggle, filter_output]))
```

---

## Pattern G: CV Annotation Viewer

Core annotation rendering with supervision/cv2 branching.

### With supervision (use_supervision=True)
```python
import supervision as sv
import numpy as np

def render_detections_sv(image, annotations, conf_threshold=0.5):
    """Render detections using supervision library."""
    if not annotations:
        return image

    boxes = np.array([a['bbox'] for a in annotations])  # xyxy format
    scores = np.array([a.get('score', 1.0) for a in annotations])
    class_ids = np.array([a.get('class_id', 0) for a in annotations])
    labels = [a.get('label', '') for a in annotations]

    # Filter by confidence
    mask = scores >= conf_threshold
    detections = sv.Detections(
        xyxy=boxes[mask],
        confidence=scores[mask],
        class_id=class_ids[mask]
    )

    # Annotate
    box_annotator = sv.BoxAnnotator(thickness=2)
    label_annotator = sv.LabelAnnotator(text_scale=0.5, text_padding=5)

    annotated = box_annotator.annotate(image.copy(), detections)
    annotated = label_annotator.annotate(
        annotated, detections,
        labels=[labels[i] for i, m in enumerate(mask) if m]
    )
    return annotated


def render_segmentation_sv(image, annotations, opacity=0.5):
    """Render segmentation masks using supervision library."""
    if not annotations:
        return image

    masks = np.array([a['mask'] for a in annotations])  # (N, H, W) bool
    class_ids = np.array([a.get('class_id', 0) for a in annotations])

    detections = sv.Detections(
        xyxy=sv.mask_to_xyxy(masks),
        mask=masks,
        class_id=class_ids
    )

    mask_annotator = sv.MaskAnnotator(opacity=opacity)
    annotated = mask_annotator.annotate(image.copy(), detections)
    return annotated
```

### Without supervision (use_supervision=False)
```python
import cv2
import numpy as np

# Color palette for classes
COLORS = [
    (255, 0, 0), (0, 255, 0), (0, 0, 255), (255, 255, 0),
    (255, 0, 255), (0, 255, 255), (128, 0, 0), (0, 128, 0),
    (0, 0, 128), (128, 128, 0), (128, 0, 128), (0, 128, 128),
]

def render_detections_cv2(image, annotations, conf_threshold=0.5):
    """Render detections using raw cv2."""
    result = image.copy()
    for ann in annotations:
        score = ann.get('score', 1.0)
        if score < conf_threshold:
            continue

        x1, y1, x2, y2 = [int(v) for v in ann['bbox']]
        class_id = ann.get('class_id', 0)
        color = COLORS[class_id % len(COLORS)]
        label = ann.get('label', f"class_{class_id}")

        # Draw box
        cv2.rectangle(result, (x1, y1), (x2, y2), color, 2)

        # Draw label background
        label_text = f"{label} {score:.2f}"
        (tw, th), _ = cv2.getTextSize(label_text, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 1)
        cv2.rectangle(result, (x1, y1 - th - 8), (x1 + tw + 4, y1), color, -1)
        cv2.putText(result, label_text, (x1 + 2, y1 - 4),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

    return result


def render_segmentation_cv2(image, annotations, opacity=0.5):
    """Render segmentation masks using raw cv2."""
    overlay = image.copy()
    for ann in annotations:
        mask = ann['mask']  # (H, W) bool
        class_id = ann.get('class_id', 0)
        color = COLORS[class_id % len(COLORS)]

        overlay[mask] = (
            np.array(color) * opacity + overlay[mask] * (1 - opacity)
        ).astype(np.uint8)

    return overlay
```

### Tracking Renderer
```python
def render_tracking(image, annotations, use_supervision=True):
    """Render tracking annotations with track ID colors."""
    result = image.copy()
    track_colors = {}

    for ann in annotations:
        track_id = ann.get('track_id', 0)
        if track_id not in track_colors:
            # Deterministic color per track ID
            rng = np.random.RandomState(track_id * 7 + 3)
            track_colors[track_id] = tuple(rng.randint(50, 255, 3).tolist())

        x1, y1, x2, y2 = [int(v) for v in ann['bbox']]
        color = track_colors[track_id]
        label = f"ID:{track_id}"

        cv2.rectangle(result, (x1, y1), (x2, y2), color, 2)
        (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 1)
        cv2.rectangle(result, (x1, y1 - th - 8), (x1 + tw + 4, y1), color, -1)
        cv2.putText(result, label, (x1 + 2, y1 - 4),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

    return result
```

### Unified Render Function
```python
def draw_annotations(image, annotations, viewer_type='detection',
                     use_supervision=True, conf_threshold=0.5, opacity=0.5):
    """Unified annotation renderer with supervision/cv2 branching."""
    if viewer_type == 'detection':
        if use_supervision:
            return render_detections_sv(image, annotations, conf_threshold)
        else:
            return render_detections_cv2(image, annotations, conf_threshold)
    elif viewer_type == 'segmentation':
        if use_supervision:
            return render_segmentation_sv(image, annotations, opacity)
        else:
            return render_segmentation_cv2(image, annotations, opacity)
    elif viewer_type == 'tracking':
        return render_tracking(image, annotations, use_supervision)
    else:
        # Custom: detection as default
        if use_supervision:
            return render_detections_sv(image, annotations, conf_threshold)
        else:
            return render_detections_cv2(image, annotations, conf_threshold)
```

---

## Composed Examples

### Detection Explorer (Complete)
```python
import ipywidgets as widgets
from IPython.display import display, clear_output
import matplotlib.pyplot as plt
import cv2
import numpy as np
from pathlib import Path

# --- Config ---
DATA_DIR = Path("./data")
DISPLAY_WIDTH = 12

# --- Cache ---
_cache = {}

def load_image_cached(path):
    key = str(path)
    if key not in _cache:
        if len(_cache) >= 200:
            del _cache[next(iter(_cache))]
        img = cv2.imread(str(path))
        if img is not None:
            img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        _cache[key] = img
    return _cache[key]

# --- Load data ---
image_paths = sorted(DATA_DIR.glob("images/*.jpg"))
annotations = load_coco_annotations(DATA_DIR / "annotations.json")  # From data-loaders.md

# --- Main Viewer ---
slider = widgets.IntSlider(value=0, min=0, max=len(image_paths)-1,
                           description='Image:', continuous_update=False,
                           layout=widgets.Layout(width='80%'))
output = widgets.Output()

def update_view(change):
    with output:
        clear_output(wait=True)
        idx = slider.value
        img = load_image_cached(image_paths[idx])
        anns = annotations.get(image_paths[idx].name, [])
        result = draw_annotations(img, anns, viewer_type='detection')
        plt.figure(figsize=(DISPLAY_WIDTH, DISPLAY_WIDTH * 0.75))
        plt.imshow(result)
        plt.title(f"[{idx}/{len(image_paths)-1}] {image_paths[idx].name} | {len(anns)} detections")
        plt.axis('off')
        plt.show()

slider.observe(update_view, names='value')
update_view({'new': 0})
display(widgets.VBox([slider, output]))
```

### Segmentation Explorer Skeleton
```python
# --- Segmentation Viewer ---
opacity_slider = widgets.FloatSlider(
    value=0.5, min=0.0, max=1.0, step=0.1,
    description='Opacity:', continuous_update=False,
    layout=widgets.Layout(width='50%')
)

def update_segmentation(change):
    with output:
        clear_output(wait=True)
        idx = slider.value
        img = load_image_cached(image_paths[idx])
        anns = annotations.get(image_paths[idx].name, [])
        result = draw_annotations(img, anns, viewer_type='segmentation',
                                  opacity=opacity_slider.value)
        plt.figure(figsize=(DISPLAY_WIDTH, DISPLAY_WIDTH * 0.75))
        plt.imshow(result)
        plt.title(f"Segmentation | Opacity: {opacity_slider.value:.1f}")
        plt.axis('off')
        plt.show()

slider.observe(update_segmentation, names='value')
opacity_slider.observe(update_segmentation, names='value')
display(widgets.VBox([slider, opacity_slider, output]))
```

### Tracking Explorer Skeleton
```python
# --- Tracking Viewer ---
frame_slider = widgets.IntSlider(value=0, min=0, max=num_frames-1,
                                  description='Frame:', continuous_update=False,
                                  layout=widgets.Layout(width='80%'))
track_dropdown = widgets.Dropdown(
    options=['ALL'] + list(map(str, unique_track_ids)),
    value='ALL', description='Track ID:'
)

play_button = widgets.Play(value=0, min=0, max=num_frames-1,
                           step=1, interval=100, description='Play')
widgets.jslink((play_button, 'value'), (frame_slider, 'value'))

def update_tracking(change):
    with output:
        clear_output(wait=True)
        frame_idx = frame_slider.value
        track_filter = track_dropdown.value

        frame = load_frame(frame_idx)
        tracks = get_tracks(frame_idx)

        if track_filter != 'ALL':
            tracks = [t for t in tracks if str(t['track_id']) == track_filter]

        result = render_tracking(frame, tracks)
        plt.figure(figsize=(DISPLAY_WIDTH, DISPLAY_WIDTH * 0.75))
        plt.imshow(result)
        plt.title(f"Frame {frame_idx} | {len(tracks)} tracks")
        plt.axis('off')
        plt.show()

frame_slider.observe(update_tracking, names='value')
track_dropdown.observe(update_tracking, names='value')
display(widgets.VBox([widgets.HBox([play_button, frame_slider]), track_dropdown, output]))
```
