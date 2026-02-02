# ImagineAPI MCP Integration Guide

Guide for using the Midjourney Proxy MCP server to generate images via ImagineAPI.

## Table of Contents

- [Available MCP Tools](#available-mcp-tools)
- [Available MCP Resources](#available-mcp-resources)
- [Typical Workflow](#typical-workflow)
- [Prompt Format](#prompt-format)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)
- [Integration with Prompt Optimization](#integration-with-prompt-optimization)

---

## Available MCP Tools

These tools are available when the midjourney-proxy-mcp MCP server is connected. Call them directly as MCP tools.

### midjourney_imagine

Generate images from a prompt.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `prompt` | string | Yes | The image generation prompt with Midjourney parameters |
| `ref` | string | No | Optional reference ID for tracking |

Response includes:
- `id`: Generation ID for status tracking
- `status`: Current status (pending, in-progress, completed, failed)
- `prompt`: The submitted prompt
- `created_at`: Timestamp

### midjourney_get_status

Check generation status and retrieve results.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `image_id` | string | Yes | Generation ID from midjourney_imagine response |

Response includes:
- `status`: Current status
- `url`: Generated image URL (when completed)
- `upscaled_urls`: Array of upscaled image URLs (when available)
- `progress`: Progress percentage (when in-progress)

### midjourney_list_images

List recent image generations.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `limit` | integer | No | Number of results (default: 10, max: 100) |
| `status` | string | No | Filter by status (pending, in-progress, completed, failed) |

---

## Available MCP Resources

### midjourney://generations

List all generations.

```
Read resource: midjourney://generations
```

### midjourney://generations/{status}

Filter generations by status.

```
Read resource: midjourney://generations/completed
Read resource: midjourney://generations/pending
Read resource: midjourney://generations/failed
```

### midjourney://generation/{id}

Get single generation details.

```
Read resource: midjourney://generation/abc123-def456
```

### midjourney://stats

Generation statistics.

```
Read resource: midjourney://stats
```

---

## Typical Workflow

### 1. Generate Image

Call `midjourney_imagine` with your optimized prompt:
- Include all Midjourney parameters in the prompt string
- Save the returned `id` for status checking

### 2. Check Status

Call `midjourney_get_status` with the image ID:
- Poll every 10-15 seconds
- Status progression: `pending` -> `in-progress` -> `completed`

### 3. Retrieve Results

When status is `completed`:
- `url`: Main generated image (grid of 4)
- `upscaled_urls`: Higher resolution versions (automatically generated)

---

## Prompt Format

The prompt string should include all Midjourney parameters:

```
[description] [parameters]
```

Examples:

```
"cinematic portrait of a samurai warrior --ar 16:9 --s 250 --q 2"

"minimalist product photography of headphones --ar 1:1 --s 100 --no background"

"fantasy landscape with floating islands --ar 21:9 --s 500 --w 100"
```

Parameters are appended directly to the prompt text, exactly as they would be used in Midjourney Discord.

---

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `invalid_prompt` | Blocked content or invalid syntax | Revise prompt content |
| `rate_limited` | Too many requests | Wait and retry |
| `timeout` | Generation took too long | Retry or simplify prompt |
| `failed` | Generation failed | Check prompt and retry |

### Retry Strategy

1. Call `midjourney_imagine`
2. Poll `midjourney_get_status` every 10-15 seconds
3. If failed, analyze error and retry with adjusted prompt
4. Maximum 3 retries before reporting failure

---

## Best Practices

1. Always include essential parameters (--ar at minimum)
2. Check status before reporting results to user
3. Provide upscaled_urls when available (higher quality)
4. Handle failures gracefully with retry logic
5. Store generation IDs for later reference
6. Use `midjourney_list_images` to check recent generations and avoid duplicates

---

## Integration with Prompt Optimization

When using this skill:

1. Transform user request into optimized prompt (see midjourney-style-guide.md)
2. Add appropriate parameters (see midjourney-parameters.md)
3. Call `midjourney_imagine` with the complete prompt string
4. Monitor status with `midjourney_get_status` and return results

Example flow:
```
User: "photo of a cat"

1. Optimize prompt:
   "professional photography of a tabby cat with green eyes,
    soft natural window light, shallow depth of field,
    warm color grading --ar 4:5 --s 150 --q 2"

2. Call midjourney_imagine with optimized prompt

3. Poll midjourney_get_status until completed

4. Return image URL and upscaled versions to user
```
