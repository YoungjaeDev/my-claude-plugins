"""Local dev server for the slide deck: live rebuild + in-browser text edit mode.

Run: python3 dev.py [DECK_DIR] [--port N]   (DECK_DIR default ./deck, port default 8765)
Serves http://127.0.0.1:<port> only. No file watcher -- refresh the page to see
changes to sections/*.html. Sections are re-assembled on every request.

Edit mode (dev build only, never in the deployed index.html):
- press E, or click the small badge top-left, to toggle contenteditable on
  the current slide's text elements.
- Ctrl+S / Cmd+S POSTs the edited <section> back to /save, which writes it
  into its source file in sections/ (whitelisted, atomic write).
"""
import argparse
import http.server
import json
import re
import time
from pathlib import Path

import build

MAX_BODY = 1024 * 1024  # 1 MiB

# Runtime-only markup that shell.html's JS (or this file's edit script) adds
# to a slide at runtime and that must never land back in a sections/*.html file.
# shell.html이 주입하는 요소는 모두 data-runtime을 달고, 안에 같은 태그를 중첩하지 않는다
# (deck-footer/deck-sechead/deck-bigbar, 목차 <li>). 그래서 같은 닫는 태그까지의
# non-greedy 매치가 정확히 요소 하나를 지운다.
_RUNTIME_ELEMENT_RE = re.compile(r"<(deck-[a-z-]+|li)\b[^>]*\bdata-runtime\b[^>]*>.*?</\1>", re.S)
# GSAP은 data-anim이 붙은 대상에 style/transform/data-svg-origin을 쓴다.
# 저작 마크업은 이 요소에 style이나 transform을 직접 넣지 않는다.
_ANIM_TAG_RE = re.compile(r"<[A-Za-z][^>]*\bdata-anim=\"[^\"]*\"[^>]*>")
_ANIM_ATTR_RE = re.compile(r'\s+(?:style|transform|data-svg-origin)="[^"]*"')
_DATA_SRC_RE = re.compile(r'\s*data-src="[^"]*"')
_DATA_IDX_RE = re.compile(r'\s*data-idx="\d+"')
_CONTENTEDITABLE_RE = re.compile(r'\s*contenteditable(="[^"]*")?')
_SPELLCHECK_RE = re.compile(r'\s*spellcheck="[^"]*"')
_ARIA_HIDDEN_RE = re.compile(r'\s*aria-hidden="[^"]*"')
_SECTION_OPEN_TAG_RE = re.compile(r"<section\b[^>]*>", re.S)
_SECTION_RE = re.compile(r"<section\b.*?</section>", re.S)
# 패널 원문 <template>은 런타임이 손대지 않고 편집 대상도 아니다. 원문 안의 코드 예시가
# 아래 제거 규칙에 걸리지 않도록 저장 전에 떼어 두었다가 그대로 되돌린다.
_TEMPLATE_RE = re.compile(r"<template\b.*?</template>", re.S)
_TEMPLATE_SLOT_RE = re.compile(r"\x00template(\d+)\x00")

