# Midjourney Plugin

Optimized Midjourney V7 prompt generation and image creation.

## Skill

| Skill | Description |
|-------|-------------|
| `midjourney-imagineapi` | Transform requests into professional MJ prompts |

## Features

- 5-layer prompt structure optimization
- Style/mood/format clarification via AskUserQuestion
- Multiple prompt variations
- Direct image generation via MCP

## Triggers

- "generate image"
- "create photo"
- "Midjourney"
- "make picture"

## Workflow

1. Analyze user request
2. Clarify style/mood/format if vague
3. Build optimized prompt (5-layer structure)
4. Present 2-3 variations
5. Generate via midjourney MCP
6. Return results with upscaled versions

## Prompt Structure

```
Layer 1: Subject & Composition
Layer 2: Style & Aesthetic
Layer 3: Lighting & Environment
Layer 4: Technical Details (camera, lens)
Layer 5: Artistic Reference (optional)
```

## Common Parameters

| Purpose | Parameters |
|---------|------------|
| Quick test | `--draft` |
| High quality | `--ar 16:9 --s 150 --q 2` |
| Artistic | `--s 400 --exp 25` |
| Character lock | `--oref <url> --ow 200` |

## Requirements

- midjourney MCP server configured
