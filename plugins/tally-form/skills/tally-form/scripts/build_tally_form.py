#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build a Tally questionnaire form from a checklist markdown (or JSON spec) and
create or (idempotently) publish it via the Tally API.

Verified API quirks (see references/tally-blocks.md):
- Create  = POST  /forms        {status, blocks, settings}
- Publish = PATCH /forms/{id}    {status:"PUBLISHED", blocks, settings}  (keeps share URL)
  Patching /forms/{id}/blocks ONLY leaves the form in draft -> share URL not updated.
- urllib needs a browser User-Agent or Cloudflare returns 403 (code 1010).
- Key = env TALLY_API_KEY or repo .env (TALLY_API_KEY=...). Never print the key.

Stdlib-only (urllib) — no third-party deps. Run with `uv run` or any Python 3.8+.
API-created forms stay fully editable in the Tally web editor afterward.

Usage:
  uv run build_tally_form.py --md checklist.md [--update <formId>]
  uv run build_tally_form.py --json spec.json --theme none
  Options: --theme neutral|hermes|none|<path.json>   --out <payload.json>
           --dividers/--no-dividers   --no-humanize   --dry-run
"""

import argparse
import json
import os
import re
import sys
import urllib.request
import urllib.error
import uuid

# --- defaults -------------------------------------------------------------
DEFAULT_OPTIONS = ["네, 해주세요", "나중에", "설명 듣고 정할게요"]
DEFAULT_THEME = "neutral"

# Neutral theme (generic): clean monochrome ink-on-white, no slop palette.
NEUTRAL_STYLES = {
    "theme": "CUSTOM",
    "color": {
        "background": "#FFFFFF",
        "text": "#18181B",
        "accent": "#52525B",
        "buttonBackground": "#18181B",
        "buttonText": "#FFFFFF",
    },
    "direction": "ltr",
}

# Hermes theme (preset): warm off-white / ink / teal accent / gold CTA.
HERMES_STYLES = {
    "theme": "CUSTOM",
    "color": {
        "background": "#FAF8F3",
        "text": "#1F2329",
        "accent": "#2BA89F",
        "buttonBackground": "#DD8E35",
        "buttonText": "#FFFFFF",
    },
    "direction": "ltr",
}

PRESETS = {"neutral": NEUTRAL_STYLES, "hermes": HERMES_STYLES}

UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
)


def u():
    return str(uuid.uuid4())


def _truthy(val, default):
    """Interpret a frontmatter scalar as a boolean, falling back to `default`."""
    if val is None:
        return default
    if isinstance(val, bool):
        return val
    return str(val).strip().lower() in ("true", "yes", "on", "1")


# --- markdown parsing -----------------------------------------------------
def _parse_frontmatter(text):
    """Minimal stdlib YAML-frontmatter parser: scalars + simple block lists.
    Returns (frontmatter_dict, body_text)."""
    if not text.startswith("---"):
        return {}, text
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n?(.*)$", text, re.DOTALL)
    if not m:
        return {}, text
    fm_raw, body = m.group(1), m.group(2)
    fm = {}
    cur_key = None
    for line in fm_raw.splitlines():
        if not line.strip():
            continue
        list_item = re.match(r"^\s*-\s+(.*)$", line)
        if list_item and cur_key is not None and isinstance(fm.get(cur_key), list):
            fm[cur_key].append(_strip_quotes(list_item.group(1).strip()))
            continue
        kv = re.match(r"^([A-Za-z0-9_]+)\s*:\s*(.*)$", line)
        if kv:
            key, val = kv.group(1), _strip_inline_comment(kv.group(2))
            if val == "":
                fm[key] = []  # opening a block list
                cur_key = key
            else:
                fm[key] = _strip_quotes(val)
                cur_key = None
    return fm, body


def _strip_quotes(s):
    if len(s) >= 2 and s[0] == s[-1] and s[0] in "\"'":
        return s[1:-1]
    return s


def _strip_inline_comment(val):
    """Drop a YAML-style inline `#` comment from a frontmatter scalar.

    A `#` only opens a comment when it starts the value or follows whitespace
    (matching YAML), so a quoted value or a `value#literal` token is preserved.
    Without this, `theme: neutral # note` would yield `neutral # note` and be
    read as a (missing) styles-file path."""
    val = val.strip()
    if val and val[0] in "\"'":
        end = val.find(val[0], 1)
        return val[: end + 1].strip() if end != -1 else val
    return re.sub(r"(^|\s)#.*$", "", val).strip()


def _ensure_section(cur, sections):
    """Return the current section, opening a headless one if none is active."""
    if cur is None:
        cur = {"heading": "", "kind": "mc", "items": []}
        sections.append(cur)
    return cur


def _parse_dt_directive(rest):
    """Parse the tail of a `%%date`/`%%time` directive into a config dict.

    Forms accepted (label is everything before any parenthetical option):
      label: 희망 상담일  (format: yyyy/MM/dd)
      희망 시간
    Recognized parentheticals map to real Tally payload fields only (`format`).
    """
    cfg = {}
    for k, v in re.findall(r"\(\s*([A-Za-z]+)\s*:\s*([^)]*)\)", rest):
        cfg[k.lower()] = v.strip()
    body = re.sub(r"\([^)]*\)", "", rest).strip()
    lm = re.match(r"^label\s*:\s*(.*)$", body, re.I)
    cfg["label"] = lm.group(1).strip() if lm else body
    return cfg


def _split_csv(v):
    return [x.strip() for x in v.split(",") if x.strip()]


def _resolve_image_url(ref):
    """Resolve an image reference to a public URL (Tally has no upload endpoint).

    - Full https:// URL -> used as-is. http:// is rejected (mixed content is
      blocked on Tally's HTTPS-served forms).
    - `owner/repo[@ref]:path` shorthand -> a raw.githubusercontent.com URL (git
      ref defaults to `main`), so a public GitHub repo's assets/ can host form
      images with no extra infra.
    """
    if not ref:
        return None
    ref = ref.strip()
    if ref.startswith("https://"):
        return ref
    if ref.startswith("http://"):
        raise ValueError(
            f"insecure image URL {ref!r} — use https:// "
            "(http is blocked as mixed content on HTTPS forms)"
        )
    m = re.match(r"^([^/\s]+)/([^/@:\s]+)(?:@([^:\s]+))?:(.+)$", ref)
    if m:
        owner, repo = m.group(1), m.group(2)
        gitref = m.group(3) or "main"
        path = m.group(4).strip().lstrip("/")
        return f"https://raw.githubusercontent.com/{owner}/{repo}/{gitref}/{path}"
    raise ValueError(
        f"unrecognized image reference {ref!r} "
        "(use a full https:// URL or owner/repo[@ref]:path)"
    )


def _image_field(key, raw):
    """url/link get inline-comment + surrounding-quote stripping (a `#` fragment
    survives — it is not whitespace-separated), matching frontmatter handling so
    a quoted `"https://..."` resolves; caption/name are free text kept verbatim."""
    if key in ("url", "link"):
        return _strip_quotes(_strip_inline_comment(raw))
    return raw.strip()


def parse_md(path):
    """Parse a checklist markdown into a form spec.

    Conventions:
      # Title                  -> form title
      > intro paragraphs       -> intro TEXT (first contiguous blockquote run;
                                  blank `>` lines split paragraphs)
      ## Section               -> HEADING_2; following `- [ ]` items are choices
      - [ ] item               -> multiple-choice question (globally numbered)
      ### Free section         -> HEADING_2; following `- label: ___` are TEXTAREA
      - label: ___             -> free-text (TEXTAREA) question (not numbered)
      %%matrix ... %%          -> matrix/grid question (rows x cols, single/multi)
      %%date label: ...        -> INPUT_DATE question
      %%time label: ...        -> INPUT_TIME question
      %%image url: ...         -> IMAGE block (hosted URL or owner/repo[@ref]:path)
    Frontmatter overrides: options (list), theme (str), form_id (str),
                           title (str), intro (str), dividers (bool, default on),
                           logo / cover (image ref), redirect (URL on completion).
    """
    with open(path, encoding="utf-8") as f:
        raw = f.read()
    fm, body = _parse_frontmatter(raw)

    title = fm.get("title")
    intro = fm.get("intro")
    options = fm.get("options") or DEFAULT_OPTIONS
    if not isinstance(options, list) or not options:
        options = DEFAULT_OPTIONS
    dividers = _truthy(fm.get("dividers"), True)
    logo = fm.get("logo")
    cover = fm.get("cover")
    redirect = fm.get("redirect")

    lines = body.splitlines()
    nlines = len(lines)
    idx = 0

    # 1) Title: locate the first `# ` line. A frontmatter title (if set) wins as
    #    the value, but either way advance past the body title line so intro
    #    detection starts after it. No `# ` line -> idx stays 0.
    title_idx = next(
        (k for k in range(nlines) if lines[k].strip().startswith("# ")), None
    )
    if title_idx is not None:
        if title is None:
            title = lines[title_idx].strip()[2:].strip()
        idx = title_idx + 1

    # 2) Intro: first contiguous blockquote run after the title. Blank `>` lines
    #    split paragraphs; a non-quote line ends the run, so later separate
    #    blockquotes (option hints, share URLs, internal memos) are ignored.
    intro_paras = [intro] if intro else None
    if intro is None:
        j = idx
        while j < nlines and lines[j].strip() == "":
            j += 1
        if j < nlines and lines[j].strip().startswith(">"):
            paras, cur_para = [], []
            while j < nlines and lines[j].strip().startswith(">"):
                content = lines[j].strip()[1:].lstrip()
                if content:
                    cur_para.append(content)
                elif cur_para:
                    paras.append(" ".join(cur_para))
                    cur_para = []
                j += 1
            if cur_para:
                paras.append(" ".join(cur_para))
            intro_paras = paras or None
            idx = j

    # 3) Sections + questions from the remaining lines.
    sections = []
    cur = None
    i = idx
    while i < nlines:
        s = lines[i].strip()
        if not s or s == "---":
            i += 1
            continue

        # matrix directive block: %%matrix ... %%
        if s == "%%matrix":
            i += 1
            rows, cols, select, label = [], [], "multi", None
            while i < nlines and lines[i].strip() != "%%":
                kv = re.match(
                    r"^(rows|cols|select|label|title)\s*:\s*(.*)$",
                    lines[i].strip(),
                    re.I,
                )
                if kv:
                    k, v = kv.group(1).lower(), kv.group(2).strip()
                    if k == "rows":
                        rows = _split_csv(v)
                    elif k == "cols":
                        cols = _split_csv(v)
                    elif k == "select":
                        select = "single" if v.lower().startswith("s") else "multi"
                    elif k in ("label", "title"):
                        label = v
                i += 1
            if i >= nlines:
                print(
                    "WARN: unclosed %%matrix directive (missing closing %%)",
                    file=sys.stderr,
                )
            i += 1  # skip the closing %%
            cur = _ensure_section(cur, sections)
            cur["items"].append(
                (
                    "matrix",
                    {"rows": rows, "cols": cols, "select": select, "label": label},
                )
            )
            continue

        # single-line directives: %%date / %%time
        dm = re.match(r"^%%date\b\s*(.*)$", s, re.I)
        if dm:
            cur = _ensure_section(cur, sections)
            cur["items"].append(("date", _parse_dt_directive(dm.group(1))))
            i += 1
            continue
        tm = re.match(r"^%%time\b\s*(.*)$", s, re.I)
        if tm:
            cur = _ensure_section(cur, sections)
            cur["items"].append(("time", _parse_dt_directive(tm.group(1))))
            i += 1
            continue

        # image directive: `%%image <url>` (single-line bare ref/URL) or a block
        # of `url:`/`caption:`/`link:`/`name:` lines (optionally closed with `%%`).
        # The block read stops at the first non-key line, so it never swallows a
        # following heading even when the `%%` close is omitted.
        im = re.match(r"^%%image\b\s*(.*)$", s, re.I)
        if im:
            rest = im.group(1).strip()
            cfg = {}
            kv0 = re.match(r"^(url|caption|link|name)\s*:\s*(.*)$", rest, re.I)
            if rest and not kv0:
                cfg["url"] = _image_field("url", rest)  # single-line bare ref/URL
                i += 1
            else:
                if kv0:
                    cfg[kv0.group(1).lower()] = _image_field(
                        kv0.group(1).lower(), kv0.group(2)
                    )
                i += 1
                while i < nlines:
                    ln = lines[i].strip()
                    if ln == "%%":
                        i += 1
                        break
                    kv = re.match(r"^(url|caption|link|name)\s*:\s*(.*)$", ln, re.I)
                    if not kv:
                        break
                    cfg[kv.group(1).lower()] = _image_field(
                        kv.group(1).lower(), kv.group(2)
                    )
                    i += 1
            if cfg.get("url"):
                cur = _ensure_section(cur, sections)
                cur["items"].append(("image", cfg))
            continue

        if s.startswith("> "):
            i += 1  # stray blockquote after the intro run -> ignore
            continue
        if s.startswith("### "):
            cur = {"heading": s[4:].strip(), "kind": "free", "items": []}
            sections.append(cur)
            i += 1
            continue
        if s.startswith("## "):
            cur = {"heading": s[3:].strip(), "kind": "mc", "items": []}
            sections.append(cur)
            i += 1
            continue
        cb = re.match(r"^-\s*\[[ xX]\]\s*(.+)$", s)
        if cb:
            cur = _ensure_section(cur, sections)
            cur["items"].append(("mc", cb.group(1).strip()))
            i += 1
            continue
        free = re.match(r"^-\s+(.*?)\s*:?\s*_+\s*$", s)
        if free and cur is not None and cur["kind"] == "free":
            cur["items"].append(("free", free.group(1).strip()))
            i += 1
            continue
        # plain `- item` under a free section without underscores -> still a textarea
        bullet = re.match(r"^-\s+(.+)$", s)
        if bullet and cur is not None and cur["kind"] == "free":
            label = bullet.group(1).strip().rstrip(":").strip()
            cur["items"].append(("free", label))
            i += 1
            continue
        i += 1

    return {
        "title": title or "설문",
        "intro": intro_paras,
        "options": options,
        "sections": sections,
        "theme": fm.get("theme"),
        "form_id": fm.get("form_id"),
        "dividers": dividers,
        "logo": logo,
        "cover": cover,
        "redirect": redirect,
    }


# --- block builder --------------------------------------------------------
def _intro_paras(spec):
    """Normalize spec['intro'] (str | list | None) into a list of paragraphs."""
    intro = spec.get("intro")
    if not intro:
        return []
    if isinstance(intro, str):
        return [intro]
    return list(intro)


def build_blocks(spec):
    b = []
    title_payload = {"html": spec["title"]}
    if spec.get("logo"):
        title_payload["logo"] = _resolve_image_url(spec["logo"])
    if spec.get("cover"):
        title_payload["cover"] = _resolve_image_url(spec["cover"])
    b.append(
        {
            "uuid": u(),
            "type": "FORM_TITLE",
            "groupUuid": u(),
            "groupType": "TEXT",
            "payload": title_payload,
        }
    )
    # Intro: one TEXT block per paragraph (readability — no <br> dependency).
    for para in _intro_paras(spec):
        g = u()
        b.append(
            {
                "uuid": u(),
                "type": "TEXT",
                "groupUuid": g,
                "groupType": "TEXT",
                "payload": {"html": para},
            }
        )

    options = spec["options"]
    n = len(options)
    qi = 1
    dividers = spec.get("dividers", True)
    headings_emitted = 0
    for sec in spec["sections"]:
        if sec["heading"]:
            # DIVIDER between sections (visual separation) — not before the first.
            if dividers and headings_emitted > 0:
                dg = u()
                b.append(
                    {
                        "uuid": dg,
                        "type": "DIVIDER",
                        "groupUuid": dg,
                        "groupType": "DIVIDER",
                        "payload": {},
                    }
                )
            hg = u()
            b.append(
                {
                    "uuid": u(),
                    "type": "HEADING_2",
                    "groupUuid": hg,
                    "groupType": "HEADING_2",
                    "payload": {"html": sec["heading"]},
                }
            )
            headings_emitted += 1
        for kind, item in sec["items"]:
            if kind == "mc":
                tg = u()
                og = u()
                b.append(
                    {
                        "uuid": u(),
                        "type": "TITLE",
                        "groupUuid": tg,
                        "groupType": "QUESTION",
                        "payload": {"html": f"{qi}. {item}"},
                    }
                )
                for i, opt in enumerate(options):
                    b.append(
                        {
                            "uuid": u(),
                            "type": "MULTIPLE_CHOICE_OPTION",
                            "groupUuid": og,
                            "groupType": "MULTIPLE_CHOICE",
                            "payload": {
                                "text": opt,
                                "index": i,
                                "isFirst": i == 0,
                                "isLast": i == n - 1,
                                "isRequired": False,
                            },
                        }
                    )
                qi += 1
            elif kind == "free":
                tg = u()
                ig = u()
                b.append(
                    {
                        "uuid": u(),
                        "type": "TITLE",
                        "groupUuid": tg,
                        "groupType": "QUESTION",
                        "payload": {"html": item},
                    }
                )
                b.append(
                    {
                        "uuid": u(),
                        "type": "TEXTAREA",
                        "groupUuid": ig,
                        "groupType": "TEXTAREA",
                        "payload": {
                            "isRequired": False,
                            "placeholder": "자유롭게 적어주세요",
                        },
                    }
                )
            elif kind == "matrix":
                b.extend(_matrix_blocks(item, sec["heading"]))
            elif kind == "date":
                b.extend(_input_blocks("INPUT_DATE", item, "날짜"))
            elif kind == "time":
                b.extend(_input_blocks("INPUT_TIME", item, "시간"))
            elif kind == "image":
                b.append(_image_block(item))
    return b


def _matrix_blocks(cfg, fallback_label):
    """Matrix/grid question: TITLE(QUESTION) + MATRIX(QUESTION container) +
    MATRIX_ROW xN + MATRIX_COLUMN xM. Rows/cols borrow the MATRIX block's uuid as
    their groupUuid (Tally's child-block grouping rule). select=single caps each
    row at one column via the MATRIX block's hasMaxChoices/maxChoices (the live
    API rejects those keys on MATRIX_ROW even though the OpenAPI schema lists
    them — verified empirically)."""
    label = cfg.get("label") or fallback_label or "선택"
    rows, cols = cfg.get("rows") or [], cfg.get("cols") or []
    single = cfg.get("select") == "single"
    mg = u()
    matrix_payload = {"isRequired": False}
    if single:
        matrix_payload["hasMaxChoices"] = True
        matrix_payload["maxChoices"] = 1
    out = [
        {
            "uuid": u(),
            "type": "TITLE",
            "groupUuid": u(),
            "groupType": "QUESTION",
            "payload": {"html": label},
        },
        {
            "uuid": mg,
            "type": "MATRIX",
            "groupUuid": mg,
            "groupType": "QUESTION",
            "payload": matrix_payload,
        },
    ]
    for ri, text in enumerate(rows):
        out.append(
            {
                "uuid": u(),
                "type": "MATRIX_ROW",
                "groupUuid": mg,
                "groupType": "MATRIX",
                "payload": {
                    "index": ri,
                    "isFirst": ri == 0,
                    "isLast": ri == len(rows) - 1,
                    "isRequired": False,
                    "text": text,
                    "html": text,
                },
            }
        )
    for ci, text in enumerate(cols):
        out.append(
            {
                "uuid": u(),
                "type": "MATRIX_COLUMN",
                "groupUuid": mg,
                "groupType": "MATRIX",
                "payload": {
                    "index": ci,
                    "isFirst": ci == 0,
                    "isLast": ci == len(cols) - 1,
                    "isRequired": False,
                    "text": text,
                    "html": text,
                },
            }
        )
    return out


def _input_blocks(block_type, cfg, fallback_label):
    """A labelled single-input question: TITLE(QUESTION) + INPUT_* block.
    Mirrors the verified TEXTAREA pattern (groupType == block type)."""
    label = cfg.get("label") or fallback_label
    tg = u()
    ig = u()
    payload = {"isRequired": False}
    if block_type == "INPUT_DATE" and cfg.get("format"):
        payload["format"] = cfg["format"]
    return [
        {
            "uuid": u(),
            "type": "TITLE",
            "groupUuid": tg,
            "groupType": "QUESTION",
            "payload": {"html": label},
        },
        {
            "uuid": u(),
            "type": block_type,
            "groupUuid": ig,
            "groupType": block_type,
            "payload": payload,
        },
    ]


def _image_block(cfg):
    """An inline IMAGE block. payload.images is exactly one {name, url}."""
    url = _resolve_image_url(cfg.get("url"))
    name = cfg.get("name") or url.rsplit("/", 1)[-1]
    payload = {"images": [{"name": name, "url": url}]}
    if cfg.get("caption"):
        payload["hasCaption"] = True
        payload["caption"] = cfg["caption"]
    if cfg.get("link"):
        payload["hasLink"] = True
        payload["link"] = cfg["link"]
    g = u()
    return {
        "uuid": g,
        "type": "IMAGE",
        "groupUuid": g,
        "groupType": "IMAGE",
        "payload": payload,
    }


def resolve_styles(theme, trusted=True):
    """theme: None/'' -> neutral preset; a preset name -> its styles;
    'none' -> no styles (Tally default theme); else a JSON file path.

    trusted=False (theme came from untrusted md frontmatter, not the operator's
    CLI flag) confines the path to the workspace so a crafted checklist cannot
    read an arbitrary file off disk into the form's settings.styles."""
    if theme in (None, ""):
        theme = DEFAULT_THEME
    if theme == "none":
        return None
    if theme in PRESETS:
        return PRESETS[theme]
    path = theme
    if not trusted:
        base = os.path.realpath(os.getcwd())
        path = os.path.realpath(os.path.join(base, theme))
        if path != base and not path.startswith(base + os.sep):
            raise ValueError(f"frontmatter theme path escapes workspace: {theme}")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


