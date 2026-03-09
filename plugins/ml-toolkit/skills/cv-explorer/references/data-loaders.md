# Data Loader Patterns

Format-specific data loading patterns for CV dataset exploration.

## COCO JSON Loader

Standard COCO format with images/ directory and annotations JSON file.

```python
import json
from pathlib import Path

def load_coco_dataset(data_dir: Path, annotation_file: str = "annotations.json"):
    """Load COCO format dataset.

    Expected structure:
        data_dir/
        ├── images/
        │   ├── image_001.jpg
        │   └── ...
        └── annotations.json  (or _annotations.coco.json for Roboflow)

    Returns:
        image_paths: sorted list of Path objects
        annotations: dict mapping filename -> list of annotation dicts
        categories: dict mapping category_id -> category_name
    """
    data_dir = Path(data_dir)

    # Find annotation file (support Roboflow naming convention)
    ann_file = data_dir / annotation_file
    if not ann_file.exists():
        ann_file = data_dir / "_annotations.coco.json"
    if not ann_file.exists():
        raise FileNotFoundError(f"No annotation file found in {data_dir}")

    with open(ann_file) as f:
        coco = json.load(f)

    # Build category mapping
    categories = {cat['id']: cat['name'] for cat in coco['categories']}

    # Build image_id -> filename mapping
    id_to_file = {img['id']: img['file_name'] for img in coco['images']}

    # Group annotations by image
    annotations = {}
    for ann in coco['annotations']:
        filename = id_to_file.get(ann['image_id'], '')
        if filename not in annotations:
            annotations[filename] = []

        # Convert COCO bbox [x, y, w, h] -> [x1, y1, x2, y2]
        if 'bbox' in ann:
            x, y, w, h = ann['bbox']
            bbox = [x, y, x + w, y + h]
        else:
            bbox = [0, 0, 0, 0]

        entry = {
            'bbox': bbox,
            'category': categories.get(ann['category_id'], 'unknown'),
            'class_id': ann['category_id'],
            'score': ann.get('score', 1.0),
            'label': categories.get(ann['category_id'], 'unknown'),
        }

        # Segmentation mask (if available)
        if 'segmentation' in ann and ann['segmentation']:
            entry['segmentation'] = ann['segmentation']

        if filename not in annotations:
            annotations[filename] = []
        annotations[filename].append(entry)

    # Collect image paths
    img_dir = data_dir / "images"
    if not img_dir.exists():
        img_dir = data_dir  # Images might be in root

    image_paths = sorted([
        p for p in img_dir.glob("*")
        if p.suffix.lower() in {'.jpg', '.jpeg', '.png', '.bmp', '.webp'}
    ])

    return image_paths, annotations, categories
```

---

## YOLO TXT Loader

YOLO format with images/ and labels/ directories.

```python
from pathlib import Path

def load_yolo_dataset(data_dir: Path, class_names: list = None):
    """Load YOLO format dataset.

    Expected structure:
        data_dir/
        ├── images/
        │   ├── image_001.jpg
        │   └── ...
        └── labels/
            ├── image_001.txt
            └── ...

    Label format: class_id cx cy w h (normalized)

    Returns:
        image_paths: sorted list of Path objects
        annotations: dict mapping filename -> list of annotation dicts
        class_names: list of class names
    """
    data_dir = Path(data_dir)
    img_dir = data_dir / "images"
    label_dir = data_dir / "labels"

    # Try to load class names from data.yaml or classes.txt
    if class_names is None:
        classes_file = data_dir / "classes.txt"
        if classes_file.exists():
            class_names = classes_file.read_text().strip().split('\n')
        else:
            yaml_file = data_dir / "data.yaml"
            if yaml_file.exists():
                import yaml
                with open(yaml_file) as f:
                    config = yaml.safe_load(f)
                class_names = config.get('names', [])

    if class_names is None:
        class_names = []

    image_paths = sorted([
        p for p in img_dir.glob("*")
        if p.suffix.lower() in {'.jpg', '.jpeg', '.png', '.bmp', '.webp'}
    ])

    annotations = {}
    for img_path in image_paths:
        label_path = label_dir / (img_path.stem + ".txt")
        anns = []

        if label_path.exists():
            # Read image dimensions for denormalization
            import cv2
            img = cv2.imread(str(img_path))
            if img is None:
                continue
            h, w = img.shape[:2]

            for line in label_path.read_text().strip().split('\n'):
                if not line.strip():
                    continue
                parts = line.strip().split()
                class_id = int(parts[0])
                cx, cy, bw, bh = map(float, parts[1:5])

                # Convert normalized center format to pixel xyxy
                x1 = (cx - bw / 2) * w
                y1 = (cy - bh / 2) * h
                x2 = (cx + bw / 2) * w
                y2 = (cy + bh / 2) * h

                label = class_names[class_id] if class_id < len(class_names) else f"class_{class_id}"
                anns.append({
                    'bbox': [x1, y1, x2, y2],
                    'category': label,
                    'class_id': class_id,
                    'score': 1.0,
                    'label': label,
                })

        annotations[img_path.name] = anns

    return image_paths, annotations, class_names
```

