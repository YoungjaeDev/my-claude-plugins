# CodeRabbit finding header, read by its emoji badges rather than its emphasis.
# Shared by fetch-cr-threads.sh (PR-bot bodies) and parse-cr-cli-jsonl.sh (CLI
# `comment`) so the two paths cannot drift. Load with `jq -L <scripts dir>` and
# `include "cr-header";`.
#
# The older header is `<category> | <severity> | <effort>`; CodeRabbit shipped it
# italic (`_…_`), bold (`**…**`) and plain, and only the badges are documented
# (severity 🔴 🟠 🟡 🔵 ⚪). So: the first line that splits on `|` into two or
# three fields whose second field opens with a severity badge is the header,
# and `*`/`_`/whitespace are trimmed off each field. Two fields is the older
# form without effort. No such line -> all three null, never a dropped record.
#
# Since PR #344 (2026-10) the header is severity-first, `·`-separated, with
# <img> icons instead of emoji:
#   **<picture><img src=".../amber-16.svg" …></picture> Minor** · **Functional Correctness** · **Quick win**
# Tags are stripped, then the first field must be exactly a known severity
# word; the icon file name is never read. The word maps to the old badge
# string, so callers and classify-item.sh see one vocabulary.
def _cr_trim: gsub("^[\\s*_]+|[\\s*_]+$"; "");
def _cr_fields: [ splits("\\|") | _cr_trim ];
def _cr_is_header: (length == 2 or length == 3) and (.[1] | test("^(🔴|🟠|🟡|🔵|⚪)"));
def _cr_sev: { "critical": "🔴 Critical", "major": "🟠 Major", "minor": "🟡 Minor",
               "trivial": "🔵 Trivial", "info": "⚪ Info" };
# One line -> [category, severity, effort?] in the old field order, or null.
def _cr_line_fields:
  (_cr_fields | select(_cr_is_header))
  // ([ gsub("<[^>]*>"; "") | splits("·") | _cr_trim ]
      | (.[0] | ascii_downcase) as $w
      | if (length == 2 or length == 3) and _cr_sev[$w] != null
        then [.[1], _cr_sev[$w]] + .[2:] else null end);
def cr_header:
  ([ (. // "") | splits("\n") | _cr_line_fields | select(. != null) ] | .[0]) as $f
  | { category_emoji: ($f[0] // null),
      severity_emoji: ($f[1] // null),
      effort_emoji:   ($f[2] // null) };

# The finding title: the first non-blank line after that header, with the same
# `*`/`_`/whitespace trim. No header -> null.
def cr_title:
  [ (. // "") | splits("\n") ] as $L
  | (first(range(0; $L | length) | select($L[.] | _cr_line_fields != null)) // null) as $h
  | if $h == null then null
    else first($L[$h+1:][] | gsub("^[\\s*_]+|[\\s*_]+$"; "") | select(length > 0)) // null end;