# --- key + API ------------------------------------------------------------
def find_key():
    key = os.environ.get("TALLY_API_KEY")
    if key:
        return key.strip()
    # walk up from CWD looking for a .env with TALLY_API_KEY
    d = os.getcwd()
    for _ in range(6):
        env_path = os.path.join(d, ".env")
        if os.path.exists(env_path):
            with open(env_path, encoding="utf-8") as f:
                for line in f:
                    m = re.match(r"\s*TALLY_API_KEY\s*=\s*(.+)\s*$", line)
                    if m:
                        return _strip_quotes(m.group(1).strip())
        parent = os.path.dirname(d)
        if parent == d:
            break
        d = parent
    return None


def call_tally(key, update_id, body):
    if update_id:
        url = f"https://api.tally.so/forms/{update_id}"
        payload = {
            "status": "PUBLISHED",
            "blocks": body["blocks"],
            "settings": body["settings"],
        }
        method = "PATCH"
    else:
        url = "https://api.tally.so/forms"
        payload = body
        method = "POST"
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "User-Agent": UA,
            "Accept": "application/json",
        },
        method=method,
    )
    with urllib.request.urlopen(req, timeout=40) as r:
        txt = r.read().decode("utf-8")
    return json.loads(txt) if txt.strip() else {}


# --- main -----------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(
        description="Build & publish a Tally form from a checklist md/json."
    )
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--md", help="checklist markdown path")
    src.add_argument(
        "--json", help="form spec JSON path (title/intro/options/sections)"
    )
    ap.add_argument(
        "--update", metavar="FORM_ID", help="PATCH-publish an existing form (keeps URL)"
    )
    ap.add_argument(
        "--theme",
        default=None,
        help="neutral (default) | hermes | none | <styles.json>",
    )
    ap.add_argument(
        "--out", help="payload sidecar JSON path (default: alongside input)"
    )
    div = ap.add_mutually_exclusive_group()
    div.add_argument(
        "--dividers",
        dest="dividers",
        action="store_true",
        default=None,
        help="insert DIVIDER blocks between sections (default on)",
    )
    div.add_argument(
        "--no-dividers",
        dest="dividers",
        action="store_false",
        help="disable section dividers",
    )
    ap.add_argument(
        "--no-humanize",
        action="store_true",
        help="passthrough for skill orchestration; the script never calls humanize itself",
    )
    ap.add_argument(
        "--dry-run", action="store_true", help="build payload only, no API call"
    )
    args = ap.parse_args()

    if args.md:
        spec = parse_md(args.md)
        in_path = args.md
    else:
        with open(args.json, encoding="utf-8") as f:
            spec = json.load(f)
        spec.setdefault("options", DEFAULT_OPTIONS)
        spec.setdefault("sections", [])
        in_path = args.json

    # CLI --dividers/--no-dividers overrides frontmatter; default on.
    if args.dividers is not None:
        spec["dividers"] = args.dividers
    spec.setdefault("dividers", True)

    # theme/form_id precedence: CLI flag > frontmatter > default
    theme = args.theme if args.theme is not None else spec.get("theme")
    theme_trusted = (
        args.theme is not None
    )  # CLI flag is operator-supplied; frontmatter is not
    update_id = args.update or spec.get("form_id")

    styles = resolve_styles(theme, trusted=theme_trusted)
    settings = {"styles": styles} if styles else {}
    if spec.get("redirect"):
        settings["redirectOnCompletion"] = {"html": spec["redirect"], "mentions": []}
    blocks = build_blocks(spec)
    body = {"status": "PUBLISHED", "blocks": blocks, "settings": settings}

    # block accounting (for the parsing verification gate)
    items = [(k, it) for s in spec["sections"] for k, it in s["items"]]
    n_headings = sum(1 for s in spec["sections"] if s["heading"])
    n_dividers = max(0, n_headings - 1) if spec.get("dividers", True) else 0
    n_intro = len(_intro_paras(spec))
    n_mc = sum(1 for k, _ in items if k == "mc")
    n_free = sum(1 for k, _ in items if k == "free")
    n_date = sum(1 for k, _ in items if k == "date")
    n_time = sum(1 for k, _ in items if k == "time")
    n_image = sum(1 for k, _ in items if k == "image")
    n_matrix_blocks = sum(
        2 + len(it.get("rows") or []) + len(it.get("cols") or [])
        for k, it in items
        if k == "matrix"
    )
    print(
        f"built payload: {len(blocks)} blocks "
        f"(title=1, intro={n_intro}, headings={n_headings}, dividers={n_dividers}, "
        f"choices={n_mc}x{1 + len(spec['options'])}, textareas={n_free}x2, "
        f"date={n_date}x2, time={n_time}x2, image={n_image}, "
        f"matrix_blocks={n_matrix_blocks})"
    )

    out = args.out or (os.path.splitext(in_path)[0] + "_tally_payload.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(body, f, ensure_ascii=False, indent=2)
    print(f"payload saved: {out}")

    if args.dry_run:
        print("DRY_RUN: no API call.")
        return

    key = find_key()
    if not key:
        print(
            "NO_KEY: payload only. Set env TALLY_API_KEY or add TALLY_API_KEY=... to .env."
        )
        return

    try:
        res = call_tally(key, update_id, body)
    except urllib.error.HTTPError as e:
        print("HTTP", e.code, e.read().decode("utf-8")[:500])
        sys.exit(1)
    except Exception as ex:
        print("ERR", ex)
        sys.exit(1)

    fid = res.get("id") or update_id or "?"
    print(("UPDATED" if update_id else "CREATED"), "id=", fid)
    print("EDIT:  https://tally.so/forms/%s/edit" % fid)
    print("SHARE: https://tally.so/r/%s" % fid)


if __name__ == "__main__":
    main()
