# CodeRabbit finding header, read by its emoji badges rather than its emphasis.
# Shared by fetch-cr-threads.sh (PR-bot bodies) and parse-cr-cli-jsonl.sh (CLI
# `comment`) so the two paths cannot drift. Load with `jq -L <scripts dir>` and
# `include "cr-header";`.
#
# The header is `<category> | <severity> | <effort>`; CodeRabbit has shipped it
# italic (`_…_`), bold (`**…**`) and plain, and only the badges are documented
# (severity 🔴 🟠 🟡 🔵 ⚪). So: the first line that splits on `|` into two or
# three fields whose second field opens with a severity badge is the header,
# and `*`/`_`/whitespace are trimmed off each field. Two fields is the older
# form without effort. No such line -> all three null, never a dropped record.
def _cr_fields: [ splits("\\|") | gsub("^[\\s*_]+|[\\s*_]+$"; "") ];
def _cr_is_header: (length == 2 or length == 3) and (.[1] | test("^(🔴|🟠|🟡|🔵|⚪)"));
def cr_header:
  ([ (. // "") | splits("\n") | _cr_fields | select(_cr_is_header) ] | .[0]) as $f
  | { category_emoji: ($f[0] // null),
      severity_emoji: ($f[1] // null),
      effort_emoji:   ($f[2] // null) };

# The finding title: the first non-blank line after that header, with the same
# `*`/`_`/whitespace trim. No header -> null.
def cr_title:
  [ (. // "") | splits("\n") ] as $L
  | (first(range(0; $L | length) | select($L[.] | _cr_fields | _cr_is_header)) // null) as $h
  | if $h == null then null
    else first($L[$h+1:][] | gsub("^[\\s*_]+|[\\s*_]+$"; "") | select(length > 0)) // null end;
