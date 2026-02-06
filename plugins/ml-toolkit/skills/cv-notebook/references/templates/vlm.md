# Vision Language Model (VLM) Templates

Comprehensive templates for Florence-2, PaliGemma, and Qwen2.5-VL models covering multi-task prompting, output parsing, visualization, and fine-tuning.

---

## 1. Florence-2 Multi-Task Vision Model

### 1.1 Model Loading

```python
import torch
from transformers import AutoProcessor, AutoModelForCausalLM
from PIL import Image
import supervision as sv

# Load Florence-2 model
device = "cuda" if torch.cuda.is_available() else "cpu"
model_name = "microsoft/Florence-2-large"  # or Florence-2-base

model = AutoModelForCausalLM.from_pretrained(
    model_name,
    torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
    trust_remote_code=True
).to(device)

processor = AutoProcessor.from_pretrained(model_name, trust_remote_code=True)
```

### 1.2 Multi-Task Prompting

Florence-2 supports various task prompts:

```python
# Task prompts
TASKS = {
    "caption": "<CAPTION>",
    "detailed_caption": "<DETAILED_CAPTION>",
    "more_detailed_caption": "<MORE_DETAILED_CAPTION>",
    "object_detection": "<OD>",
    "dense_region_caption": "<DENSE_REGION_CAPTION>",
    "region_proposal": "<REGION_PROPOSAL>",
    "caption_to_phrase_grounding": "<CAPTION_TO_PHRASE_GROUNDING>",
    "referring_expression_segmentation": "<REFERRING_EXPRESSION_SEGMENTATION>",
    "region_to_segmentation": "<REGION_TO_SEGMENTATION>",
    "open_vocabulary_detection": "<OPEN_VOCABULARY_DETECTION>",
    "region_to_category": "<REGION_TO_CATEGORY>",
    "region_to_description": "<REGION_TO_DESCRIPTION>",
    "ocr": "<OCR>",
    "ocr_with_region": "<OCR_WITH_REGION>"
}

def run_florence_task(image_path: str, task: str, text_input: str = None):
    """Run Florence-2 on any task"""
    image = Image.open(image_path).convert("RGB")

    prompt = TASKS[task]
    if text_input:
        prompt = f"{prompt}{text_input}"

    inputs = processor(text=prompt, images=image, return_tensors="pt").to(device)

    generated_ids = model.generate(
        input_ids=inputs["input_ids"],
        pixel_values=inputs["pixel_values"],
        max_new_tokens=1024,
        num_beams=3,
        do_sample=False
    )

    generated_text = processor.batch_decode(generated_ids, skip_special_tokens=False)[0]
    parsed_answer = processor.post_process_generation(
        generated_text,
        task=prompt,
        image_size=(image.width, image.height)
    )

    return parsed_answer
```

### 1.3 Output Parsing Examples

```python
# Captioning
result = run_florence_task("image.jpg", "detailed_caption")
caption = result["<DETAILED_CAPTION>"]
print(f"Caption: {caption}")

# Object Detection
result = run_florence_task("image.jpg", "object_detection")
detections = result["<OD>"]
# Format: {'bboxes': [[x1, y1, x2, y2], ...], 'labels': ['person', 'car', ...]}
print(f"Found {len(detections['labels'])} objects")

# OCR with Regions
result = run_florence_task("image.jpg", "ocr_with_region")
ocr_data = result["<OCR_WITH_REGION>"]
# Format: {'quad_boxes': [...], 'labels': ['text1', 'text2', ...]}

# Phrase Grounding (find objects from caption)
result = run_florence_task("image.jpg", "caption_to_phrase_grounding", "a red car")
grounding = result["<CAPTION_TO_PHRASE_GROUNDING>"]
# Format: {'bboxes': [...], 'labels': ['a red car', ...]}

# Open Vocabulary Detection
result = run_florence_task("image.jpg", "open_vocabulary_detection", "person.car.dog")
detections = result["<OPEN_VOCABULARY_DETECTION>"]
```

### 1.4 Visualization with Supervision

