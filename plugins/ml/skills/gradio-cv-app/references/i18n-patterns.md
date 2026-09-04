# Internationalization (i18n) Patterns

Simple dictionary-based internationalization for Gradio CV applications. Supports Korean and English.

## Basic Pattern

### Label Dictionary

```python
LABELS = {
    "en": {
        "title": "Image Classification",
        "upload": "Upload Image",
        "result": "Result",
        "run": "Run",
        "clear": "Clear",
        "loading": "Processing...",
        "error": "An error occurred",
    },
    "ko": {
        "title": "이미지 분류",
        "upload": "이미지 업로드",
        "result": "결과",
        "run": "실행",
        "clear": "초기화",
        "loading": "처리 중...",
        "error": "오류가 발생했습니다",
    },
}

def L(key: str, lang: str = "en") -> str:
    """Get localized label"""
    return LABELS.get(lang, LABELS["en"]).get(key, key)
```

### Usage in Gradio

```python
import gradio as gr

lang = "ko"  # or "en"

with gr.Blocks() as demo:
    gr.Markdown(f"# {L('title', lang)}")
    image = gr.Image(label=L("upload", lang), type="pil")
    output = gr.Label(label=L("result", lang))
    btn = gr.Button(L("run", lang), variant="primary")
```

---

## Common UI Labels

### General

| Key | English | Korean |
|-----|---------|--------|
| `run` | Run | 실행 |
| `submit` | Submit | 제출 |
| `clear` | Clear | 초기화 |
| `reset` | Reset | 리셋 |
| `cancel` | Cancel | 취소 |
| `loading` | Loading... | 로딩 중... |
| `processing` | Processing... | 처리 중... |
| `done` | Done | 완료 |
| `error` | Error | 오류 |
| `success` | Success | 성공 |

### Image Components

| Key | English | Korean |
|-----|---------|--------|
| `upload_image` | Upload Image | 이미지 업로드 |
| `input_image` | Input Image | 입력 이미지 |
| `output_image` | Output Image | 출력 이미지 |
| `result` | Result | 결과 |
| `original` | Original | 원본 |
| `preview` | Preview | 미리보기 |

### Settings

| Key | English | Korean |
|-----|---------|--------|
| `settings` | Settings | 설정 |
| `advanced` | Advanced Options | 고급 옵션 |
| `language` | Language | 언어 |
| `theme` | Theme | 테마 |
| `dark_mode` | Dark Mode | 다크 모드 |
| `light_mode` | Light Mode | 라이트 모드 |

### Model Parameters

| Key | English | Korean |
|-----|---------|--------|
| `model` | Model | 모델 |
| `temperature` | Temperature | 온도 |
| `max_tokens` | Max Tokens | 최대 토큰 |
| `threshold` | Threshold | 임계값 |
| `steps` | Steps | 스텝 |
| `guidance` | Guidance Scale | 가이던스 스케일 |
| `seed` | Seed | 시드 |
| `random_seed` | Random Seed | 랜덤 시드 |

---

## Task-Specific Labels

### OCR/VLM

```python
OCR_LABELS = {
    "en": {
        "title": "Document OCR",
        "upload": "Upload Document",
        "prompt": "Enter prompt",
        "prompt_placeholder": "Extract text from this image...",
        "result": "Extracted Text",
        "tab_image": "Image",
        "tab_video": "Video",
        "tab_pdf": "PDF",
    },
    "ko": {
        "title": "문서 OCR",
        "upload": "문서 업로드",
        "prompt": "프롬프트 입력",
        "prompt_placeholder": "이 이미지에서 텍스트를 추출하세요...",
        "result": "추출된 텍스트",
        "tab_image": "이미지",
        "tab_video": "비디오",
        "tab_pdf": "PDF",
    },
}
```

### Image Classification

```python
CLASSIFY_LABELS = {
    "en": {
        "title": "Image Classification",
        "upload": "Upload Image",
        "result": "Classification Result",
        "confidence": "Confidence",
        "top_classes": "Top Classes",
    },
    "ko": {
        "title": "이미지 분류",
        "upload": "이미지 업로드",
        "result": "분류 결과",
        "confidence": "신뢰도",
        "top_classes": "상위 클래스",
    },
}
```

### Image Generation

```python
GENERATE_LABELS = {
    "en": {
        "title": "Image Generation",
        "prompt": "Prompt",
        "prompt_placeholder": "Describe the image you want to create...",
        "negative": "Negative Prompt",
        "style": "Style",
        "generate": "Generate",
        "result": "Generated Image",
        "used_seed": "Used Seed",
    },
    "ko": {
        "title": "이미지 생성",
        "prompt": "프롬프트",
        "prompt_placeholder": "생성하고 싶은 이미지를 설명하세요...",
        "negative": "네거티브 프롬프트",
        "style": "스타일",
        "generate": "생성",
        "result": "생성된 이미지",
        "used_seed": "사용된 시드",
    },
}
```

### Segmentation

