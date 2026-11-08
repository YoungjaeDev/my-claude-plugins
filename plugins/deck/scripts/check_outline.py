"""Check that slide copy in <deck>/sections/*.html also appears verbatim in <deck>/outline.md.

    python3 check_outline.py [DECK_DIR] [--outline FILE]   # default ./deck and DECK_DIR/outline.md
    python3 check_outline.py --selftest

The outline is the copy source (deck-authoring: the outline wins); this catches a section edit that
never reached it. Checked per slide: every h2, p.lead and li, and each text piece of a .fbox
(its <strong>, its own text, its <span>), since outlines list box text as "name(label · note)".
The match is a substring search over the whole outline, so the table layout does not matter.
Outline markup is ignored: backticks, ==highlight== marks, **bold** and __bold__ outside code spans,
the table escape backslash-pipe (read as |) and runs of whitespace. A line break reads
as " / " on both sides (a <br> in the section, " / " or <br> in the outline), so a literal " / " in
slide text needs no escape in the outline; the older &#47; escape still works.
Not checked: <template> panels, <pre>, <svg>, mockups (.term, .tr-win, .browser-win) and
anything under [data-outline-skip].
Exit 1 and print file, slide id, kind and text per miss; exit 2 when a file cannot be read.
Warns only (exit unchanged): an outline row whose 유형 names a flow, order, structure or screen
(흐름, 순서, 구성, 화면) while both its 캡처·목업 and 모션 cells are empty (blank or a dash).
"""
import argparse
import html
import re
import sys
from html.parser import HTMLParser
from pathlib import Path

SKIP_TAGS = {"template", "pre", "svg"}
SKIP_CLASSES = {"term", "tr-win", "browser-win"}
BREAK = "\x00"  # a <br> inside a lead or item; becomes " / " when the text is read
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
            self.flush_piece()  # a line break in a box splits pieces
            if self.buf is not None and not self.skipping():
                self.buf[2] += BREAK  # a lead or item keeps its halves, joined by " / " like the outline
        if tag in VOID:
            return
        self.flush_piece()
        if tag == "math" and not self.skipping():
            alt = a.get("alttext") or ""  # the outline carries the LaTeX, not the MathML text
            if self.buf is not None:
                self.buf[2] += alt
            elif self.piece is not None:
                self.piece += alt
            elif norm(alt):
                self.found.append((self.slide, "math", norm(alt)))  # a standalone block equation
        skip = tag in SKIP_TAGS or tag == "math" or bool(classes & SKIP_CLASSES) or "data-outline-skip" in a
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
            text = re.sub(r"\s*(?:\x00\s*)+", " / ", self.buf[2])
            text = norm(text).strip(" /")
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


BOLD = re.compile(r"\*\*(?=\S)(.+?)(?<=\S)\*\*|(?<!\w)__(?=\S)(.+?)(?<=\S)__(?!\w)")  # __ only at word edges, as in Markdown


def outline_text(text: str) -> str:
    # The outline breaks a line with <br> or " / " (deck-copy); both read as " / ", as a section <br> does.
    # Bold marks drop outside code spans only (`__init__` stays), also when the bold wraps a code span
    # (**`echo` 명령**): code spans are held out as placeholders first. A table cell writes | as \|.
    codes = []
    text = re.sub(r"`([^`]*)`", lambda m: codes.append(m[1]) or f"\0{len(codes) - 1}\0",
                  text.replace("\\|", "|").replace("==", ""))
    text = BOLD.sub(lambda m: m[1] or m[2], text).replace("`", "")
    text = re.sub(r"\0(\d+)\0", lambda m: codes[int(m[1])], text)
    return norm(re.sub(r"\s*<br\s*/?>\s*", " / ", text))


MOVING = re.compile(r"흐름|순서|구성|화면")  # slide types that show a flow, an order, a structure or a screen
EMPTY = {"", "—", "-", "–"}