EDIT_JS = r"""
(function () {
  var TEXT_SELECTOR = "h1, h2, h3, p, li, td, th, .pending, .kind";
  var active = false;
  var badge = document.createElement("div");
  badge.id = "dev-edit-badge";
  badge.textContent = "EDIT";
  badge.style.cssText = "position:fixed;top:10px;left:10px;z-index:9999;font:11px monospace;" +
    "padding:4px 8px;border-radius:4px;background:rgba(255,255,255,.08);color:#9ca1a8;" +
    "cursor:pointer;user-select:none;";
  document.body.appendChild(badge);

  function currentSection() {
    return document.querySelector(".slide.active") || document.querySelector(".slide.visible");
  }

  function paint() {
    badge.style.background = active ? "#8db4e8" : "rgba(255,255,255,.08)";
    badge.style.color = active ? "#1f2226" : "#9ca1a8";
  }

  function setActive(on) {
    active = on;
    // 편집 중에는 모션을 끝 상태로 고정한다.
    if (on && window.presentation && window.presentation.finishMotion) window.presentation.finishMotion();
    var section = currentSection();
    if (section) {
      section.querySelectorAll(TEXT_SELECTOR).forEach(function (el) {
        // 런타임 요소와 코드 블록을 품은 요소는 저장 시 버려지거나 구조가 깨지므로 편집하지 않는다.
        // <template> 패널 원문은 DocumentFragment라 querySelectorAll에 잡히지 않는다.
        if (el.closest("[data-runtime]") || el.querySelector("pre")) return;
        if (on) { el.setAttribute("contenteditable", "true"); el.setAttribute("spellcheck", "false"); }
        else { el.removeAttribute("contenteditable"); el.removeAttribute("spellcheck"); }
      });
    }
    paint();
  }

  function flash(msg, ok) {
    badge.textContent = msg;
    badge.style.background = ok ? "#1a7a1a" : "#aa1111";
    badge.style.color = "#fff";
    setTimeout(function () { badge.textContent = "EDIT"; paint(); }, 1200);
  }

  function save() {
    var section = currentSection();
    if (!section || !section.dataset.src) { flash("no src", false); return; }
    var payload = { src: section.dataset.src, idx: Number(section.dataset.idx), html: section.outerHTML };
    fetch("/save", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) })
      .then(function (res) { return res.json().catch(function () { return {}; }).then(function (body) { return { ok: res.ok, body: body }; }); })
      .then(function (r) { flash(r.ok ? "saved" : (r.body && r.body.error) || "error", r.ok); })
      .catch(function () { flash("error", false); });
  }

  badge.addEventListener("click", function () { setActive(!active); });
  document.addEventListener("keydown", function (e) {
    var editingNow = e.target.closest && e.target.closest("[contenteditable=''], [contenteditable='true']");
    if ((e.key === "e" || e.key === "E") && !editingNow) setActive(!active);
    if ((e.key === "s" || e.key === "S") && (e.ctrlKey || e.metaKey)) { e.preventDefault(); save(); }
  });
})();
"""


def _strip_class_tokens(text: str, tokens: set) -> str:
    """Remove the given class tokens from every class="..." in text.

    Drops the whole (leading-whitespace + class="...") attribute, not just an
    empty class="", when nothing is left after filtering.
    """

    def repl(match: "re.Match[str]") -> str:
        remaining = [t for t in match.group(2).split() if t not in tokens]
        if not remaining:
            return ""
        return f'{match.group(1)}class="{" ".join(remaining)}"'

    return re.sub(r'(\s*)class="([^"]*)"', repl, text)


def _strip_runtime_artifacts(html: str) -> str:
    templates = []

    def hold(match: "re.Match[str]") -> str:
        templates.append(match.group(0))
        return f"\x00template{len(templates) - 1}\x00"

    html = _TEMPLATE_RE.sub(hold, html)
    # deck-panel(패널 DOM과 복사 버튼 상태)은 셸이 stage에 붙이지만, 섹션 안에 섞여 와도 여기서 지운다.
    html = _RUNTIME_ELEMENT_RE.sub("", html)
    html = _ANIM_TAG_RE.sub(lambda m: _ANIM_ATTR_RE.sub("", m.group(0)), html)
    html = _DATA_SRC_RE.sub("", html)
    html = _DATA_IDX_RE.sub("", html)
    html = _CONTENTEDITABLE_RE.sub("", html)
    html = _SPELLCHECK_RE.sub("", html)

    # shell.html's show() toggles active/visible class and aria-hidden only on
    # the <section> (== .slide) element itself, never on its descendants.
    # A descendant can legitimately author the same class/attribute (e.g. a
    # v2 table-of-contents "active" list item), so scope this removal to just
    # the section's own opening tag instead of the whole section.
    open_tag_match = _SECTION_OPEN_TAG_RE.search(html)
    if open_tag_match:
        open_tag = _ARIA_HIDDEN_RE.sub("", open_tag_match.group(0))
        open_tag = _strip_class_tokens(open_tag, {"active", "visible"})
        html = html[: open_tag_match.start()] + open_tag + html[open_tag_match.end() :]

    # "zoomed" is toggled by a plain click handler on any figure.shot, so
    # it can appear on any element and is always safe to strip everywhere.
    html = _strip_class_tokens(html, {"zoomed"})
    return _TEMPLATE_SLOT_RE.sub(lambda m: templates[int(m.group(1))], html)


def _validate_src(src: object, sections_dir: Path) -> Path:
    if not isinstance(src, str) or ".." in src or not re.fullmatch(r"[A-Za-z0-9_.-]+\.html", src):
        raise ValueError("invalid src")
    path = sections_dir / src
    if not path.is_file() or path.resolve().parent != sections_dir.resolve():
        raise ValueError("unknown src")
    return path


