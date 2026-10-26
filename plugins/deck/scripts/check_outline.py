"""Check that slide copy in <deck>/sections/*.html also appears verbatim in <deck>/outline.md.

    python3 check_outline.py [DECK_DIR] [--outline FILE]   # default ./deck and DECK_DIR/outline.md
    python3 check_outline.py --selftest

The outline is the copy source (deck-authoring: the outline wins); this catches a section edit that
never reached it. Checked per slide: every h2, p.lead and li, and each text piece of a .fbox
(its <strong>, its own text, its <span>), since outlines list box text as "name(label · note)".
The match is a substring search over the whole outline, so the table layout does not matter.
Outline markup is ignored: backticks, ==highlight== marks, <br> and runs of whitespace.
Not checked: <template> panels, <pre>, <svg>, mockups (.term, .tr-win, .browser-win) and
anything under [data-outline-skip].
Exit 1 and print file, slide id, kind and text per miss; exit 2 when a file cannot be read.
"""
import argparse
import html
import re
import sys
from html.parser import HTMLParser
from pathlib import Path

SKIP_TAGS = {"template", "pre", "svg"}
SKIP_CLASSES = {"term", "tr-win", "browser-win"}
VOID = {"img", "br", "input", "meta", "link", "hr", "source", "wbr", "area", "col", "embed", "track"}


def norm(text: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(text)).strip()


