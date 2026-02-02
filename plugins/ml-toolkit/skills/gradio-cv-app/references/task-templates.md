# Task Templates

Implementation templates for each CV task type.

## Common Patterns

### Device Configuration

```python
import torch

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Using device: {device}")
```

### GPU Decorator (Local/HF Spaces Compatible)

```python
try:
    import spaces
    SPACES_AVAILABLE = True
except ImportError:
    SPACES_AVAILABLE = False

def gpu_decorator(func):
    """Runs directly on local, allocates GPU on Spaces"""
    if SPACES_AVAILABLE:
        return spaces.GPU(func)
    return func

@gpu_decorator
def inference_function(image, model_name="default"):
    # Your inference logic here
    pass
```

### App Launch Pattern

```python
if __name__ == "__main__":
    demo.queue(max_size=30).launch(mcp_server=True, ssr_mode=False, show_error=True)
```

### Dark Mode Toggle

Add a theme toggle button with system preference detection. See [refined-theme.md](refined-theme.md) for full theme code.

```python
# Lucide icons (CSS controls visibility based on theme)
THEME_ICONS = '''
<span class="icon-moon"><svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/></svg></span>
<span class="icon-sun"><svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"/></svg></span>
'''

# Toggle and init JavaScript
TOGGLE_JS = """() => {
    document.documentElement.classList.toggle('dark');
    localStorage.setItem('theme', document.documentElement.classList.contains('dark') ? 'dark' : 'light');
}"""

INIT_JS = """() => {
    const saved = localStorage.getItem('theme');
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    if (saved === 'dark' || (!saved && prefersDark)) {
        document.documentElement.classList.add('dark');
    }
}"""

# Add to CSS
theme_toggle_css = """
#theme-toggle button { min-width: 40px !important; padding: 8px !important; }
#theme-toggle .icon-moon { display: inline-block; }
#theme-toggle .icon-sun { display: none; }
.dark #theme-toggle .icon-moon { display: none; }
.dark #theme-toggle .icon-sun { display: inline-block; }
"""

# Usage in Blocks
with gr.Blocks(theme=refined_theme, css=css + theme_toggle_css) as demo:
    with gr.Row():
        gr.Markdown("# App Title", elem_id="main-title")
        theme_btn = gr.Button(THEME_ICONS, elem_id="theme-toggle", size="sm")

    # ... UI components ...

    theme_btn.click(fn=None, js=TOGGLE_JS)
    demo.load(fn=None, js=INIT_JS)
```

---

## OCR/VLM App (`ocr`)

Multimodal OCR app - Extract text from images/videos/PDFs

### Key Components
- `gr.Tabs`: Image/Video/PDF tab structure
- `gr.Accordion`: Advanced Options (max_tokens, temperature)
- `TextIteratorStreamer`: Streaming output

### Structure

```python
import gradio as gr
from transformers import AutoProcessor, AutoModelForVision2Seq, TextIteratorStreamer
import threading

# Model loading
processor = AutoProcessor.from_pretrained("model-name")
model = AutoModelForVision2Seq.from_pretrained("model-name").to(device)
model.train(False)  # Inference mode

@gpu_decorator
def process_image(image, prompt, max_tokens, temperature):
    streamer = TextIteratorStreamer(processor.tokenizer, skip_special_tokens=True)
    # Inference logic
    ...

with gr.Blocks(theme=refined_theme, css=css) as demo:
    with gr.Column(elem_id="col-container"):
        gr.Markdown("# OCR App", elem_id="main-title")

        with gr.Tabs():
            with gr.TabItem("Image"):
                image_input = gr.Image(label="Image", type="pil")

            with gr.TabItem("Video"):
                video_input = gr.Video(label="Video")

            with gr.TabItem("PDF"):
                pdf_input = gr.File(label="PDF", file_types=[".pdf"])

        prompt_input = gr.Textbox(label="Prompt", placeholder="Extract text from the image")

        with gr.Accordion("Advanced Options", open=False):
            max_tokens = gr.Slider(100, 2000, value=500, label="Max Tokens")
            temperature = gr.Slider(0.1, 1.0, value=0.7, label="Temperature")

        output = gr.Textbox(label="Result", lines=10, show_copy_button=True)
        submit_btn = gr.Button("Run", variant="primary")
```

