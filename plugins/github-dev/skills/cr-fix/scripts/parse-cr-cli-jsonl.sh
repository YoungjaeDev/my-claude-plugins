#!/usr/bin/env bash
# Usage: bash scripts/parse-cr-cli-jsonl.sh /path/to/cr-cli.jsonl
# Reads JSONL, filters to type=="finding", projects to unified record schema (same as fetch-cr-threads.sh).
# Emits JSON array on stdout.
# See references/cr-cli-jsonl-schema.md for field mapping (Phase A TBD bindings).
set -euo pipefail

JSONL="${1:?jsonl path required}"
[ -f "$JSONL" ] || { echo "error: $JSONL not found" >&2; exit 1; }

# Severity lowercase → emoji per references/cr-cli-jsonl-schema.md.
jq -c -s '
  [ .[]
    | select(.type == "finding")
    | . as $f
    | {
        source: "cli",
        path: ($f.fileName // $f.file // null),
        # Phase A TBD: source-line field name. Try common candidates in order.
        line: ($f.line // $f.lineNumber // $f.startLine // ($f.suggestions[0].line // null)),
        body: ($f.comment // ""),
        guidance: ($f.codegenInstructions // ""),
        comment_id: null,
        severity_emoji: (
          { "critical": "🔴 Critical", "major": "🟠 Major", "minor": "🟡 Minor",
            "trivial": "🟢 Trivial", "info": "🟢 Info" }[(($f.severity // "") | ascii_downcase)] // null
        ),
        # Phase A TBD: issue-category header. Try header regex (same as PR-bot); fallback to category field.
        # `try ... catch null` keeps a single malformed comment from aborting the whole array.
        type_emoji: (
          (try (($f.comment // "") | capture("_(?<t>[^_]+)_\\s*\\|\\s*_(?<s>[^_]+)_").t) catch null)
          // ($f.category // null)
        )
      }
  ]
' "$JSONL" 2>/dev/null || {
  echo "warn: parse-cr-cli-jsonl: malformed JSONL lines present in $JSONL; falling back to per-line filter" >&2
  # Per-line fallback: skip non-JSON lines defensively. Mirrors the main path field set
  # (suggestions[0].line included, capture() wrapped in try) so behavior stays consistent.
  jq -c -R '. as $l | try (fromjson | select(.type == "finding")) catch empty' "$JSONL" \
    | jq -c -s '[ .[] | {
        source: "cli", path: (.fileName // .file // null),
        line: (.line // .lineNumber // .startLine // ((.suggestions // [])[0].line // null)),
        body: (.comment // ""), guidance: (.codegenInstructions // ""), comment_id: null,
        severity_emoji: ({ "critical":"🔴 Critical","major":"🟠 Major","minor":"🟡 Minor","trivial":"🟢 Trivial","info":"🟢 Info" }[((.severity // "") | ascii_downcase)] // null),
        type_emoji: ((try ((.comment // "") | capture("_(?<t>[^_]+)_\\s*\\|\\s*_(?<s>[^_]+)_").t) catch null) // (.category // null))
      } ]'
}
