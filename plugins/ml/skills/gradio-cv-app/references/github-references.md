# GitHub References

Reference Gradio CV repositories by PRITHIVSAKTHIUR ([GitHub](https://github.com/PRITHIVSAKTHIUR), [Hugging Face](https://huggingface.co/prithivMLmods)), grouped by the skill's 7 task keys. Open the repo for a task when its template in `task-templates.md` does not cover a pattern.

## Reference repositories by task

### OCR/VLM (`ocr`)

| Repository | Key Patterns |
|-----------|----------|
| [Multimodal-OCR](https://github.com/PRITHIVSAKTHIUR/Multimodal-OCR) | Multi-model selection, streaming output, Image/Video tabs |
| [Qwen3-VL-Outpost](https://github.com/PRITHIVSAKTHIUR/Qwen3-VL-Outpost) | PDF processing, GIF support, custom themes |
| [Multimodal-OCR2](https://github.com/PRITHIVSAKTHIUR/Multimodal-OCR2) | Video OCR, markdown output |

### Image Classification (`classify`)

| Repository | Key Patterns |
|-----------|----------|
| [deepfake-detector-model-v1](https://github.com/PRITHIVSAKTHIUR/deepfake-detector-model-v1) | gr.Interface, SiglipForImageClassification |
| [AIorNot-SigLIP2](https://github.com/PRITHIVSAKTHIUR/AIorNot-SigLIP2) | Binary classification, gr.Label output |

### Image Generation (`generate`)

| Repository | Key Patterns |
|-----------|----------|
| [FLUX-REALISM](https://github.com/PRITHIVSAKTHIUR/FLUX-REALISM) | Style dictionary, LoRA loading, dual models |
| [Flux-LoRA-DLC](https://github.com/PRITHIVSAKTHIUR/Flux-LoRA-DLC) | 255+ LoRA collection, dynamic loading |
| [Imagineo-4K](https://github.com/PRITHIVSAKTHIUR/Imagineo-4K) | Grid generation, filter/style combinations |

### Segmentation (`segment`)

| Repository | Key Patterns |
|-----------|----------|
| [SAM3-Image-Segmentation](https://github.com/PRITHIVSAKTHIUR/SAM3-Image-Segmentation) | gr.AnnotatedImage, text prompts |

### Image Editing (`edit`)

| Repository | Key Patterns |
|-----------|----------|
| [Qwen-Image-Edit-2509-LoRAs-Fast](https://github.com/PRITHIVSAKTHIUR/Qwen-Image-Edit-2509-LoRAs-Fast) | LoRA adapter selection, image editing |
| [Magic_Eraser](https://github.com/PRITHIVSAKTHIUR/Magic_Eraser) | Streamlit canvas, inpainting |

### Image Captioning (`caption`)

| Repository | Key Patterns |
|-----------|----------|
| [Florence-2-Image-Caption](https://github.com/PRITHIVSAKTHIUR/Florence-2-Image-Caption) | Model selection radio buttons, detailed captions |

### Detection (`detect`)

| Repository | Key Patterns |
|-----------|----------|
| [deepfake-detector-model-v1](https://github.com/PRITHIVSAKTHIUR/deepfake-detector-model-v1) | Real/Fake binary classification |
| [AIorNot-SigLIP2](https://github.com/PRITHIVSAKTHIUR/AIorNot-SigLIP2) | AI/Real detection |

## Fine-tuning and notebook repositories

| Repository | Description |
|-----------|------|
| [FineTuning-SigLIP-2](https://github.com/PRITHIVSAKTHIUR/FineTuning-SigLIP-2) | Image classification model fine-tuning notebooks |
| [Multimodal-Outpost-Notebooks](https://github.com/PRITHIVSAKTHIUR/Multimodal-Outpost-Notebooks) | VLM implementation notebooks |
| [OCR-ReportLab-Notebooks](https://github.com/PRITHIVSAKTHIUR/OCR-ReportLab-Notebooks) | OCR experiment notebooks |

## Key code patterns

The theme pattern shared across these apps inherits from `gradio.themes.Soft`, defines custom colors, and uses gradient backgrounds and buttons. This skill replaces the gradients with solid colors to avoid an AI-generated look.

### GPU compatibility

```python
try:
    import spaces
    @spaces.GPU
    def inference(...): ...
except ImportError:
    def inference(...): ...
```

### Streaming output

```python
from transformers import TextIteratorStreamer
import threading

streamer = TextIteratorStreamer(tokenizer, skip_special_tokens=True)
thread = threading.Thread(target=model.generate, kwargs={..., "streamer": streamer})
thread.start()

for text in streamer:
    yield partial_output + text
```

### Model selection

```python
MODELS = {
    "Model A": "path/to/model-a",
    "Model B": "path/to/model-b",
}

model_selector = gr.Radio(list(MODELS.keys()), value="Model A", label="Select Model")
```

### Example images

```python
examples = [
    ["examples/image1.jpg", "Prompt 1"],
    ["examples/image2.jpg", "Prompt 2"],
]

gr.Examples(examples=examples, inputs=[image_input, prompt_input])
```
