---
name: translate-web-article
description: Convert web pages to Korean markdown documents. Fetches page via firecrawl, translates text to Korean, analyzes images with VLM for Korean captions, preserves code/tables with explanations. Use for tech blogs, papers, documentation. Triggers on "translate web page", "blog to Korean", "translate this article".
---

# Web Article Translator

Converts web pages to Korean markdown while analyzing images with VLM to generate context-aware Korean captions.

## Workflow

```
URL Input
    |
    +-- Fetch page via firecrawl (markdown + links)
    |
    +-- Ask user options via AskUserQuestion
    |   +-- Output directory
    |   +-- Download images locally or not
    |
    +-- Process content
    |   +-- Text: Translate to Korean (keep tech terms)
    |   +-- Images: Download -> VLM analysis -> Korean caption
    |   +-- Code/Tables: Keep original + add explanation
    |
    +-- Generate markdown file
```

## Step 1: Fetch Web Page

Use firecrawl MCP:

```
mcp__firecrawl__firecrawl_scrape
- url: target URL
- formats: ["markdown", "links"]
- onlyMainContent: true
```

Return error for inaccessible pages:
- Login required
- Paywall content
- Blocked sites

## Step 2: User Options

Use AskUserQuestion to confirm:

1. **Output directory**: Where to save translated markdown
2. **Download images**: Save locally or keep URL references

## Step 3: Translation Rules

### General Text

Translate to natural Korean.

### Technical Terms

Keep original English. See `references/tech-terms.md`.

```
Transformer, Fine-tuning, API, GPU, CUDA, Tokenizer,
Embedding, Attention, Backbone, Checkpoint, Epoch,
Batch Size, Learning Rate, Loss, Gradient, Weight...
```

### Code Blocks

Keep original + add Korean explanation below:

````markdown
```python
def train(model, data):
    optimizer.zero_grad()
    loss = model(data)
    loss.backward()
    optimizer.step()
```
> 이 코드는 모델 학습의 한 스텝을 수행합니다. gradient 초기화, forward pass, backward pass, weight 업데이트 순으로 진행됩니다.
````

### Tables

Keep original + add Korean explanation below:

```markdown
| Model | Params | Score |
|-------|--------|-------|
| BERT  | 110M   | 89.3  |
| GPT-2 | 1.5B   | 91.2  |

> 이 테이블은 모델별 파라미터 수와 성능 점수를 비교합니다.
```

### Links

Keep URL, translate link text only:

```markdown
자세한 내용은 [공식 문서](https://example.com/docs)를 참고하세요.
```

## Step 4: Image Processing

### Process Flow

1. Extract image URLs from markdown
2. Download to `/tmp` (use scripts/download_image.sh)
3. Analyze with Read tool (VLM auto-applied)
4. Generate Korean caption considering surrounding context
5. Add VLM analysis as blockquote below image (alt text is hidden in preview)

### Caption Guidelines

- Around 2 sentences
- Describe image meaning and role
- Reflect surrounding context
- Use blockquote format for visibility in markdown preview

Example:
```markdown
![Transformer 아키텍처](image_url)
*원문 캡션*

> Transformer 아키텍처의 전체 구조를 보여주는 다이어그램입니다. Encoder와 Decoder가 병렬로 배치되어 있으며, Multi-Head Attention 레이어가 핵심 구성요소입니다.
```

### Error Handling

When image load fails:

```markdown
![이미지 로드 실패](original_url)
> [경고] 이미지를 불러올 수 없습니다: {error_message}
```

Show warning and continue translation.

## Step 5: Output Generation

### File Structure

```
{output_dir}/
├── {article_name}.md          # Translated markdown
└── images/                    # Downloaded images (if selected)
    ├── image_001.png
    └── image_002.png
```

### Markdown Header

```markdown
# 번역된 제목

원문: {original_url}
번역일: {YYYY-MM-DD}

---

(Body starts here)
```

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Image URL inaccessible | Show warning, keep original URL, continue |
| Login/Paywall | Return error, stop processing |
| Document > 10,000 chars | Chunk by sections, process sequentially |
| No images | Translate text only |
| Non-English source | Translate from that language to Korean |

## Scripts

### download_image.sh

Downloads image URL to /tmp:

```bash
scripts/download_image.sh "https://example.com/image.png"
# Output: /tmp/img_<hash>.png
```

## References

- `references/tech-terms.md` - Technical terms to keep in English

## Limitations

- Cannot process PDF directly
- Cannot process video content
- Dynamic JS-rendered content (if firecrawl fails)
