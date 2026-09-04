# Refined Theme (Editorial Style)

A polished theme for Gradio applications with dark mode support. Avoids the generic AI aesthetic and delivers a professional tool-like experience.

## Theme Class

```python
from typing import Iterable
from gradio.themes import Soft
from gradio.themes.utils import colors, fonts, sizes


class RefinedTheme(Soft):
    """Editorial/Documentation style theme with dark mode support

    Features:
    - No gradients, solid colors only
    - Single accent color (Emerald)
    - High contrast, professional look
    - Pretendard font (Korean support)
    - Built-in dark mode via _dark variants
    """

    def __init__(
        self,
        *,
        primary_hue: colors.Color | str = colors.zinc,
        secondary_hue: colors.Color | str = colors.emerald,
        neutral_hue: colors.Color | str = colors.zinc,
        text_size: sizes.Size | str = sizes.text_md,
        font: fonts.Font | str | Iterable[fonts.Font | str] = (
            fonts.GoogleFont("Pretendard"),
            "Pretendard",
            "-apple-system",
            "BlinkMacSystemFont",
            "system-ui",
            "sans-serif",
        ),
        font_mono: fonts.Font | str | Iterable[fonts.Font | str] = (
            fonts.GoogleFont("JetBrains Mono"),
            "ui-monospace",
            "monospace",
        ),
    ):
        super().__init__(
            primary_hue=primary_hue,
            secondary_hue=secondary_hue,
            neutral_hue=neutral_hue,
            text_size=text_size,
            font=font,
            font_mono=font_mono,
        )
        super().set(
            # === Light Mode (Default) ===
            body_background_fill="#fafafa",
            background_fill_primary="#ffffff",
            background_fill_secondary="#f4f4f5",

            # === Dark Mode Variants ===
            body_background_fill_dark="#18181b",
            background_fill_primary_dark="#27272a",
            background_fill_secondary_dark="#3f3f46",

            # Text colors
            body_text_color="*neutral_800",
            body_text_color_dark="#fafafa",
            block_title_text_color="*neutral_800",
            block_title_text_color_dark="#fafafa",

            # Buttons - solid colors (no gradients)
            button_primary_background_fill="*secondary_600",
            button_primary_background_fill_hover="*secondary_700",
            button_primary_text_color="white",
            button_primary_background_fill_dark="*secondary_500",
            button_primary_background_fill_hover_dark="*secondary_600",

            button_secondary_background_fill="*neutral_100",
            button_secondary_background_fill_hover="*neutral_200",
            button_secondary_background_fill_dark="*neutral_700",
            button_secondary_background_fill_hover_dark="*neutral_600",
            button_secondary_text_color_dark="#fafafa",

            # Minimal styling
            block_border_width="1px",
            block_border_color="*neutral_200",
            block_border_color_dark="*neutral_700",
            block_shadow="none",
            button_shadow="none",
            button_primary_shadow="none",

            # Margins and spacing
            spacing_lg="1.5rem",
            spacing_md="1rem",

            # Title styling
            block_title_text_weight="600",
            block_title_text_size="*text_md",

            # Input fields
            input_background_fill="*neutral_50",
            input_background_fill_dark="*neutral_800",
            input_border_color="*neutral_300",
            input_border_color_dark="*neutral_600",
            input_border_width="1px",

            # Accent colors - for tabs, links, and interactive elements
            # Use secondary (emerald) instead of primary (zinc) for visibility
            color_accent="*secondary_500",
            color_accent_soft="*secondary_100",
            color_accent_soft_dark="*secondary_800",
            border_color_accent="*secondary_400",
            border_color_accent_dark="*secondary_600",
        )


# Create theme instance
refined_theme = RefinedTheme()
```

## CSS Styles

