#!/usr/bin/env bash
# Usage: bash scripts/parse-cr-cli-jsonl.sh /path/to/cr-cli.jsonl
# Reads JSONL, filters to type=="finding", projects to unified record schema (same as fetch-cr-threads.sh).
# Emits JSON array on stdout.
# See references/cr-cli-jsonl-schema.md for the field mapping.
#
# Schema notes, measured against CodeRabbit CLI 0.6.5 (issue #105):
#   - A `finding` carries exactly: type, fileName, severity, suggestions, codegenInstructions.
#   - `suggestions` is an array of raw PATCH STRINGS, not objects. Indexing
#     `.suggestions[0].line` therefore aborts jq with
#     `Cannot index string with string "line"` and takes the whole fallback path
#     down with it, since both branches used the same expression.
#   - There is no `comment`, no `location`, no `line`. The only position
#     information lives inside `codegenInstructions` as prose:
#     `around lines 11 - 23` / `at line 4`.
set -euo pipefail

JSONL="${1:?jsonl path required}"
[ -f "$JSONL" ] || { echo "error: $JSONL not found" >&2; exit 1; }

# One projection, used by both the slurp path and the per-line fallback, so the
# two can never disagree about a field again.
read -r -d '' PROJECT <<'JQ' || true
# jq's `capture()` yields NO OUTPUT on a non-match — it does not throw, and it
# does not produce null. `try capture(...) catch null` therefore still yields
# empty, and an empty value anywhere in an object constructor makes the whole
# object vanish: a finding with no line hint would be silently dropped from the
# array rather than projected with `line: null`. Collect into an array first so
# "no match" becomes an honest null.
def first_or_null(f): ([ f? ] | .[0]);
def line_from_guidance:
  # `around lines 11 - 23` -> 11 ; `at line 4` -> 4
  first_or_null(capture("around lines?\\s+(?<n>[0-9]+)"; "i").n)
  // first_or_null(capture("at line\\s+(?<n>[0-9]+)"; "i").n);
def suggestion_line:
  # 0.5.x handed objects here; 0.6.x hands patch strings. Guard on type instead
  # of assuming, or a single string suggestion kills the whole run.
  ((. // [])[0]) as $s
  | if ($s | type) == "object" then ($s.line // null) else null end;
{
  source: "cli",
  path: (.fileName // .file // null),
  line: (
    (
      .line // .lineNumber // .startLine
      // (.suggestions | suggestion_line)
      // ((.codegenInstructions // "") | line_from_guidance)
    ) | if . == null then null else (tonumber? // null) end
  ),
  # 0.6.x drops `comment` entirely; codegenInstructions is the only prose left,
  # so an empty body would leave the Step 9a table with nothing to display.
  body: (.comment // .codegenInstructions // ""),
  guidance: (.codegenInstructions // ""),
  comment_id: null,
  severity_emoji: (
    { "critical": "🔴 Critical", "major": "🟠 Major", "minor": "🟡 Minor",
      "trivial": "🟢 Trivial", "info": "🟢 Info" }[((.severity // "") | ascii_downcase)] // null
  ),
  # The `_Type_ | _Severity_` header only exists in PR-bot comment bodies. When
  # the CLI omits `comment` this stays null and classify-item.sh falls through to
  # its severity-only branch, which is the documented behavior.
  type_emoji: (
    first_or_null((.comment // "") | capture("_(?<t>[^_]+)_\\s*\\|\\s*_(?<s>[^_]+)_").t)
    // (.category // null)
  )
}
JQ

if out=$(jq -c -s "[ .[] | select(.type == \"finding\") | $PROJECT ]" "$JSONL" 2>/dev/null); then
  printf '%s\n' "$out"
  exit 0
fi

# The slurp path only fails when a line is not valid JSON — a projection error is
# now impossible, since every field access above is type-guarded. Say that, rather
# than the old blanket "malformed JSONL lines present", which was printed for jq
# errors of any kind and sent readers looking for corruption that was not there.
echo "warn: parse-cr-cli-jsonl: $JSONL is not uniformly valid JSON; skipping unparseable lines" >&2
jq -c -R '. as $l | try (fromjson | select(.type == "finding")) catch empty' "$JSONL" \
  | jq -c -s "[ .[] | $PROJECT ]"
