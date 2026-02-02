---
name: gradio-cv-app
description: Creates professional Gradio computer vision apps. Applies a refined Editorial design based on PRITHIVSAKTHIUR style. Automatically triggered for OCR, image classification, generation, segmentation, editing, captioning, and detection app requests. Used for Gradio CV apps, computer vision demos, and image processing app creation requests.
---

# Gradio CV App Generator

A skill for creating professional Gradio computer vision apps.
Combines PRITHIVSAKTHIUR's functional patterns with Editorial design principles.

## Design Principles

### What to Avoid (AI Look)
- Purple/rainbow gradients
- Multiple mixed colors
- Excessive animations
- Colors commonly seen in AI demos like Steel Blue, Purple, etc.

### What to Apply (Editorial Style)
- Solid colors + single accent
- Pretendard font (Korean support)
- Minimal and functional UI
- Ample whitespace and high contrast
- Professional tool-like feel
- Dark mode support (system preference by default)

### Dark Mode Considerations
- **Accent color**: Must use `color_accent="*secondary_500"` (emerald) instead of default primary (zinc)
- Zinc primary causes poor tab text visibility in dark mode
- See [refined-theme.md](references/refined-theme.md) for complete theme settings

## Supported Task Types

| Task | Description | Key Patterns |
|------|-------------|--------------|
| `ocr` | OCR/VLM multimodal app | Tabs, TextIteratorStreamer, Accordion |
| `classify` | Image classification | gr.Interface, gr.Label |
| `generate` | Image generation | LoRA loading, style dictionary |
| `segment` | Segmentation | gr.AnnotatedImage |
| `edit` | Image editing | LoRA adapter, prompts |
| `caption` | Image captioning | VLM model, copy button |
| `detect` | Detection (Deepfake, etc.) | Binary classification, gr.Label |

## Usage

When creating a Gradio CV app:

1. **Identify task type**: Determine the CV task from the user request
2. **Apply theme**: Use the RefinedTheme class from [refined-theme.md](references/refined-theme.md)
3. **Reference templates**: Check the relevant task pattern in [task-templates.md](references/task-templates.md)
4. **Check reference repos**: Refer to [github-references.md](references/github-references.md) if needed
5. **Generate complete app.py**: Write ready-to-run code

## Theme Mode

Apps support light/dark mode with automatic system preference detection.

| Mode | Description |
|------|-------------|
| **Auto (Default)** | Detects OS preference, saves user choice to localStorage |
| Light | Forces light theme |
| Dark | Forces dark theme |

Implementation: Add theme toggle button using Lucide icons. See [refined-theme.md](references/refined-theme.md) for details.

## Internationalization (i18n)

Simple dictionary-based labels for Korean/English support.

```python
LABELS = {
    "en": {"title": "Image Classification", "run": "Run"},
    "ko": {"title": "이미지 분류", "run": "실행"},
}
```

See [i18n-patterns.md](references/i18n-patterns.md) for full label dictionaries and usage patterns.

## Output Requirements

1. **Complete app.py file**: Ready-to-run code
2. **requirements.txt**: Required package list
   - `gradio>=5.50.0,<6.0` (required version range)
   - Other necessary packages

## Code Quality Standards

- Use type hints
- Error handling (use gr.Error)
- Memory management (torch.cuda.empty_cache())
- Apply inference mode when loading models (model.train(False))
- Appropriate comments

## Layout Best Practices

### Row/Column Nesting Rules

**CRITICAL**: Never nest `gr.Row` inside `gr.Row` - this causes double flex context conflicts.

| Pattern | Status | Reason |
|---------|--------|--------|
| `Row > Column > components` | CORRECT | Clear flex hierarchy |
| `Row > Row > components` | WRONG | Double flex context, alignment issues |
| `Column > Row > components` | CORRECT | Standard layout pattern |

**Example - Header Layout:**

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

### Theme Toggle Implementation

**IMPORTANT**: In Gradio 5.x, `gr.Button` does NOT render HTML in the `value` parameter - it escapes HTML to text.

**For SVG Icons**: Use `gr.HTML` with native `<button>` element
**For Text Only**: Use `gr.Button` with text value (e.g., "Dark" / "Light")

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

### CSS Guidelines

| Practice | Status | Alternative |
|----------|--------|-------------|
| Use CSS variables | REQUIRED | `var(--body-text-color)` |
| Hardcoded hex colors | AVOID | Use theme variables |
| Excessive `!important` | AVOID | Let Gradio handle defaults |
| Manual flex layouts | MINIMIZE | Use `gr.Row`/`gr.Column` scale |

## Common Execution Pattern

```python
if __name__ == "__main__":
    demo.queue(max_size=30).launch(mcp_server=True, ssr_mode=False, show_error=True)
```

## Additional Resources

- Theme code (with dark mode): [references/refined-theme.md](references/refined-theme.md)
- Task-specific templates: [references/task-templates.md](references/task-templates.md)
- i18n patterns (Korean/English): [references/i18n-patterns.md](references/i18n-patterns.md)
- GitHub references: [references/github-references.md](references/github-references.md)
