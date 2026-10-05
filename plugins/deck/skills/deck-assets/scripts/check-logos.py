#!/usr/bin/env python3
"""Verify deck/assets/logos: files <-> sources.json records, sha256, SVG safety.

usage: check-logos.py [LOGOS_DIR]      (default deck/assets/logos)
       check-logos.py --self-test
exit 0 = clean, 1 = problems printed one per line.
"""
import hashlib
import json
import re
import sys
import tempfile
from pathlib import Path

FIELDS = ("file", "name", "source_url", "official", "license", "guidelines_url", "variant", "sha256", "retrieved")
BAD = [
    (re.compile(r"<\s*script", re.I), "<script>"),
    (re.compile(r"<\s*foreignObject", re.I), "<foreignObject>"),
    (re.compile(r"\son[a-z]+\s*=", re.I), "on* handler"),
    (re.compile(r"""(?:xlink:)?href\s*=\s*["']\s*(?!#)[^"']""", re.I), "external/non-fragment href"),
    (re.compile(r"""url\(\s*["']?\s*(?!#)|@import""", re.I), "external/non-fragment CSS url()"),
]


def check(d):
    d = Path(d)
    errs = []
    sj = d / "sources.json"
    try:
        recs = json.loads(sj.read_text())
    except Exception as e:
        return [f"{sj}: unreadable ({e})"]
    files = {p.name for p in d.glob("*.svg")}
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
        txt = (d / f).read_text(errors="replace")
        for rx, label in BAD:
            if rx.search(txt):
                errs.append(f"{f}: contains {label}")
    return errs


def self_test():
    with tempfile.TemporaryDirectory() as t:
        d = Path(t)
        ok = b'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><path fill="url(#g)" d="M0 0h1v1z"/></svg>'
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
        (d / "a.svg").write_bytes(ok + b" ")  # hash drift
        assert any("sha256 mismatch" in x for x in check(d))
        (d / "a.svg").unlink()
        assert any("record without file" in x for x in check(d))
    print("check-logos self-test ok")


if __name__ == "__main__":
    a = sys.argv[1:]
    if a == ["--self-test"]:
        self_test()
        sys.exit(0)
    errs = check(a[0] if a else "deck/assets/logos")
    print("\n".join(errs) if errs else "logos ok")
    sys.exit(1 if errs else 0)
