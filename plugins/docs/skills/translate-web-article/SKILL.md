---
name: translate-web-article
description: Convert web pages to Korean markdown documents. Fetches page via Bright Data, translates text to Korean, analyzes images with VLM for Korean captions, preserves code/tables with explanations. Use for tech blogs, papers, documentation. Triggers on "translate web page", "blog to Korean", "translate this article".
---

# Web Article Translator

Convert a web page into one Korean markdown file in 6 steps: fetch, ask 2 options, translate, caption images with the VLM, write, and pass a 2-count structure gate (image refs and section headings) before declaring it done.

Ask with `AskUserQuestion` on Claude Code or `request_user_input` on Codex; when neither is available, proceed with the safe default (save to the current directory, keep image URLs as references) and say so.

## Step 1: Fetch the page

Use the Bright Data MCP tool `mcp__brightdata__scrape_as_markdown` with `url` and the default `format` (markdown). Current servers return JSON (`url`, `title`, `format`, `content`); older ones take only `url` and return the markdown itself, so read `content` when the result is JSON and the text as-is otherwise. When the JSON has a `note` saying the content was truncated, or a `format` other than markdown, tell the user and stop before translating. Either way it is the whole page with no main-content switch, so strip site chrome (nav, footer, share widgets) while translating and read links off the inline markdown (`[text](url)`, `![alt](src)`).

- **Fallback**: without the MCP tools, run `bdata scrape <url> -f markdown` in the terminal.
- **Neither works**: check four gates in order (Bright Data MCP tools present, `bdata` installed, `bdata` authenticated, a default zone set; confirm the commands with `bdata --help`), report the first that failed, and stop. Do not substitute a plain built-in fetch, which the blocked pages this skill targets will defeat.
- **Inaccessible page** (login required, paywall, blocked site): return the error and stop.

## Step 2: User options

Confirm with the question tool:

1. **Output directory**: where to save the translated markdown.
2. **Download images**: save locally, or keep URL references.

## Step 3: Translation rules

- **Text**: natural Korean.
- **Technical terms**: keep the original English (Transformer, Fine-tuning, API, GPU, Tokenizer, Checkpoint, Learning Rate and so on); the full list is in `references/tech-terms.md`.
- **Code blocks and tables**: keep the original and add a one-line Korean explanation below as a blockquote.
- **Links**: keep the URL, translate only the link text.

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

## Step 4: Image processing

1. Extract image URLs from the markdown.
2. Download each to `/tmp` with `scripts/download_image.sh -`, passing the URL on stdin through a quoted heredoc (`<<'URL'`), never inside the command text where `$()` or backticks would run (prints `/tmp/img_<hash>.<ext>`).
3. Read the file with the Read tool (the VLM applies automatically).
4. Write a Korean caption of about 2 sentences on the image's meaning and role in its surrounding context, as a blockquote below the image, since alt text is hidden in preview.

```markdown
![Transformer 아키텍처](image_url)
*원문 캡션*

> Transformer 아키텍처의 전체 구조를 보여주는 다이어그램입니다. Encoder와 Decoder가 병렬로 배치되어 있으며, Multi-Head Attention 레이어가 핵심 구성요소입니다.
```

When an image fails to load, keep the original URL, write `![이미지 로드 실패](original_url)` with `> [경고] 이미지를 불러올 수 없습니다: {error_message}` below it, and continue.

## Step 5: Output

Write `{output_dir}/{article_name}.md`, plus `{output_dir}/images/image_001.png` and onward when images are downloaded. The file opens with this header:

```markdown
# 번역된 제목

원문: {original_url}
번역일: {YYYY-MM-DD}

---
```

## Step 6: Final checklist gate (MANDATORY)

A long translation can silently drop a section or an image, so diff the source against the output on two deterministic counts and act on the result.

- **Source file**: save as the source temp file the main-content markdown you set out to translate, with the site chrome already stripped, not the raw whole-page dump; nav headings and widget images would otherwise fail the gate against a correct translation.
- **Image-ref count** must match exactly: fewer means a dropped image, more a hallucinated one. Rewriting a URL to a local `images/` path keeps the count.
- **Section-heading count** must match, after stripping the output's own header block (title, `원문`, `번역일`, through the first `---`).

```bash
SRC="/tmp/source-article.md"          # main-content markdown from Step 1 (chrome already stripped)
OUT="{output_dir}/{article_name}.md"  # the generated translation
s_img=$(grep -oE '!\[[^]]*\]\([^)]*\)' "$SRC" | wc -l | tr -d ' ')
o_img=$(grep -oE '!\[[^]]*\]\([^)]*\)' "$OUT" | wc -l | tr -d ' ')
s_head=$(grep -cE '^#{1,6}[[:space:]]' "$SRC")
# strip the output's translator header block (through the first '---') so its
# added title does not inflate the count; compare the body against the source.
if grep -qE '^---[[:space:]]*$' "$OUT"; then
  o_head=$(awk 'f{print} /^---[[:space:]]*$/{f=1}' "$OUT" | grep -cE '^#{1,6}[[:space:]]')
else
  o_head=$(grep -cE '^#{1,6}[[:space:]]' "$OUT")
fi
fail=0
echo "images: source=$s_img output=$o_img | body headings: source=$s_head output=$o_head"
[ "$s_img" != "$o_img" ] && { echo "FAIL — image-ref count mismatch (dropped or hallucinated image)"; fail=1; }
[ "$s_head" != "$o_head" ] && { echo "FAIL — section-heading count differs (a section was dropped or invented)"; fail=1; }
[ "$fail" -eq 0 ] && echo "PASS — image + section structure preserved"
exit $fail
```

On any FAIL, re-translate the missing section or restore the dropped image and re-run until it prints `PASS` (exit 0). A legitimately merged or split heading is the one case to override, and only by stating it; never skip the gate.

## Edge cases and limits

| Scenario | Handling |
|----------|----------|
| Image URL inaccessible | Show warning, keep original URL, continue |
| Login/Paywall | Return error, stop processing |
| Document > 10,000 chars | Chunk by sections, process sequentially |
| No images | Translate text only |
| Non-English source | Translate from that language to Korean |
| PDF or video | Not supported |
| Dynamic JS-rendered page | Not rendered: `scrape_as_markdown` runs no JavaScript, so report the content that did not load |
