#!/usr/bin/env python3
"""Cut a sprite sheet into equal grid cells.

usage: slice-sheet.py SHEET.png ROWS COLS OUT_DIR PREFIX [--trim N]
       slice-sheet.py --self-test
writes OUT_DIR/PREFIX-r{row}c{col}.png (1-based), dropping --trim px on every
cell edge so the 1 px grid lines never land inside a cell (default 2).
"""
import sys
import tempfile
from pathlib import Path

from PIL import Image


def slice_sheet(sheet, rows, cols, out_dir, prefix, trim=2):
    im = Image.open(sheet).convert("RGBA")
    w, h = im.size
    cw, ch = w // cols, h // rows
    if cw <= 2 * trim or ch <= 2 * trim:
        sys.exit(f"trim {trim} too large for {cw}x{ch} cells")
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    written = []
    for r in range(rows):
        for c in range(cols):
            box = (c * cw + trim, r * ch + trim, (c + 1) * cw - trim, (r + 1) * ch - trim)
            p = out_dir / f"{prefix}-r{r + 1}c{c + 1}.png"
            im.crop(box).save(p)
            written.append(p)
    return written


def self_test():
    rows, cols, cell, trim = 3, 4, 40, 2
    im = Image.new("RGB", (cols * cell, rows * cell), (31, 34, 38))
    for r in range(rows):
        for c in range(cols):  # distinct color per cell
            im.paste((10 * (r * cols + c) + 20, 100, 200), (c * cell + 5, r * cell + 5, (c + 1) * cell - 5, (r + 1) * cell - 5))
    with tempfile.TemporaryDirectory() as d:
        src = Path(d) / "sheet.png"
        im.save(src)
        out = slice_sheet(src, rows, cols, Path(d) / "cells", "t", trim)
        assert len(out) == rows * cols, len(out)
        assert out[0].name == "t-r1c1.png" and out[-1].name == f"t-r{rows}c{cols}.png"
        for p in out:
            assert Image.open(p).size == (cell - 2 * trim,) * 2, p
        assert Image.open(out[5]).getpixel((20, 20))[:3] == (70, 100, 200)  # r2c2
    print("slice-sheet self-test ok")


if __name__ == "__main__":
    a = sys.argv[1:]
    if a == ["--self-test"]:
        self_test()
        sys.exit(0)
    trim = 2
    if "--trim" in a:
        i = a.index("--trim")
        trim = int(a[i + 1])
        del a[i:i + 2]
    if len(a) != 5:
        sys.exit(__doc__)
    for p in slice_sheet(a[0], int(a[1]), int(a[2]), a[3], a[4], trim):
        print(p)