def motion_gaps(outline: str) -> list:
    """(slide id, type) of outline rows whose 유형 is a flow/order/structure/screen kind and whose
    캡처·목업 and 모션 cells are both empty (deck-authoring: a flow is shown by motion or a mockup)."""
    out, cols = [], None
    for line in outline.splitlines():
        if not line.lstrip().startswith("|"):
            cols = None
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if cols is None:
            cols = cells if {"유형", "캡처·목업", "모션"} <= set(cells) else []
            continue
        if not cols or set("".join(cells)) <= set("-: "):
            continue  # a table without those columns, or the |---| separator
        row = dict(zip(cols, cells))
        kind = row.get("유형", "")
        if MOVING.search(kind) and row.get("캡처·목업", "") in EMPTY and row.get("모션", "") in EMPTY:
            out.append((cells[0], kind))
    return out


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
        ("lead", "리드 <a> / 둘째"), ("li", "항목 밑줄이다."), ("fbox", "moim.example.com"), ("fbox", "IP로"), ("fbox", "바꾼다")], found
    assert {s for _, s, _, _ in found} == {"S9-01"}
    found, _ = misses([("a.html", '<section class="slide" aria-label="S9-02 t"><p class="lead">첫 문장<br>다음 문장</p></section>')],
                      "| S9-02 | 리드: 첫 문장 / 다음 문장 · 첫 문장 <br> 다음 문장 |")
    assert found == [], found
    assert outline_text("첫 문장 <br> 다음 문장") == "첫 문장 / 다음 문장"
    assert outline_text("**프로젝트 밖 폴더**를 설명과 __키__") == "프로젝트 밖 폴더를 설명과 키"
    assert outline_text("`env \\| grep` 과 `__init__`, a**b") == "env | grep 과 __init__, a**b"
    assert outline_text("**`echo` 명령**과 **`__init__` 파일**") == "echo 명령과 __init__ 파일"
    # A literal " / " in slide text needs no escape; a <br> in the section still matches the outline's " / ".
    slash = ('<section class="slide" aria-label="S9-05 t"><p class="lead">홈과<br>메뉴의 ABOUT / BRAND 페이지</p>'
             '<li>구글 / 네이버</li><li>끝<br></li></section>')
    found, total = misses([("s.html", slash)], "| S9-05 | 리드: 홈과 / 메뉴의 ABOUT / BRAND 페이지<br>- 구글 / 네이버<br>- 끝 |")
    assert found == [] and total == 3, (found, total)
    found, _ = misses([("s.html", slash)], "| S9-05 | 홈과 / 메뉴의 ABOUT &#47; BRAND 페이지 / 구글 &#47; 네이버 / 끝 |")
    assert found == [], found  # decks that escaped the slash as &#47; keep passing
    # MathML: the outline holds the LaTeX in alttext; the MathML text inside is skipped.
    math = ('<section class="slide" aria-label="S9-03 t"><li>은닉 상태는 <math alttext="h_t = \\tanh(x_t)"><msub><mi>h</mi>'
            '<mi>t</mi></msub></math> 로 이어진다.</li></section>')
    found, total = misses([("m.html", math)], "| S9-03 | 은닉 상태는 h_t = \\tanh(x_t) 로 이어진다. |")
    assert found == [] and total == 1, (found, total)
    box = ('<section class="slide" aria-label="S9-04 t"><div class="fbox"><strong>상태</strong>'
           '<math alttext="x"><mi>x</mi></math></div>'
           '<div class="equation"><math display="block" alttext="y = Wx"><mi>y</mi></math></div></section>')
    found, total = misses([("m.html", box)], "| S9-04 | 상태 |")
    assert [(k, t) for _, _, k, t in found] == [("fbox", "x"), ("math", "y = Wx")] and total == 3, (found, total)
    found, _ = misses([("m.html", box)], "| S9-04 | 상태 x y = Wx |")
    assert found == [], found
    # A flow, order, structure or screen slide gets a motion or a mockup; both cells empty is a warning.
    table = "\n".join([
        "| ID | 유형 | 라벨 | 제목 | 본문 | 캡처·목업 | 패널 | 모션 |", "|---|---|---|---|---|---|---|---|",
        "| S1-01 | 흐름 | — | a | b | — | — | — |",
        "| S1-02 | 개념(순서) | — | a | b | `.boxflow` 상자 | — | — |",
        "| S1-03 | 목업(구성도) | — | a | b |  | — | `hops` |",
        "| S1-04 | 화면 | — | a | b | - | — | - |",
        "| S1-05 | 비교 | — | a | b | — | — | — |",
        "| 장 | 패널 ID | 종류 |", "|---|---|---|", "| S1-01 | `p-1` | prompt |",
    ])
    assert motion_gaps(table) == [("S1-01", "흐름"), ("S1-04", "화면")], motion_gaps(table)
    assert motion_gaps("| ID | 제목 |\n|---|---|\n| S1-01 | 흐름 |") == []  # no 유형/모션 columns: nothing to judge
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
    for sid, kind in motion_gaps(outline):
        print(f"outline: warning {sid} {kind}: no mockup and no motion; show a flow, order, structure or screen "
              "with a motion or a mockup (캡처·목업 or 모션 column)")
    print(f"outline: {len(found)} missing of {total}")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