```python
import supervision as sv
import cv2

def visualize_florence_detections(image_path: str, task: str = "object_detection"):
    """Visualize Florence-2 detections using supervision"""
    image = cv2.imread(image_path)
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    pil_image = Image.fromarray(image_rgb)

    # Run detection
    result = run_florence_task(image_path, task)
    task_key = TASKS[task]
    detections_data = result[task_key]

    # Convert to supervision Detections
    bboxes = np.array(detections_data['bboxes'])
    labels = detections_data['labels']

    # Create Detections object
    detections = sv.Detections(
        xyxy=bboxes,
        class_id=np.arange(len(labels))
    )

    # Annotate
    box_annotator = sv.BoxAnnotator()
    label_annotator = sv.LabelAnnotator()

    annotated = box_annotator.annotate(scene=image.copy(), detections=detections)
    annotated = label_annotator.annotate(
        scene=annotated,
        detections=detections,
        labels=labels
    )

    return annotated

# Usage
annotated_image = visualize_florence_detections("image.jpg", "object_detection")
sv.plot_image(annotated_image)
```

---

## 2. PaliGemma Multi-Modal Model

### 2.1 Model Loading

```python
from transformers import AutoProcessor, PaliGemmaForConditionalGeneration
from PIL import Image
import torch

# Load PaliGemma
model_id = "google/paligemma-3b-mix-224"  # or paligemma-3b-mix-448
device = "cuda" if torch.cuda.is_available() else "cpu"

model = PaliGemmaForConditionalGeneration.from_pretrained(
    model_id,
    torch_dtype=torch.bfloat16 if torch.cuda.is_available() else torch.float32,
    device_map="auto"
)

processor = AutoProcessor.from_pretrained(model_id)
```

### 2.2 Multi-Task Prompting

PaliGemma uses natural language prompts:

```python
def run_paligemma(image_path: str, prompt: str, max_new_tokens: int = 100):
    """Run PaliGemma with any prompt"""
    image = Image.open(image_path).convert("RGB")

    inputs = processor(
        text=prompt,
        images=image,
        return_tensors="pt",
        padding="longest"
    ).to(device)

    with torch.inference_mode():
        generated_ids = model.generate(
            **inputs,
            max_new_tokens=max_new_tokens,
            do_sample=False
        )

    # Decode only the generated part (skip input prompt)
    generated_ids = generated_ids[:, inputs['input_ids'].shape[1]:]
    result = processor.batch_decode(generated_ids, skip_special_tokens=True)[0]

    return result.strip()

# Task examples
PALIGEMMA_PROMPTS = {
    "caption": "caption en",
    "detailed_caption": "describe this image in detail",
    "detect": "detect {object}",  # e.g., "detect person ; car"
    "segment": "segment {object}",
    "ocr": "ocr",
    "vqa": "{question}",  # e.g., "What color is the car?"
    "counting": "count {object}",  # e.g., "count people"
}

# Usage examples
caption = run_paligemma("image.jpg", "caption en")
answer = run_paligemma("image.jpg", "What is in this image?")
ocr = run_paligemma("document.jpg", "ocr")
```

### 2.3 Detection Output Parsing

PaliGemma detection format: `<loc0123>` tokens representing normalized coordinates

```python
import re
import numpy as np

def parse_paligemma_detection(text: str, image_size: tuple):
    """Parse PaliGemma detection output to bounding boxes

    Format: <loc####> where #### are 4 digits (0-1023) representing
    normalized coordinates multiplied by 1024
    """
    width, height = image_size

    # Extract location tokens: <loc0123>
    pattern = r'<loc(\d{4})>'
    matches = re.findall(pattern, text)

    boxes = []
    labels = []

    # Extract text between location tokens
    parts = re.split(r'<loc\d{4}>', text)

    # Parse coordinates (groups of 4 tokens = 1 box)
    for i in range(0, len(matches), 4):
        if i + 3 < len(matches):
            y1 = int(matches[i]) / 1024 * height
            x1 = int(matches[i+1]) / 1024 * width
            y2 = int(matches[i+2]) / 1024 * height
            x2 = int(matches[i+3]) / 1024 * width

            boxes.append([x1, y1, x2, y2])

            # Extract label (text after this box's tokens)
            label_idx = (i // 4) + 1
            if label_idx < len(parts):
                label = parts[label_idx].strip(';').strip()
                labels.append(label)

    return {
        'bboxes': np.array(boxes),
        'labels': labels
    }

# Usage
image = Image.open("image.jpg")
detection_text = run_paligemma("image.jpg", "detect person ; car", max_new_tokens=256)
detections = parse_paligemma_detection(detection_text, image.size)

print(f"Detected: {detections['labels']}")
print(f"Boxes: {detections['bboxes']}")
```

### 2.4 Segmentation Output Parsing

