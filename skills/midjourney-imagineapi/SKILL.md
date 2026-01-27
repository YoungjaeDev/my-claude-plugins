---
name: midjourney-imagineapi
description: Generate optimized Midjourney V7 prompts and create images via ImagineAPI MCP server. Transform basic user requests into professional, cinematic prompts using 5-layer structure. Use when users request (1) Midjourney image generation, (2) prompt optimization for V7, (3) character/style reference usage, (4) professional photography prompts. Trigger phrases include "generate image", "create photo", "Midjourney", "make picture", "image generation".
---

# Midjourney Prompt Optimizer for ImagineAPI

Transform user image requests into optimized Midjourney V7 prompts and generate images through ImagineAPI MCP.

## Workflow Overview

```
User Request -> Clarify (if needed) -> Build Prompt -> Present Options -> Generate Image -> Return Results
```

## Step 1: Analyze User Request

Determine what the user wants:
- Main subject and concept
- Implied style or mood
- Any specific requirements mentioned

If the request is clear and specific, proceed to Step 3.
If the request is vague or generic (e.g., "make me a cat picture"), proceed to Step 2.

## Step 2: Clarify with User (When Needed)

For vague requests, use AskUserQuestion to clarify:

**Style Clarification:**
```
AskUserQuestion:
  header: "Style"
  question: "What style do you want for this image?"
  options:
    - label: "Photorealistic"
      description: "Looks like a real photograph"
    - label: "Cinematic"
      description: "Movie-like, dramatic lighting"
    - label: "Artistic/Illustration"
      description: "Stylized, artistic interpretation"
    - label: "Minimal/Clean"
      description: "Simple, clean aesthetic"
```

**Mood Clarification:**
```
AskUserQuestion:
  header: "Mood"
  question: "What mood or atmosphere?"
  options:
    - label: "Bright & Cheerful"
      description: "Warm, optimistic feeling"
    - label: "Moody & Dramatic"
      description: "Dark, atmospheric, cinematic"
    - label: "Calm & Serene"
      description: "Peaceful, tranquil"
    - label: "Energetic & Dynamic"
      description: "Action, movement, excitement"
```

**Aspect Ratio:**
```
AskUserQuestion:
  header: "Format"
  question: "What format do you need?"
  options:
    - label: "Widescreen (16:9)"
      description: "Cinematic, landscape, desktop"
    - label: "Portrait (4:5)"
      description: "Vertical, mobile, Instagram"
    - label: "Square (1:1)"
      description: "Social media, profile"
    - label: "Ultra-wide (21:9)"
      description: "Panoramic, banner"
```

## Step 3: Build Optimized Prompt

Use the 5-layer structure from `references/midjourney-style-guide.md`:

**Layer 1 (Required):** Subject & Composition
```
[Subject] [action/pose], [composition]
```

**Layer 2 (Required):** Style & Aesthetic
```
[style], [mood], [color treatment]
```

**Layer 3 (Recommended):** Lighting & Environment
```
[lighting], [time of day], [atmosphere]
```

**Layer 4 (Recommended):** Technical Details
```
[camera] [lens] [aperture], [depth of field], [quality terms]
```

**Layer 5 (Optional):** Artistic Reference
```
[artist/style reference]
```

Consult `references/prompt-examples.md` for transformation patterns.

## Step 4: Select Parameters

Based on the image type, select appropriate parameters from `references/midjourney-parameters.md`:

**Portrait:**
```
--ar 4:5 --s 100-150 --q 2
```

**Landscape/Cinematic:**
```
--ar 16:9 --s 150-250 --q 2
```

**Product:**
```
--ar 1:1 --s 50-100
```

**Artistic:**
```
--ar varies --s 300-500 --exp 10-25
```

**Quick Iteration:**
```
--draft --c 25-50
```

## Step 5: Present Options to User

Before generating, present 2-3 prompt variations using AskUserQuestion:

```
AskUserQuestion:
  header: "Prompt"
  question: "Which prompt direction do you prefer?"
  options:
    - label: "Option A: Dramatic"
      description: "[show key differences - lighting, mood]"
    - label: "Option B: Natural"
      description: "[show key differences]"
    - label: "Option C: Artistic"
      description: "[show key differences]"
```

Show the full prompts in the response text, then ask for selection.

## Step 6: Generate Image

Use the midjourney-proxy-mcp MCP tools directly. See `references/imagineapi-integration.md` for details.

**Generate:**
Call the `midjourney_imagine` MCP tool with the optimized prompt:
- `prompt`: The complete prompt string including all parameters

**Check Status:**
Call the `midjourney_get_status` MCP tool:
- `image_id`: The ID returned from midjourney_imagine

Poll every 10-15 seconds until status is "completed".

## Step 7: Return Results

Provide to user:
1. Generated image URL
2. Upscaled versions (if available in upscaled_urls)
3. The prompt used (for user's reference)
4. Offer to create variations if needed

---

## Reference Files

### midjourney-parameters.md
Complete V7 parameter reference. Consult when:
- Selecting appropriate parameters
- Explaining parameter effects to user
- Troubleshooting parameter combinations

Search patterns:
- "Quick Reference Table" - All parameters at a glance
- "V7-Specific Parameters" - Draft, exp, oref
- "Reference System" - Style and character references

### midjourney-style-guide.md
Prompt structure and vocabulary. Consult when:
- Building prompts from scratch
- Selecting descriptive vocabulary
- Checking quality guidelines

Search patterns:
- "5-Layer Prompt Structure" - Building prompts
- "Descriptive Vocabulary" - Lighting, mood, color terms
- "Genre-Specific Patterns" - Templates by category

### prompt-examples.md
Before/after transformations. Consult when:
- Learning transformation patterns
- Finding inspiration for specific genres
- Understanding enhancement techniques

Search patterns:
- "Portrait Photography" - People, characters
- "Landscape/Environment" - Nature, cities
- "Product Photography" - Objects, commercial
- "Character Consistency" - Using references

### imagineapi-integration.md
MCP tool usage. Consult when:
- Calling imagine tool
- Checking generation status
- Handling errors

---

## Quick Reference

### Minimum Viable Prompt
```
[subject], [style], [lighting], [camera spec] --ar [ratio] --s [value]
```

### Full Prompt Template
```
[Subject description], [composition], [style category], [lighting type],
[mood/atmosphere], shot on [camera] [lens], [color treatment],
[quality markers] --ar [ratio] --s [value] --q [value]
```

### Common Parameter Combos

| Purpose | Parameters |
|---------|------------|
| Quick test | `--draft` |
| Standard quality | `--ar 16:9 --s 100` |
| High quality | `--ar 16:9 --s 150 --q 2` |
| Artistic | `--s 400 --exp 25` |
| Character lock | `--oref <url> --ow 200` |
| Style lock | `--sref <url> --sw 300` |
| Both locks | `--oref <url> --ow 150 --sref <url> --sw 200` |

---

## Important Notes

1. V7 does not support multi-prompting (`::` syntax)
2. Use natural language - V7 understands creative intent
3. Keep prompts 20-75 words for best results
4. Always append parameters after the descriptive text
5. Use --draft for rapid iteration, then enhance winners
6. Combine --oref and --sref for maximum consistency
