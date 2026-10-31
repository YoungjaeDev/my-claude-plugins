"""Scaffold a deck repo and keep its rule copies in step with this plugin.

    python3 kit.py new   [REPO] [--template NAME] # REPO/deck from templates/decks/NAME (default monitor) + stamped rule copies + .githooks; refuses if REPO/deck exists
    python3 kit.py sync  [REPO] [--force] # rewrite rule copies + deck/vendor, add missing .githooks, print the shell.html diff (never writes shell)
    python3 kit.py check [REPO] [--diff]  # rule copies, vendor, shell base; exit 1 on drift
    python3 kit.py prereq                 # is the frontend-slides plugin installed? warning only, always exit 0
    python3 kit.py --selftest

REPO defaults to the current directory. A deck template is a folder under templates/decks/; its
rules/ subfolder holds the template's own rule originals and is not copied into the deck; its brand.txt names a
folder under templates/brands/ that goes to deck/brand/ and that sync overwrites like vendor/. sync and
check read the template name from the shell stamp; a stamp without a name is an older monitor deck.
Rule templates are templates/rules/*.md plus templates/decks/NAME/rules/*.md; each copy in
REPO/.claude/rules/ gets STAMP inserted right after its YAML frontmatter. A copy is compared by
re-stamping the template with the copy's own version, so no unstamping heuristics are needed.
REPO/.claude/rules/deck-local.md is the deck's own file and is never read or written here.
templates/githooks/* (the `deck` launcher, pre-commit, commit-msg) go to REPO/.githooks/ only when
missing; an existing hook is never overwritten, and git config is left to the user.
"""
import difflib
import json
import os
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEMPLATE_DECKS = ROOT / "templates" / "decks"
TEMPLATE_BRANDS = ROOT / "templates" / "brands"
DEFAULT_TEMPLATE = "monitor"
TEMPLATE_RULES = ROOT / "templates" / "rules"
TEMPLATE_HOOKS = ROOT / "templates" / "githooks"
LOCAL_RULE = "deck-local.md"
STAMP = "> deck 플러그인 {v} 사본. 고칠 때는 플러그인 원본을 고친다."
STAMP_RE = re.compile(r"^> deck 플러그인 (\S+) 사본\.", re.M)
SHELL_STAMP = "<!-- deck shell base {t} {v} -->"
# The template name is optional: decks scaffolded before templates existed carry only the version.
SHELL_STAMP_RE = re.compile(r"^<!-- deck shell base (?:([a-z][a-z0-9-]*) )?(\S+) -->\n", re.M)
FRONTEND_SLIDES_INSTALL = ("/plugin marketplace add zarazhangrui/frontend-slides",
                           "/plugin install frontend-slides@frontend-slides")