```python
def parse_paligemma_segmentation(text: str, image_size: tuple):
    """Parse PaliGemma segmentation output to polygon coordinates"""
    width, height = image_size

    # Segmentation uses <seg###> tokens (0-127)
    pattern = r'<seg(\d{3})>'
    matches = re.findall(pattern, text)

    # Convert to normalized coordinates
    points = []
    for i in range(0, len(matches), 2):
        if i + 1 < len(matches):
            x = int(matches[i]) / 128 * width
            y = int(matches[i+1]) / 128 * height
            points.append([x, y])

    return np.array(points)

# Usage
seg_text = run_paligemma("image.jpg", "segment person", max_new_tokens=512)
polygon = parse_paligemma_segmentation(seg_text, image.size)
```

### 2.5 Fine-Tuning PaliGemma with LoRA

```python
from transformers import TrainingArguments, Trainer
from peft import LoraConfig, get_peft_model
import torch
from torch.utils.data import Dataset

class VQADataset(Dataset):
    """Custom dataset for VQA fine-tuning"""
    def __init__(self, image_paths, questions, answers, processor):
        self.image_paths = image_paths
        self.questions = questions
        self.answers = answers
        self.processor = processor

    def __len__(self):
        return len(self.image_paths)

    def __getitem__(self, idx):
        image = Image.open(self.image_paths[idx]).convert("RGB")
        question = self.questions[idx]
        answer = self.answers[idx]

        # Process inputs
        inputs = self.processor(
            text=question,
            images=image,
            return_tensors="pt",
            padding="max_length",
            truncation=True,
            max_length=512
        )

        # Process labels (answers)
        labels = self.processor.tokenizer(
            answer,
            return_tensors="pt",
            padding="max_length",
            truncation=True,
            max_length=128
        )

        return {
            "input_ids": inputs["input_ids"].squeeze(),
            "attention_mask": inputs["attention_mask"].squeeze(),
            "pixel_values": inputs["pixel_values"].squeeze(),
            "labels": labels["input_ids"].squeeze()
        }

# Configure LoRA
lora_config = LoraConfig(
    r=8,  # LoRA rank
    lora_alpha=16,
    target_modules=["q_proj", "v_proj"],  # Apply LoRA to attention layers
    lora_dropout=0.05,
    bias="none",
    task_type="CAUSAL_LM"
)

# Apply LoRA to model
model = get_peft_model(model, lora_config)
model.print_trainable_parameters()

# Prepare dataset
train_dataset = VQADataset(
    image_paths=train_images,
    questions=train_questions,
    answers=train_answers,
    processor=processor
)

# Training arguments
training_args = TrainingArguments(
    output_dir="./paligemma-finetuned",
    num_train_epochs=3,
    per_device_train_batch_size=4,
    gradient_accumulation_steps=4,
    learning_rate=5e-5,
    warmup_steps=100,
    logging_steps=10,
    save_steps=100,
    evaluation_strategy="steps",
    eval_steps=100,
    save_total_limit=2,
    fp16=True,
    dataloader_num_workers=4,
    remove_unused_columns=False
)

# Trainer
trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=train_dataset,
    data_collator=lambda x: {k: torch.stack([d[k] for d in x]) for k in x[0].keys()}
)

# Train
trainer.train()

# Save LoRA weights
model.save_pretrained("./paligemma-lora-weights")
processor.save_pretrained("./paligemma-lora-weights")
```

### 2.6 Inference with Fine-Tuned Model

```python
from peft import PeftModel

# Load base model
base_model = PaliGemmaForConditionalGeneration.from_pretrained(
    "google/paligemma-3b-mix-224",
    torch_dtype=torch.bfloat16,
    device_map="auto"
)

# Load LoRA weights
model = PeftModel.from_pretrained(base_model, "./paligemma-lora-weights")
model = model.merge_and_unload()  # Merge LoRA weights for faster inference

# Use as normal
result = run_paligemma("image.jpg", "your custom prompt")
```

---

## 3. Qwen2.5-VL (Qwen2-VL)

### 3.1 Model Loading

```python
from transformers import Qwen2VLForConditionalGeneration, AutoProcessor
from qwen_vl_utils import process_vision_info
import torch

# Load Qwen2.5-VL
model_name = "Qwen/Qwen2.5-VL-7B-Instruct"  # or 2B, 72B variants
device = "cuda" if torch.cuda.is_available() else "cpu"

model = Qwen2VLForConditionalGeneration.from_pretrained(
    model_name,
    torch_dtype=torch.bfloat16 if torch.cuda.is_available() else torch.float32,
    device_map="auto"
)

processor = AutoProcessor.from_pretrained(model_name)
```

