"""Check deck section copy against the deck-copy / korean-style rules. Exit 1 on violations.

    python3 check_copy.py [DECK_DIR] [--rules PATH]    # DECK_DIR default ./deck
    python3 check_copy.py --selftest

Banned patterns come from the deck repo's rule copy, not from this file: the table under the
heading "### 금지 표기" in <repo>/.claude/rules/deck-copy.md (repo = DECK_DIR/..), columns
| 쓰지 않는다 | 대신 | 검사식 |, where 검사식 holds one or more regexes in backticks. Write a
literal pipe inside a regex as \\|. The other checks (comma after a connective ending, native
counting words, p.source / tag chips, slide labels) are shell-contract checks and live here.
Text inside <pre>, <code>, <template>, <svg>, <style>, <script> is skipped.
"""
import argparse
import html.parser
import re
import sys
from pathlib import Path

TABLE_HEADING = "### 금지 표기"
TABLE_COLUMNS = ("쓰지 않는다", "대신", "검사식")
COMMA = re.compile(r"([가-힣]*(?:고|며|지만|면서|어서|아서|해서)),")
COMMA_OK = {"보고", "광고", "창고", "참고", "최고", "재고", "경고", "원고", "사고"}
NATIVE = re.compile(r"(?<![가-힣])(셋|넷|다섯|여섯)(이|을|은|으로|에게|에|의|과|와|도|만|뿐|이다)?(?![가-힣])(?!\s*(?:다(?![가-힣])|번째))")
SKIP = {"pre", "code", "template", "svg", "style", "script"}
NO_LABEL = ("cover", "section-cover", "statement", "quote")  # 덱 표지·섹션 표지·핵심 주장·인용(닫는 장 포함)
KINDS = {"체크포인트", "오해 바로잡기", "프롬프트"}
MARKUP = ((r'<p class="source"', "출처 줄 금지(deck-copy 사실만)"),
          (r'class="tags"', "태그 칩 금지(deck-copy 문장으로)"))


def _cells(row: str) -> list:
    """Split a markdown table row on | outside backtick spans; \\| stays a literal pipe."""
    cells, cur, tick, i = [], "", False, 0
    row = row.strip().removeprefix("|")
    if row.endswith("|") and not row.endswith("\\|"):
        row = row[:-1]
    while i < len(row):
        c = row[i]
        if c == "\\" and row[i + 1:i + 2] == "|":
            cur += "|"
            i += 2
            continue
        if c == "`":
            tick = not tick
        if c == "|" and not tick:
            cells.append(cur.strip())
            cur = ""
        else:
            cur += c
        i += 1
    cells.append(cur.strip())
    return cells


def banned_patterns(md: str) -> list:
    """(regex, label) pairs from the first table under TABLE_HEADING."""
    lines = md.splitlines()
    try:
        start = next(i for i, l in enumerate(lines) if l.strip() == TABLE_HEADING)
    except StopIteration:
        raise ValueError(f"heading '{TABLE_HEADING}' not found")
    rows = []
    for line in lines[start + 1:]:
        if line.startswith("#"):
            break
        if line.lstrip().startswith("|"):
            rows.append(_cells(line))
        elif rows:
            break
    if len(rows) < 2 or tuple(rows[0][:3]) != TABLE_COLUMNS:
        raise ValueError(f"table under '{TABLE_HEADING}' must start with columns {' | '.join(TABLE_COLUMNS)}")
    out = []
    for cells in rows[2:]:  # rows[1] is the |---| separator
        if len(cells) < 3:
            continue
        for rx in re.findall(r"`([^`]+)`", cells[2]):
            re.compile(rx)  # a bad regex should fail loudly, not silently match nothing
            out.append((rx, cells[0]))
    if not out:
        raise ValueError(f"table under '{TABLE_HEADING}' has no regex in backticks")
    return out


def labels(raw: str) -> list:
    """장 라벨: 내용 장표는 h2 바로 앞에 span.kind 하나, 실습·개념 뒤는 16자 안팎 명사구."""
    tags = lambda t: re.sub(r"<[^>]+>", "", t).strip()
    out = []
    for m in re.finditer(r'<section\b([^>]*)>(.*?)</section>', raw, re.S):
        attrs, body = m.groups()
        sid = (re.search(r'aria-label="(\S+)', attrs) or [None, "?"])[1]
        cls = (re.search(r'class="([^"]*)"', attrs) or [None, ""])[1].split()
        n = len(re.findall(r'class="kind"', body))
        if any(c in cls for c in NO_LABEL) or 'class="agenda"' in body or "<h2" not in body:
            if n:
                out.append(f"{sid}: 라벨을 두지 않는 장표")
            continue
        k = re.search(r'<span class="kind">(.*?)</span>\s*<h2[^>]*>(.*?)</h2>', body, re.S)
        if n != 1 or not k:
            out.append(f"{sid}: h2 바로 앞 span.kind 하나 필요")
            continue
        label, h2 = tags(k[1]), tags(k[2])
        tail = re.fullmatch(r"(?:실습|개념) · (.+)", label)
        if label not in KINDS and not (tail and len(tail[1].replace(" ", "")) <= 16 and tail[1] != h2):
            out.append(f"{sid}: 라벨 형식 '{label}'")
    return out


