#!/usr/bin/env python3
"""Verify deck/assets/logos: files (.svg, .png) <-> sources.json records, sha256, SVG safety,
PNG short side >= 256 px.

usage: check-logos.py [LOGOS_DIR]      (default deck/assets/logos)
       check-logos.py --self-test   (or --selftest)
exit 0 = clean, 1 = problems printed one per line.
"""
import hashlib
import json
import re
import struct
import sys
import tempfile
from pathlib import Path

FIELDS = ("file", "name", "source_url", "official", "license", "guidelines_url", "variant", "sha256", "retrieved")
BAD = [
    (re.compile(r"""(?:href\s*=\s*["']|url\(\s*["']?)\s*data:""", re.I), "embedded raster (data URI)"),
    (re.compile(r"<\s*script", re.I), "<script>"),
    (re.compile(r"<\s*foreignObject", re.I), "<foreignObject>"),
    (re.compile(r"\son[a-z]+\s*=", re.I), "on* handler"),
    (re.compile(r"""(?:xlink:)?href\s*=\s*["'](?!\s*(?:#|data:))\s*[^"'\s]""", re.I), "external/non-fragment href"),
    (re.compile(r"""url\(\s*(?!["']?\s*(?:#|data:))|@import""", re.I), "external/non-fragment CSS url()"),
]


def check(d):
    d = Path(d)
    errs = []
    sj = d / "sources.json"
    try:
        recs = json.loads(sj.read_text())
    except Exception as e:
        return [f"{sj}: unreadable ({e})"]
    files = {p.name for p in d.iterdir() if p.suffix in (".svg", ".png")}
    seen = set()
    for r in recs:
        f = r.get("file", "?")
        for k in FIELDS:
            if k not in r:
                errs.append(f"{f}: record missing field {k}")
        if not isinstance(r.get("official"), bool):
            errs.append(f"{f}: official must be bool")
        if f in seen:
            errs.append(f"{f}: duplicate record")
        seen.add(f)
        if f not in files:
            errs.append(f"{f}: record without file")
            continue
        data = (d / f).read_bytes()
        if hashlib.sha256(data).hexdigest() != r.get("sha256"):
            errs.append(f"{f}: sha256 mismatch")
    for f in sorted(files - seen):
        errs.append(f"{f}: file without record")
    for f in sorted(files):
        if f.endswith(".png"):
            head = (d / f).read_bytes()[:24]
            if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
                errs.append(f"{f}: not a PNG file")
            elif min(struct.unpack(">II", head[16:24])) < 256:
                errs.append(f"{f}: PNG short side under 256 px")
            continue
        txt = (d / f).read_text(errors="replace")
        for rx, label in BAD:
            if rx.search(txt):
                errs.append(f"{f}: contains {label}")
    return errs


def self_test():
    with tempfile.TemporaryDirectory() as t:
        d = Path(t)
        ok = (b'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><path fill="url(#g)" d="M0 0h1v1z"/>'
              b'<path style=\'fill:url("#g")\' d="M0 0"/><use href=" #g"/></svg>')
        (d / "a.svg").write_bytes(ok)
        rec = dict(file="a.svg", name="A", source_url="https://x", official=True, license="x",
                   guidelines_url="https://x", variant="color", sha256=hashlib.sha256(ok).hexdigest(), retrieved="2026-10-05")
        (d / "sources.json").write_text(json.dumps([rec]))
        assert check(d) == [], check(d)
        bad = b'<svg onload="x()"><script>1</script><image href="https://e/x.png"/><style>rect{fill:url(https://e/a.svg)}</style></svg>'
        (d / "b.svg").write_bytes(bad)  # no record + unsafe
        e = "\n".join(check(d))
        assert "b.svg: file without record" in e and "<script>" in e and "on* handler" in e and "href" in e and "CSS url()" in e, e
        (d / "b.svg").unlink()
        uri = b'<svg xmlns="http://www.w3.org/2000/svg"><image href="data:image/png;base64,iVBO"/></svg>'
        (d / "c.svg").write_bytes(uri)
        e = check(d)
        assert "c.svg: contains embedded raster (data URI)" in e and not any("c.svg" in x and "external" in x for x in e), e
        (d / "c.svg").unlink()
        png = lambda w, h: b"\x89PNG\r\n\x1a\n" + b"\0\0\0\rIHDR" + struct.pack(">II", w, h) + b"\x08\x06\0\0\0"
        recs = [rec]
        for name, data in (("p.png", png(512, 256)), ("q.png", png(512, 128)), ("r.png", png(512, 512)[:12])):
            (d / name).write_bytes(data)
            recs.append(dict(rec, file=name, sha256=hashlib.sha256(data).hexdigest()))
        (d / "sources.json").write_text(json.dumps(recs))
        assert check(d) == ["q.png: PNG short side under 256 px", "r.png: not a PNG file"], check(d)
        for name in ("p.png", "q.png", "r.png"):
            (d / name).unlink()
        (d / "sources.json").write_text(json.dumps([rec]))
        (d / "a.svg").write_bytes(ok + b" ")  # hash drift
        assert any("sha256 mismatch" in x for x in check(d))
        (d / "a.svg").unlink()
        assert any("record without file" in x for x in check(d))
    print("check-logos self-test ok")


if __name__ == "__main__":
    a = sys.argv[1:]
    if a in (["--self-test"], ["--selftest"]):
        self_test()
        sys.exit(0)
    errs = check(a[0] if a else "deck/assets/logos")
    print("\n".join(errs) if errs else "logos ok")
    sys.exit(1 if errs else 0)
