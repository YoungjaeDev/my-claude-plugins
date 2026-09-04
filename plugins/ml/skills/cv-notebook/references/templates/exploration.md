# Exploration Notebook Template

Cell templates for interactive CV data exploration notebooks.
Uses `{variable}` placeholders — replace during generation.

## Standard Section Order

| #  | Section            | Cell Type | Template               |
|----|--------------------| ----------|------------------------|
| 1  | Header             | Markdown  | `header_template`      |
| 2  | Setup              | Code      | `setup_template`       |
| 3  | Configuration      | Code      | `config_template`      |
| 4  | Data Loading       | Code      | `data_loading_template`|
| 5  | Interactive Viewer | Code      | `viewer_template`      |
| 6  | Comparison         | Code      | `comparison_template`  |
| 7  | Threshold Tuning   | Code      | `threshold_template`   |
| 8  | Statistics         | Code      | `statistics_template`  |
| 9  | Summary            | Markdown  | `summary_template`     |

---

## Header Template

```markdown
# {title}

{description}

**Environment**: Local Jupyter / JupyterLab
**Dataset**: `{dataset_name}` ({data_format})
**Viewer Type**: {viewer_type}
**Date**: {date}
```

---

## Setup Template

### Minimal Setup (All viewer types)
```python
# ============================================================
# Section: Setup
# ============================================================
import warnings
warnings.filterwarnings('ignore')

# Core dependencies
import cv2
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
from IPython.display import display, clear_output

# Interactive widgets
import ipywidgets as widgets

# {supervision_import_block}
```

### supervision_import_block (use_supervision=True)
```python
# Annotation rendering
import supervision as sv
print(f"supervision: {sv.__version__}")
```

### supervision_import_block (use_supervision=False)
```python
# Using raw cv2 for annotation rendering (no supervision dependency)
```

### Korean Font Setup Block (language=ko or hybrid)
```python
# Korean font setup for matplotlib
import matplotlib.font_manager as fm

# Try system fonts first
korean_fonts = [f.name for f in fm.fontManager.ttflist
                if any(k in f.name.lower() for k in ['nanum', 'malgun', 'gothic', 'batang'])]

if korean_fonts:
    plt.rcParams['font.family'] = korean_fonts[0]
    plt.rcParams['axes.unicode_minus'] = False
    print(f"Korean font: {korean_fonts[0]}")
else:
    # Install NanumGothic as fallback
    import subprocess
    subprocess.run(['pip', 'install', '-q', 'fonts-nanum-gothic'], check=False)
    try:
        plt.rcParams['font.family'] = 'NanumGothic'
        plt.rcParams['axes.unicode_minus'] = False
    except Exception:
        print("⚠️ Korean font not found. Labels may not render correctly.")
```

### pip install cell (before imports)
```python
# Install dependencies
# {pip_install_line}
```

#### pip_install_line variants
- **use_supervision=True**: `!pip install -q opencv-python-headless matplotlib ipywidgets supervision`
- **use_supervision=False**: `!pip install -q opencv-python-headless matplotlib ipywidgets`
- **data_format=yolo-txt**: append `pyyaml` if data.yaml parsing needed
- **language=ko**: append `fonts-nanum-gothic` (for font fallback)

---

## Configuration Template

```python
# ============================================================
# Section: Configuration
# ============================================================

# --- Paths ---
DATA_DIR = Path("{data_dir}")
# {format_specific_paths}

# --- Display settings ---
DISPLAY_WIDTH = {display_width}  # matplotlib figure width in inches
COLORS = [
    '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
    '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9',
]

# --- Cache settings ---
MAX_CACHE_SIZE = {max_cache_size}  # Number of images to keep in memory
```