---

## Image Classification App (`classify`)

Binary or multi-class image classification

### Key Components
- `gr.Interface`: Simple structure
- `gr.Label`: Probability display

### Structure

```python
import gradio as gr
from transformers import AutoImageProcessor, AutoModelForImageClassification
import torch

# Model loading
processor = AutoImageProcessor.from_pretrained("model-name")
model = AutoModelForImageClassification.from_pretrained("model-name").to(device)
model.train(False)

def classify_image(image):
    inputs = processor(images=image, return_tensors="pt").to(device)

    with torch.no_grad():
        outputs = model(**inputs)
        probs = torch.nn.functional.softmax(outputs.logits, dim=-1)[0]

    labels = model.config.id2label
    return {labels[i]: float(probs[i]) for i in range(len(labels))}

demo = gr.Interface(
    fn=classify_image,
    inputs=gr.Image(type="pil", label="Image"),
    outputs=gr.Label(num_top_classes=5, label="Classification Result"),
    title="Image Classification",
    theme=refined_theme,
    css=css,
)
```

---

## Image Generation App (`generate`)

Diffusion model-based image generation (with LoRA support)

### Key Components
- Style dictionary
- LoRA loading pattern
- Grid generation options

### Structure

```python
import gradio as gr
from diffusers import DiffusionPipeline
import torch

# Style presets
STYLES = {
    "Default": "",
    "Cinematic": "cinematic lighting, dramatic shadows, film grain",
    "Minimal": "minimal, clean, simple composition",
}

# Pipeline loading
pipe = DiffusionPipeline.from_pretrained(
    "model-name",
    torch_dtype=torch.float16,
).to(device)

# LoRA loading (optional)
# pipe.load_lora_weights("lora-path")

@gpu_decorator
def generate_image(prompt, style, seed, steps, guidance):
    if seed == -1:
        seed = torch.randint(0, 2**32, (1,)).item()

    generator = torch.Generator(device=device).manual_seed(seed)

    full_prompt = f"{prompt}, {STYLES[style]}" if STYLES[style] else prompt

    image = pipe(
        prompt=full_prompt,
        num_inference_steps=steps,
        guidance_scale=guidance,
        generator=generator,
    ).images[0]

    return image, seed

with gr.Blocks(theme=refined_theme, css=css) as demo:
    with gr.Column(elem_id="col-container"):
        gr.Markdown("# Image Generation", elem_id="main-title")

        prompt = gr.Textbox(label="Prompt", lines=3)
        style = gr.Radio(list(STYLES.keys()), value="Default", label="Style")

        with gr.Row():
            seed = gr.Number(value=-1, label="Seed (-1 = Random)")
            steps = gr.Slider(10, 50, value=25, step=1, label="Steps")
            guidance = gr.Slider(1, 15, value=7.5, step=0.5, label="Guidance Scale")

        output = gr.Image(label="Result")
        used_seed = gr.Number(label="Used Seed", interactive=False)

        submit_btn = gr.Button("Generate", variant="primary")
        submit_btn.click(generate_image, [prompt, style, seed, steps, guidance], [output, used_seed])
```

---

## Segmentation App (`segment`)

Text prompt-based image segmentation

### Key Components
- `gr.AnnotatedImage`: Segmentation result visualization
- Confidence Threshold slider

### Structure