```python
css = """
/* Container */
#col-container {
    margin: 0 auto;
    max-width: 1000px;
}

/* Title */
#main-title h1 {
    font-size: 1.75rem !important;
    font-weight: 600 !important;
}

/* Smooth theme transition */
body, .gradio-container {
    transition: background-color 0.2s ease, color 0.2s ease;
}

/* Buttons */
.submit-btn {
    font-weight: 500 !important;
}

/* Theme toggle button (native HTML button via gr.HTML) */
.theme-toggle-btn {
    min-width: 40px;
    height: 40px;
    padding: 8px;
    border: 1px solid var(--border-color-primary);
    border-radius: 8px;
    background-color: var(--background-fill-primary);
    color: var(--body-text-color);
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    transition: border-color 0.2s ease, background-color 0.2s ease;
}
.theme-toggle-btn:hover {
    border-color: var(--color-accent);
    background-color: var(--background-fill-secondary);
}

/* Moon icon (light mode - shows moon to switch to dark) */
#theme-toggle .icon-moon { display: inline-flex; }
#theme-toggle .icon-sun { display: none; }

/* Sun icon (dark mode - shows sun to switch to light) */
.dark #theme-toggle .icon-moon { display: none; }
.dark #theme-toggle .icon-sun { display: inline-flex; }

/* Text areas */
textarea {
    font-size: 0.9rem !important;
}

/* Labels */
.label-wrap {
    font-weight: 500 !important;
}
"""
```

---

## Dark Mode Toggle

### Method 1: gr.HTML with Native Button (Recommended for SVG Icons)

**IMPORTANT**: In Gradio 5.x, `gr.Button` does NOT render HTML in the `value` parameter - it escapes HTML to text. Use `gr.HTML` with a native `<button>` element for SVG icon toggles.

```python
import gradio as gr

# Native HTML button with SVG icons (CSS controls visibility)
THEME_TOGGLE_HTML = """
<button id="theme-toggle" class="theme-toggle-btn" type="button" aria-label="Toggle theme">
    <span class="icon-moon"><svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/></svg></span>
    <span class="icon-sun"><svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/></svg></span>
</button>
"""
```

### JavaScript for Theme Toggle

```python
# Initialize theme on page load AND attach click handler
INIT_THEME_JS = """
() => {
    const saved = localStorage.getItem('theme');
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const shouldBeDark = saved === 'dark' || (!saved && prefersDark);

    if (shouldBeDark) {
        document.documentElement.classList.add('dark');
    }

    // Attach click handler to theme toggle button
    const toggleBtn = document.getElementById('theme-toggle');
    if (toggleBtn) {
        toggleBtn.addEventListener('click', (e) => {
            e.preventDefault();
            document.documentElement.classList.toggle('dark');
            const isDark = document.documentElement.classList.contains('dark');
            localStorage.setItem('theme', isDark ? 'dark' : 'light');
        });
    }
}
"""
```

### Usage Pattern

**Important**: Gradio Row wraps each child in a div with `flex: 1 1 0%` by default.
To push the toggle to the right edge, CSS wrapper override is required.

**Additional CSS for header layout:**
```css
/* Header row - prevent wrap, center vertically */
.row.header-row {
    align-items: center !important;
    flex-wrap: nowrap !important;
}

/* Title wrapper - expand to fill space */
#main-title {
    flex: 1 1 auto !important;
    min-width: 0 !important;
}

/* Toggle wrapper - fixed size */
.header-row > .theme-toggle-container {
    flex: 0 0 auto !important;
    min-width: 0 !important;
    width: auto !important;
}
```

**Layout code:**
```python
import gradio as gr

with gr.Blocks(theme=refined_theme, css=css) as demo:
    with gr.Column(elem_id="col-container"):
        # Header with theme toggle (use elem_classes for CSS targeting)
        with gr.Row(elem_classes=["header-row"]):
            gr.Markdown("# App Title", elem_id="main-title")
            gr.HTML(value=THEME_TOGGLE_HTML, elem_classes=["theme-toggle-container"])

        # Your UI components here...
        input_image = gr.Image(label="Input Image", type="pil")
        submit_btn = gr.Button("Run", variant="primary")

    # Initialize theme on load (includes click handler)
    demo.load(fn=None, js=INIT_THEME_JS)
```

