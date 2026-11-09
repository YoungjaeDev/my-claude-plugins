# Exploration mode

Exploration mode builds an ipywidgets interactive data-exploration notebook from 5 viewer types and 5 data formats. It uses the same structure-aware authoring (`NotebookEdit` / `nbformat`) and the same End Gate as the standard flow, with different templates. The triggers and non-triggers live in `SKILL.md`.

## Viewer types

| viewer_type | Description | Best data_format |
|-------------|--------------|-------------------|
| `detection` | Bounding box viewer, class/confidence filter | coco-json |
| `segmentation` | Mask overlay viewer, opacity control | coco-json |
| `tracking` | Frame-by-frame viewer, track ID highlight, play button | npz |
| `classification` | Grid viewer, class filter, sorting | csv |
| `custom` | Fallback: base navigation + cache + supervision/cv2 render | any |

`data_format` is one of `coco-json`, `yolo-txt`, `npz`, `csv`, `imagefolder`, with one loader each in `explorer-data-loaders.md`. Detection and segmentation favor coco-json, tracking needs npz, and classification favors csv or imagefolder. A mismatched viewer_type x data_format pairing gets a warning markdown cell in the generated notebook rather than a hard block.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `viewer_type` | `detection` | detection / segmentation / tracking / classification / custom |
| `data_format` | `coco-json` | coco-json / yolo-txt / npz / csv / imagefolder |
| `comparison` | `false` | side-by-side comparison view |
| `threshold_tuning` | `false` | interactive confidence threshold slider |
| `statistics` | `true` | dataset statistics section |
| `use_supervision` | `true` | supervision library vs raw cv2 rendering |

- **Optional sections**: `comparison=true` adds a side-by-side view (raw vs annotated, or model A vs B), `threshold_tuning=true` a live confidence/NMS slider, and `statistics=true` class-distribution and bbox-size-distribution plots. They are built from `explorer-patterns.md` Pattern C, D, and E+F respectively.
- **Level and language**: `level` and `language` follow the same beginner/intermediate/expert convention and Korean-insight categories as the standard flow (format spec in `insights-ko.md`).
- **Insights**: compose ipywidgets-specific insights (continuous_update, Output/clear_output, cache eviction, NMS/threshold tuning) from the Key Points already listed under each pattern in `explorer-patterns.md`, not from a separate insight bank.

## Generation

1. Parse `viewer_type` / `data_format` / `comparison` / `threshold_tuning` / `statistics` / `use_supervision` from the request; check the viewer_type x data_format table above and warn on a mismatch.
2. Load `explorer-patterns.md` (Pattern A + B + G minimum, plus C/D/E+F as the optional flags require) and the matching loader in `explorer-data-loaders.md`.
3. Assemble the notebook from `templates/exploration.md`'s section order (Header, Setup, Configuration, Data Loading, Interactive Viewer, optional Comparison/Threshold/Statistics, Summary).
4. Author cells the same structure-aware way as the standard flow (`NotebookEdit` / `nbformat`) and run the same End Gate validation before handing the notebook back.