class Texts(HTMLParser):
    """Collects (slide id, kind, text) for h2, p.lead, li and .fbox pieces outside skipped containers."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []  # (tag, skip, is_fbox) per open element
        self.slide = ""
        self.buf = None  # [tag, depth, text] for the open h2/lead/li
        self.piece = None  # text of the current .fbox piece, or None outside a box
        self.found = []

    def skipping(self) -> bool:
        return any(skip for _, skip, _ in self.stack)

    def in_fbox(self) -> bool:
        return any(box for _, _, box in self.stack)

    def flush_piece(self) -> None:
        if self.piece is not None:
            text = norm(self.piece)
            if text:
                self.found.append((self.slide, "fbox", text))
            self.piece = ""

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        classes = set((a.get("class") or "").split())
        if tag == "section" and "slide" in classes:
            self.slide = (a.get("aria-label") or "").split(" ")[0]
        if tag == "br":
            self.flush_piece()  # a line break in a box splits pieces; a lead keeps joining its halves
        if tag in VOID:
            return
        self.flush_piece()
        skip = tag in SKIP_TAGS or bool(classes & SKIP_CLASSES) or "data-outline-skip" in a
        box = "fbox" in classes
        self.stack.append((tag, skip, box))
        if self.skipping():
            return
        if box and self.piece is None:
            self.piece = ""
        if self.buf is None and not self.in_fbox() and (tag in ("h2", "li") or (tag == "p" and "lead" in classes)):
            self.buf = [tag, len(self.stack), ""]

    def handle_endtag(self, tag):
        if tag in VOID:
            return
        self.flush_piece()
        if self.buf and len(self.stack) == self.buf[1] and tag == self.buf[0]:
            text = norm(self.buf[2])
            if text:
                self.found.append((self.slide, tag if tag != "p" else "lead", text))
            self.buf = None
        while self.stack:
            if self.stack.pop()[0] == tag:
                break
        if not self.in_fbox():
            self.piece = None

    def handle_data(self, data):
        if self.skipping():
            return
        if self.buf is not None:
            self.buf[2] += data
        if self.piece is not None:
            self.piece += data


def outline_text(text: str) -> str:
    # A lead may break at <br> or the outline's " / " (deck-copy); the section text joins the halves without a space.
    return norm(re.sub(r"\s*<br\s*/?>\s*|\s+/\s+", "", text.replace("==", "").replace("`", "")))


def misses(sections: list, outline: str) -> tuple:
    """(missing [(file, slide, kind, text)], number of texts checked)."""
    hay = outline_text(outline)
    out, total = [], 0
    for name, source in sections:
        p = Texts()
        p.feed(source)
        p.close()
        total += len(p.found)
        out += [(name, sid, kind, t) for sid, kind, t in p.found if t not in hay]
    return out, total


def selftest() -> None:
    section = ('<section class="slide" aria-label="S9-01 t"><h2>제목 하나</h2><p class="lead">리드 &lt;a&gt;<br>둘째</p>'
               '<ul class="points"><li>항목 <span class="mark">밑줄</span>이다.</li></ul>'
               '<div class="boxflow"><div class="fbox on"><strong>moim.example.com</strong>도메인<span class="out">IP로<br>바꾼다</span></div></div>'
               '<div class="term"><pre>무시</pre></div><div data-outline-skip><li>무시</li></div>'
               '<template class="panel"><p class="lead">무시</p></template></section>')
    full = ("| S9-01 | 제목 하나 | 리드: 리드 `<a>`<br>둘째 / 항목 ==밑줄==이다. | "
            "`.boxflow` moim.example.com(도메인 · IP로 바꾼다) |")
    found, total = misses([("a.html", section)], full)
    assert found == [] and total == 7, (found, total)
    found, _ = misses([("a.html", section)], "| S9-01 | 제목 하나 | 도메인 |")
    assert [(k, t) for _, _, k, t in found] == [
        ("lead", "리드 <a>둘째"), ("li", "항목 밑줄이다."), ("fbox", "moim.example.com"), ("fbox", "IP로"), ("fbox", "바꾼다")], found
    assert {s for _, s, _, _ in found} == {"S9-01"}
    found, _ = misses([("a.html", '<section class="slide" aria-label="S9-02 t"><p class="lead">첫 문장<br>다음 문장</p></section>')],
                      "| S9-02 | 리드: 첫 문장 / 다음 문장 · 첫 문장 <br> 다음 문장 |")
    assert found == [], found
    assert outline_text("첫 문장 <br> 다음 문장") == "첫 문장다음 문장"
    # Unclosed tags and stray end tags must not raise.
    misses([("b.html", '<section class="slide" aria-label="X"><li>열림</div></p>')], "열림")
    # A section that is not UTF-8 exits 2 and names the file.
    import subprocess, tempfile
    with tempfile.TemporaryDirectory() as t:
        (Path(t) / "sections").mkdir()
        (Path(t) / "outline.md").write_text("x", encoding="utf-8")
        (Path(t) / "sections" / "bad.html").write_bytes(b"\xff\xfe")
        r = subprocess.run([sys.executable, "-I", __file__, t], capture_output=True, text=True)
        assert r.returncode == 2 and "bad.html" in r.stderr, (r.returncode, r.stderr)
    print("check_outline selftest OK")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("deck_dir", nargs="?", default="deck")
    ap.add_argument("--outline", help="outline file (default DECK_DIR/outline.md)")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()
    if args.selftest:
        selftest()
        return 0
    deck = Path(args.deck_dir).resolve()
    outline_path = Path(args.outline) if args.outline else deck / "outline.md"
    files = sorted((deck / "sections").glob("*.html"))
    if not files:
        print(f"outline: no {deck / 'sections'}/*.html; pass the deck directory", file=sys.stderr)
        return 2
    path, sections = outline_path, []
    try:  # UnicodeDecodeError has no .filename, so track the file being read
        outline = outline_path.read_text(encoding="utf-8")
        for path in files:
            sections.append((path.name, path.read_text(encoding="utf-8")))
    except (OSError, UnicodeDecodeError) as error:
        print(f"outline: cannot read {path}: {error}", file=sys.stderr)
        return 2
    found, total = misses(sections, outline)
    for name, sid, kind, text in found:
        print(f"outline: {name} {sid or '-'} {kind} not in {outline_path.name}: {text}")
    if total and len(found) == total:
        print(f"outline: none of the {total} texts is in {outline_path}. Section text must appear there verbatim "
              "(table cells, lists or prose all work); check the path or the outline format.")
    print(f"outline: {len(found)} missing of {total}")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