---

## NPZ Loader (Tracking / Pose)

NumPy archive format for frame-based data (tracking, pose estimation).

```python
import numpy as np
from pathlib import Path

def load_npz_dataset(npz_path: Path):
    """Load NPZ format dataset (tracking/pose).

    Expected NPZ keys:
        - 'frames' or 'images': (N, H, W, 3) uint8 array
        - 'boxes' or 'bboxes': (N, M, 4) float array [x1, y1, x2, y2]
        - 'track_ids' (optional): (N, M) int array
        - 'scores' (optional): (N, M) float array
        - 'keypoints' (optional): (N, M, K, 2 or 3) float array
        - 'class_ids' (optional): (N, M) int array

    Returns:
        frames: numpy array (N, H, W, 3)
        frame_annotations: list of list of annotation dicts
        metadata: dict with additional info
    """
    npz_path = Path(npz_path)
    data = np.load(str(npz_path), allow_pickle=False)

    # Load frames
    frames_key = 'frames' if 'frames' in data else 'images'
    frames = data[frames_key]

    # Load boxes
    boxes_key = 'boxes' if 'boxes' in data else 'bboxes'
    boxes = data.get(boxes_key, np.zeros((len(frames), 0, 4)))

    track_ids = data.get('track_ids', None)
    scores = data.get('scores', None)
    class_ids = data.get('class_ids', None)
    keypoints = data.get('keypoints', None)

    num_frames = len(frames)
    frame_annotations = []

    for i in range(num_frames):
        frame_anns = []
        num_objects = boxes[i].shape[0] if len(boxes.shape) > 1 else 0

        for j in range(num_objects):
            ann = {
                'bbox': boxes[i][j].tolist(),
                'score': float(scores[i][j]) if scores is not None else 1.0,
                'class_id': int(class_ids[i][j]) if class_ids is not None else 0,
            }
            if track_ids is not None:
                ann['track_id'] = int(track_ids[i][j])
            if keypoints is not None:
                ann['keypoints'] = keypoints[i][j].tolist()
            frame_anns.append(ann)

        frame_annotations.append(frame_anns)

    metadata = {
        'num_frames': num_frames,
        'frame_shape': frames[0].shape if num_frames > 0 else None,
        'has_tracking': track_ids is not None,
        'has_keypoints': keypoints is not None,
        'keys': list(data.keys()),
    }

    return frames, frame_annotations, metadata
```

---

## CSV Loader (Classification / Experiment)

CSV format for classification labels or experiment results.