class Text(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.skip, self.slide, self.out = 0, "?", []

    def handle_starttag(self, tag, attrs):
        if tag == "section":
            self.slide = (dict(attrs).get("aria-label") or "?").split(" ")[0]
        if tag in SKIP:
            self.skip += 1

    def handle_endtag(self, tag):
        if tag in SKIP and self.skip:
            self.skip -= 1

    def handle_data(self, data):
        if not self.skip and data.strip():
            self.out.append((self.slide, data.strip()))


def text_hits(text: str, banned: list) -> list:
    hits = [f"{why or rx}" for rx, why in banned if re.search(rx, text)]
    hits += [f"쉼표:{m.group(1)}" for m in COMMA.finditer(text) if m.group(1) not in COMMA_OK]
    hits += [f"고유어 수사:{m.group(0)}" for m in NATIVE.finditer(text)]
    return hits


def check_file(name: str, raw: str, banned: list) -> list:
    out = []
    no_tpl = re.sub(r"<template.*?</template>", "", raw, flags=re.S)
    for pat, why in MARKUP:
        out += [f"{name}: {why}" for _ in re.finditer(pat, no_tpl)]
    out += [f"{name} {h}" for h in labels(no_tpl)]
    p = Text()
    p.feed(raw)
    for slide, text in p.out:
        out += [f"{name} {slide}: {h}: {text}" for h in text_hits(text, banned)]
    return out


def selftest() -> None:
    md = "\n".join([
        "# x", "### 금지 표기", "",
        "| 쓰지 않는다 | 대신 | 검사식 |", "|---|---|---|",
        "| 에 대해 | 목적격 | `에 대해`, `에 대하여` |",
        "| 따라 하기 | 실습 · 할 일 | `따라 ?하기` |",
        "| 둘 중 하나 | 하나로 | `가\\|나` |",
        "", "## next", "| 쓰지 않는다 | 대신 | 검사식 |", "|---|---|---|", "| x | y | `NOTME` |",
    ])
    banned = banned_patterns(md)
    assert [rx for rx, _ in banned] == ["에 대해", "에 대하여", "따라 ?하기", "가|나"], banned
    assert text_hits("모델에 대해 본다", banned) == ["에 대해"]
    assert text_hits("NOTME", banned) == []
    assert text_hits("파일을 읽고, 쓴다", banned) == ["쉼표:읽고"]
    assert text_hits("참고, 이것", banned) == []
    assert text_hits("셋이 남았다", banned) == ["고유어 수사:셋이"]
    assert text_hits("셋 다 본다", banned) == []
    assert text_hits("다나", banned) == ["둘 중 하나"]
    ok = '<section class="slide" aria-label="S1-01 x"><span class="kind">개념 · 덱 제작 순서</span><h2>제목</h2></section>'
    bad = '<section class="slide" aria-label="S1-02 x"><h2>제목</h2></section>'
    cover = '<section class="slide cover" aria-label="00-01 x"><span class="kind">개념 · 표지</span><h1>t</h1></section>'
    assert labels(ok) == []
    assert labels(bad) == ["S1-02: h2 바로 앞 span.kind 하나 필요"]
    assert labels(cover) == ["00-01: 라벨을 두지 않는 장표"]
    assert check_file("f", '<p class="source">x</p><template><p class="source">y</p></template>', banned) == \
        ["f: 출처 줄 금지(deck-copy 사실만)"]
    for broken in ("# none", "### 금지 표기\n\n| a | b | c |\n|---|---|---|\n| x | y | `z` |"):
        try:
            banned_patterns(broken)
        except ValueError:
            continue
        raise AssertionError(f"accepted a malformed rule file: {broken!r}")
    print("check_copy selftest OK")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("deck_dir", nargs="?", default="deck")
    ap.add_argument("--rules", help="deck-copy.md path (default <deck>/../.claude/rules/deck-copy.md)")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()
    if args.selftest:
        selftest()
        return 0
    deck = Path(args.deck_dir).resolve()
    rules = Path(args.rules) if args.rules else deck.parent / ".claude" / "rules" / "deck-copy.md"
    if not (deck / "sections").is_dir():
        print(f"no sections/ under {deck}", file=sys.stderr)
        return 2
    try:
        banned = banned_patterns(rules.read_text(encoding="utf-8"))
    except (OSError, ValueError, re.error) as exc:
        print(f"cannot read banned patterns from {rules}: {exc} (run deck-sync to restore the rule copy)", file=sys.stderr)
        return 2
    bad = []
    for path in sorted((deck / "sections").glob("*.html")):
        bad += check_file(path.name, path.read_text(encoding="utf-8"), banned)
    for line in bad:
        print(line)
    print(f"patterns: {len(banned)} from {rules}")
    print("violations:", len(bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