### 3.2 Multi-Task Prompting

Qwen2.5-VL uses chat format with image/video inputs:

```python
def run_qwen_vl(image_path: str, prompt: str, max_new_tokens: int = 512):
    """Run Qwen2.5-VL with chat-style prompts"""

    messages = [
        {
            "role": "user",
            "content": [
                {"type": "image", "image": image_path},
                {"type": "text", "text": prompt}
            ]
        }
    ]

    # Apply chat template
    text = processor.apply_chat_template(
        messages,
        tokenize=False,
        add_generation_prompt=True
    )

    # Process inputs
    image_inputs, video_inputs = process_vision_info(messages)
    inputs = processor(
        text=[text],
        images=image_inputs,
        videos=video_inputs,
        padding=True,
        return_tensors="pt"
    ).to(device)

    # Generate
    generated_ids = model.generate(
        **inputs,
        max_new_tokens=max_new_tokens,
        do_sample=False
    )

    # Trim input tokens
    generated_ids_trimmed = [
        out_ids[len(in_ids):]
        for in_ids, out_ids in zip(inputs.input_ids, generated_ids)
    ]

    output_text = processor.batch_decode(
        generated_ids_trimmed,
        skip_special_tokens=True,
        clean_up_tokenization_spaces=False
    )[0]

    return output_text

# Task examples
caption = run_qwen_vl("image.jpg", "Describe this image in detail.")
answer = run_qwen_vl("image.jpg", "What objects are in this image?")
ocr = run_qwen_vl("document.jpg", "Extract all text from this image.")
count = run_qwen_vl("image.jpg", "How many people are in this image?")
```

### 3.3 Grounding and Detection

Qwen2.5-VL supports grounding with special tokens:

```python
def run_qwen_grounding(image_path: str, prompt: str):
    """Run Qwen2.5-VL with grounding (returns bounding boxes)"""

    # Grounding prompt format
    grounding_prompt = f"{prompt} Provide bounding boxes in the format <ref>object</ref><box>[[x1,y1,x2,y2]]</box>"

    result = run_qwen_vl(image_path, grounding_prompt, max_new_tokens=1024)
    return result

# Parse grounding output
def parse_qwen_grounding(text: str, image_size: tuple):
    """Parse Qwen2.5-VL grounding output

    Format: <ref>object</ref><box>[[x1,y1,x2,y2]]</box>
    Coordinates are in pixels
    """
    import re

    width, height = image_size

    # Extract ref and box pairs
    pattern = r'<ref>(.*?)</ref><box>\[\[(\d+),(\d+),(\d+),(\d+)\]\]</box>'
    matches = re.findall(pattern, text)

    boxes = []
    labels = []

    for match in matches:
        label, x1, y1, x2, y2 = match
        boxes.append([int(x1), int(y1), int(x2), int(y2)])
        labels.append(label.strip())

    return {
        'bboxes': np.array(boxes),
        'labels': labels
    }

# Usage
from PIL import Image
image = Image.open("image.jpg")
result = run_qwen_grounding("image.jpg", "Detect all objects in this image.")
detections = parse_qwen_grounding(result, image.size)

print(f"Detected: {detections['labels']}")
print(f"Boxes: {detections['bboxes']}")
```

### 3.4 Video Understanding

```python
def run_qwen_video(video_path: str, prompt: str, max_new_tokens: int = 512):
    """Run Qwen2.5-VL on video"""

    messages = [
        {
            "role": "user",
            "content": [
                {"type": "video", "video": video_path, "max_pixels": 360 * 420, "fps": 1.0},
                {"type": "text", "text": prompt}
            ]
        }
    ]

    # Apply chat template
    text = processor.apply_chat_template(
        messages,
        tokenize=False,
        add_generation_prompt=True
    )

    # Process inputs (same as image)
    image_inputs, video_inputs = process_vision_info(messages)
    inputs = processor(
        text=[text],
        images=image_inputs,
        videos=video_inputs,
        padding=True,
        return_tensors="pt"
    ).to(device)

    # Generate
    generated_ids = model.generate(**inputs, max_new_tokens=max_new_tokens)
    generated_ids_trimmed = [
        out_ids[len(in_ids):]
        for in_ids, out_ids in zip(inputs.input_ids, generated_ids)
    ]

    output_text = processor.batch_decode(
        generated_ids_trimmed,
        skip_special_tokens=True,
        clean_up_tokenization_spaces=False
    )[0]

    return output_text

# Usage
description = run_qwen_video("video.mp4", "Describe what happens in this video.")
action = run_qwen_video("video.mp4", "What action is the person performing?")
```