```python
import csv
from pathlib import Path

def load_csv_dataset(data_dir: Path, csv_file: str = "labels.csv",
                     image_col: str = "filename", label_col: str = "label",
                     score_col: str = None):
    """Load CSV format dataset.

    Expected CSV columns:
        - filename (or image_col): image filename
        - label (or label_col): class label
        - score (optional): confidence score

    Expected structure:
        data_dir/
        ├── images/
        │   ├── image_001.jpg
        │   └── ...
        └── labels.csv

    Returns:
        image_paths: sorted list of Path objects
        labels: dict mapping filename -> dict with 'label', 'score', etc.
        class_names: sorted list of unique class names
    """
    data_dir = Path(data_dir)
    csv_path = data_dir / csv_file

    labels = {}
    class_names_set = set()

    with open(csv_path, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            filename = row[image_col]
            label = row[label_col]
            class_names_set.add(label)

            entry = {
                'label': label,
                'category': label,
            }
            if score_col and score_col in row:
                entry['score'] = float(row[score_col])

            # Include all other columns as metadata
            for key, value in row.items():
                if key not in {image_col, label_col, score_col}:
                    entry[key] = value

            labels[filename] = entry

    class_names = sorted(class_names_set)

    # Collect image paths
    img_dir = data_dir / "images"
    if not img_dir.exists():
        img_dir = data_dir

    image_paths = sorted([
        p for p in img_dir.glob("*")
        if p.suffix.lower() in {'.jpg', '.jpeg', '.png', '.bmp', '.webp'}
        and p.name in labels
    ])

    return image_paths, labels, class_names
```

---

## ImageFolder Loader

Glob-based loader for directory-organized datasets (class per folder).

```python
from pathlib import Path

def load_imagefolder_dataset(data_dir: Path):
    """Load ImageFolder format dataset.

    Expected structure:
        data_dir/
        ├── class_a/
        │   ├── image_001.jpg
        │   └── ...
        ├── class_b/
        │   ├── image_001.jpg
        │   └── ...
        └── ...

    Returns:
        image_paths: sorted list of Path objects
        labels: dict mapping filename -> dict with 'label', 'class_id'
        class_names: sorted list of class (folder) names
    """
    data_dir = Path(data_dir)
    image_extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.webp', '.tiff'}

    # Discover classes from subdirectories
    class_dirs = sorted([
        d for d in data_dir.iterdir()
        if d.is_dir() and not d.name.startswith('.')
    ])

    class_names = [d.name for d in class_dirs]
    image_paths = []
    labels = {}

    for class_id, class_dir in enumerate(class_dirs):
        class_images = sorted([
            p for p in class_dir.glob("*")
            if p.suffix.lower() in image_extensions
        ])

        for img_path in class_images:
            image_paths.append(img_path)
            labels[str(img_path)] = {
                'label': class_dir.name,
                'category': class_dir.name,
                'class_id': class_id,
            }

    return image_paths, labels, class_names
```

---

## Loader Selection Helper

```python
def load_dataset(data_dir, data_format='coco-json', **kwargs):
    """Unified dataset loader based on format type.

    Args:
        data_dir: Path to dataset root
        data_format: One of 'coco-json', 'yolo-txt', 'npz', 'csv', 'imagefolder'
        **kwargs: Format-specific keyword arguments

    Returns:
        Dataset-specific tuple (see individual loaders)
    """
    data_dir = Path(data_dir)

    # NPZ expects a file path, not a directory
    if data_format == 'npz':
        npz_path = kwargs.pop('npz_path', None)
        if npz_path is None:
            # Find first .npz file in data_dir
            npz_files = list(data_dir.glob("*.npz"))
            if not npz_files:
                raise FileNotFoundError(f"No .npz file found in {data_dir}")
            npz_path = npz_files[0]
        return load_npz_dataset(npz_path, **kwargs)

    loaders = {
        'coco-json': load_coco_dataset,
        'yolo-txt': load_yolo_dataset,
        'csv': load_csv_dataset,
        'imagefolder': load_imagefolder_dataset,
    }

    if data_format not in loaders:
        raise ValueError(f"Unsupported format: {data_format}. Choose from {list(loaders.keys()) + ['npz']}")

    return loaders[data_format](data_dir, **kwargs)
```