```python
import gradio as gr
from transformers import AutoProcessor, AutoModelForMaskGeneration

processor = AutoProcessor.from_pretrained("model-name")
model = AutoModelForMaskGeneration.from_pretrained("model-name").to(device)
model.train(False)

@gpu_decorator
def segment_image(image, text_prompt, threshold):
    inputs = processor(images=image, text=text_prompt, return_tensors="pt").to(device)

    with torch.no_grad():
        outputs = model(**inputs)

    # Mask processing logic
    masks = outputs.pred_masks[0]
    # ...

    return (image, annotations)

with gr.Blocks(theme=refined_theme, css=css) as demo:
    with gr.Column(elem_id="col-container"):
        gr.Markdown("# Image Segmentation", elem_id="main-title")

        with gr.Row():
            input_image = gr.Image(label="Input Image", type="pil")
            output_image = gr.AnnotatedImage(label="Segmentation Result")

        text_prompt = gr.Textbox(label="Segmentation Target", placeholder="e.g., person, car, dog")
        threshold = gr.Slider(0.1, 0.9, value=0.5, label="Confidence Threshold")

        submit_btn = gr.Button("Segment", variant="primary")
```

---

## Image Editing App (`edit`)

Prompt-based image editing

### Key Components
- Side-by-side input/output image layout
- LoRA adapter selection Dropdown

### Structure

```python
import gradio as gr

ADAPTERS = {
    "Default": None,
    "Style A": "adapter-a",
    "Style B": "adapter-b",
}

@gpu_decorator
def edit_image(image, prompt, adapter_name, strength):
    # Adapter loading
    if ADAPTERS[adapter_name]:
        pipe.load_lora_weights(ADAPTERS[adapter_name])

    # Editing logic
    result = pipe(
        image=image,
        prompt=prompt,
        strength=strength,
    ).images[0]

    return result

with gr.Blocks(theme=refined_theme, css=css) as demo:
    with gr.Column(elem_id="col-container"):
        gr.Markdown("# Image Editing", elem_id="main-title")

        with gr.Row():
            input_image = gr.Image(label="Original Image", type="pil")
            output_image = gr.Image(label="Edited Result")

        prompt = gr.Textbox(label="Editing Prompt")
        adapter = gr.Dropdown(list(ADAPTERS.keys()), value="Default", label="Style Adapter")
        strength = gr.Slider(0.1, 1.0, value=0.75, label="Edit Strength")

        submit_btn = gr.Button("Edit", variant="primary")
```

---

## Image Captioning App (`caption`)

Image description generation

### Key Components
- Model selection Radio
- `show_copy_button=True`

### Structure

```python
import gradio as gr
from transformers import AutoProcessor, AutoModelForCausalLM

MODELS = {
    "Default": "model-a",
    "Detailed": "model-b",
}

def caption_image(image, model_choice):
    model_name = MODELS[model_choice]
    # Captioning logic
    ...
    return caption

with gr.Blocks(theme=refined_theme, css=css) as demo:
    with gr.Column(elem_id="col-container"):
        gr.Markdown("# Image Captioning", elem_id="main-title")

        input_image = gr.Image(label="Image", type="pil")
        model_choice = gr.Radio(list(MODELS.keys()), value="Default", label="Model")

        output = gr.Textbox(label="Caption", lines=5, show_copy_button=True)

        submit_btn = gr.Button("Generate Caption", variant="primary")
```

---

## Detection App (`detect`)

Deepfake, AI-generated image detection, etc.

### Key Components
- Binary classification (Real/Fake)
- `gr.Label` for probability output

### Structure

```python
import gradio as gr
from transformers import AutoImageProcessor, AutoModelForImageClassification

processor = AutoImageProcessor.from_pretrained("model-name")
model = AutoModelForImageClassification.from_pretrained("model-name").to(device)
model.train(False)

def detect(image):
    inputs = processor(images=image, return_tensors="pt").to(device)

    with torch.no_grad():
        outputs = model(**inputs)
        probs = torch.nn.functional.softmax(outputs.logits, dim=-1)[0]

    return {
        "Real": float(probs[0]),
        "Fake": float(probs[1]),
    }

demo = gr.Interface(
    fn=detect,
    inputs=gr.Image(type="pil", label="Image"),
    outputs=gr.Label(label="Detection Result"),
    title="Deepfake Detection",
    theme=refined_theme,
    css=css,
)
```
