# Captures

Real screens (a running app, a result page, instructor-provided screenshots) are content, not art. Capture them, never generate them.

## Folder and log

`deck/assets/<source>/` per source (for example `student-app/`, `instructor/`), one `captures.md` per folder. A pre-commit check refuses an image there that has no row.

```markdown
| file | screen | capture date | redaction |
|---|---|---|---|
| feed-light.png | feed, light theme | 2026-01-31 | avatars blurred via CSS |
| lesson-2.png | lesson list | 2026-01-31 | sidebar cropped, 3 faces blurred (circle) |
```

`redaction` says what was removed or `none` (a row with `none` asserts nothing private is visible).

## Rules

- Redact other people's faces, names, IDs, emails, tokens, project names and any private data before the image enters the repo.
- Originals from a personal account stay outside the repo (for example `~/Pictures` or a scratch dir). Only the redacted output goes in `deck/assets/<source>/`.
- Blur or crop; never paint over with text. Do not touch pixels beyond what the redaction needs.

## Capture a running app

```bash
node "$SCRIPTS/capture-page.cjs" --out deck/assets/<source> --base http://127.0.0.1:5173 \
  --viewport 390x844 --scale 2 --storage theme=light --blur '.avatar,.story-ring img' --suffix light / /users/me
```

One run per theme or state: `--storage key=value` presets localStorage before load (repeatable), `--suffix` names the variant. `--blur` takes CSS selectors for avatar-like images. Output is `<slug>[-<suffix>].png`, one line per file. It tries bundled Chromium, then system Chrome. Playwright comes from the plugin root (`npm ci --ignore-scripts`) or `NODE_PATH`.

## Clean up a provided screenshot

```bash
"$PY" "$SCRIPTS/redact-image.py" ORIGINAL.png deck/assets/<source>/name.png \
  --blur-circle 412,230,38 --blur-rect 20,300,180,340 --crop 240,0,1440,900
```

Coordinates are source pixels of the original; blur runs first, then the crop, so crop boxes and blur coordinates share one coordinate system. Prints the output size. Self-test: `"$PY" "$SCRIPTS/redact-image.py" --selftest`.

## Verify before logging

Read every output image (the Read tool shows it) and confirm no face, name, ID or private text remains and the crop is right. Only then add the `captures.md` row.