### format_specific_paths variants
- **coco-json**: `IMAGE_DIR = DATA_DIR / "images"\nANN_FILE = DATA_DIR / "annotations.json"`
- **yolo-txt**: `IMAGE_DIR = DATA_DIR / "images"\nLABEL_DIR = DATA_DIR / "labels"`
- **npz**: `NPZ_FILE = DATA_DIR / "{npz_filename}"`
- **csv**: `IMAGE_DIR = DATA_DIR / "images"\nCSV_FILE = DATA_DIR / "labels.csv"`
- **imagefolder**: `# Images organized in class subdirectories under DATA_DIR`

---

## Data Loading Template

Uses the appropriate loader from `explorer-data-loaders.md`.

```python
# ============================================================
# Section: Data Loading
# ============================================================

# {data_loader_code}  -- Insert from explorer-data-loaders.md based on data_format

# --- Image Cache ---
_cache = {}

def load_image_cached(path):
    """Load image with cache. BGR -> RGB conversion included."""
    key = str(path)
    if key not in _cache:
        if len(_cache) >= MAX_CACHE_SIZE:
            oldest = next(iter(_cache))
            del _cache[oldest]
        img = cv2.imread(str(path))
        if img is not None:
            img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        _cache[key] = img
    return _cache[key]

# Load dataset
# {dataset_load_call}  -- e.g., image_paths, annotations, categories = load_coco_dataset(DATA_DIR)

print(f"Loaded {len(image_paths)} images")
# {format_specific_summary}
```

### dataset_load_call variants
- **coco-json**: `image_paths, annotations, categories = load_coco_dataset(DATA_DIR)`
- **yolo-txt**: `image_paths, annotations, class_names = load_yolo_dataset(DATA_DIR)`
- **npz**: `frames, frame_annotations, metadata = load_npz_dataset(NPZ_FILE)`
- **csv**: `image_paths, labels, class_names = load_csv_dataset(DATA_DIR)`
- **imagefolder**: `image_paths, labels, class_names = load_imagefolder_dataset(DATA_DIR)`

### format_specific_summary variants
- **coco-json**: `print(f"Categories: {list(categories.values())}")\nprint(f"Total annotations: {sum(len(v) for v in annotations.values())}")`
- **yolo-txt**: `print(f"Classes: {class_names}")\nprint(f"Total annotations: {sum(len(v) for v in annotations.values())}")`
- **npz**: `print(f"Frames: {metadata['num_frames']}, Shape: {metadata['frame_shape']}")\nprint(f"Tracking: {metadata['has_tracking']}, Keypoints: {metadata['has_keypoints']}")`
- **csv**: `print(f"Classes: {class_names}")\nprint(f"Labeled images: {len(labels)}")`
- **imagefolder**: `print(f"Classes: {class_names}")\nprint(f"Images per class: {dict(Counter(l['label'] for l in labels.values()))}")`

---

## Interactive Viewer Template

### Detection / Segmentation / Custom Viewer
```python
# ============================================================
# Section: Interactive Viewer
# ============================================================

# {annotation_renderer_code}  -- From explorer-patterns.md Pattern G (supervision or cv2 branch)

# --- Navigation Widget ---
slider = widgets.IntSlider(
    value=0, min=0, max=len(image_paths) - 1,
    step=1, description='{slider_label}:',
    continuous_update=False,
    layout=widgets.Layout(width='80%')
)

# {viewer_specific_widgets}  -- e.g., opacity_slider for segmentation

output = widgets.Output()

def update_view(change):
    with output:
        clear_output(wait=True)
        idx = slider.value
        img = load_image_cached(image_paths[idx])
        # {get_annotations_code}
        result = draw_annotations(img, anns, viewer_type='{viewer_type}'{extra_params})

        plt.figure(figsize=(DISPLAY_WIDTH, DISPLAY_WIDTH * 0.75))
        plt.imshow(result)
        plt.title(f"[{idx}/{len(image_paths)-1}] {image_paths[idx].name} | {len(anns)} annotations")
        plt.axis('off')
        plt.tight_layout()
        plt.show()

slider.observe(update_view, names='value')
# {additional_widget_observers}
update_view({'new': 0})

display(widgets.VBox([{widget_list}]))
```

