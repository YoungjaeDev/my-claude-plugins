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
def cr_header:
  ([ (. // "") | splits("\n")
     | [ splits("\\|") | gsub("^[\\s*_]+|[\\s*_]+$"; "") ]
     | select((length == 2 or length == 3) and (.[1] | test("^(🔴|🟠|🟡|🔵|⚪)"))) ]
   | .[0]) as $f
  | { category_emoji: ($f[0] // null),
      severity_emoji: ($f[1] // null),
      effort_emoji:   ($f[2] // null) };