### 3.5 Visualization with Supervision

```python
import supervision as sv
import cv2

def visualize_qwen_detections(image_path: str, prompt: str = "Detect all objects"):
    """Visualize Qwen2.5-VL grounding results"""

    image = cv2.imread(image_path)
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    pil_image = Image.fromarray(image_rgb)

    # Run grounding
    result = run_qwen_grounding(image_path, prompt)
    detections_data = parse_qwen_grounding(result, pil_image.size)

    # Convert to supervision Detections
    detections = sv.Detections(
        xyxy=detections_data['bboxes'],
        class_id=np.arange(len(detections_data['labels']))
    )

    # Annotate
    box_annotator = sv.BoxAnnotator()
    label_annotator = sv.LabelAnnotator()

    annotated = box_annotator.annotate(scene=image.copy(), detections=detections)
    annotated = label_annotator.annotate(
        scene=annotated,
        detections=detections,
        labels=detections_data['labels']
    )

    return annotated

# Usage
annotated_image = visualize_qwen_detections("image.jpg", "Detect all people and cars")
sv.plot_image(annotated_image)
```

---

## 4. Unified VLM Interface

Create a unified interface for all three models:

```python
from enum import Enum
from typing import Dict, List, Tuple
import numpy as np

class VLMModel(Enum):
    FLORENCE2 = "florence2"
    PALIGEMMA = "paligemma"
    QWEN2VL = "qwen2vl"

class UnifiedVLM:
    """Unified interface for Florence-2, PaliGemma, and Qwen2.5-VL"""

    def __init__(self, model_type: VLMModel):
        self.model_type = model_type
        # Initialize appropriate model based on type
        # (model loading code here)

    def caption(self, image_path: str, detailed: bool = False) -> str:
        """Generate image caption"""
        if self.model_type == VLMModel.FLORENCE2:
            task = "detailed_caption" if detailed else "caption"
            result = run_florence_task(image_path, task)
            return result[TASKS[task]]

        elif self.model_type == VLMModel.PALIGEMMA:
            prompt = "describe this image in detail" if detailed else "caption en"
            return run_paligemma(image_path, prompt)

        elif self.model_type == VLMModel.QWEN2VL:
            prompt = "Describe this image in detail." if detailed else "Caption this image."
            return run_qwen_vl(image_path, prompt)

    def detect(self, image_path: str, classes: List[str] = None) -> Dict[str, np.ndarray]:
        """Detect objects in image"""
        if self.model_type == VLMModel.FLORENCE2:
            if classes:
                task = "open_vocabulary_detection"
                result = run_florence_task(image_path, task, ".".join(classes))
            else:
                result = run_florence_task(image_path, "object_detection")
            return result[list(result.keys())[0]]

        elif self.model_type == VLMModel.PALIGEMMA:
            if classes:
                prompt = f"detect {' ; '.join(classes)}"
            else:
                prompt = "detect objects"

            image = Image.open(image_path)
            result_text = run_paligemma(image_path, prompt, max_new_tokens=256)
            return parse_paligemma_detection(result_text, image.size)

        elif self.model_type == VLMModel.QWEN2VL:
            if classes:
                prompt = f"Detect {', '.join(classes)} in this image."
            else:
                prompt = "Detect all objects in this image."

            image = Image.open(image_path)
            result = run_qwen_grounding(image_path, prompt)
            return parse_qwen_grounding(result, image.size)

    def ocr(self, image_path: str, with_regions: bool = True) -> Dict:
        """Extract text from image"""
        if self.model_type == VLMModel.FLORENCE2:
            task = "ocr_with_region" if with_regions else "ocr"
            result = run_florence_task(image_path, task)
            return result[TASKS[task]]

        elif self.model_type == VLMModel.PALIGEMMA:
            result = run_paligemma(image_path, "ocr", max_new_tokens=512)
            return {"text": result}

        elif self.model_type == VLMModel.QWEN2VL:
            result = run_qwen_vl(image_path, "Extract all text from this image.", max_new_tokens=512)
            return {"text": result}

    def vqa(self, image_path: str, question: str) -> str:
        """Visual Question Answering"""
        if self.model_type == VLMModel.FLORENCE2:
            # Florence-2 doesn't have native VQA, use caption
            caption = self.caption(image_path, detailed=True)
            return f"Based on image: {caption}"

        elif self.model_type == VLMModel.PALIGEMMA:
            return run_paligemma(image_path, question)

        elif self.model_type == VLMModel.QWEN2VL:
            return run_qwen_vl(image_path, question)

# Usage
vlm = UnifiedVLM(VLMModel.QWEN2VL)

# All models now have same interface
caption = vlm.caption("image.jpg", detailed=True)
detections = vlm.detect("image.jpg", classes=["person", "car"])
ocr_result = vlm.ocr("document.jpg")
answer = vlm.vqa("image.jpg", "What color is the car?")
```