### Tracking Viewer (frame-based)
```python
# ============================================================
# Section: Interactive Viewer (Tracking)
# ============================================================

frame_slider = widgets.IntSlider(
    value=0, min=0, max=len(frames) - 1,
    description='Frame:', continuous_update=False,
    layout=widgets.Layout(width='80%')
)

track_dropdown = widgets.Dropdown(
    options=['ALL'] + [str(tid) for tid in sorted(unique_track_ids)],
    value='ALL', description='Track ID:'
)

play_button = widgets.Play(
    value=0, min=0, max=len(frames) - 1,
    step=1, interval=100, description='▶'
)
widgets.jslink((play_button, 'value'), (frame_slider, 'value'))

output = widgets.Output()

def update_tracking(change):
    with output:
        clear_output(wait=True)
        frame_idx = frame_slider.value
        frame = frames[frame_idx]
        tracks = frame_annotations[frame_idx]

        if track_dropdown.value != 'ALL':
            tracks = [t for t in tracks if str(t.get('track_id')) == track_dropdown.value]

        result = draw_annotations(frame, tracks, viewer_type='tracking')
        plt.figure(figsize=(DISPLAY_WIDTH, DISPLAY_WIDTH * 0.75))
        plt.imshow(result)
        plt.title(f"Frame {frame_idx}/{len(frames)-1} | {len(tracks)} tracks")
        plt.axis('off')
        plt.tight_layout()
        plt.show()

frame_slider.observe(update_tracking, names='value')
track_dropdown.observe(update_tracking, names='value')
update_tracking({'new': 0})

display(widgets.VBox([
    widgets.HBox([play_button, frame_slider]),
    track_dropdown,
    output
]))
```

### Classification Viewer (grid-based)
```python
# ============================================================
# Section: Interactive Viewer (Classification)
# ============================================================

class_dropdown = widgets.Dropdown(
    options=['ALL'] + class_names,
    value='ALL', description='Class:'
)

sort_dropdown = widgets.Dropdown(
    options=['filename', 'score_desc', 'score_asc'],
    value='filename', description='Sort by:'
)

page_slider = widgets.IntSlider(
    value=0, min=0, max=0,  # Updated dynamically
    description='Page:', continuous_update=False
)

GRID_COLS = 4
GRID_ROWS = 3
PER_PAGE = GRID_COLS * GRID_ROWS

output = widgets.Output()

def get_filtered_images():
    """Get filtered and sorted image list."""
    filtered = image_paths
    if class_dropdown.value != 'ALL':
        filtered = [p for p in filtered
                    if labels.get(str(p), labels.get(p.name, {})).get('label') == class_dropdown.value]

    if sort_dropdown.value == 'score_desc':
        filtered.sort(key=lambda p: labels.get(str(p), labels.get(p.name, {})).get('score', 0), reverse=True)
    elif sort_dropdown.value == 'score_asc':
        filtered.sort(key=lambda p: labels.get(str(p), labels.get(p.name, {})).get('score', 0))

    return filtered

def update_classification(change):
    filtered = get_filtered_images()
    max_page = max(0, (len(filtered) - 1) // PER_PAGE)
    page_slider.max = max_page
    page_slider.value = min(page_slider.value, max_page)

    start = page_slider.value * PER_PAGE
    page_images = filtered[start:start + PER_PAGE]

    with output:
        clear_output(wait=True)
        if not page_images:
            print("No images found for this filter.")
            return

        rows = (len(page_images) + GRID_COLS - 1) // GRID_COLS
        fig, axes = plt.subplots(rows, GRID_COLS,
                                  figsize=(DISPLAY_WIDTH, DISPLAY_WIDTH * rows / GRID_COLS))
        if rows == 1:
            axes = [axes]

        for i, ax in enumerate(np.array(axes).flatten()):
            if i < len(page_images):
                img = load_image_cached(page_images[i])
                ax.imshow(img)
                info = labels.get(str(page_images[i]), labels.get(page_images[i].name, {}))
                title = info.get('label', 'unknown')
                if 'score' in info:
                    title += f" ({info['score']:.2f})"
                ax.set_title(title, fontsize=9)
            ax.axis('off')

        plt.suptitle(f"Class: {class_dropdown.value} | Page {page_slider.value + 1}/{max_page + 1} | {len(filtered)} images",
                     fontsize=12)
        plt.tight_layout()
        plt.show()

class_dropdown.observe(update_classification, names='value')
sort_dropdown.observe(update_classification, names='value')
page_slider.observe(update_classification, names='value')
update_classification({'new': None})

display(widgets.VBox([
    widgets.HBox([class_dropdown, sort_dropdown]),
    page_slider,
    output
]))
```

