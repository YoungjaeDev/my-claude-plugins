"""Scaffold a deck repo and keep its rule copies in step with this plugin.

    python3 kit.py new   [REPO]          # REPO/deck from templates/deck + stamped rule copies; refuses if REPO/deck exists
    python3 kit.py sync  [REPO] [--force] # rewrite rule copies + deck/vendor, print the shell.html diff (never writes shell)
    python3 kit.py check [REPO] [--diff]  # rule copies, vendor, shell base; exit 1 on drift
    python3 kit.py prereq                 # is the frontend-slides plugin installed? warning only, always exit 0
    python3 kit.py --selftest

REPO defaults to the current directory. Rule templates are templates/rules/*.md; each copy in
REPO/.claude/rules/ gets STAMP inserted right after its YAML frontmatter. A copy is compared by
re-stamping the template with the copy's own version, so no unstamping heuristics are needed.
REPO/.claude/rules/deck-local.md is the deck's own file and is never read or written here.
"""
import difflib
import json
import os
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEMPLATE_DECK = ROOT / "templates" / "deck"
TEMPLATE_RULES = ROOT / "templates" / "rules"
LOCAL_RULE = "deck-local.md"
STAMP = "> deck 플러그인 {v} 사본. 고칠 때는 플러그인 원본을 고친다."
STAMP_RE = re.compile(r"^> deck 플러그인 (\S+) 사본\.", re.M)
SHELL_STAMP = "<!-- deck shell base {v} -->"
SHELL_STAMP_RE = re.compile(r"^<!-- deck shell base (\S+) -->\n", re.M)
FRONTEND_SLIDES_INSTALL = ("/plugin marketplace add zarazhangrui/frontend-slides",
                           "/plugin install frontend-slides@frontend-slides")


