#!/usr/bin/env python3
"""Blur regions of a screenshot, then crop it. Coordinates are source pixels; blur runs before crop.

usage: redact-image.py IN OUT [--blur-circle cx,cy,r]... [--blur-rect x0,y0,x1,y1]...
                       [--crop x0,y0,x1,y1]
       redact-image.py --selftest
Prints the output size. The input is never modified; keep personal-account originals outside the repo.
"""
import argparse
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


def nums(s, n):
    v = [int(x) for x in s.split(",")]
    if len(v) != n:
        sys.exit(f"expected {n} comma-separated integers, got {s!r}")
    return v


def blur_region(im, box, circle=False):
    part = im.crop(box).filter(ImageFilter.GaussianBlur(max(2, min(box[2] - box[0], box[3] - box[1]) // 4)))
    mask = Image.new("L", part.size, 255)
    if circle:
        mask = Image.new("L", part.size, 0)
        ImageDraw.Draw(mask).ellipse((0, 0, part.size[0] - 1, part.size[1] - 1), fill=255)
    im.paste(part, box[:2], mask)


def redact(src, dst, circles=(), rects=(), crop=None):
    im = Image.open(src).convert("RGB")
    for cx, cy, r in circles:
        blur_region(im, (cx - r, cy - r, cx + r, cy + r), circle=True)
    for box in rects:
        blur_region(im, tuple(box))
    if crop:
        im = im.crop(tuple(crop))
    Path(dst).parent.mkdir(parents=True, exist_ok=True)  # a new deck/assets/<source>/ folder
    im.save(dst)
    return im.size


def selftest():
    with tempfile.TemporaryDirectory() as d:
        src, dst = Path(d) / "a.png", Path(d) / "b.png"
        im = Image.new("RGB", (200, 100), (255, 255, 255))
        for x in range(0, 200, 4):  # stripes so a blur visibly changes pixels
            ImageDraw.Draw(im).rectangle((x, 0, x + 1, 99), fill=(0, 0, 0))
        im.save(src)
        size = redact(src, dst, circles=[(150, 50, 20)], rects=[(0, 0, 30, 30)], crop=(40, 10, 190, 90))
        assert size == (150, 80), size
        out = Image.open(dst)
        assert out.size == (150, 80)
        # circle centre (150,50) -> (110,40) in the crop; stripes there must have been smoothed
        assert out.getpixel((110, 40)) != im.getpixel((150, 50)) or out.getpixel((111, 40)) != im.getpixel((151, 50))
        assert Image.open(src).tobytes() == im.tobytes(), "input modified"
        # unblurred, uncropped area outside the blur stays identical
        assert out.getpixel((0, 79)) == im.getpixel((40, 89))
    print("redact-image selftest ok")


def main():
    if sys.argv[1:] == ["--selftest"]:
        return selftest()
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("input")
    p.add_argument("output")
    p.add_argument("--crop")
    p.add_argument("--blur-circle", action="append", default=[])
    p.add_argument("--blur-rect", action="append", default=[])
    a = p.parse_args()
    if Path(a.input).resolve() == Path(a.output).resolve():
        sys.exit("output must differ from input")
    w, h = redact(
        a.input, a.output,
        circles=[nums(s, 3) for s in a.blur_circle],
        rects=[nums(s, 4) for s in a.blur_rect],
        crop=nums(a.crop, 4) if a.crop else None,
    )
    print(f"{a.output} {w}x{h}")


if __name__ == "__main__":
    main()
