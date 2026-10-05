# Usage gate

Corporate lecture tone. Art explains a moment; it never decorates.

## Rules

- At most one cut per slide.
- No cell reused on a second slide.
- None on 실습 slides: the capture or mockup is the content.
- Only on meaningful moments: blocked, caution, misconception, first or last checkpoint, background or concept intro.
- Cap about 1 cut per 10-12 slides.
- One style per role: pixel for small cuts and icons, voxel for large concept illustrations. Do not mix on one slide.
- Never as a brand logo, a screen/UI/terminal, a chart, or with readable text. Mascot never larger than the content and no exaggerated expression on security or cost topics.
- Every `deck/assets/logos/*` image on a slide needs a `sources.json` record (`check-logos.py` covers files, so also grep the sections: `grep -oh 'assets/logos/[^"]*' deck/sections/*.html | sort -u`, each must exist and have a record).
- Check reuse and counts: `grep -oh 'assets/sprites/cells/[^"]*' deck/sections/*.html | sort | uniq -d` must print nothing.

## `deck/assets/sprites/README.md` layout

```markdown
## sheet-01-{topic}.png - {N}x{N} -> cells/{prefix}-*

| cell | meaning | cell | meaning |
|---|---|---|---|
| r1c1 | ... | r1c2 | ... |

## Used on slides

| cell file | slide id | moment |
|---|---|---|
| cells/{prefix}-r1c1.png | S1-13 | blocked |
```

Update the used-on table in the same change that places the cut.
