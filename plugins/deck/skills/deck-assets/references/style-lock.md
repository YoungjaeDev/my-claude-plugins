# Prompts

Palette tokens come from the deck (`deck/shell.html` `:root`). Defaults below match the house deck: background `#1F2226`, accent `#8DB4E8`, skin `#F6D33C`, hair `#7A4B22`, grid line `#2C3036`. Replace if the deck differs. Cell px = 1920 / N.

## STYLE LOCK (icon sheet, no character)

```text
STYLE LOCK - pixel-style icon sheet, no character in this sheet.
Pixel rules: crisp hard-edged pixels, no anti-aliasing, no blur, no gradients, no outlines thicker than 1 px. One fixed pixel scale for the whole sheet (objects about 48 px tall, rendered at 8x so each pixel is a clean 8x8 block).
Palette: max 16 colors - light blue #8DB4E8 as the single accent, warm yellow #F6D33C, brown #7A4B22, mid grey, light grey, white, background flat dark graphite #1F2226 filling the whole image, fully opaque, no transparency. No other saturated colors.
Camera: 3/4 front view, eye level, same for every cell. Flat lighting, no cast shadows.
Layout: strict grid of equal cells, {N} columns x {N} rows, square image, every cell exactly 1/{N} of the width and of the height, generous empty margin inside each cell, each object centered alone, cells separated by 1 px #2C3036 lines, nothing crossing cell borders.
Forbidden: any letters, numbers, words, labels, logos, watermarks, UI screens, charts, graphs, gauges, scores, trophies, extra characters, real brand marks.

Sheet: {topic}, {N} columns x {N} rows.
Row 1: {cell} · {cell} · {cell}
Row 2: ...
Output: one image, {N}x{N} grid, exactly 1920x1920 pixels, every cell exactly {cell_px} px.
```

Cell lines name one object each ("a padlock", "a circular loop of two arrows (retry)"). Concepts, not brands.

## STYLE LOCK (3D icon sheet, `ralphdev-light` template)

The `ralphdev-light` template draws icons in soft 3D, not pixels, on its light canvas. Generate at `--size 1920x1920`; a
sheet that comes back smaller (one came back 1254px and was upscaled) is fine for 220px cells but say so. Before slicing,
match each cell's background to the slide background `#FDFDFD`, or a faint square shows around the icon.

```text
Icon sheet for a light-themed lecture slide deck. Soft 3D style.
Style: soft 3D rendered icons, smooth clay-like material with a subtle satin sheen, rounded chunky forms, soft studio lighting from the upper left, a faint soft contact shadow under each object, consistent scale and camera, three-quarter front view, clean and friendly.
Palette: coral #F25C45 as the single accent, charcoal #2A2A2A, warm light grey #F3EFED, white. No other saturated colors.
Background: flat off-white #FDFDFD filling the whole image, fully opaque.
Layout: strict {N} columns x {N} rows grid, square image, every cell exactly 1/{N} of the width and height, one object centered alone in each cell with generous empty margin, no cell borders or grid lines drawn, nothing crossing cell boundaries.
Cells, row by row:
Row 1: {cell} · {cell} · {cell}
Row 2: ...
Forbidden: any letters, numbers, words, labels, logos, watermarks, screens or user interfaces, people, extra objects.
```

## Mascot pixel sheet (expressions / poses, 4x3)

Same block with the character line instead of "no character", used with `--ref deck/assets/ralph.png`:

```text
Character: the character in the reference image, identity identical in every cell (same face, yellow skin, brown spiky hair, light blue shirt). Only expression/pose changes. Bust for expressions, full body for poses, one fixed sprite scale.
```

Layout becomes `4 columns x 3 rows`, output `exactly 1920x1440, every cell exactly 480x480`. Rows list the cells (neutral, happy, thinking, confused, worried, alert warning, proud, pointing, thumbs up, stop gesture, ...). Skip sleepy/zzz and exaggerated faces for serious topics (security, cost).

## Mascot voxel concept illustration (large, 1920x1280)

```text
Slide visual, concept illustration for a corporate lecture slide titled "{idea}". Style: 3D voxel toy style matching the reference character (chunky cubes, soft studio lighting, clean matte materials). Keep identity from the reference: same face, yellow skin, brown spiky hair, light blue shirt; the pose is new. Subject and setting: {one scene}. Composition: wide 3:2, subjects in the right two thirds, generous empty dark space on the left for slide text. Background flat dark graphite close to #1F2226. One restrained cool blue accent (#8DB4E8). Avoid: any readable text, letters, numbers, charts, screens with content, program UI, logos, watermarks, clouds, extra characters, clutter.
```
