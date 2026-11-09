---
name: gradio-cv-app
description: Build a Gradio computer-vision demo app (OCR, classification, detection, segmentation, captioning, image editing or generation) in an Editorial design derived from the PRITHIVSAKTHIUR style. Use on /ml:gradio-cv-app, "Gradio app", "Gradio 데모", "CV demo UI", "image processing app". For the model work itself use /ml:ml-dev-principles.
---

# Gradio CV App Generator

Builds a ready-to-run Gradio CV app for one of 7 task types, combining PRITHIVSAKTHIUR's functional patterns with an Editorial design. The output is a complete `app.py` plus `requirements.txt`.

## Design principles

- **Avoid (the AI look)**: purple or rainbow gradients, several mixed colors, excessive animation, and the Steel Blue or Purple shades common in AI demos.
- **Apply (Editorial style)**: solid colors with a single accent, the Pretendard font (Korean support), a minimal functional UI, ample whitespace and high contrast, a professional tool-like feel.
- **Dark mode**: supported, following the system preference by default. Use `color_accent="*secondary_500"` (emerald), not the default zinc primary, which leaves tab text hard to read in dark mode. Full theme settings are in [refined-theme.md](references/refined-theme.md).

## Supported task types

| Task | Description | Key Patterns |
|------|-------------|--------------|
| `ocr` | OCR/VLM multimodal app | Tabs, TextIteratorStreamer, Accordion |
| `classify` | Image classification | gr.Interface, gr.Label |
| `generate` | Image generation | LoRA loading, style dictionary |
| `segment` | Segmentation | gr.AnnotatedImage |
| `edit` | Image editing | LoRA adapter, prompts |
| `caption` | Image captioning | VLM model, copy button |
| `detect` | Detection (Deepfake, etc.) | Binary classification, gr.Label |

## Workflow

1. **Identify task type**: determine the CV task from the user request.
2. **Apply theme**: use the RefinedTheme class from [refined-theme.md](references/refined-theme.md), including its light/dark toggle (Auto by default: detects the OS preference and saves the user's choice to localStorage; Light and Dark force a theme; Lucide icons on the button).
3. **Reference templates**: check the task pattern in [task-templates.md](references/task-templates.md), and the dictionary-based Korean/English `LABELS` in [i18n-patterns.md](references/i18n-patterns.md).
4. **Check reference repos**: refer to [github-references.md](references/github-references.md) if needed.
5. **Generate complete app.py**: write ready-to-run code.

## Output requirements

- **app.py**: complete and ready to run, ending with the execution pattern below.
- **requirements.txt**: `gradio>=5.50.0,<6.0` (required version range: the references pass `theme` and `css` to `gr.Blocks()`, which Gradio 6 moved to `launch()`) plus the other packages the app needs.
- **Code quality**: type hints, error handling with `gr.Error`, memory management (`torch.cuda.empty_cache()`), inference mode when loading models (`model.train(False)`), appropriate comments.

```python
if __name__ == "__main__":
    demo.queue(max_size=30).launch(mcp_server=True, ssr_mode=False, show_error=True)
```

## Layout rules

**Never nest `gr.Row` inside `gr.Row`**: it creates a double flex context with alignment conflicts. `Row > Column > components` and `Column > Row > components` are the correct patterns.

```python
# CORRECT - Single Row level with direct children
with gr.Row(elem_id="header-row"):
    gr.Image(...)                      # Direct child
    gr.Markdown("# Title")             # Direct child
    gr.HTML(value=HEADER_CONTROLS_HTML)  # Use gr.HTML for multiple controls

# WRONG - Nested Rows cause alignment issues
with gr.Row(elem_id="header-row"):
    with gr.Row(elem_id="header-left"):   # DO NOT DO THIS
        gr.Image(...)
        gr.Markdown(...)
    with gr.Group(elem_id="header-controls"):  # gr.Group forces column layout!
        gr.HTML(...)
        gr.HTML(...)
```

In Gradio 5.x, `gr.Button` does not render HTML in its `value`; it escapes it to text. For an SVG icon toggle use `gr.HTML` with a native `<button>` element, and for text only use `gr.Button` with a text value (for example "Dark" / "Light").

```python
# CORRECT - gr.HTML for SVG icon toggle
THEME_TOGGLE_HTML = '''
<button id="theme-toggle" class="theme-toggle-btn" type="button">
    <span class="icon-moon"><svg>...</svg></span>
    <span class="icon-sun"><svg>...</svg></span>
</button>
'''
gr.HTML(value=THEME_TOGGLE_HTML)

# Click handler attached via demo.load() JS
demo.load(fn=None, js=INIT_THEME_JS)  # Includes click handler

# WRONG - gr.Button does NOT render HTML
theme_btn = gr.Button(value="<span>...</span>")  # Shows escaped text, not icon!
```

| CSS practice | Status | Alternative |
|----------|--------|-------------|
| Use CSS variables | REQUIRED | `var(--body-text-color)` |
| Hardcoded hex colors | AVOID | Use theme variables |
| Excessive `!important` | AVOID | Let Gradio handle defaults |
| Manual flex layouts | MINIMIZE | Use `gr.Row`/`gr.Column` scale |
