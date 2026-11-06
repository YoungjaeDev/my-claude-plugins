"""Check deck section copy against the deck-copy / korean-style rules. Exit 1 on violations.

    python3 check_copy.py [DECK_DIR] [--rules PATH]    # DECK_DIR default ./deck
    python3 check_copy.py --selftest

Banned patterns come from the deck repo's rule copy, not from this file: the table under the
heading "### 금지 표기" in <repo>/.claude/rules/deck-copy.md (repo = DECK_DIR/..), columns
| 쓰지 않는다 | 대신 | 검사식 |, where 검사식 holds one or more regexes in backticks. Write a
literal pipe inside a regex as \\|. A deck adds its own bans in the same table form under the
heading "### 덱 금지 표기" in <repo>/.claude/rules/deck-local.md (the deck's file, which deck-sync
never touches), and in a report deck the stamped deck-report.md adds its "### 보고 덱 금지 표기" table
(the deck kind alone decides, so a leftover copy in a lecture deck is ignored); the files and the headings are optional. The other checks (comma after a connective
ending, native counting words, p.source / tag chips, slide labels) are shell-contract checks and
live here, and so do the per-slide limits: a figcaption longer than CAPTION_MAX (50) characters
(a capture caption is one line; its conditions go in captures.md) and more than MARK_MAX (6)
highlighter marks (.mark) on one slide, whatever the slide holds. Text inside <pre>, <code>, <template>, <svg>, <style>, <script> is skipped. alt and
aria-label text is read aloud by screen readers, so it is checked against the banned patterns only,
not the sentence checks. A report deck (the line "- deck_kind: report" in the header of DECK_DIR/outline.md, above its first ## heading,
read by kit.deck_kind; absent means a lecture) also bans the first person 내 / 나 / 저 (standalone, or 내가 나는 저는 제가 저희 and
the like) in slide text: the PDF is read later without the presenter.
"""
import argparse
import html.parser
import re
import sys
from pathlib import Path

from kit import deck_kind  # the one deck_kind parser, shared with the rule-copy tool

TABLE_HEADING = "### 금지 표기"
LOCAL_HEADING = "### 덱 금지 표기"
REPORT_HEADING = "### 보고 덱 금지 표기"  # in deck-report.md, the stamped copy only a report deck gets
TABLE_COLUMNS = ("쓰지 않는다", "대신", "검사식")
COMMA = re.compile(r"([가-힣]*(?:고|며|지만|면서|어서|아서|해서)),")
COMMA_OK = {"보고", "광고", "창고", "참고", "최고", "재고", "경고", "원고", "사고"}
NATIVE = re.compile(r"(?<![가-힣])(셋|넷|다섯|여섯)(이|을|은|으로|에게|에|의|과|와|도|만|뿐|이다)?(?![가-힣])(?!\s*(?:다(?![가-힣])|번째))")
# 보고 덱(outline 머리 "- deck_kind: report")의 1인칭. 단독 어절과 흔한 조사 꼴만 본다(내용·저장·나중은 아니다).
# 단독 "내"는 구의 첫머리일 때만 센다. 낱말 뒤 띄어 쓴 "내"는 의존 명사다(기간 내, 1년 내, 사이트 내).
FIRST_PERSON = re.compile(r"(?<![가-힣])(내가|내|나는|나도|나의|나를|나|저는|저도|저의|저를|저희(?:는|가|의|도|를)?|저|제가)(?![가-힣])")
SKIP = {"pre", "code", "template", "svg", "style", "script"}
NO_LABEL = ("cover", "section-cover", "statement", "quote")  # 덱 표지·섹션 표지·핵심 주장·인용(닫는 장 포함)
CAPTION_MAX = 50  # 1920 장의 캡처 캡션(--t-xs) 한 줄 분량. 캡처의 조건은 captures.md 에 둔다
MARK_MAX = 6  # 형광펜(.mark)은 청중이 집중할 곳에 장당 최대 6개. 목록 개수 조건은 없고 주의 문구(※)가 먼저다
KINDS = {"체크포인트", "오해 바로잡기", "프롬프트", "강사 시연"}
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


