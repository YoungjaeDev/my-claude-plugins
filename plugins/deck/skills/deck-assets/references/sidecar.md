# Sidecar template

One `.md` per generated image, same basename, next to it (per sheet, not per cell).

```markdown
# {file}.png

- Use: {what the sheet or image is for; "not a program screen"}
- Generated: {tool + version, e.g. Codex CLI 0.154.0 built-in image tool via codex-image}, {W}x{H}, quality {q}, {YYYY-MM-DD}
- Source copy: {~/.codex/generated_images/<session>/... or output path}
- Reference images: {paths or none}
- Post-processing: {none | resize method + sizes}; slicing: slice-sheet.py --trim {N} -> cells/{prefix}-rRcC.png
- Review notes: {letters? cells inside borders? palette? faint cells at small size?}
- Fallback used: {none | agy -> codex-image -> Higgsfield, why}

## Prompt

{full prompt, verbatim}
```
