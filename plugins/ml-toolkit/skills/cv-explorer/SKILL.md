---
name: cv-explorer
description: Generate interactive CV data exploration notebooks with ipywidgets viewers. Supports detection, segmentation, tracking, classification datasets in COCO, YOLO, NPZ, CSV, ImageFolder formats. Triggers on "exploration notebook", "explore dataset", "interactive viewer", "data viewer", "image viewer", "browse dataset", "browse annotations", "visualize dataset interactively".
---

# cv-explorer Skill

Interactive Computer Vision data exploration notebook generator using ipywidgets.

## Design Principles

1. **ipywidgets-first**: All interactive elements use ipywidgets (IntSlider, Dropdown, ToggleButtons, FloatSlider)
2. **Cache-aware**: Image loading uses `@lru_cache` or dict-based `_cache` to avoid redundant I/O
3. **Format-flexible**: Supports COCO JSON, YOLO TXT, NPZ, CSV, ImageFolder data formats
4. **Comparison-ready**: Optional side-by-side comparison with adjustable parameters
5. **Statistics-integrated**: Dataset-level statistics (class distribution, size histogram, annotation density)
6. **Supervision-optional**: `use_supervision=True` enables `sv.Detections`-based rendering; False uses raw cv2/matplotlib

## Supported Viewer Types

| viewer_type     | Description                                    | Primary Patterns |
|-----------------|------------------------------------------------|------------------|
| `detection`     | Bounding box viewer with class/confidence filter | A + B + E + G   |
| `segmentation`  | Mask overlay viewer with opacity control         | A + B + E + G   |
| `tracking`      | Frame-by-frame viewer with track ID highlight    | A + B + D + G   |
| `classification`| Grid viewer with class filter and sorting        | A + B + F       |
| `custom`        | Fallback: combines A + B + G as default base     | A + B + G       |

## Parameters

| Parameter         | Type     | Default       | Description                                           |
|-------------------|----------|---------------|-------------------------------------------------------|
| `viewer_type`     | string   | `detection`   | One of: detection, segmentation, tracking, classification, custom |
| `data_format`     | string   | `coco-json`   | One of: coco-json, yolo-txt, npz, csv, imagefolder    |
| `comparison`      | boolean  | `false`       | Enable side-by-side comparison view                   |
| `threshold_tuning`| boolean  | `false`       | Enable interactive confidence threshold slider        |
| `statistics`      | boolean  | `true`        | Include dataset statistics section                    |
| `use_supervision` | boolean  | `true`        | Use supervision library for annotation rendering      |
| `language`        | string   | `ko`          | Language: en, ko, hybrid                              |
| `level`           | string   | `intermediate`| User level: beginner, intermediate, expert             |

## Viewer Type × Data Format Recommendation Matrix

| viewer_type      | coco-json  | yolo-txt | npz   | csv   | imagefolder |
|------------------|------------|----------|-------|-------|-------------|
| `detection`      | ★★★ (best) | ★★       | ★     | -     | ★           |
| `segmentation`   | ★★★        | -        | ★★    | -     | ★           |
| `tracking`       | -          | -        | ★★★   | ★     | -           |
| `classification` | -          | -        | -     | ★★★   | ★★          |
| `custom`         | ★★         | ★★       | ★★    | ★★    | ★★          |

Legend: `★★★` = optimal, `★★` = supported, `★` = possible with limitations, `-` = not recommended (generates warning)

### Incompatible Combinations

When a `-` combination is requested, generate a warning markdown cell:

```python
# ⚠️ Warning: '{viewer_type}' viewer with '{data_format}' format is not recommended.
# Consider using {recommended_viewer_type} for {data_format} data.
# Proceeding with best-effort rendering...
```

## Notebook Structure

| #  | Section              | Required | Patterns Used | Description                              |
|----|----------------------|----------|---------------|------------------------------------------|
| 1  | Header               | Yes      | -             | Title, description, environment info     |
| 2  | Setup                | Yes      | -             | Imports, ipywidgets, cv2, matplotlib, font |
| 3  | Configuration        | Yes      | -             | Data paths, DISPLAY_WIDTH, colors        |
| 4  | Data Loading         | Yes      | B (cache)     | Format-specific loader with caching      |
| 5  | Interactive Viewer   | Yes      | A + G         | Main ipywidgets viewer                   |
| 6  | Comparison           | Optional | C             | Side-by-side comparison view             |
| 7  | Threshold Tuning     | Optional | D             | Confidence threshold slider              |
| 8  | Statistics           | Optional | E + F         | Class distribution, size analysis        |
| 9  | Summary              | Yes      | -             | Key findings, next steps                 |