```python
SEGMENT_LABELS = {
    "en": {
        "title": "Image Segmentation",
        "input": "Input Image",
        "output": "Segmentation Result",
        "target": "Segmentation Target",
        "target_placeholder": "e.g., person, car, dog",
        "threshold": "Confidence Threshold",
    },
    "ko": {
        "title": "이미지 세그멘테이션",
        "input": "입력 이미지",
        "output": "세그멘테이션 결과",
        "target": "세그멘테이션 대상",
        "target_placeholder": "예: 사람, 자동차, 개",
        "threshold": "신뢰도 임계값",
    },
}
```

### Detection

```python
DETECT_LABELS = {
    "en": {
        "title": "Deepfake Detection",
        "upload": "Upload Image",
        "result": "Detection Result",
        "real": "Real",
        "fake": "Fake",
        "ai_generated": "AI Generated",
        "authentic": "Authentic",
    },
    "ko": {
        "title": "딥페이크 탐지",
        "upload": "이미지 업로드",
        "result": "탐지 결과",
        "real": "진짜",
        "fake": "가짜",
        "ai_generated": "AI 생성",
        "authentic": "원본",
    },
}
```

---

## Language Selector Component

### Dropdown Style

```python
import gradio as gr

LANGUAGES = {
    "en": "English",
    "ko": "한국어",
}

def create_language_selector():
    return gr.Dropdown(
        choices=list(LANGUAGES.values()),
        value="English",
        label="Language",
        elem_id="lang-selector",
        scale=0,
        min_width=120,
    )

# Usage
with gr.Blocks() as demo:
    with gr.Row():
        gr.Markdown("# App Title")
        lang_selector = create_language_selector()
```

### Radio Style (Compact)

```python
def create_language_radio():
    return gr.Radio(
        choices=["EN", "KO"],
        value="EN",
        label="",
        elem_id="lang-selector",
        scale=0,
    )
```

---

## Dynamic Language Switching

Gradio doesn't support dynamic label changes without page reload. Use one of these approaches:

### Approach 1: Query Parameter (Recommended)

```python
# User accesses: ?lang=ko or ?lang=en
# Parse in app initialization

import gradio as gr
from urllib.parse import parse_qs

def get_lang_from_request(request: gr.Request) -> str:
    if request and request.query_params:
        return request.query_params.get("lang", "en")
    return "en"

# In interface function
def process(image, request: gr.Request):
    lang = get_lang_from_request(request)
    # Use lang for error messages, etc.
    ...
```

### Approach 2: JavaScript-Based Text Replacement

```python
# For simple label changes without state
LANG_SWITCH_JS = """
(lang) => {
    const labels = {
        'run': { en: 'Run', ko: '실행' },
        'clear': { en: 'Clear', ko: '초기화' },
    };

    document.querySelectorAll('[data-i18n]').forEach(el => {
        const key = el.dataset.i18n;
        if (labels[key]) {
            el.textContent = labels[key][lang];
        }
    });
}
"""
```

### Approach 3: Separate App Instances

```python
# Create language-specific launchers
def create_app(lang: str):
    L = LABELS[lang]

    with gr.Blocks() as demo:
        gr.Markdown(f"# {L['title']}")
        # ... rest of UI with L[key]

    return demo

# app_en.py
demo = create_app("en")

# app_ko.py
demo = create_app("ko")
```

---

## Complete Example

```python
import gradio as gr
from gradio.themes import Soft
from gradio.themes.utils import colors, fonts


# === Labels ===
LABELS = {
    "en": {
        "title": "Image Classifier",
        "upload": "Upload Image",
        "result": "Classification Result",
        "run": "Classify",
        "clear": "Clear",
    },
    "ko": {
        "title": "이미지 분류기",
        "upload": "이미지 업로드",
        "result": "분류 결과",
        "run": "분류",
        "clear": "초기화",
    },
}


def create_app(lang: str = "en"):
    L = LABELS[lang]

    def classify(image):
        if image is None:
            return None
        # Classification logic here
        return {"Cat": 0.9, "Dog": 0.1}

    with gr.Blocks() as demo:
        gr.Markdown(f"# {L['title']}")

        with gr.Row():
            input_img = gr.Image(label=L["upload"], type="pil")
            output = gr.Label(label=L["result"])

        with gr.Row():
            clear_btn = gr.Button(L["clear"], variant="secondary")
            run_btn = gr.Button(L["run"], variant="primary")

        run_btn.click(fn=classify, inputs=input_img, outputs=output)
        clear_btn.click(fn=lambda: (None, None), outputs=[input_img, output])

    return demo


# Default: English
demo = create_app("en")

# For Korean version, deploy separately or use query param
# demo = create_app("ko")

if __name__ == "__main__":
    demo.launch()
```

---

## Best Practices

1. **Keep labels in constants**: Define all labels at the top of the file
2. **Use consistent keys**: Use snake_case for label keys
3. **Fallback to English**: Always provide English as fallback
4. **Separate content from code**: Consider external JSON files for larger apps
5. **Test both languages**: Ensure UI looks good in both languages (Korean text is often shorter)