def banned_patterns(md: str, heading: str = TABLE_HEADING) -> list:
    """(regex, label) pairs from the first table under heading."""
    lines = md.splitlines()
    try:
        start = next(i for i, l in enumerate(lines) if l.strip() == heading)
    except StopIteration:
        raise ValueError(f"heading '{heading}' not found")
    rows = []
    for line in lines[start + 1:]:
        if line.startswith("#"):
            break
        if line.lstrip().startswith("|"):
            rows.append(_cells(line))
        elif rows:
            break
    if len(rows) < 2 or tuple(rows[0][:3]) != TABLE_COLUMNS:
        raise ValueError(f"table under '{heading}' must start with columns {' | '.join(TABLE_COLUMNS)}")
    out = []
    for cells in rows[2:]:  # rows[1] is the |---| separator
        regexes = re.findall(r"`([^`]+)`", cells[2]) if len(cells) >= 3 else []
        if not regexes:  # a row that bans nothing is a typo, not an intent
            raise ValueError(f"table under '{heading}' has a row without a regex in backticks: {' | '.join(cells)}")
        for rx in regexes:
            re.compile(rx)  # a bad regex should fail loudly, not silently match nothing
            out.append((rx, cells[0]))
    if not out:
        raise ValueError(f"table under '{heading}' has no regex in backticks")
    return out


def labels(raw: str, report: bool = False) -> list:
    """장 라벨: 실습 장만 h2 바로 앞에 span.kind 하나("실습 · " 뒤 16자 안팎 명사구), 개념·사례 장은 라벨 없음.
    보고 덱은 발표자가 보여 주는 장에 "시연"을 쓴다(deck-report.md)."""
    kinds = KINDS | {"시연"} if report else KINDS
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
        if not n:
            continue  # 개념·사례 장은 라벨을 두지 않는다
        k = re.search(r'<span class="kind">(.*?)</span>\s*<h2[^>]*>(.*?)</h2>', body, re.S)
        if n != 1 or not k:
            out.append(f"{sid}: 라벨은 h2 바로 앞에 하나")
            continue
        label, h2 = tags(k[1]), tags(k[2])
        if re.fullmatch(r"(?:개념|사례) · .+", label):
            out.append(f"{sid}: 라벨은 실습 장에만 '{label}'")
            continue
        tail = re.fullmatch(r"실습 · (.+)", label)
        if label not in kinds and not (tail and len(tail[1].replace(" ", "")) <= 16 and tail[1] != h2):
            out.append(f"{sid}: 라벨 형식 '{label}'")
    return out


def caption_and_mark_limits(raw: str) -> list:
    """Per-slide limits: a figcaption over CAPTION_MAX characters, more than MARK_MAX .mark highlights."""
    plain = lambda t: re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", t))).strip()
    out = []
    for m in re.finditer(r'<section\b([^>]*)>(.*?)</section>', raw, re.S):
        sid = (re.search(r'aria-label="(\S+)', m[1]) or [None, "?"])[1]
        for cap in re.findall(r"<figcaption\b[^>]*>(.*?)</figcaption>", m[2], re.S):
            if len(plain(cap)) > CAPTION_MAX:
                out.append(f"{sid}: 캡션 {len(plain(cap))}자(최대 {CAPTION_MAX}자, 한 줄): {plain(cap)}")
        marks = len(re.findall(r'class="(?:[^"]*\s)?mark(?:\s[^"]*)?"', m[2]))
        if marks > MARK_MAX:
            out.append(f"{sid}: 형광펜 {marks}개(장당 최대 {MARK_MAX}개)")
    return out


