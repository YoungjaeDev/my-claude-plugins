# Midjourney V7 Parameter Reference

Complete parameter guide for Midjourney V7 (default model since June 2025).

## Table of Contents

- [Quick Reference Table](#quick-reference-table)
- [Core Parameters](#core-parameters)
- [V7-Specific Parameters](#v7-specific-parameters)
- [Reference System](#reference-system)
- [V7 vs V6.1 Compatibility](#v7-vs-v61-compatibility)
- [Parameter Combinations](#parameter-combinations)
- [Best Practices](#best-practices)
- [Sources](#sources)

---

## Quick Reference Table

| Parameter | Syntax | Range | Default | Notes |
|-----------|--------|-------|---------|-------|
| Version | `--v 7` | - | 7 | Current default |
| Aspect Ratio | `--ar W:H` | any | 1:1 | No limit |
| Stylize | `--s` | 0-1000 | 100 | Artistic influence |
| Chaos | `--c` | 0-100 | 0 | Variation between images |
| Quality | `--q` | 1, 2, 4 | 1 | Detail level |
| Seed | `--seed` | 0-4294967295 | random | Reproducibility |
| Weird | `--w` | 0-3000 | 0 | Unconventional results |
| Experimental | `--exp` | 0-100 | 0 | Enhanced details (V7 only) |
| Raw Mode | `--raw` | - | off | Less artistic interpretation |
| Draft | `--draft` | - | off | 10x faster, half cost (V7 only) |
| Omni Ref | `--oref` | URL | - | Character/object reference (V7) |
| Omni Weight | `--ow` | 1-1000 | 100 | Reference strength |
| Style Ref | `--sref` | URL/code | - | Style reference |
| Style Weight | `--sw` | 0-1000 | 100 | Style strength |
| Style Version | `--sv` | 1-6 | 6 | Sref model version |
| Image Weight | `--iw` | 0-3 | 1 | Image prompt influence |
| No | `--no` | text | - | Negative prompt |
| Tile | `--tile` | - | off | Seamless patterns |

---

## Core Parameters

### Aspect Ratio (--ar)

Controls output image dimensions.

```
--ar 16:9    # Widescreen, cinematic
--ar 9:16    # Vertical, mobile/portrait
--ar 1:1     # Square (default)
--ar 3:2     # Classic photo
--ar 4:5     # Portrait, Instagram
--ar 21:9    # Ultra-wide, panoramic
```

Common use cases:
- Landscape/cinematic: `16:9`, `21:9`
- Portrait/character: `9:16`, `4:5`, `2:3`
- Product/social: `1:1`, `4:5`

### Stylize (--s)

Controls how strongly Midjourney applies its aesthetic training.

| Value | Effect |
|-------|--------|
| 0-50 | Very literal, minimal artistic interpretation |
| 50-100 | Balanced (default: 100) |
| 100-300 | More artistic, stylized |
| 300-600 | Highly stylized |
| 600-1000 | Maximum artistic interpretation |

```
--s 50     # Closer to prompt, less stylization
--s 250    # Moderately stylized
--s 750    # Heavily stylized, artistic
```

### Chaos (--c)

Controls variation between the 4 generated images.

| Value | Effect |
|-------|--------|
| 0 | Very similar results (default) |
| 1-25 | Subtle variation |
| 25-50 | Moderate variation |
| 50-100 | Highly varied results |

```
--c 0      # Consistent results
--c 25     # Some variety
--c 75     # Explore different interpretations
```

### Quality (--q)

Controls detail level and generation time.

| Value | Effect | GPU Cost |
|-------|--------|----------|
| 1 | Standard quality (default) | 1x |
| 2 | Higher detail | 2x |
| 4 | Maximum detail (V7 only) | 4x |

```
--q 1      # Standard, fast
--q 2      # Enhanced detail
--q 4      # Maximum fidelity (V7)
```

### Weird (--w)

Introduces unconventional, unexpected elements.

| Value | Effect |
|-------|--------|
| 0 | Normal output (default) |
| 1-100 | Subtle oddities |
| 100-500 | Noticeable weirdness |
| 500-1500 | Very unusual |
| 1500-3000 | Extremely unconventional |

```
--w 50     # Slight quirks
--w 500    # Noticeably strange
--w 1500   # Very experimental
```

Note: Keep 5-30 for controlled results. Does not work well with mood boards.

### No (--no)

Negative prompt - excludes specified elements.

```
--no text, watermark           # Remove text/watermarks
--no people, humans            # Exclude people
--no blur, noise               # Avoid artifacts
--no red                       # Exclude color
```

Multiple exclusions: comma-separated or multiple --no parameters.

### Seed (--seed)

Controls randomness for reproducibility.

```
--seed 12345    # Specific seed for consistent results
```

Use same seed + same prompt = similar output. Useful for:
- Iterating on a concept
- Creating variations of a successful image
- A/B testing parameter changes

---

## V7-Specific Parameters

### Draft Mode (--draft)

10x faster generation at half GPU cost. V7 exclusive.

```
--draft    # Enable draft mode
```

Best for:
- Rapid prototyping
- Iterative concept development
- Testing prompt variations

Workflow:
1. Generate with `--draft`
2. Iterate 5-10 times
3. Use "Enhance" on best result for full quality

### Experimental (--exp)

Enhances details and creativity. V7 exclusive.

| Value | Effect |
|-------|--------|
| 0 | Off (default) |
| 5 | Subtle enhancement |
| 10 | Light detail boost |
| 25 | Moderate enhancement |
| 50 | Strong creative boost |
| 100 | Maximum effect |

```
--exp 5     # Subtle detail enhancement
--exp 25    # Noticeable improvement
--exp 50    # Strong creative effect
```

Tips:
- Start low (5-10) when combining with other parameters
- High values (>25-50) can overwhelm --stylize and --p
- Avoid for literal prompt interpretation or consistency needs

### Raw Mode (--raw)

Less artistic interpretation, more literal output.

```
--raw    # Enable raw mode
```

Note: In V7, use `--raw` instead of `--style raw`.

---

## Reference System

### Style Reference (--sref)

Transfer visual style from reference images.

```
prompt --sref <image_url>              # Single reference
prompt --sref <url1> <url2>            # Multiple references
prompt --sref random                   # Random style code
prompt --sref 123456789                # Style code
```

### Style Weight (--sw)

Controls style reference strength.

```
--sw 50      # Subtle style influence
--sw 100     # Default
--sw 500     # Strong style adherence
--sw 1000    # Maximum style influence
```

In V7, --sw has more impact with sref codes than with images.

### Style Version (--sv)

Controls which sref model to use.

| Value | Description |
|-------|-------------|
| --sv 6 | New V7 default (since June 2025) |
| --sv 4 | Old V7 sref model (pre-June 2025) |
| --sv 1-6 | Full range for uploaded images |

```
--sref random --sv 6    # New V7 style model
--sref random --sv 4    # Legacy V7 style model
```

Old sref codes still work; use `--sv 4` for compatibility.

### Omni Reference (--oref)

Character/object reference system. Replaces --cref from V6.

```
prompt --oref <image_url>              # Reference image
prompt --oref <url> --ow 200           # With weight
```

Features:
- Works with characters, objects, vehicles, creatures
- Better compatibility with external images
- Higher consistency for subject preservation

### Omni Weight (--ow)

Controls omni reference strength.

| Value | Effect |
|-------|--------|
| 1-100 | Allow style changes, preserve key features |
| 100-200 | Balanced (default: 100) |
| 200-400 | Strong fidelity for facial features/details |
| 400+ | Only with high stylize values |

```
--ow 50      # Flexible, allows style variation
--ow 200     # Strong character preservation
--ow 300     # Maximum fidelity (use carefully)
```

Tips:
- Keep under 400 unless using high stylize values
- High --stylize or --exp requires higher --ow for character preservation
- Example: `--stylize 1000 --ow 400 --exp 100`

Limitations:
- Not compatible with: Fast Mode, Draft Mode, --q 4
- Uses 2x GPU time compared to regular V7 images
- Not compatible with: Vary Region, Pan, Zoom Out

### Image Weight (--iw)

Controls influence of image prompts.

```
--iw 0.5    # Less image influence
--iw 1      # Default balance
--iw 2      # Strong image influence
--iw 3      # Maximum image influence
```

---

## V7 vs V6.1 Compatibility

### Supported in V7
- All core parameters (--ar, --s, --c, --q, --w, --no)
- Reference system (--sref, --oref)
- New features (--draft, --exp)

### Not Supported in V7
- Multi-Prompting (`::` weight syntax)
- Stop Parameter (--stop)
- Character Reference (--cref) - replaced by --oref

### V6.1 Fallback Features
These use V6.1 rendering even when V7 is selected:
- Upscalers (Subtle & Creative)
- Pan
- Zoom Out
- Inpainting (Editor)

---

## Parameter Combinations

### Portrait Photography
```
cinematic portrait --ar 4:5 --s 150 --q 2
```

### Landscape/Cinematic
```
epic landscape --ar 16:9 --s 200 --q 2
```

### Character Consistency
```
character description --oref <url> --ow 200 --s 100
```

### Style Transfer
```
subject description --sref <style_url> --sw 300 --s 150
```

### Experimental Art
```
abstract concept --exp 50 --w 100 --s 500
```

### Rapid Iteration
```
concept idea --draft --c 50
```

### Production Quality
```
detailed scene --q 4 --s 200 --exp 10
```

---

## Best Practices

1. Start with defaults, adjust incrementally
2. Use --draft for exploration, enhance winners
3. Combine --oref with --sref for character + style consistency
4. Keep --ow under 400 unless using high --stylize
5. Use --seed for reproducible iterations
6. V7 treats entire prompt equally - word order matters less
7. Short, high-signal phrases work well in V7

---

## Sources

- [Midjourney Parameter List](https://docs.midjourney.com/hc/en-us/articles/32859204029709-Parameter-List)
- [Midjourney Version Documentation](https://docs.midjourney.com/hc/en-us/articles/32199405667853-Version)
- [Omni Reference Guide](https://docs.midjourney.com/hc/en-us/articles/36285124473997-Omni-Reference)
- [Style Reference Documentation](https://docs.midjourney.com/hc/en-us/articles/32180011136653-Style-Reference)
- [Draft & Conversational Modes](https://docs.midjourney.com/hc/en-us/articles/35577175650957-Draft-Conversational-Modes)