---

## 5. Comparison and Best Practices

### Model Comparison

| Model | Strengths | Best For | Speed | Memory |
|-------|-----------|----------|-------|--------|
| **Florence-2** | Fast, multi-task, structured output | Production pipelines, specific tasks | ⚡⚡⚡ | Low |
| **PaliGemma** | Fine-tunable, good grounding | Custom domains, fine-tuning | ⚡⚡ | Medium |
| **Qwen2.5-VL** | Best reasoning, video support | Complex VQA, detailed analysis | ⚡ | High |

### Task Recommendations

| Task | Best Model | Why |
|------|------------|-----|
| Object Detection | Florence-2 | Fastest, structured output |
| OCR | Florence-2 or Qwen2.5-VL | Florence for speed, Qwen for accuracy |
| Image Captioning | Qwen2.5-VL | Most detailed and natural |
| Phrase Grounding | Florence-2 | Built-in task, fast |
| Visual QA | Qwen2.5-VL | Superior reasoning |
| Video Understanding | Qwen2.5-VL | Only model with native video support |
| Custom Domain | PaliGemma | Easy to fine-tune with LoRA |
| Production/Real-time | Florence-2 | Fastest inference |

### Memory Optimization

```python
# Use 4-bit quantization for memory-constrained environments
from transformers import BitsAndBytesConfig

quantization_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
    bnb_4bit_quant_type="nf4"
)

model = AutoModelForCausalLM.from_pretrained(
    model_name,
    quantization_config=quantization_config,
    device_map="auto"
)
```

### Batch Processing

```python
def batch_process_images(image_paths: List[str], model_type: VLMModel, task: str):
    """Process multiple images efficiently"""
    vlm = UnifiedVLM(model_type)
    results = []

    # Use batching for supported models
    batch_size = 8 if model_type == VLMModel.FLORENCE2 else 4

    for i in range(0, len(image_paths), batch_size):
        batch = image_paths[i:i+batch_size]
        batch_results = [vlm.caption(path) for path in batch]
        results.extend(batch_results)

    return results
```

---

## 6. Advanced Use Cases

### Multi-Model Ensemble

```python
def ensemble_detection(image_path: str, classes: List[str] = None):
    """Use multiple models for more robust detection"""

    florence = UnifiedVLM(VLMModel.FLORENCE2)
    qwen = UnifiedVLM(VLMModel.QWEN2VL)

    # Get detections from both models
    florence_det = florence.detect(image_path, classes)
    qwen_det = qwen.detect(image_path, classes)

    # Combine with NMS
    all_boxes = np.vstack([florence_det['bboxes'], qwen_det['bboxes']])
    all_labels = florence_det['labels'] + qwen_det['labels']

    # Apply Non-Maximum Suppression
    detections = sv.Detections(xyxy=all_boxes)
    detections = detections.with_nms(threshold=0.5)

    return detections
```

### Visual Chain-of-Thought

```python
def visual_reasoning(image_path: str, question: str):
    """Use VLM for step-by-step visual reasoning"""
    vlm = UnifiedVLM(VLMModel.QWEN2VL)

    # Step 1: Get detailed description
    description = vlm.caption(image_path, detailed=True)

    # Step 2: Detect relevant objects
    prompt = f"Based on the question '{question}', what objects should we focus on?"
    focus_objects = vlm.vqa(image_path, prompt)

    # Step 3: Final answer with context
    final_prompt = f"""
    Image description: {description}
    Focus areas: {focus_objects}
    Question: {question}

    Provide a detailed answer:
    """
    answer = vlm.vqa(image_path, final_prompt)

    return {
        "description": description,
        "focus": focus_objects,
        "answer": answer
    }
```

---

**End of VLM Templates**