def version() -> str:
    return json.loads((ROOT / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8"))["version"]


def stamp(text: str, v: str) -> str:
    """Insert the stamp line right after the frontmatter (or at the top when there is none)."""
    m = re.match(r"---\n.*?\n---\n", text, re.S)
    head, body = (text[: m.end()], text[m.end():]) if m else ("", text)
    return head + STAMP.format(v=v) + "\n" + (body if body.startswith("\n") else "\n" + body)


def templates() -> list:
    # Only names the stamp regex reads back, and shells new can stamp; anything else would sync as monitor.
    return sorted(p.name for p in TEMPLATE_DECKS.iterdir()
                  if re.fullmatch(r"[a-z][a-z0-9-]*", p.name) and (p / "shell.html").is_file()
                  and (p / "shell.html").read_text(encoding="utf-8").startswith("<!DOCTYPE html>\n"))


def shell_base(text: str):
    """(template, version) from a shell stamp, or None when the shell has no stamp."""
    m = SHELL_STAMP_RE.search(text)
    return (m[1] or DEFAULT_TEMPLATE, m[2]) if m else None


def deck_template(deck: Path) -> str:
    """The template a deck was scaffolded from; an unstamped shell counts as the default."""
    base = shell_base((deck / "shell.html").read_text(encoding="utf-8"))
    return base[0] if base else DEFAULT_TEMPLATE


def rule_templates(template: str) -> list:
    rules = list(TEMPLATE_RULES.glob("*.md")) + list((TEMPLATE_DECKS / template / "rules").glob("*.md"))
    return sorted((p for p in rules if p.name != LOCAL_RULE), key=lambda p: p.name)


def rule_status(repo: Path, v: str, template: str) -> list:
    """(name, status, copy_version) per template: ok | missing | stale | edited | unstamped | bare.

    bare: no stamp, but otherwise the template itself (a copy made by hand); safe to stamp.
    """
    out = []
    for tpl in rule_templates(template):
        copy = repo / ".claude" / "rules" / tpl.name
        if not copy.is_file():
            out.append((tpl.name, "missing", None))
            continue
        text = copy.read_text(encoding="utf-8")
        m = STAMP_RE.search(text)
        if not m:
            same = text.strip() == tpl.read_text(encoding="utf-8").strip()
            out.append((tpl.name, "bare" if same else "unstamped", None))
        elif m[1] != v:
            out.append((tpl.name, "stale", m[1]))
        elif text != stamp(tpl.read_text(encoding="utf-8"), v):
            out.append((tpl.name, "edited", m[1]))
        else:
            out.append((tpl.name, "ok", m[1]))
    return out


def write_rules(repo: Path, v: str, force: bool, template: str) -> int:
    """Write every rule copy except ones edited by hand at the current version (unless forced)."""
    dest = repo / ".claude" / "rules"
    dest.mkdir(parents=True, exist_ok=True)
    sources = {p.name: p for p in rule_templates(template)}
    blocked = 0
    for name, status, _ in rule_status(repo, v, template):
        if status == "ok":
            print(f"rules: {name} ok ({v})")
            continue
        if status in ("edited", "unstamped") and not force:
            print(f"rules: {name} {status}: left as is. Move deck-specific lines to .claude/rules/{LOCAL_RULE}, then rerun with --force")
            blocked += 1
            continue
        (dest / name).write_text(stamp(sources[name].read_text(encoding="utf-8"), v), encoding="utf-8")
        print(f"rules: {name} ok (stamped {v}, content was the template)" if status == "bare"
              else f"rules: {name} written ({status} -> {v})")
    return blocked


def write_hooks(repo: Path) -> None:
    """Copy each missing templates/githooks file into REPO/.githooks; never overwrite."""
    dest = repo / ".githooks"
    dest.mkdir(exist_ok=True)
    for src in sorted(TEMPLATE_HOOKS.iterdir()):
        target = dest / src.name
        if target.exists():
            print(f"githooks: {src.name} exists, left as is")
            continue
        shutil.copyfile(src, target)
        target.chmod(0o755)
        print(f"githooks: {src.name} written")
    print("githooks: enable with `git config core.hooksPath .githooks`; tools: `sh .githooks/deck <command>`")


def brand_of(template: str):
    """The brand a template uses (its brand.txt), or None for a template that carries its own look."""
    f = TEMPLATE_DECKS / template / "brand.txt"
    return f.read_text(encoding="utf-8").strip() if f.is_file() else None


def brand_drift(deck: Path) -> list:
    """Brand files (paths relative to the brand folder) that deck/brand/ lacks or holds in another version."""
    b = brand_of(deck_template(deck))
    if not b:
        return []
    src = TEMPLATE_BRANDS / b
    return [p.relative_to(src).as_posix() for p in sorted(src.rglob("*"))
            if p.is_file() and (not (deck / "brand" / p.relative_to(src)).is_file()
                                or (deck / "brand" / p.relative_to(src)).read_bytes() != p.read_bytes())]


def vendor_drift(deck: Path) -> list:
    src = TEMPLATE_DECKS / deck_template(deck) / "vendor"
    return [p.name for p in sorted(src.iterdir())
            if not (deck / "vendor" / p.name).is_file() or (deck / "vendor" / p.name).read_bytes() != p.read_bytes()]


def shell_diff(deck: Path) -> list:
    tpl = (TEMPLATE_DECKS / deck_template(deck) / "shell.html").read_text(encoding="utf-8")
    cur = SHELL_STAMP_RE.sub("", (deck / "shell.html").read_text(encoding="utf-8"))
    return list(difflib.unified_diff(tpl.splitlines(True), cur.splitlines(True), "template/shell.html", "deck/shell.html"))


def frontend_slides() -> str:
    """Where frontend-slides is installed, or '' when no runtime records it."""
    home = Path(os.environ.get("HOME") or os.environ.get("USERPROFILE") or Path.home())
    try:
        installed = json.loads((home / ".claude" / "plugins" / "installed_plugins.json").read_text(encoding="utf-8"))
        for key, entries in (installed.get("plugins") or {}).items():
            if key.split("@")[0] == "frontend-slides" and entries:
                return f"Claude Code {key} {entries[0].get('version', '?')}"
    except (OSError, ValueError, AttributeError):
        pass
    for cache in (home / ".claude" / "plugins" / "cache", home / ".codex" / "plugins" / "cache"):
        hits = sorted(cache.glob("*/frontend-slides")) if cache.is_dir() else []
        if hits:
            return f"cache {hits[0]}"
    return ""


def prereq() -> None:
    where = frontend_slides()
    if where:
        print(f"frontend-slides: installed ({where})")
    else:
        print("frontend-slides: missing (warning only; the deck builds without it). Install in Claude Code with:")
        for cmd in FRONTEND_SLIDES_INSTALL:
            print(f"  {cmd}")


def cmd_new(repo: Path, v: str, template: str) -> int:
    if template not in templates():
        print(f"[abort] no deck template {template!r}. Templates: {', '.join(templates())}", file=sys.stderr)
        return 2
    deck = repo / "deck"
    if deck.exists():
        print(f"[abort] {deck} already exists. Use deck-sync to update rule copies instead.", file=sys.stderr)
        return 1
    src = TEMPLATE_DECKS / template
    # rules/ holds the template's rule originals, which go to .claude/rules/ stamped, not into the deck;
    # brand.txt names the brand folder that goes to deck/brand/.
    skip = shutil.ignore_patterns("__pycache__", ".DS_Store")
    shutil.copytree(src, deck, ignore=lambda d, names: set(skip(d, names)) | ({"rules", "brand.txt"} if Path(d) == src else set()))
    if brand_of(template):
        shutil.copytree(TEMPLATE_BRANDS / brand_of(template), deck / "brand", ignore=skip)
    shell = deck / "shell.html"
    text = shell.read_text(encoding="utf-8")
    shell.write_text(text.replace("<!DOCTYPE html>\n", "<!DOCTYPE html>\n" + SHELL_STAMP.format(t=template, v=v) + "\n", 1), encoding="utf-8")
    print(f"deck: scaffolded {deck} from templates/decks/{template} ({v})")
    blocked = write_rules(repo, v, force=False, template=template)
    write_hooks(repo)
    prereq()
    return 1 if blocked else 0


def cmd_sync(repo: Path, v: str, force: bool) -> int:
    deck = repo / "deck"
    if not (deck / "shell.html").is_file():
        print(f"[abort] no deck at {deck}. Use deck-new first.", file=sys.stderr)
        return 1
    template = deck_template(deck)
    if template not in templates():
        print(f"[abort] deck/shell.html names template {template!r}, not in this plugin. Templates: {', '.join(templates())}", file=sys.stderr)
        return 1
    print(f"template: {template}")
    blocked = write_rules(repo, v, force, template)
    write_hooks(repo)
    for name in vendor_drift(deck):
        (deck / "vendor").mkdir(exist_ok=True)
        shutil.copy2(TEMPLATE_DECKS / template / "vendor" / name, deck / "vendor" / name)
        print(f"vendor: {name} updated")
    for rel in brand_drift(deck):
        (deck / "brand" / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(TEMPLATE_BRANDS / brand_of(template) / rel, deck / "brand" / rel)
        print(f"brand: {rel} updated")
    diff = shell_diff(deck)
    print(f"shell.html: {'same as template' if not diff else f'differs from template ({len(diff)} diff lines, not written)'}")
    sys.stdout.writelines(diff)
    return 1 if blocked else 0


def cmd_check(repo: Path, v: str, show_diff: bool) -> int:
    deck = repo / "deck"
    template = deck_template(deck) if (deck / "shell.html").is_file() else DEFAULT_TEMPLATE
    if template not in templates():
        print(f"shell.html: names template {template!r}, not in this plugin. Templates: {', '.join(templates())}")
        return 1
    sources = {p.name: p for p in rule_templates(template)}
    bad = 0
    for name, status, cv in rule_status(repo, v, template):
        hint = {"ok": "", "missing": " -> run deck-sync", "stale": f" (copy {cv}, plugin {v}) -> run deck-sync",
                "edited": " (hand-edited at the current version) -> move deck lines to deck-local.md",
                "unstamped": " (no stamp) -> run deck-sync --force after review",
                "bare": " (no stamp, same as template) -> run deck-sync"}[status]
        print(f"rules: {name} {status}{hint}")
        bad += status != "ok"
        if show_diff and status in ("edited", "stale", "unstamped"):
            tpl = stamp(sources[name].read_text(encoding="utf-8"), cv or v)
            cur = (repo / ".claude" / "rules" / name).read_text(encoding="utf-8")
            sys.stdout.writelines(difflib.unified_diff(tpl.splitlines(True), cur.splitlines(True), f"template/{name}", f"copy/{name}"))
    if (deck / "shell.html").is_file():
        drift = vendor_drift(deck)
        print(f"vendor: {'ok' if not drift else 'differs: ' + ', '.join(drift) + ' -> run deck-sync'}")
        bad += bool(drift)
        if brand_of(template):
            drift = brand_drift(deck)
            print(f"brand: {'ok' if not drift else 'differs: ' + ', '.join(drift) + ' -> run deck-sync'}")
            bad += bool(drift)
    else:
        print(f"vendor: no {deck / 'shell.html'} -> run deck-new")
        bad += 1
    if (deck / "shell.html").is_file():
        base = shell_base((deck / "shell.html").read_text(encoding="utf-8"))
        print(f"shell.html: base {' '.join(base) if base else 'unknown'}, {'same as' if not shell_diff(deck) else 'differs from'} template {template} {v} (info only)")
    prereq()
    return 1 if bad else 0


def selftest() -> None:
    fm = "---\npaths: deck/**\n---\n\n# 제목\n본문\n"
    s = stamp(fm, "1.2.3")
    assert s == "---\npaths: deck/**\n---\n> deck 플러그인 1.2.3 사본. 고칠 때는 플러그인 원본을 고친다.\n\n# 제목\n본문\n", s
    assert STAMP_RE.search(s)[1] == "1.2.3"
    assert stamp("# 제목\n", "1.0.0") == "> deck 플러그인 1.0.0 사본. 고칠 때는 플러그인 원본을 고친다.\n\n# 제목\n"
    assert SHELL_STAMP_RE.sub("", "<!DOCTYPE html>\n<!-- deck shell base 1.0.0 -->\n<html>") == "<!DOCTYPE html>\n<html>"
    import contextlib, io, tempfile
    with tempfile.TemporaryDirectory() as d, contextlib.redirect_stdout(io.StringIO()):
        repo = Path(d)
        tpl = rule_templates(DEFAULT_TEMPLATE)[0]
        (repo / ".claude" / "rules").mkdir(parents=True)
        (repo / ".claude" / "rules" / tpl.name).write_text(tpl.read_text(encoding="utf-8"), encoding="utf-8")
        assert dict((n, s) for n, s, _ in rule_status(repo, "9.9.9", DEFAULT_TEMPLATE))[tpl.name] == "bare"
        assert write_rules(repo, "9.9.9", False, DEFAULT_TEMPLATE) == 0
        assert dict((n, s) for n, s, _ in rule_status(repo, "9.9.9", DEFAULT_TEMPLATE))[tpl.name] == "ok"
        write_hooks(repo)
        (repo / ".githooks" / "pre-commit").write_text("mine", encoding="utf-8")
        write_hooks(repo)
        assert (repo / ".githooks" / "pre-commit").read_text(encoding="utf-8") == "mine"
        assert (repo / ".githooks" / "deck").is_file()
    # Template selection: the stamp names the template; a stamp without a name is an older monitor deck.
    assert shell_base("<!DOCTYPE html>\n<!-- deck shell base 1.0.0 -->\n") == ("monitor", "1.0.0")
    assert shell_base("<!DOCTYPE html>\n<!-- deck shell base ralphdev-light 1.4.0 -->\n") == ("ralphdev-light", "1.4.0")
    assert shell_base("<!DOCTYPE html>\n<html>") is None
    assert SHELL_STAMP_RE.sub("", "<!DOCTYPE html>\n<!-- deck shell base monitor 1.4.0 -->\n<html>") == "<!DOCTYPE html>\n<html>"
    assert DEFAULT_TEMPLATE in templates()
    assert "deck-design.md" in [p.name for p in rule_templates(DEFAULT_TEMPLATE)]
    with tempfile.TemporaryDirectory() as d, contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
        repo = Path(d)
        assert main(["kit.py", "new", d, "--template", "no-such-template"]) == 2
        assert main(["kit.py", "new", d, "--template"]) == 2
        (repo / "deck").mkdir()
        assert main(["kit.py", "check", d]) == 1  # deck/ without shell.html is a failure, not a crash
        (repo / "deck").rmdir()
        assert not (repo / "deck").exists()
        main(["kit.py", "new", d, f"--template={DEFAULT_TEMPLATE}"])
        shell = (repo / "deck" / "shell.html").read_text(encoding="utf-8")
        assert shell.splitlines()[1] == SHELL_STAMP.format(t=DEFAULT_TEMPLATE, v=version()), shell.splitlines()[1]
        assert deck_template(repo / "deck") == DEFAULT_TEMPLATE
        assert (repo / ".claude" / "rules" / "deck-design.md").is_file()
        assert all(s == "ok" for _, s, _ in rule_status(repo, version(), DEFAULT_TEMPLATE))
        # A deck scaffolded before templates existed: old stamp, no deck-design.md. sync adds the copy.
        (repo / "deck" / "shell.html").write_text(shell.replace(SHELL_STAMP.format(t=DEFAULT_TEMPLATE, v=version()), "<!-- deck shell base 1.0.0 -->"), encoding="utf-8")
        (repo / ".claude" / "rules" / "deck-design.md").unlink()
        assert deck_template(repo / "deck") == DEFAULT_TEMPLATE
        assert main(["kit.py", "sync", d]) == 0
        assert (repo / ".claude" / "rules" / "deck-design.md").is_file()
        assert not shell_diff(repo / "deck")
        # A stamp naming a template this install lacks: refused before anything is written.
        (repo / "deck" / "shell.html").write_text(shell.replace(SHELL_STAMP.format(t=DEFAULT_TEMPLATE, v=version()), "<!-- deck shell base gone 9.9.9 -->"), encoding="utf-8")
        assert main(["kit.py", "sync", d]) == 1
        assert main(["kit.py", "check", d]) == 1
    # A template naming a brand in its brand.txt gets that brand folder as deck/brand; sync restores it.
    assert brand_of(DEFAULT_TEMPLATE) is None and brand_of("ralphdev-light") == "ralphdev"
    with tempfile.TemporaryDirectory() as d, contextlib.redirect_stdout(io.StringIO()):
        repo = Path(d)
        assert main(["kit.py", "new", d, "--template", "ralphdev-light"]) == 0
        deck = repo / "deck"
        assert (deck / "brand" / "tokens.css").is_file()
        assert not (deck / "brand.txt").exists() and not (deck / "rules").exists(), sorted(p.name for p in deck.iterdir())
        assert not brand_drift(deck)
        (deck / "brand" / "tokens.css").write_text("changed", encoding="utf-8")
        assert brand_drift(deck) == ["tokens.css"]
        assert main(["kit.py", "check", d]) == 1
        main(["kit.py", "sync", d])
        assert not brand_drift(deck)
    print("kit selftest OK")


def main(argv: list) -> int:
    rest, template = list(argv[1:]), DEFAULT_TEMPLATE
    for i, a in enumerate(rest):
        if a.startswith("--template="):
            template = rest.pop(i).split("=", 1)[1]
            break
        if a == "--template":
            if i + 1 == len(rest) or rest[i + 1].startswith("--"):
                print(__doc__, file=sys.stderr)
                return 2
            template = rest[i + 1]
            del rest[i:i + 2]
            break
    args = [a for a in rest if not a.startswith("--")]
    flags = {a for a in rest if a.startswith("--")}
    if "--selftest" in flags:
        selftest()
        return 0
    if not args or args[0] not in ("new", "sync", "check", "prereq"):
        print(__doc__, file=sys.stderr)
        return 2
    if args[0] == "prereq":
        prereq()
        return 0
    repo = Path(args[1] if len(args) > 1 else ".").resolve()
    v = version()
    if args[0] == "new":
        return cmd_new(repo, v, template)
    if args[0] == "sync":
        return cmd_sync(repo, v, "--force" in flags)
    return cmd_check(repo, v, "--diff" in flags)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
