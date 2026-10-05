"""Concatenate <deck>/sections/*.html into <deck>/shell.html -> <deck>/index.html.

    python3 build.py [DECK_DIR]      # default ./deck; prints "slides: N"
"""
import re
import sys
from pathlib import Path

_SECTION_OPEN_RE = re.compile(r"<section\b")


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


def main(argv: list) -> int:
    deck = Path(argv[1] if len(argv) > 1 else "deck")
    if not (deck / "shell.html").is_file() or not (deck / "sections").is_dir():
        print(f"not a deck directory (needs shell.html and sections/): {deck}", file=sys.stderr)
        return 2
    html = assemble(deck / "sections", deck / "shell.html")
    (deck / "index.html").write_text(html, encoding="utf-8")
    print("slides:", html.count('<section class="slide'))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
