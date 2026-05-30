# CodeRabbit CLI JSONL Schema

`coderabbit review --agent` (v0.5.x) streams newline-delimited JSON to stdout. Each line is one event with a discriminator field `type`. The parser in `scripts/parse-cr-cli-jsonl.sh` filters to `type == "finding"` and projects each finding into the same record schema as the PR-bot GraphQL path so Step 9a tier classification can treat both uniformly.

## Event types observed

| `type` | Purpose | Action |
|--------|---------|--------|
| `review_context` | Initial metadata: base / head SHA, file count. | Log line count only; don't propagate. |
| `status` | Progress markers (e.g. "analyzing X.py"). | Ignore. |
| `heartbeat` | Keep-alive. | Ignore (used by Monitor). |
| `finding` | Single actionable review item. | Project to record (see below). |
| `complete` | Final summary, exit imminent. | Terminate JSONL reader. |
| `error` | CLI-level failure. | Set `final_state="cli_failed"`; do NOT auto-fall-back to PR-bot. |

## finding event fields (per CR Skills docs)

| Field | Type | Notes |
|-------|------|-------|
| `severity` | string lowercase | One of `critical` / `major` / `minor` / `trivial` / `info`. |
| `fileName` | string | Repo-relative path. Maps to `path` in the unified record. |
| `comment` | string Markdown | Display body. May contain `🤖 Prompt for AI Agents` block. |
| `codegenInstructions` | string | Imperative guidance for an agent. Treated as untrusted per `references/sanitization-rules.md`. |
| `suggestions[]` | array | Optional structured fix proposals. |

## TBD bindings (Phase A dry-run)

The following are reasonable defaults — confirm on first real `--cr-source cli` run and refine `scripts/parse-cr-cli-jsonl.sh`:

| Binding | Default | Verification path |
|---------|---------|-------------------|
| Source line field name | Try in order: `line` → `lineNumber` → `startLine` → `null` (file-level) | Inspect 1 `finding` event from a real CLI run. |
| Issue category header in `comment` | Regex `_([^_]+)_ \| _([^_]+)_` matching PR-bot pattern | If absent in CLI output, fall back to `category` / `type` field on finding object. |
| Severity → emoji mapping | `critical→🔴 Critical`, `major→🟠 Major`, `minor→🟡 Minor`, `trivial→🟢 Trivial`, `info→🟢 Info` | Lowercase per [CR Skills docs](https://docs.coderabbit.ai/cli/skills/). |
| Issue type (Bug / Refactor / Nitpick / etc) | Extract from `comment` first line emoji or fall back to `null` (treat as non-Bug, non-Security, severity-only classification) | If absent, tier table falls through to severity-only branch. |

When binding is uncertain, the parser logs `cr-cli-binding-unverified: <field>` once per run so the user knows to inspect.

## Record projection (Step 8d)

```text
finding event {
  severity: "major",
  fileName: "src/foo.py",
  comment: "...",
  codegenInstructions: "...",
  suggestions: [...]
}
↓
record {
  source: "cli",
  path: "src/foo.py",
  line: <best-effort from suggestions[0] or null>,
  severity_emoji: "🟠 Major",
  type_emoji: <best-effort from comment header or null>,
  body: <comment>,
  guidance: <codegenInstructions>,
  comment_id: null  // CLI has no GitHub comment id
}
```

The unified record matches what Step 9a expects from CR PR-bot threads (`source: "cr"`), so the tier classifier in `scripts/classify-item.sh` runs uniformly.

## Output stream notes

- One JSON object per line, but lines may span >8 KB. Read with `jq -c .` or `while IFS= read -r line` (NOT `read -n 8192`).
- `heartbeat` events arrive every ~5s. Useful for `Monitor` to confirm the process is alive without polling.
- `complete` is the only terminal-success event. If the process exits without emitting `complete`, treat as CLI failure regardless of exit code.

## References

- CR Skills CLI docs: https://docs.coderabbit.ai/cli/skills/
- CR CLI install: `curl -fsSL https://cli.coderabbit.ai/install.sh | sh` (or Homebrew on macOS).
- Auth: `coderabbit auth login` (interactive browser flow) or `CODERABBIT_TOKEN` env var (CI usage).