---

## Comparison Template (comparison=true)

Insert Pattern C from explorer-patterns.md.

```python
# ============================================================
# Section: Side-by-Side Comparison
# ============================================================
# See explorer-patterns.md Pattern C for full implementation
```

---

## Threshold Tuning Template (threshold_tuning=true)

Insert Pattern D from explorer-patterns.md.

```python
# ============================================================
# Section: Threshold Tuning
# ============================================================
# See explorer-patterns.md Pattern D for full implementation
```

---

## Statistics Template (statistics=true)

### Detection / Segmentation Statistics
```python
# ============================================================
# Section: Dataset Statistics
# ============================================================

# --- Compute Stats ---
stats = compute_statistics(annotations)  # From explorer-patterns.md Pattern E
stats_widget = render_stats_html(stats)
display(stats_widget)

# --- Class Distribution ---
plot_class_distribution(stats)

# --- Annotation Size Distribution ---
def plot_size_distribution(annotations):
    """Plot bounding box size distribution."""
    widths, heights, areas = [], [], []
    for anns in annotations.values():
        for ann in anns:
            x1, y1, x2, y2 = ann['bbox']
            w, h = x2 - x1, y2 - y1
            widths.append(w)
            heights.append(h)
            areas.append(w * h)

    if not areas:
        print("No bounding boxes found.")
        return

    fig, axes = plt.subplots(1, 3, figsize=(DISPLAY_WIDTH, 4))

    axes[0].hist(widths, bins=30, color='steelblue', edgecolor='white')
    axes[0].set_title('Width Distribution')
    axes[0].set_xlabel('pixels')

    axes[1].hist(heights, bins=30, color='coral', edgecolor='white')
    axes[1].set_title('Height Distribution')
    axes[1].set_xlabel('pixels')

    axes[2].hist(areas, bins=30, color='mediumseagreen', edgecolor='white')
    axes[2].set_title('Area Distribution')
    axes[2].set_xlabel('pixels²')

    plt.suptitle('Bounding Box Size Distribution', fontsize=12)
    plt.tight_layout()
    plt.show()

plot_size_distribution(annotations)

# --- Annotations per Image ---
def plot_annotations_per_image(annotations):
    """Plot number of annotations per image."""
    counts = [len(v) for v in annotations.values()]
    plt.figure(figsize=(DISPLAY_WIDTH, 4))
    plt.hist(counts, bins=max(10, max(counts) - min(counts) + 1),
             color='steelblue', edgecolor='white')
    plt.title('Annotations per Image')
    plt.xlabel('Number of annotations')
    plt.ylabel('Number of images')
    plt.axvline(np.mean(counts), color='red', linestyle='--',
                label=f'Mean: {np.mean(counts):.1f}')
    plt.legend()
    plt.tight_layout()
    plt.show()

plot_annotations_per_image(annotations)
```

