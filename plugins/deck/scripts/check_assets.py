"""Check deck images and the asset paths the deck loads. Exit 1 on a failure, 2 on an unreadable deck.

    python3 check_assets.py [DECK_DIR] [--staged]    # DECK_DIR default ./deck
    python3 check_assets.py --selftest

Fails on:
  - a file named like a raw OS screenshot (스크린샷*, Screenshot*, Screen Shot*) or a .zip archive;
  - an image under DECK/assets/ whose nearest captures.md (its own folder, or a parent folder up to
    assets/) has no table row naming the file. captures.md is the deck's record of what a capture
    shows and what was blurred, so a folder opts in by holding one;
  - an assets/... image path in sections/*.html, shell.html or motions/*.js that does not exist.
Warns only: an image under assets/ that no section, shell or motion names by path or by file name
(the shell builds logo paths from bare file names at runtime).

Without --staged every check reads the working tree, and the name check covers DECK/assets/.
With --staged (the pre-commit hook) the name check covers every staged path in the repo, and the
other checks read the git index, so they judge what the commit holds. They run only when the
commit touches DECK.
"""
import argparse
import contextlib
import io
import posixpath
import re
import subprocess
import sys
import tempfile
import unicodedata
from pathlib import Path
from urllib.parse import unquote

IMAGE = (".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg", ".avif")
RAW = ("스크린샷", "screenshot", "screen shot")
REF = re.compile(r"assets/[^\"'<>()?#\s`\\]+")


def nfc(s: str) -> str:
    return unicodedata.normalize("NFC", s)  # macOS can hand out decomposed Hangul file names


def raw_name(path: str) -> bool:
    name = nfc(posixpath.basename(path)).lower()
    return name.startswith(RAW) or name.endswith(".zip")


def raw_fails(paths) -> list:
    return [f"{p}: raw screenshot or archive, keep it outside the repo" for p in sorted(paths) if raw_name(p)]


def is_image(path: str) -> bool:
    return path.lower().endswith(IMAGE)


def sources_of(paths) -> list:
    """sections/*.html, shell.html, motions/*.js among deck-relative paths."""
    return sorted(p for p in paths if p == "shell.html"
                  or re.fullmatch(r"sections/[^/]+\.html", p) or re.fullmatch(r"motions/[^/]+\.js", p))


def problems(files: set, read, sources: list) -> tuple:
    """(failures, unused) for deck-relative asset paths `files`; read(path) gives text or None."""
    fail = []
    text = "\n".join(read(s) or "" for s in sources)
    for img in sorted(p for p in files if is_image(p)):
        folder = posixpath.dirname(img)
        while folder.startswith("assets") and f"{folder}/captures.md" not in files:
            folder = posixpath.dirname(folder)
        if not folder.startswith("assets"):
            continue
        log = f"{folder}/captures.md"
        row = re.compile(r"(?<![\w.-])" + re.escape(nfc(posixpath.basename(img))) + r"(?![\w.-])")
        if not any(l.lstrip().startswith("|") and row.search(l) for l in nfc(read(log) or "").splitlines()):
            fail.append(f"{img}: no row in {log} (what it shows, when, what was blurred)")
    for ref in sorted(set(REF.findall(text))):
        path = posixpath.normpath(unquote(ref))
        if is_image(path) and path not in files:
            fail.append(f"{ref}: referenced but missing")
    named = nfc(text + "\n" + unquote(text))
    unused = [p for p in sorted(files) if is_image(p) and p not in named and nfc(posixpath.basename(p)) not in named]
    return fail, unused


def git(deck: Path, *args) -> str:
    return subprocess.run(["git", "-C", str(deck), *args], capture_output=True, text=True, check=True).stdout


