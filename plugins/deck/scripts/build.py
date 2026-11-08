"""Concatenate <deck>/sections/*.html into <deck>/shell.html -> <deck>/index.html.

    python3 build.py [DECK_DIR]      # default ./deck; prints "slides: N", then any page-reference warnings
    python3 build.py --selftest

A page reference in slide text, "(N쪽)" or "N~M쪽", gets a "warn:" line when N is outside 1..slides or
lands on the cover, the agenda or a section cover. Warnings only: the exit code stays 0.
"""
import re
import sys
from pathlib import Path

_SECTION_OPEN_RE = re.compile(r"<section\b")
_SLIDE_RE = re.compile(r'<section class="slide[ "]')
_PAGE_REF_RE = re.compile(r"\((\d+)쪽\)|(\d+)\s*~\s*(\d+)쪽")
_SKIP_RE = re.compile(r"<(script|style)\b.*?</\1>|<!--.*?-->", re.S)


def _tag_sections(text: str, filename: str) -> str:
    """Inject data-src/data-idx onto each <section> (dev mode only)."""
    idx = 0

    def repl(match: "re.Match[str]") -> str:
        nonlocal idx
        tagged = f'{match.group(0)} data-src="{filename}" data-idx="{idx}"'
        idx += 1
        return tagged

    return _SECTION_OPEN_RE.sub(repl, text)


def assemble(sections_dir: Path, shell_path: Path, *, tag_sections: bool = False) -> str:
    """Build the deck HTML by splicing sections/*.html into shell.html.

    tag_sections=True is dev-only: it adds data-src/data-idx attributes so
    the dev server can map an edited <section> back to its source file.
    """
    parts = []
    for path in sorted(sections_dir.glob("*.html")):
        text = path.read_text(encoding="utf-8")
        if tag_sections:
            text = _tag_sections(text, path.name)
        parts.append(text)
    sections_html = "\n".join(parts)
    shell = shell_path.read_text(encoding="utf-8")
    motions = "\n".join(f'  <script src="motions/{m.name}"></script>'
                        for m in sorted((shell_path.parent / "motions").glob("*.js")))
    return shell.replace("<!-- SECTIONS -->", sections_html).replace("<!-- MOTION_SCRIPTS -->", motions)


def page_ref_warnings(html: str) -> list:
    """One line per "(N쪽)" or "N~M쪽" in slide text that names no slide or a cover, agenda or section cover."""
    starts = [m.start() for m in _SLIDE_RE.finditer(html)]
    slides = [html[a:b] for a, b in zip(starts, starts[1:] + [len(html)])]
    if slides:  # the last slide runs into the shell's closing scripts
        slides[-1] = slides[-1][: slides[-1].find("</section>") + 10]

    def kind(i: int) -> str:
        classes = re.match(r'<section class="([^"]*)"', slides[i - 1])[1].split()
        if "cover" in classes:
            return "cover"
        if "section-cover" in classes:
            return "section cover"
        return "agenda" if re.search(r'<ol class="agenda\b', slides[i - 1]) else ""

    out = []
    for i, slide in enumerate(slides, 1):
        text = re.sub(r"<[^>]+>", "", _SKIP_RE.sub("", slide))
        label = re.search(r'aria-label="([^"]*)"', slide)
        where = f"slide {i}" + (f" ({label[1]})" if label else "")
        for m in _PAGE_REF_RE.finditer(text):
            for n in (int(g) for g in m.groups() if g):
                if not 1 <= n <= len(slides):
                    out.append(f"warn: {where}: '{m[0]}' names slide {n}, the deck has {len(slides)}")
                elif kind(n):
                    out.append(f"warn: {where}: '{m[0]}' names slide {n}, which is the {kind(n)}")
    return out


def selftest() -> None:
    sec = lambda cls, body: f'<section class="slide{cls}" aria-label="x">{body}</section>\n'
    html = ("<html>" + sec(" cover backdrop", "표지") + sec("", '<h2>목차</h2><ol class="agenda"></ol>')
            + sec(" section-cover", "S1") + sec("", "본문 (4쪽) 4~5쪽 (9쪽) (1쪽) 2~3쪽 인쇄 12쪽")
            + sec("", "끝") + "<script>var a = '(40쪽)';</script></html>")
    w = page_ref_warnings(html)
    assert len(w) == 4, w
    assert "names slide 9, the deck has 5" in w[0] and "slide 4 (x)" in w[0]
    assert "slide 1, which is the cover" in w[1]
    assert "slide 2, which is the agenda" in w[2] and "slide 3, which is the section cover" in w[3]
    assert "'2~3쪽'" in w[3] and "'2~3쪽'" in w[2]
    assert page_ref_warnings(sec("", "(1쪽)")) == []
    print("build selftest OK")


def main(argv: list) -> int:
    if "--selftest" in argv:
        selftest()
        return 0
    deck = Path(argv[1] if len(argv) > 1 else "deck")
    if not (deck / "shell.html").is_file() or not (deck / "sections").is_dir():
        print(f"not a deck directory (needs shell.html and sections/): {deck}", file=sys.stderr)
        return 2
    html = assemble(deck / "sections", deck / "shell.html")
    (deck / "index.html").write_text(html, encoding="utf-8")
    print("slides:", html.count('<section class="slide'))
    for line in page_ref_warnings(html):
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
