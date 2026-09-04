# CodeRabbit CLI JSONL Schema

`coderabbit review --agent` streams newline-delimited JSON to stdout. Each line is one event with a discriminator field `type`. The parser in `scripts/parse-cr-cli-jsonl.sh` filters to `type == "finding"` and projects each finding into the same record schema as the PR-bot GraphQL path so Step 9a tier classification can treat both uniformly.

## Event types observed

| `type` | Purpose | Action |
|--------|---------|--------|
| `review_context` | Initial metadata: base / head SHA, file count. | Log line count only; don't propagate. |
| `status` | Progress markers (e.g. "analyzing X.py"). | Ignore. |
| `heartbeat` | Keep-alive. | Ignore (used by Monitor). |
| `finding` | Single actionable review item. | Project to record (see below). |
| `complete` | Final summary, exit imminent. | Terminate JSONL reader. |
| `error` | CLI-level failure. | Set `final_state="cli_failed"`; do NOT auto-fall-back to PR-bot. |

## finding event fields

Measured against **CLI 0.6.5** on a live run (issue #105). A `finding` carries exactly these five keys and no others:

| Field | Type | Notes |
|-------|------|-------|
| `type` | string | Always `"finding"` for this event. |
| `severity` | string lowercase | One of `critical` / `major` / `minor` / `trivial` / `info`. |
| `fileName` | string | Repo-relative path. Maps to `path` in the unified record. |
| `codegenInstructions` | string | Imperative guidance for an agent, and the ONLY carrier of position: `around lines 11 - 23`, `at line 4`. Treated as untrusted per `references/sanitization-rules.md`. |
| `suggestions[]` | array of **strings** | Raw patch text, not objects. Often `[]`. |

Three keys the parser once assumed are **absent in 0.6.x**: `comment`, `location`, `line`.

- `body` therefore falls back to `codegenInstructions`; without it the Step 9a table renders empty rows.
- `line` is parsed out of `codegenInstructions`. `suggestions[0].line` is still tried first for 0.5.x compatibility, but only after a `type == "object"` guard — indexing a patch string with `.line` aborts jq (`Cannot index string with string "line"`) and, because the slurp path and the per-line fallback shared the expression, took the fallback down with it.
- `type_emoji` stays `null`, so `classify-item.sh` falls through to its severity-only branch. That means a `minor` CLI finding with no `Refactor` header lands in the `review` tier (surfaced, not applied) — a known consequence, not a bug in the parser.

**jq gotcha, load-bearing here**: `capture()` on a non-match yields *no output*. It does not throw and it does not return null, so `try capture(...) catch null` still yields `empty` — and an `empty` anywhere inside an object constructor makes the entire object disappear. A finding with no line hint was silently dropped from the array. The parser wraps every `capture()` in `first_or_null(f): ([ f? ] | .[0])`.

## Record projection (Step 8d)

```text
finding event {              # CLI 0.6.5
  type: "finding",
  severity: "major",
  fileName: "src/foo.py",
  codegenInstructions: "In @src/foo.py around lines 11 - 23, ...",
  suggestions: ["<patch text>"]
}
↓  scripts/parse-cr-cli-jsonl.sh
record {
  source: "cli",
  path: "src/foo.py",
  line: 11,                  // suggestions[0].line if object, else parsed from codegenInstructions
  severity_emoji: "🟠 Major",
  type_emoji: null,          // no `comment` -> severity-only tier classification
  body: <codegenInstructions>,
  guidance: <codegenInstructions>,
  comment_id: null           // CLI has no GitHub comment id
}
```

## Regression fixtures

`tests/fixtures/cr-cli-0.6.5-findings.jsonl` (captured from a real run, string `suggestions`) and
`tests/fixtures/cr-cli-0.5.x-findings.jsonl` (object `suggestions`, `comment` present) pin both
schemas. `tests/run-tests.sh` asserts the parser exits 0 and projects both. This path only executes
when the PR-bot has already failed, so without the fixtures nothing exercises it.
