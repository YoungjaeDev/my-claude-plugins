#!/usr/bin/env python3
"""Download one logo into deck/assets/logos and upsert its sources.json record.

usage: fetch-logo.py FILE URL --name N (--official|--unofficial) --license L --guidelines URL
                     --variant color|mono|wordmark [--member PATH_IN_ZIP] [--dir LOGOS_DIR]
       fetch-logo.py --selftest
FILE is a bare name ending .svg or .png. With --member, URL is a zip (brand kit) and the member is
saved; source_url then records URL#member. The file is saved unmodified. Run check-logos.py after.
"""
import argparse
import datetime
import hashlib
import io
import json
import re
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

MAX_BYTES = 50 * 1024 * 1024  # brand kits run to tens of MB; anything larger is not a logo download
UA = "Mozilla/5.0 (compatible; deck-assets fetch-logo)"  # some brand CDNs refuse the default Python agent


def download(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read(MAX_BYTES + 1)
    if len(data) > MAX_BYTES:
        raise ValueError(f"{url}: larger than {MAX_BYTES} bytes")
    return data


def fetch(file, url, name, official, license, guidelines, variant, member=None, logos="deck/assets/logos"):
    if not re.fullmatch(r"[a-z0-9][a-z0-9._-]*\.(svg|png)", file):
        raise ValueError(f"{file}: want a bare lower-case name ending .svg or .png")
    data = download(url)
    if member:
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            data = z.read(member)  # KeyError names the missing member
    if file.endswith(".png") and data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{file}: downloaded bytes are not a PNG")
    if file.endswith(".svg") and b"<svg" not in data[:4096]:
        raise ValueError(f"{file}: downloaded bytes are not an SVG")
    d = Path(logos)
    d.mkdir(parents=True, exist_ok=True)
    (d / file).write_bytes(data)
    rec = dict(file=file, name=name, source_url=f"{url}#{member}" if member else url, official=official,
               license=license, guidelines_url=guidelines, variant=variant,
               sha256=hashlib.sha256(data).hexdigest(), retrieved=datetime.date.today().isoformat())
    sj = d / "sources.json"
    recs = json.loads(sj.read_text(encoding="utf-8")) if sj.exists() else []
    recs = [r for r in recs if r.get("file") != file] + [rec]
    sj.write_text(json.dumps(recs, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return rec


def selftest():
    import importlib.util
    sys.dont_write_bytecode = True  # no __pycache__ left in the plugin tree
    spec = importlib.util.spec_from_file_location("check_logos", Path(__file__).with_name("check-logos.py"))
    check_logos = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(check_logos)
    with tempfile.TemporaryDirectory() as t:
        t = Path(t)
        svg = b'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><path d="M0 0h1v1z"/></svg>'
        (t / "src.svg").write_bytes(svg)
        with zipfile.ZipFile(t / "kit.zip", "w") as z:
            z.writestr("Kit/Logo/mark.svg", svg + b" ")
        logos = t / "logos"
        args = dict(name="A", official=True, license="x", guidelines="https://a.example", variant="color", logos=logos)
        fetch("a.svg", (t / "src.svg").as_uri(), **args)
        fetch("a.svg", (t / "src.svg").as_uri(), **dict(args, official=False))  # upsert replaces
        r = fetch("b-mono.svg", (t / "kit.zip").as_uri(), member="Kit/Logo/mark.svg", **dict(args, variant="mono"))
        recs = json.loads((logos / "sources.json").read_text())
        assert [x["file"] for x in recs] == ["a.svg", "b-mono.svg"] and recs[0]["official"] is False, recs
        assert r["source_url"].endswith("kit.zip#Kit/Logo/mark.svg") and r["sha256"] == hashlib.sha256(svg + b" ").hexdigest()
        assert set(r) == set(check_logos.FIELDS), r
        assert check_logos.check(logos) == [], check_logos.check(logos)
        for bad in ("../x.svg", "A.svg", "x.gif"):
            try:
                fetch(bad, (t / "src.svg").as_uri(), **args)
            except ValueError:
                continue
            raise AssertionError(f"accepted file name {bad!r}")
        try:
            fetch("c.png", (t / "src.svg").as_uri(), **args)
            raise AssertionError("saved SVG bytes as .png")
        except ValueError:
            pass
    print("fetch-logo selftest ok")


def main():
    if sys.argv[1:] in (["--selftest"], ["--self-test"]):
        selftest()
        return 0
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("file")
    ap.add_argument("url")
    ap.add_argument("--name", required=True)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--official", dest="official", action="store_true")
    g.add_argument("--unofficial", dest="official", action="store_false")
    ap.add_argument("--license", required=True)
    ap.add_argument("--guidelines", required=True)
    ap.add_argument("--variant", required=True, choices=("color", "mono", "wordmark"))
    ap.add_argument("--member")
    ap.add_argument("--dir", default="deck/assets/logos")
    a = ap.parse_args()
    try:
        rec = fetch(a.file, a.url, a.name, a.official, a.license, a.guidelines, a.variant, a.member, a.dir)
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as e:
        print(f"fetch-logo: {e}", file=sys.stderr)
        return 1
    print(json.dumps(rec, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