class Text(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.skip, self.slide, self.out, self.attrs = 0, "?", [], []

    def handle_starttag(self, tag, attrs):
        if tag == "section":
            self.slide = (dict(attrs).get("aria-label") or "?").split(" ")[0]
        if not self.skip:
            self.attrs += [(self.slide, f'{k}="{v.strip()}"', v.strip())
                           for k, v in attrs if k in ("alt", "aria-label") and v and v.strip()]
        if tag in SKIP:
            self.skip += 1

    def handle_endtag(self, tag):
        if tag in SKIP and self.skip:
            self.skip -= 1

    def handle_data(self, data):
        if not self.skip and data.strip():
            self.out.append((self.slide, data.strip()))


def text_hits(text: str, banned: list, report: bool = False) -> list:
    hits = [f"{why or rx}" for rx, why in banned if re.search(rx, text)]
    if report:
        hits += [f"1인칭(보고 덱):{m[1]}" for m in FIRST_PERSON.finditer(text)
                 if not (m[1] == "내" and re.search(r"\w\s+$", text[:m.start()]))]
    hits += [f"쉼표:{m.group(1)}" for m in COMMA.finditer(text) if m.group(1) not in COMMA_OK]
    hits += [f"고유어 수사:{m.group(0)}" for m in NATIVE.finditer(text)]
    return hits


def check_file(name: str, raw: str, banned: list, report: bool = False) -> list:
    out = []
    no_tpl = re.sub(r"<template.*?</template>", "", raw, flags=re.S)
    for pat, why in MARKUP:
        out += [f"{name}: {why}" for _ in re.finditer(pat, no_tpl)]
    out += [f"{name} {h}" for h in labels(no_tpl, report)]
    out += [f"{name} {h}" for h in caption_and_mark_limits(no_tpl)]
    p = Text()
    p.feed(raw)
    for slide, text in p.out:
        out += [f"{name} {slide}: {h}: {text}" for h in text_hits(text, banned, report)]
    for slide, attr, text in p.attrs:
        out += [f"{name} {slide}: {why or rx}: {attr}" for rx, why in banned if re.search(rx, text)]
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
    ok = '<section class="slide" aria-label="S1-01 x"><span class="kind">실습 · 덱 빌드하기</span><h2>제목</h2></section>'
    bare = '<section class="slide" aria-label="S1-02 x"><h2>제목</h2></section>'
    cover = '<section class="slide cover" aria-label="00-01 x"><span class="kind">실습 · 표지</span><h1>t</h1></section>'
    assert labels(ok) == []
    assert labels(bare) == []  # a concept or case slide carries no label
    assert labels(ok.replace("실습 · 덱 빌드하기", "체크포인트")) == []
    demo = ok.replace("실습 · 덱 빌드하기", "시연")  # a report deck labels a slide the presenter shows "시연"
    assert labels(demo, report=True) == [] and labels(demo) == ["S1-01: 라벨 형식 '시연'"]
    assert labels(ok.replace("실습 · 덱 빌드하기", "개념 · 덱 제작 순서")) == ["S1-01: 라벨은 실습 장에만 '개념 · 덱 제작 순서'"]
    assert labels(ok.replace("실습 · 덱 빌드하기", "사건 · 데이터센터 화재")) == ["S1-01: 라벨 형식 '사건 · 데이터센터 화재'"]
    assert labels(ok.replace('<h2>', '<p>x</p><h2>')) == ["S1-01: 라벨은 h2 바로 앞에 하나"]
    assert labels(cover) == ["00-01: 라벨을 두지 않는 장표"]
    assert check_file("f", '<p class="source">x</p><template><p class="source">y</p></template>', banned) == \
        ["f: 출처 줄 금지(deck-copy 사실만)"]
    local = banned_patterns(md.replace("### 금지 표기", LOCAL_HEADING), LOCAL_HEADING)
    assert local == banned, local
    # alt / aria-label: banned patterns only, no comma rule; nothing inside <template>
    attrs = check_file("f", '<section aria-label="S1-01 x"><img alt="모델에 대해 읽고, 쓴다">'
                       '<a aria-label="파일을 읽고, 쓴다">a</a><template><img alt="에 대해"></template></section>', banned)
    assert attrs == ['f S1-01: 에 대해: alt="모델에 대해 읽고, 쓴다"'], attrs
    for broken in ("# none","### 금지 표기\n\n| a | b | c |\n|---|---|---|\n| x | y | `z` |",
                   md.replace("| 따라 하기 | 실습 · 할 일 | `따라 ?하기` |", "| 따라 하기 | 실습 · 할 일 | 따라 하기 |")):
        try:
            banned_patterns(broken)
        except ValueError:
            continue
        raise AssertionError(f"accepted a malformed rule file: {broken!r}")
    # 강의 현장 지시어: the shipped rule table, so the real regexes are what is tested
    real = banned_patterns((Path(__file__).resolve().parent.parent / "templates/rules/deck-copy.md").read_text(encoding="utf-8"))
    deixis = lambda t: [h for h in text_hits(t, real) if "현장 지시어" in h]
    for t in ("오늘 만들 앱", "지금 보는 화면", "지금까지 본 구조", "이번 시간에는", "여기서 브라우저가"):
        assert deixis(t), t
    for t in ("오늘날 웹", "착지금지 표시", "이야기서 나온다", "예제 앱"):
        assert not deixis(t), t
    # A capture caption is one line; the capture's conditions go in captures.md.
    long_cap = "가" * 51
    cap = (f'<section aria-label="S1-02 x"><figure><img alt=""><figcaption>{"나" * 30}'
           f'<a href="#">{"다" * 20}</a></figcaption></figure>'
           f'<figure><figcaption>{long_cap}</figcaption></figure></section>')
    assert [h for h in check_file("f", cap, banned) if "캡션" in h] == [f"f S1-02: 캡션 51자(최대 50자, 한 줄): {long_cap}"]
    # Up to 6 highlighter marks per slide, with or without a list; a 7th is a violation.
    marks = lambda n: '<section aria-label="S1-03 x"><p>※ ' + '<span class="mark">a</span>' * n + '</p></section>'
    assert not [h for h in check_file("f", marks(6), banned) if "형광펜" in h]
    assert [h for h in check_file("f", marks(7), banned) if "형광펜" in h] == ["f S1-03: 형광펜 7개(장당 최대 6개)"]
    # A report deck (outline header "- deck_kind: report") bans the first person in slide text.
    assert deck_kind("# t\n\n- 덱의 주장: x\n- deck_kind: report\n") == "report"
    assert deck_kind("# t\n- 강의: x\n") == "lecture"
    assert deck_kind("# t\n-deck_kind:report\n") == "lecture"  # the same parser as kit.py
    assert deck_kind("# t\n\n## 0. 표지\n- deck_kind: report\n") == "lecture"  # below a ## heading: not the header (kit.py agrees)
    first = '<section aria-label="S1-01 x"><p>내 계정을 옮긴다</p><li>저는 확인했다</li><p>제가 맡는다</p>' \
            '<p>내용을 저장하고 나중에 본다</p><p>기간 안에 나누어 본다</p></section>'
    hits = [h for h in check_file("f", first, banned, report=True) if "1인칭" in h]
    assert hits == ["f S1-01: 1인칭(보고 덱):내: 내 계정을 옮긴다", "f S1-01: 1인칭(보고 덱):저는: 저는 확인했다",
                    "f S1-01: 1인칭(보고 덱):제가: 제가 맡는다"], hits
    assert not [h for h in check_file("f", first, banned) if "1인칭" in h]  # a lecture deck keeps its voice
    # 내 after a word and a space is the bound noun "within" (기간 내); the possessive 내 opens its phrase.
    person = lambda t: [h for h in text_hits(t, [], report=True) if "1인칭" in h]
    for t in ("기간 내 처리한다", "1년 내 끝낸다", "사이트 내 검색", "A 내 B", "기간\n      내 처리한다"):
        assert not person(t), (t, person(t))
    for t in ("내 계정을 옮긴다", "(내 판단) 맞다", "· 내 계정", "이번엔 내가 맡는다", "그 일은 제가 한다",
              "저희는 결과를 전달했다", "저희가 맡는다"):
        assert person(t), t
    # A report deck's stamped deck-report.md adds its "### 보고 덱 금지 표기" table when the file is present.
    import subprocess, tempfile
    with tempfile.TemporaryDirectory() as t:
        rules, deck = Path(t) / ".claude" / "rules", Path(t) / "deck"
        rules.mkdir(parents=True)
        (deck / "sections").mkdir(parents=True)
        (rules / "deck-copy.md").write_text(md, encoding="utf-8")
        (deck / "sections" / "a.html").write_text('<section aria-label="S1-01 x"><p>강의를 마친다</p></section>', encoding="utf-8")
        run = lambda: subprocess.run([sys.executable, __file__, str(deck)], capture_output=True, text=True)
        assert run().returncode == 0
        (rules / "deck-report.md").write_text("# r\n" + md.replace(TABLE_HEADING, REPORT_HEADING).replace("에 대해", "강의"), encoding="utf-8")
        r = run()  # a lecture deck ignores a leftover deck-report.md: the outline flag alone decides
        assert r.returncode == 0 and "deck-report.md" not in r.stdout, r.stdout + r.stderr
        (deck / "outline.md").write_text("# t\n- deck_kind: report\n\n## 1\n", encoding="utf-8")
        r = run()
        assert r.returncode == 1 and "S1-01: 강의" in r.stdout and "deck-report.md" in r.stdout, r.stdout + r.stderr
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
    try:
        kind = deck_kind((deck / "outline.md").read_text(encoding="utf-8")) if (deck / "outline.md").is_file() else "lecture"
    except (OSError, UnicodeDecodeError) as exc:
        print(f"cannot read {deck / 'outline.md'}: {exc}", file=sys.stderr)
        return 2
    read_from = []
    # Next to the deck-copy.md in use: the report copy's bans (report decks only, the same flag as the
    # first-person check, so a leftover copy in a lecture deck is ignored), then the deck's own; both optional.
    extras = ([("deck-report.md", REPORT_HEADING)] if kind == "report" else []) + [("deck-local.md", LOCAL_HEADING)]
    for extra, heading in extras:
        extra_path = rules.parent / extra
        try:
            extra_md = extra_path.read_text(encoding="utf-8") if extra_path.is_file() else ""
            if any(l.strip() == heading for l in extra_md.splitlines()):
                banned += banned_patterns(extra_md, heading)
                read_from.append(extra)
        except (OSError, ValueError, re.error) as exc:
            print(f"cannot read deck bans from {extra_path}: {exc}", file=sys.stderr)
            return 2
    bad = []
    for path in sorted((deck / "sections").glob("*.html")):
        bad += check_file(path.name, path.read_text(encoding="utf-8"), banned, kind == "report")
    for line in bad:
        print(line)
    print(f"patterns: {len(banned)} from {rules}" + "".join(f" and {n}" for n in read_from) + f"; deck_kind: {kind}")
    print("violations:", len(bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