## Triggers

This skill activates when the user's request matches these patterns:

- "exploration notebook", "explore dataset"
- "interactive viewer", "data viewer", "image viewer"
- "ipywidgets viewer", "widget-based viewer"
- "browse dataset", "browse annotations"
- "data exploration notebook"
- "visualize dataset interactively"

**Non-triggers** (→ route to cv-notebook instead):
- "training notebook", "train model"
- "fine-tune", "transfer learning"
- "deploy model", "export model"

## Usage Examples

### Basic Detection Explorer
```
User: "COCO 데이터셋 탐색 notebook 만들어줘"
→ viewer_type=detection, data_format=coco-json, language=ko, statistics=true
```

### Segmentation with Comparison
```
User: "Create a segmentation dataset explorer with model comparison"
→ viewer_type=segmentation, data_format=coco-json, comparison=true, language=en
```

### Tracking Data Viewer
```
User: "NPZ 트래킹 데이터 interactive viewer"
→ viewer_type=tracking, data_format=npz, language=ko
```

### Classification with Threshold
```
User: "ImageFolder classification explorer with confidence threshold tuning"
→ viewer_type=classification, data_format=imagefolder, threshold_tuning=true, language=en
```

### Custom Format Explorer
```
User: "커스텀 데이터 탐색 노트북, supervision 없이"
→ viewer_type=custom, use_supervision=false, language=ko
```

## Generation Workflow

### Step 1: Parameter Identification
Extract parameters from user request. Apply defaults for unspecified values.
Check viewer_type × data_format matrix; warn if incompatible.

### Step 2: Reference Loading
Load required references based on parameters:
- Always: `references/patterns.md` (Pattern A, B, G minimum)
- Always: `references/data-loaders.md` (format-specific loader)
- If comparison=true: Pattern C
- If threshold_tuning=true: Pattern D
- If statistics=true: Pattern E, F
- If language contains ko: `references/insights-ko.md`
- If language contains ko and matplotlib used: `references/korean-font-setup.md`
- Always: `references/templates/exploration.md`

### Step 3: Template Assembly
Assemble notebook sections in order from `references/templates/exploration.md`.
Insert data loader from `references/data-loaders.md` based on data_format.
Apply viewer patterns from `references/patterns.md` based on viewer_type.

### Step 4: Insight Injection (if language=ko or hybrid)
Load `references/insights-ko.md` and inject insights according to level density:
- beginner: 12-15 insights
- intermediate: 6-10 insights
- expert: 2-4 insights

### Step 5: Supervision Branch
If `use_supervision=true`:
- Use `sv.Detections` + `sv.BoxAnnotator`/`sv.MaskAnnotator` for rendering
- Add supervision to pip install cell

If `use_supervision=false`:
- Use raw cv2.rectangle/cv2.drawContours for rendering
- Remove supervision dependency

### Step 6: NotebookEdit Cell Generation
Generate cells sequentially using NotebookEdit tool:
1. Create new notebook or modify existing one
2. Track cell IDs for each section
3. Generate cells in section order
4. Validate cell count matches expected structure

## NotebookEdit Integration

Same strategy as cv-notebook skill:

### Cell Generation Strategy
```
1. Create markdown cell (section header) → record cell_id
2. Create code cell (section code) → record cell_id
3. Repeat for each section
4. Final validation: all sections present
```

### Cell ID Tracking
```python
cell_map = {
    "header": "cell-header",
    "setup": "cell-setup",
    "config": "cell-config",
    "data_loading": "cell-data-loading",
    "viewer": "cell-viewer",
    "comparison": "cell-comparison",      # optional
    "threshold": "cell-threshold",        # optional
    "statistics": "cell-statistics",      # optional
    "summary": "cell-summary"
}
```

## User Level Configuration

### Insight Density by Level

| Level        | Insight Count | Code Comments | Widget Explanations |
|--------------|---------------|---------------|---------------------|
| beginner     | 12-15         | Verbose       | Every widget explained |
| intermediate | 6-10          | Moderate      | Key widgets only      |
| expert       | 2-4           | Minimal       | None                  |

### Code Complexity by Level

| Level        | Patterns Used | Error Handling | Performance Optimization |
|--------------|---------------|----------------|--------------------------|
| beginner     | A, B, G       | Basic try/except | None                   |
| intermediate | A, B, C/D, E, G | Standard      | lru_cache              |
| expert       | All (A-G)     | Comprehensive  | lru_cache + lazy loading |