def version() -> str:
    return json.loads((ROOT / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8"))["version"]


def stamp(text: str, v: str) -> str:
    """Insert the stamp line right after the frontmatter (or at the top when there is none)."""
    m = re.match(r"---\n.*?\n---\n", text, re.S)
    head, body = (text[: m.end()], text[m.end():]) if m else ("", text)
    return head + STAMP.format(v=v) + "\n" + (body if body.startswith("\n") else "\n" + body)


def rule_templates() -> list:
    return sorted(p for p in TEMPLATE_RULES.glob("*.md") if p.name != LOCAL_RULE)


def rule_status(repo: Path, v: str) -> list:
    """(name, status, copy_version) per template: ok | missing | stale | edited | unstamped."""
    out = []
    for tpl in rule_templates():
        copy = repo / ".claude" / "rules" / tpl.name
        if not copy.is_file():
            out.append((tpl.name, "missing", None))
            continue
        text = copy.read_text(encoding="utf-8")
        m = STAMP_RE.search(text)
        if not m:
            out.append((tpl.name, "unstamped", None))
        elif m[1] != v:
            out.append((tpl.name, "stale", m[1]))
        elif text != stamp(tpl.read_text(encoding="utf-8"), v):
            out.append((tpl.name, "edited", m[1]))
        else:
            out.append((tpl.name, "ok", m[1]))
    return out


def write_rules(repo: Path, v: str, force: bool) -> int:
    """Write every rule copy except ones edited by hand at the current version (unless forced)."""
    dest = repo / ".claude" / "rules"
    dest.mkdir(parents=True, exist_ok=True)
    blocked = 0
    for name, status, _ in rule_status(repo, v):
        if status == "ok":
            print(f"rules: {name} ok ({v})")
            continue
        if status in ("edited", "unstamped") and not force:
            print(f"rules: {name} {status}: left as is. Move deck-specific lines to .claude/rules/{LOCAL_RULE}, then rerun with --force")
            blocked += 1
            continue
        (dest / name).write_text(stamp((TEMPLATE_RULES / name).read_text(encoding="utf-8"), v), encoding="utf-8")
        print(f"rules: {name} written ({status} -> {v})")
    return blocked


def vendor_drift(deck: Path) -> list:
    src = TEMPLATE_DECK / "vendor"
    return [p.name for p in sorted(src.iterdir())
            if not (deck / "vendor" / p.name).is_file() or (deck / "vendor" / p.name).read_bytes() != p.read_bytes()]


def shell_diff(deck: Path) -> list:
    tpl = (TEMPLATE_DECK / "shell.html").read_text(encoding="utf-8")
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


def cmd_new(repo: Path, v: str) -> int:
    deck = repo / "deck"
    if deck.exists():
        print(f"[abort] {deck} already exists. Use deck-sync to update rule copies instead.", file=sys.stderr)
        return 1
    shutil.copytree(TEMPLATE_DECK, deck, ignore=shutil.ignore_patterns("__pycache__", ".DS_Store"))
    shell = deck / "shell.html"
    text = shell.read_text(encoding="utf-8")
    shell.write_text(text.replace("<!DOCTYPE html>\n", "<!DOCTYPE html>\n" + SHELL_STAMP.format(v=v) + "\n", 1), encoding="utf-8")
    print(f"deck: scaffolded {deck} from templates/deck ({v})")
    blocked = write_rules(repo, v, force=False)
    prereq()
    return 1 if blocked else 0


def cmd_sync(repo: Path, v: str, force: bool) -> int:
    deck = repo / "deck"
    if not (deck / "shell.html").is_file():
        print(f"[abort] no deck at {deck}. Use deck-new first.", file=sys.stderr)
        return 1
    blocked = write_rules(repo, v, force)
    for name in vendor_drift(deck):
        (deck / "vendor").mkdir(exist_ok=True)
        shutil.copy2(TEMPLATE_DECK / "vendor" / name, deck / "vendor" / name)
        print(f"vendor: {name} updated")
    diff = shell_diff(deck)
    print(f"shell.html: {'same as template' if not diff else f'differs from template ({len(diff)} diff lines, not written)'}")
    sys.stdout.writelines(diff)
    return 1 if blocked else 0


def cmd_check(repo: Path, v: str, show_diff: bool) -> int:
    deck = repo / "deck"
    bad = 0
    for name, status, cv in rule_status(repo, v):
        hint = {"ok": "", "missing": " -> run deck-sync", "stale": f" (copy {cv}, plugin {v}) -> run deck-sync",
                "edited": " (hand-edited at the current version) -> move deck lines to deck-local.md",
                "unstamped": " (no stamp) -> run deck-sync --force after review"}[status]
        print(f"rules: {name} {status}{hint}")
        bad += status != "ok"
        if show_diff and status in ("edited", "stale", "unstamped"):
            tpl = stamp((TEMPLATE_RULES / name).read_text(encoding="utf-8"), cv or v)
            cur = (repo / ".claude" / "rules" / name).read_text(encoding="utf-8")
            sys.stdout.writelines(difflib.unified_diff(tpl.splitlines(True), cur.splitlines(True), f"template/{name}", f"copy/{name}"))
    if deck.is_dir():
        drift = vendor_drift(deck)
        print(f"vendor: {'ok' if not drift else 'differs: ' + ', '.join(drift) + ' -> run deck-sync'}")
        bad += bool(drift)
    else:
        print(f"vendor: no deck at {deck} -> run deck-new")
        bad += 1
    if (deck / "shell.html").is_file():
        m = SHELL_STAMP_RE.search((deck / "shell.html").read_text(encoding="utf-8"))
        print(f"shell.html: base {m[1] if m else 'unknown'}, {'same as' if not shell_diff(deck) else 'differs from'} template {v} (info only)")
    prereq()
    return 1 if bad else 0


def selftest() -> None:
    fm = "---\npaths: deck/**\n---\n\n# 제목\n본문\n"
    s = stamp(fm, "1.2.3")
    assert s == "---\npaths: deck/**\n---\n> deck 플러그인 1.2.3 사본. 고칠 때는 플러그인 원본을 고친다.\n\n# 제목\n본문\n", s
    assert STAMP_RE.search(s)[1] == "1.2.3"
    assert stamp("# 제목\n", "1.0.0") == "> deck 플러그인 1.0.0 사본. 고칠 때는 플러그인 원본을 고친다.\n\n# 제목\n"
    assert SHELL_STAMP_RE.sub("", "<!DOCTYPE html>\n<!-- deck shell base 1.0.0 -->\n<html>") == "<!DOCTYPE html>\n<html>"
    print("kit selftest OK")


def main(argv: list) -> int:
    args = [a for a in argv[1:] if not a.startswith("--")]
    flags = {a for a in argv[1:] if a.startswith("--")}
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
        return cmd_new(repo, v)
    if args[0] == "sync":
        return cmd_sync(repo, v, "--force" in flags)
    return cmd_check(repo, v, "--diff" in flags)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
