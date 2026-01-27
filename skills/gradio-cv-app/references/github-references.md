# GitHub References

Reference repositories for Gradio CV applications by PRITHIVSAKTHIUR.

## Profile

- **GitHub**: https://github.com/PRITHIVSAKTHIUR
- **Hugging Face**: https://huggingface.co/prithivMLmods
- **Specialty**: Extensive experience building Gradio apps based on Computer Vision, VLM, and Diffusion models

---

## Reference Repositories by Task

### OCR/VLM (`ocr`)

| Repository | Stars | Key Patterns |
|-----------|-------|----------|
| [Multimodal-OCR](https://github.com/PRITHIVSAKTHIUR/Multimodal-OCR) | 14 | Multi-model selection, streaming output, Image/Video tabs |
| [Qwen3-VL-Outpost](https://github.com/PRITHIVSAKTHIUR/Qwen3-VL-Outpost) | 6 | PDF processing, GIF support, custom themes |
| [Multimodal-OCR2](https://github.com/PRITHIVSAKTHIUR/Multimodal-OCR2) | 4 | Video OCR, markdown output |

### Image Classification (`classify`)

| Repository | Stars | Key Patterns |
|-----------|-------|----------|
| [deepfake-detector-model-v1](https://github.com/PRITHIVSAKTHIUR/deepfake-detector-model-v1) | 15 | gr.Interface, SiglipForImageClassification |
| [AIorNot-SigLIP2](https://github.com/PRITHIVSAKTHIUR/AIorNot-SigLIP2) | 3 | Binary classification, gr.Label output |

### Image Generation (`generate`)

| Repository | Stars | Key Patterns |
|-----------|-------|----------|
| [FLUX-REALISM](https://github.com/PRITHIVSAKTHIUR/FLUX-REALISM) | 15 | Style dictionary, LoRA loading, dual models |
| [Flux-LoRA-DLC](https://github.com/PRITHIVSAKTHIUR/Flux-LoRA-DLC) | 13 | 255+ LoRA collection, dynamic loading |
| [Imagineo-4K](https://github.com/PRITHIVSAKTHIUR/Imagineo-4K) | 12 | Grid generation, filter/style combinations |

### Segmentation (`segment`)

| Repository | Stars | Key Patterns |
|-----------|-------|----------|
| [SAM3-Image-Segmentation](https://github.com/PRITHIVSAKTHIUR/SAM3-Image-Segmentation) | 2 | gr.AnnotatedImage, text prompts |

### Image Editing (`edit`)

| Repository | Stars | Key Patterns |
|-----------|-------|----------|
| [Qwen-Image-Edit-2509-LoRAs-Fast](https://github.com/PRITHIVSAKTHIUR/Qwen-Image-Edit-2509-LoRAs-Fast) | 5 | LoRA adapter selection, image editing |
| [Magic_Eraser](https://github.com/PRITHIVSAKTHIUR/Magic_Eraser) | 15 | Streamlit canvas, inpainting |

### Image Captioning (`caption`)

| Repository | Stars | Key Patterns |
|-----------|-------|----------|
| [Florence-2-Image-Caption](https://github.com/PRITHIVSAKTHIUR/Florence-2-Image-Caption) | 6 | Model selection radio buttons, detailed captions |

### Detection (`detect`)

| Repository | Stars | Key Patterns |
|-----------|-------|----------|
| [deepfake-detector-model-v1](https://github.com/PRITHIVSAKTHIUR/deepfake-detector-model-v1) | 15 | Real/Fake binary classification |
| [AIorNot-SigLIP2](https://github.com/PRITHIVSAKTHIUR/AIorNot-SigLIP2) | 3 | AI/Real detection |

---

## Additional Reference Repositories

### Fine-tuning & Notebooks

| Repository | Stars | Description |
|-----------|-------|------|
| [FineTuning-SigLIP-2](https://github.com/PRITHIVSAKTHIUR/FineTuning-SigLIP-2) | 44 | Image classification model fine-tuning notebooks |
| [Multimodal-Outpost-Notebooks](https://github.com/PRITHIVSAKTHIUR/Multimodal-Outpost-Notebooks) | 24 | VLM implementation notebooks |
| [OCR-ReportLab-Notebooks](https://github.com/PRITHIVSAKTHIUR/OCR-ReportLab-Notebooks) | 23 | OCR experiment notebooks |

---

## Key Code Patterns Summary

### 1. Custom Theme Structure

Common theme pattern used across all apps:
- Inherits from `gradio.themes.Soft`
- Custom Color definitions
- Gradient backgrounds and buttons (original style)

**Note**: This skill replaces gradients with solid colors to avoid an AI-generated aesthetic.

### 2. GPU Compatibility Pattern

```python
try:
    import spaces
    @spaces.GPU
    def inference(...): ...
except ImportError:
    def inference(...): ...
```

### 3. Streaming Output Pattern

```python
from transformers import TextIteratorStreamer
import threading

streamer = TextIteratorStreamer(tokenizer, skip_special_tokens=True)
thread = threading.Thread(target=model.generate, kwargs={..., "streamer": streamer})
thread.start()

for text in streamer:
    yield partial_output + text
```

### 4. Model Selection Pattern

```python
MODELS = {
    "Model A": "path/to/model-a",
    "Model B": "path/to/model-b",
}

model_selector = gr.Radio(list(MODELS.keys()), value="Model A", label="Select Model")
```

### 5. Example Images Pattern

```python
examples = [
    ["examples/image1.jpg", "Prompt 1"],
    ["examples/image2.jpg", "Prompt 2"],
]

gr.Examples(examples=examples, inputs=[image_input, prompt_input])
```