**Common pitfalls:**
- `Row > Column(scale=0, min_width=0)` pattern can cause width=0px issues
- `margin-left: auto` on inner element won't work (targets wrong div)
- Without `flex-wrap: nowrap`, toggle may wrap to next line

---

### Method 2: Text-Based Toggle (Simplest)

For minimal implementation without icons:

```python
THEME_TOGGLE_JS_TEXT = """
() => {
    const html = document.documentElement;
    html.classList.toggle('dark');
    const isDark = html.classList.contains('dark');
    localStorage.setItem('theme', isDark ? 'dark' : 'light');

    const btn = document.querySelector('#theme-toggle button');
    if (btn) {
        btn.textContent = isDark ? 'Light' : 'Dark';
    }
}
"""

# Usage
theme_btn = gr.Button("Dark", elem_id="theme-toggle", size="sm")
```

---

## Alternative Accent Colors

Single accent color options to use instead of Emerald:

| Color | Gradio Color | Use Case |
|-------|--------------|----------|
| Amber | `colors.amber` | Warm and energetic feel |
| Sky | `colors.sky` | Calm and trustworthy feel |
| Rose | `colors.rose` | Soft and approachable feel |
| Teal | `colors.teal` | Modern and sophisticated feel |

**Note**: Use only one accent color per application. Mixing multiple colors creates a generic AI aesthetic.

---

## Complete Example

```python
import gradio as gr
from gradio.themes import Soft
from gradio.themes.utils import colors, fonts


class RefinedTheme(Soft):
    def __init__(self):
        super().__init__(
            primary_hue=colors.zinc,
            secondary_hue=colors.emerald,
            neutral_hue=colors.zinc,
            font=(fonts.GoogleFont("Pretendard"), "system-ui", "sans-serif"),
            font_mono=(fonts.GoogleFont("JetBrains Mono"), "monospace"),
        )
        super().set(
            body_background_fill="#fafafa",
            body_background_fill_dark="#18181b",
            background_fill_primary="#ffffff",
            background_fill_primary_dark="#27272a",
            body_text_color="*neutral_800",
            body_text_color_dark="#fafafa",
            button_primary_background_fill="*secondary_600",
            button_primary_background_fill_dark="*secondary_500",
            block_shadow="none",
            button_shadow="none",
        )


THEME_ICONS = '''
<span class="icon-moon"><svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/></svg></span>
<span class="icon-sun"><svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"/></svg></span>
'''

css = """
#col-container { margin: 0 auto; max-width: 1000px; }
#theme-toggle button { min-width: 40px !important; padding: 8px !important; }
#theme-toggle .icon-moon { display: inline-block; }
#theme-toggle .icon-sun { display: none; }
.dark #theme-toggle .icon-moon { display: none; }
.dark #theme-toggle .icon-sun { display: inline-block; }
body { transition: background-color 0.2s ease; }
"""

TOGGLE_JS = """() => {
    document.documentElement.classList.toggle('dark');
    const isDark = document.documentElement.classList.contains('dark');
    localStorage.setItem('theme', isDark ? 'dark' : 'light');
}"""

INIT_JS = """() => {
    const saved = localStorage.getItem('theme');
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    if (saved === 'dark' || (!saved && prefersDark)) {
        document.documentElement.classList.add('dark');
    }
}"""

theme = RefinedTheme()

with gr.Blocks(theme=theme, css=css) as demo:
    with gr.Column(elem_id="col-container"):
        with gr.Row():
            gr.Markdown("# My App")
            theme_btn = gr.Button(THEME_ICONS, elem_id="theme-toggle", size="sm")

        image = gr.Image(label="Upload", type="pil")
        btn = gr.Button("Run", variant="primary")

    theme_btn.click(fn=None, js=TOGGLE_JS)
    demo.load(fn=None, js=INIT_JS)

if __name__ == "__main__":
    demo.queue(max_size=30).launch(mcp_server=True, ssr_mode=False, show_error=True)
```