def run(deck: Path, staged: bool) -> int:
    if not (deck / "sections").is_dir():
        print(f"no sections/ under {deck}", file=sys.stderr)
        return 2
    if staged:
        try:
            names = [p for p in git(deck, "diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z").split("\0") if p]
            prefix = git(deck, "rev-parse", "--show-prefix").strip()
            fail = raw_fails(names)
            if not any(p.startswith(prefix) for p in names):
                for line in fail:
                    print(line)
                print(f"assets: {len(fail)} failed (commit does not touch {prefix or 'the deck'})")
                return 1 if fail else 0
            indexed = [p for p in git(deck, "ls-files", "-z", "--", ".").split("\0") if p]
        except (OSError, subprocess.CalledProcessError) as exc:
            print(f"--staged needs a git repo: {exc}", file=sys.stderr)
            return 2
        files = {p for p in indexed if p.startswith("assets/")}
        sources = sources_of(indexed)

        def read(p):
            try:
                return git(deck, "show", f":./{p}")
            except subprocess.CalledProcessError:
                return None
    else:
        files = {p.relative_to(deck).as_posix() for p in (deck / "assets").rglob("*") if p.is_file()}
        fail = raw_fails(files)
        found = [*deck.glob("sections/*.html"), deck / "shell.html", *deck.glob("motions/*.js")]
        sources = sources_of(p.relative_to(deck).as_posix() for p in found if p.is_file())

        def read(p):
            try:
                return (deck / p).read_text(encoding="utf-8")
            except OSError:
                return None
    more, unused = problems(files, read, sources)
    fail += more
    for line in fail:
        print(line)
    if unused:
        print(f"unused ({len(unused)}, warning only): {', '.join(unused)}")
    print(f"assets: {len(fail)} failed, {len(unused)} unused, {len(files)} files under assets/")
    return 1 if fail else 0


def selftest() -> None:
    def tree(files):
        return set(files), files.get
    files, read = tree({
        "shell.html": '<img src="assets/logos/${f}"> SECTIONS logos: ["react.svg"]',
        "sections/01.html": '<img src="assets/shots/a.png"><img src="assets/shots/gone.png">'
                            '<img src="assets/x/%ED%95%9C.png">',
        "motions/m.js": "url('assets/shots/sub/b.png')",
        "assets/shots/captures.md": "| 파일 | 화면 |\n|---|---|\n| `a.png` | 피드 |\nsub/b.png 는 표 밖",
        "assets/shots/a.png": "", "assets/shots/sub/b.png": "", "assets/shots/c.png": "",
        "assets/logos/react.svg": "", "assets/logos/vite.svg": "", "assets/x/한.png": "",
        "assets/Screenshot 2026.png": "", "assets/raw.ZIP": "",
    })
    assets = {p for p in files if p.startswith("assets/")}
    fail, unused = problems(assets, read, sources_of(files))
    fail += raw_fails(assets)
    assert sorted(fail) == sorted([
        "assets/Screenshot 2026.png: raw screenshot or archive, keep it outside the repo",
        "assets/raw.ZIP: raw screenshot or archive, keep it outside the repo",
        "assets/shots/sub/b.png: no row in assets/shots/captures.md (what it shows, when, what was blurred)",
        "assets/shots/c.png: no row in assets/shots/captures.md (what it shows, when, what was blurred)",
        "assets/shots/gone.png: referenced but missing",
    ]), fail
    assert unused == ["assets/Screenshot 2026.png", "assets/logos/vite.svg", "assets/shots/c.png"], unused
    assert raw_name(unicodedata.normalize("NFD", "x/스크린샷 2026-10-27.png")) and not raw_name("a/screen.png")
    # --staged reads the index: a row only in the working tree, or an unstaged image, does not count.
    with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
        repo = Path(tmp)
        g = lambda *a: subprocess.run(["git", "-C", tmp, *a], capture_output=True, check=True)
        g("init", "-q")
        (repo / "deck/sections").mkdir(parents=True)
        (repo / "deck/assets/shots").mkdir(parents=True)
        (repo / "deck/sections/01.html").write_text('<img src="assets/shots/a.png">', encoding="utf-8")
        (repo / "deck/assets/shots/a.png").write_bytes(b"")
        (repo / "deck/assets/shots/captures.md").write_text("| 파일 |\n|---|\n", encoding="utf-8")
        g("add", "deck")
        (repo / "deck/assets/shots/captures.md").write_text("| 파일 |\n|---|\n| `a.png` |\n", encoding="utf-8")
        assert run(repo / "deck", staged=False) == 0
        assert run(repo / "deck", staged=True) == 1
        g("add", "deck")
        assert run(repo / "deck", staged=True) == 0
        (repo / "스크린샷 1.png").write_bytes(b"")
        g("reset", "-q")
        g("add", "스크린샷 1.png")
        assert run(repo / "deck", staged=True) == 1  # caught even when the commit leaves deck/ alone
    print("check_assets selftest OK")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("deck_dir", nargs="?", default="deck")
    ap.add_argument("--staged", action="store_true", help="read the git index, as the pre-commit hook does")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()
    if args.selftest:
        selftest()
        return 0
    return run(Path(args.deck_dir).resolve(), args.staged)


if __name__ == "__main__":
    sys.exit(main())