### Classification Statistics
```python
# ============================================================
# Section: Dataset Statistics (Classification)
# ============================================================

from collections import Counter

# --- Class Distribution ---
class_counts = Counter(info['label'] for info in labels.values())

fig, ax = plt.subplots(figsize=(max(8, len(class_counts) * 0.6), 5))
classes = list(class_counts.keys())
counts = list(class_counts.values())
bars = ax.bar(range(len(classes)), counts, color='steelblue')
ax.set_xticks(range(len(classes)))
ax.set_xticklabels(classes, rotation=45, ha='right')
ax.set_ylabel('Count')
ax.set_title('Class Distribution')

for bar, count in zip(bars, counts):
    ax.text(bar.get_x() + bar.get_width()/2., bar.get_height(),
            str(count), ha='center', va='bottom', fontsize=9)

plt.tight_layout()
plt.show()

# --- Summary ---
print(f"Total images: {len(labels)}")
print(f"Classes: {len(class_counts)}")
print(f"Min/Max per class: {min(counts)}/{max(counts)}")
print(f"Imbalance ratio: {max(counts)/max(min(counts),1):.1f}x")
```

### Tracking Statistics
```python
# ============================================================
# Section: Dataset Statistics (Tracking)
# ============================================================

# --- Track Length Distribution ---
track_lengths = {}
for frame_anns in frame_annotations:
    for ann in frame_anns:
        tid = ann.get('track_id', -1)
        track_lengths[tid] = track_lengths.get(tid, 0) + 1

lengths = list(track_lengths.values())
plt.figure(figsize=(DISPLAY_WIDTH, 4))
plt.hist(lengths, bins=30, color='steelblue', edgecolor='white')
plt.title('Track Length Distribution')
plt.xlabel('Frames')
plt.ylabel('Number of tracks')
plt.axvline(np.mean(lengths), color='red', linestyle='--',
            label=f'Mean: {np.mean(lengths):.1f}')
plt.legend()
plt.tight_layout()
plt.show()

# --- Objects per Frame ---
objects_per_frame = [len(anns) for anns in frame_annotations]
plt.figure(figsize=(DISPLAY_WIDTH, 4))
plt.plot(objects_per_frame, color='steelblue', linewidth=0.8)
plt.fill_between(range(len(objects_per_frame)), objects_per_frame, alpha=0.3)
plt.title('Objects per Frame')
plt.xlabel('Frame')
plt.ylabel('Count')
plt.tight_layout()
plt.show()

print(f"Total tracks: {len(track_lengths)}")
print(f"Total frames: {len(frame_annotations)}")
print(f"Avg track length: {np.mean(lengths):.1f} frames")
print(f"Avg objects/frame: {np.mean(objects_per_frame):.1f}")
```

---

## Summary Template

```markdown
# Summary

## Dataset Overview
- **Format**: {data_format}
- **Total Images/Frames**: {total_count}
- **Viewer Type**: {viewer_type}

## Key Findings
{findings_placeholder}

## Next Steps
- [ ] Review annotation quality for edge cases
- [ ] Check class distribution balance
- [ ] Identify potential data augmentation needs
- [ ] Export filtered subset if needed
```

---

## NotebookEdit Cell Generation Strategy

Same as cv-notebook:

### Sequential Cell Generation
```
Step 1: Create notebook file if needed
Step 2: For each section in order:
  a. Add markdown header cell → record cell_id
  b. Add code cell(s) → record cell_id(s)
  c. If language=ko/hybrid, add insight cell after code
Step 3: Validate all required sections present
```

### Cell ID Map
```python
cell_ids = {
    "pip_install": None,     # Code cell
    "header": None,          # Markdown cell
    "setup": None,           # Code cell
    "config": None,          # Code cell
    "data_loading": None,    # Code cell
    "viewer_header": None,   # Markdown cell
    "viewer": None,          # Code cell
    "comparison": None,      # Code cell (optional)
    "threshold": None,       # Code cell (optional)
    "stats_header": None,    # Markdown cell (optional)
    "statistics": None,      # Code cell (optional)
    "summary": None,         # Markdown cell
}
```

### Section Markers
Use comment-based markers for easy identification:
```python
# ============================================================
# Section: {section_name}
# ============================================================
```