def save_section(sections_dir: Path, src: object, idx: object, html: object) -> None:
    """Replace the idx-th <section> of src with a sanitized version of html."""
    if not isinstance(idx, int) or isinstance(idx, bool):
        raise ValueError("idx must be an int")
    if not isinstance(html, str) or not html.strip():
        raise ValueError("html must be non-empty")

    path = _validate_src(src, sections_dir)
    cleaned = _strip_runtime_artifacts(html).strip()
    if not cleaned.startswith("<section"):
        raise ValueError("html is not a <section>")

    file_text = path.read_text(encoding="utf-8")
    matches = list(_SECTION_RE.finditer(file_text))
    if not (0 <= idx < len(matches)):
        raise ValueError("idx out of range")
    m = matches[idx]
    new_text = file_text[: m.start()] + cleaned + file_text[m.end() :]

    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(new_text, encoding="utf-8")
    tmp.replace(path)


def build_server(deck_dir: Path, host: str = "127.0.0.1", port: int = 8765) -> http.server.ThreadingHTTPServer:
    sections_dir = deck_dir / "sections"
    shell_path = deck_dir / "shell.html"

    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(deck_dir), **kwargs)

        def do_GET(self):
            if self.path in ("/", "/index.html"):
                self._serve_index()
            else:
                super().do_GET()

        def _serve_index(self):
            html = build.assemble(sections_dir, shell_path, tag_sections=True)
            html = html.replace("</body>", f"<script>{EDIT_JS}</script>\n</body>", 1)
            body = html.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self):
            if self.path != "/save":
                self.send_error(404)
                return
            try:
                length = int(self.headers.get("Content-Length", 0))
            except ValueError:
                length = -1
            # Windows는 읽지 않은 본문이 남은 소켓을 닫으면 RST를 보내 거부 응답이 사라진다. 선언된 본문을 기한 안에 먼저 비운다.
            raw = b""
            if length > 0:
                self.connection.settimeout(2)
                deadline = time.monotonic() + 5
                chunks, left = [], length
                try:
                    while left:
                        if time.monotonic() > deadline:
                            raise TimeoutError("request body deadline")
                        chunk = self.rfile.read(min(left, 64 * 1024))
                        if not chunk:
                            raise ConnectionError("incomplete request body")
                        if length <= MAX_BODY:
                            chunks.append(chunk)
                        left -= len(chunk)
                except OSError:
                    self.close_connection = True
                    return
                raw = b"".join(chunks)
            # 다른 origin의 simple POST와 DNS rebinding으로 sections/*.html이 바뀌지 않게 파일을 쓰기 전에 막는다.
            port = self.server.server_address[1]
            allowed_hosts = {f"127.0.0.1:{port}", f"localhost:{port}"}
            origin = self.headers.get("Origin")
            if self.headers.get("Host") not in allowed_hosts or (
                origin is not None and origin not in {f"http://{h}" for h in allowed_hosts}
            ):
                self._json(403, {"ok": False, "error": "forbidden origin"})
                return
            if self.headers.get("Content-Type", "").split(";")[0].strip().lower() != "application/json":
                self._json(415, {"ok": False, "error": "content type must be application/json"})
                return
            if length <= 0 or length > MAX_BODY:
                self._json(400, {"ok": False, "error": "invalid body size"})
                return
            try:
                payload = json.loads(raw)
                if not isinstance(payload, dict):
                    raise ValueError("body must be a JSON object")
                save_section(sections_dir, payload.get("src"), payload.get("idx"), payload.get("html"))
            except (ValueError, TypeError, json.JSONDecodeError) as exc:
                self._json(400, {"ok": False, "error": str(exc)})
                return
            self._json(200, {"ok": True})

        def _json(self, status: int, obj: dict):
            body = json.dumps(obj).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    return http.server.ThreadingHTTPServer((host, port), Handler)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Serve a deck with live rebuild and edit mode.")
    ap.add_argument("deck_dir", nargs="?", default="deck")
    ap.add_argument("--port", type=int, default=8765)
    args = ap.parse_args()
    deck = Path(args.deck_dir).resolve()
    if not (deck / "shell.html").is_file() or not (deck / "sections").is_dir():
        raise SystemExit(f"not a deck directory (needs shell.html and sections/): {deck}")
    httpd = build_server(deck, port=args.port)
    print(f"serving http://{httpd.server_address[0]}:{httpd.server_address[1]}", flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
