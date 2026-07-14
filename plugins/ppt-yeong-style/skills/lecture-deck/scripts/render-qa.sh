#!/bin/sh
# render-qa.sh — deterministic completion gate for a lecture-deck project.
# Replaces the prose "대괄호 grep 0 / placeholder 0 / 리넘버 동기화 재확인" checks in
# lecture-deck SKILL.md §3-§4 with three machine checks. deck-review consumes the
# report. POSIX sh — no bashisms (no arrays, no [[ ]], no ${v,,}).
#
# Usage: render-qa.sh [DECK_ROOT]   (DECK_ROOT default: current dir)
# Layout expected under DECK_ROOT: svg_output/P*.svg, notes/P*.md, sources/deck.md
#
# Exit 0 = all checks passed (gate silent). Exit 1 = a check failed (gate fires).
# Exit 2 = usage / nothing to check (no svg_output).

set -u

ROOT="${1:-.}"
SVG_DIR="$ROOT/svg_output"
NOTES_DIR="$ROOT/notes"
DECK_MD="$ROOT/sources/deck.md"

# Byte-wise, locale-independent matching for the Korean placeholder marker.
LC_ALL=C
export LC_ALL

fail=0

if [ ! -d "$SVG_DIR" ]; then
  echo "render-qa: no svg_output/ under '$ROOT' — nothing to check (build the deck first)" >&2
  exit 2
fi

# page number from a P-prefixed basename: P01_cover.svg -> 1 (strip zero pad).
page_num() {
  # $1 = basename; echoes the integer page number, or nothing if it does not match.
  n=$(printf '%s\n' "$1" | sed -n 's/^[Pp]0*\([0-9][0-9]*\).*/\1/p')
  [ -n "$n" ] && printf '%s\n' "$n"
}

# ---- Check 1: bracket-glyph leak in rendered SVG text -----------------------
# Authoring placeholders like [제목] / [시연 필수] must be filled before ship;
# a leftover [...] token inside SVG text content (between > and <) is a leak.
echo "== Check 1: bracket-glyph leak in svg_output text =="
b_hits=$(grep -REl '>[^<]*\[[^]]*\][^<]*<' "$SVG_DIR" 2>/dev/null || true)
if [ -n "$b_hits" ]; then
  fail=1
  echo "  FAIL — bracket placeholder(s) leaked into rendered text:"
  for f in $b_hits; do
    c=$(grep -Eo '>[^<]*\[[^]]*\][^<]*<' "$f" 2>/dev/null | wc -l | tr -d ' ')
    echo "    $f ($c)"
  done
else
  echo "  PASS — no bracket glyphs in svg text"
fi

# ---- Check 2: unfilled screenshot placeholders remaining --------------------
# §3: a capture slot renders with the label "캡처 후 교체"; at the completion gate
# every slot must be replaced (count 0). deck.md image-slot comments count too.
echo "== Check 2: unfilled placeholder slots =="
p_count=$(grep -RF '캡처 후 교체' "$SVG_DIR" 2>/dev/null | wc -l | tr -d ' ')
if [ -f "$DECK_MD" ]; then
  d_count=$(grep -F 'image-slot' "$DECK_MD" 2>/dev/null | wc -l | tr -d ' ')
else
  d_count=0
fi
p_total=$((p_count + d_count))
if [ "$p_total" -gt 0 ]; then
  fail=1
  echo "  FAIL — $p_total placeholder marker(s) remain (svg: $p_count, deck.md image-slot: $d_count)"
else
  echo "  PASS — no unfilled placeholders"
fi

# ---- Check 3: renumber sync (svg_output <-> notes, contiguity) --------------
echo "== Check 3: renumber sync =="
svg_nums=$(for f in "$SVG_DIR"/[Pp]*.svg; do
  [ -e "$f" ] || continue
  page_num "$(basename "$f")"
done | sort -n | uniq)

if [ -z "$svg_nums" ]; then
  fail=1
  echo "  FAIL — no P<n>.svg files found in $SVG_DIR"
else
  # contiguity: sorted unique page numbers must be 1..count with no gap/dup
  count=$(printf '%s\n' "$svg_nums" | wc -l | tr -d ' ')
  max=$(printf '%s\n' "$svg_nums" | tail -1)
  raw=$(for f in "$SVG_DIR"/[Pp]*.svg; do [ -e "$f" ] || continue; page_num "$(basename "$f")"; done | wc -l | tr -d ' ')
  if [ "$count" != "$max" ] || [ "$count" != "$raw" ]; then
    fail=1
    echo "  FAIL — svg page numbers not contiguous 1..N (unique=$count, max=$max, files=$raw) — gap or duplicate"
  else
    echo "  PASS — svg pages contiguous 1..$max"
  fi

  # cross-check notes/ if present: same page-number set.
  # POSIX: comm needs files, not process substitution — stage both sets in tmp.
  if [ -d "$NOTES_DIR" ]; then
    note_nums=$(for f in "$NOTES_DIR"/[Pp]*.md; do
      [ -e "$f" ] || continue
      page_num "$(basename "$f")"
    done | sort -n | uniq)
    svg_f=$(mktemp) || exit 3
    note_f=$(mktemp) || { rm -f "$svg_f"; exit 3; }
    printf '%s\n' "$svg_nums" > "$svg_f"
    printf '%s\n' "$note_nums" > "$note_f"
    only_svg=$(comm -23 "$svg_f" "$note_f")
    only_note=$(comm -13 "$svg_f" "$note_f")
    rm -f "$svg_f" "$note_f"
    if [ -n "$only_svg" ] || [ -n "$only_note" ]; then
      fail=1
      echo "  FAIL — svg_output vs notes page mismatch:"
      [ -n "$only_svg" ] && echo "    slides without a note: $(printf '%s' "$only_svg" | tr '\n' ' ')"
      [ -n "$only_note" ] && echo "    notes without a slide: $(printf '%s' "$only_note" | tr '\n' ' ')"
    else
      echo "  PASS — svg_output and notes page sets match"
    fi
  else
    echo "  note: no notes/ dir — skipped svg<->notes cross-check"
  fi
fi

echo "----"
if [ "$fail" -ne 0 ]; then
  echo "render-qa: GATE FIRED — fix the FAIL items above before completion."
  exit 1
fi
echo "render-qa: all checks passed."
exit 0
