# Midjourney V7 Style Guide

Comprehensive guidelines for creating optimized Midjourney V7 prompts.

## Table of Contents

- [V7 Prompt Characteristics](#v7-prompt-characteristics)
- [5-Layer Prompt Structure](#5-layer-prompt-structure)
- [Descriptive Vocabulary](#descriptive-vocabulary)
- [Genre-Specific Patterns](#genre-specific-patterns)
- [Reference System Usage](#reference-system-usage)
- [Quality Checklist](#quality-checklist)
- [Common Mistakes to Avoid](#common-mistakes-to-avoid)
- [V7-Optimized Tips](#v7-optimized-tips)
- [Sources](#sources)

---

## V7 Prompt Characteristics

### Key Differences from Previous Versions

1. **Equal Attention**: V7 views the entire prompt with equal weight - word order matters less
2. **Shorter Prompts Work**: Short, high-signal phrases are effective
3. **No Multi-Prompting**: The `::` weight syntax is not supported in V7
4. **Natural Language**: V7's LLM-based interpretation understands creative intent better
5. **Default Personalization**: V7 tailors outputs to individual aesthetic preferences

### Optimal Prompt Length

- **20-50 words**: Optimal for most prompts
- **50-75 words**: Complex scenes with multiple elements
- **Under 20 words**: May lack sufficient detail
- **Over 75 words**: Diminishing returns

---

## 5-Layer Prompt Structure

### Layer 1: Subject & Composition (Required)

The primary subject and its positioning.

```
[Subject] [action/pose/position], [composition]
```

Examples:
- "woman standing in wheat field, centered composition"
- "vintage sports car on coastal highway, rule of thirds"
- "modern skyscraper reaching into clouds, low angle perspective"

### Layer 2: Style & Aesthetic (Required)

Artistic direction and visual treatment.

```
[style/genre], [mood], [color treatment]
```

Examples:
- "cinematic photography, moody and atmospheric, rich earth tones"
- "editorial fashion photography, elegant and refined, high contrast"
- "documentary portrait, intimate and raw, desaturated colors"

### Layer 3: Lighting & Environment (Recommended)

Lighting conditions and environmental context.

```
[lighting type], [time of day], [atmosphere]
```

Examples:
- "golden hour sunlight, late afternoon, light fog"
- "studio softbox lighting, controlled environment, clean backdrop"
- "dramatic rim lighting, blue hour, scattered clouds"

### Layer 4: Technical Details (Recommended)

Photography specifications and quality markers.

```
[camera/lens], [depth of field], [quality terms]
```

Examples:
- "shot on Canon R5 85mm f/1.4, shallow depth of field, professional photography"
- "medium format Hasselblad, tack sharp focus, 8k resolution"
- "35mm film grain, Portra 400 colors, highly detailed"

### Layer 5: Artistic References (Optional)

Stylistic guidance when appropriate.

```
[artist/photographer], [art movement], [cultural reference]
```

Examples:
- "in the style of Annie Leibovitz, contemporary portrait"
- "inspired by Blade Runner 2049, neo-noir cinematography"
- "reminiscent of Gregory Crewdson, staged photography"

---

## Descriptive Vocabulary

### Lighting Terms
- Golden hour, blue hour, twilight, dusk, dawn
- Rim lighting, backlighting, side lighting, three-point lighting
- Soft diffused light, hard directional light, volumetric lighting
- Studio lighting, natural light, candlelight, neon glow
- God rays, lens flare, atmospheric haze, light shafts

### Composition Terms
- Rule of thirds, centered composition, symmetrical framing
- Low angle, high angle, bird's eye view, worm's eye view
- Dutch angle, over-the-shoulder, close-up, wide shot
- Negative space, leading lines, framing within frame
- Depth layering, foreground interest, background separation

### Mood & Atmosphere
- Cinematic, dramatic, ethereal, dreamlike, surreal
- Moody, atmospheric, intimate, epic, grandiose
- Melancholic, nostalgic, futuristic, timeless
- Serene, tranquil, chaotic, dynamic, peaceful
- Mysterious, ominous, hopeful, triumphant

### Color & Tone
- Rich earth tones, muted pastels, vibrant colors, desaturated
- High contrast, low contrast, tonal depth, color grading
- Warm tones, cool tones, complementary colors, analogous palette
- Monochromatic, duotone, technicolor, sepia toned
- Film emulation: Fuji Velvia, Kodak Portra, Ilford HP5

### Quality Enhancers
- Highly detailed, ultra realistic, photorealistic, 8k resolution
- Professional photography, award-winning, museum quality
- Tack sharp, crisp focus, pin sharp, crystal clear
- Fine art photography, editorial quality, commercial photography
- Masterful composition, expert color grading

### Texture & Material
- Soft fabric, rough concrete, polished metal, weathered wood
- Smooth glass, organic textures, intricate details
- Translucent, reflective surface, matte finish, glossy sheen
- Fine grain, subtle texture, rich tactile quality

### Camera & Technical
- Camera brands: Canon R5, Sony A7R, Hasselblad, Phase One, RED, ARRI
- Focal lengths: 24mm, 35mm, 50mm, 85mm, 200mm
- Apertures: f/1.4, f/2.8, f/4, f/5.6, f/8
- Film stocks: Kodak Portra 400, Fuji Velvia, Ilford HP5
- Formats: Medium format, large format, 35mm film, digital cinema

---

## Genre-Specific Patterns

### Portrait Photography
```
[Subject description], [framing], cinematic portrait photography,
[lighting], [mood], shot on [camera] [lens] [aperture],
[background treatment], [color grading], [quality terms]
```

### Landscape/Environment
```
[Scene description], [time of day], [weather/atmosphere],
[composition], [lighting quality], shot on [camera] [lens],
[color treatment], [artistic reference]
```

### Product Photography
```
[Product] [positioning], editorial product photography,
[lighting setup], [background], shot on [camera] [lens],
[material emphasis], [quality terms]
```

### Architectural
```
[Building/structure], [perspective], [time/lighting],
[environment], [mood], shot on [camera] [lens],
architectural photography, [artistic treatment]
```

### Fashion Editorial
```
[Subject] [outfit/styling], [pose/action], [setting],
[lighting], high fashion editorial aesthetic, shot on [camera] [lens],
[artistic reference], [quality terms]
```

---

## Reference System Usage

### Style Reference (--sref)

For consistent visual style across generations:

```
prompt text --sref <style_image_url> --sw 200
```

Use cases:
- Maintaining brand aesthetic
- Series with consistent look
- Matching existing visual style

### Omni Reference (--oref)

For character/subject consistency:

```
prompt text --oref <character_image_url> --ow 200
```

Use cases:
- Character consistency across scenes
- Product variations
- Subject in different contexts

### Combined References

For both style and subject consistency:

```
prompt text --oref <character_url> --ow 150 --sref <style_url> --sw 200
```

---

## Quality Checklist

Before finalizing a prompt, verify:

- [ ] Main subject clearly defined and positioned
- [ ] Lighting described with direction and quality
- [ ] Mood/atmosphere conveyed through descriptive terms
- [ ] Technical photography details add authenticity
- [ ] Color treatment or grading specified
- [ ] Composition guidance included
- [ ] At least 2-3 quality enhancers present
- [ ] Appropriate parameters appended
- [ ] Prompt reads naturally and coherently
- [ ] No redundant or contradictory terms

---

## Common Mistakes to Avoid

### Too Generic
- Bad: "beautiful landscape photo"
- Good: "misty mountain valley at golden hour, dramatic god rays, cinematic landscape photography --ar 16:9 --s 200"

### Contradictory Elements
- Bad: "bright sunlight, moody dark atmosphere"
- Good: "overcast diffused light, moody and atmospheric"

### Overstuffed with Keywords
- Bad: Listing every possible quality term
- Good: Select 2-3 most relevant quality enhancers

### Missing Technical Anchor
- Bad: "nice photo of a person"
- Good: "shot on Canon R5 85mm f/1.4, professional portrait photography"

### Vague Style Reference
- Bad: "artistic and creative"
- Good: "inspired by Annie Leibovitz, contemporary editorial portrait"

### Using Deprecated V6 Features
- Bad: "mountain::2 sky::1" (multi-prompting not supported)
- Good: "dramatic mountain with expansive sky" (natural language)

---

## V7-Optimized Tips

1. **Trust Natural Language**: V7 understands creative intent - describe what you want naturally
2. **Front-load Key Elements**: Put the most important subject/concept first
3. **Use Draft Mode**: Iterate quickly with `--draft`, then enhance winners
4. **Leverage Personalization**: V7 adapts to your aesthetic preferences over time
5. **Combine References**: Use both --oref and --sref for maximum consistency
6. **Start with Default Stylize**: `--s 100` is well-balanced; adjust from there
7. **Use --exp Sparingly**: Start at 5-10, increase if needed

---

## Sources

- [V7 Alpha Release Notes](https://updates.midjourney.com/v7-alpha/)
- [V7 Default Model Update](https://updates.midjourney.com/v7-is-now-the-default-model/)
